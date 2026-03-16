const axios = require('axios');
const db = require('../config/db');
const storageService = require('../services/storageService');
const { 
  getStorageStrategyForUser,
  updateCloudUsedSpace 
} = require('../helpers/storageStrategyHelper');
const FormData = require('form-data');

const QUOTA_LIMIT_BYTES = parseInt(process.env.STORAGE_QUOTA_BYTES || 314572800);
const AI_ENGINE_URL = process.env.AI_ENGINE_URL || 'http://localhost:8000';

// ===================================================
// HELPER: KIỂM TRA QUOTA
// ===================================================
async function checkUserQuota(uid, fileSize) {
  const quotaQuery = `
    SELECT COALESCE(SUM(size_bytes), 0) as total_used
    FROM storage_items
    WHERE user_id = $1::TEXT AND provider = 'local'
  `;
  const quotaResult = await db.query(quotaQuery, [uid]);
  const totalUsed = parseInt(quotaResult.rows[0]?.total_used || 0);

  if (totalUsed + fileSize > QUOTA_LIMIT_BYTES) {
    const usedMB = (totalUsed / 1024 / 1024).toFixed(2);
    const limitMB = (QUOTA_LIMIT_BYTES / 1024 / 1024).toFixed(2);
    const fileSizeMB = (fileSize / 1024 / 1024).toFixed(2);

    throw {
      status: 403,
      message: `Storage quota exceeded. Used ${usedMB}MB / ${limitMB}MB. File: ${fileSizeMB}MB`,
      used_mb: parseFloat(usedMB),
      limit_mb: parseFloat(limitMB)
    };
  }

  return totalUsed;
}

// ===================================================
// HELPER: PROCESS DOCUMENT THROUGH AI ENGINE
// ===================================================
async function processDocumentThroughAI(uid, metadata, pdfUrl = null, pdfBuffer = null) {
  console.log(`🤖 Processing document through AI Engine...`);
  
  // Get user's API keys
  const userResult = await db.query(`
    SELECT gemini_key, openai_key, use_own_key, active_provider 
    FROM users 
    WHERE firebase_uid = $1
  `, [uid]);

  let apiKey = process.env.GEMINI_API_KEY;
  let provider = 'gemini';

  if (userResult.rows.length > 0) {
    const userData = userResult.rows[0];
    if (userData.use_own_key && userData.active_provider === 'openai') {
      provider = 'openai';
      apiKey = userData.openai_key;
    } else if (userData.use_own_key) {
      apiKey = userData.gemini_key;
    }
  }

  // Strategy 1: If we have DOI, use process-doi endpoint (best option)
  if (metadata.doi) {
    console.log(`   📌 Using DOI: ${metadata.doi}`);
    try {
      const aiResponse = await axios.post(`${AI_ENGINE_URL}/process-doi`, {
        doi: metadata.doi,
        user_id: uid,
        parent_id: null,
        api_key: apiKey,
        provider: provider
      }, {
        timeout: 120000
      });

      if (aiResponse.data.success) {
        return {
          success: true,
          file_content: aiResponse.data.file_content,
          size_bytes: aiResponse.data.size_bytes,
          metadata: aiResponse.data.metadata,
          has_pdf: aiResponse.data.has_pdf,
          file_id: aiResponse.data.file_id
        };
      }
    } catch (error) {
      console.warn(`   ⚠️ DOI processing failed: ${error.message}`);
      // Continue to next strategy
    }
  }

  // Strategy 2: If we have PDF buffer, process it directly
  if (pdfBuffer) {
    console.log(`   📄 Processing PDF buffer (${pdfBuffer.length} bytes)`);
    try {
      const formData = new FormData();
      formData.append('file', pdfBuffer, {
        filename: `${metadata.title.substring(0, 50)}.pdf`,
        contentType: 'application/pdf'
      });
      formData.append('provider', provider);
      formData.append('api_key', apiKey);
      formData.append('extract_only', 'true'); // Only extract metadata, don't create embeddings yet

      const aiResponse = await axios.post(`${AI_ENGINE_URL}/extract-metadata`, formData, {
        headers: formData.getHeaders(),
        timeout: 120000
      });

      if (aiResponse.data.success) {
        // Merge AI-extracted metadata with our metadata
        const enrichedMetadata = {
          ...metadata,
          ...aiResponse.data.metadata,
          // Keep original if AI didn't find it
          title: aiResponse.data.metadata.title || metadata.title,
          authors: aiResponse.data.metadata.authors?.length > 0 
            ? aiResponse.data.metadata.authors 
            : metadata.authors
        };

        return {
          success: true,
          file_content: pdfBuffer.toString('hex'),
          size_bytes: pdfBuffer.length,
          metadata: enrichedMetadata,
          has_pdf: true
        };
      }
    } catch (error) {
      console.warn(`   ⚠️ PDF extraction failed: ${error.message}`);
    }
  }

  // Strategy 3: If we have PDF URL, download and process
  if (pdfUrl) {
    console.log(`   🔗 Downloading PDF from: ${pdfUrl}`);
    try {
      const pdfResponse = await axios.get(pdfUrl, {
        responseType: 'arraybuffer',
        timeout: 30000,
        maxContentLength: 50 * 1024 * 1024
      });

      const downloadedBuffer = Buffer.from(pdfResponse.data);
      console.log(`   ✅ Downloaded ${downloadedBuffer.length} bytes`);

      // Recursively process the downloaded PDF
      return await processDocumentThroughAI(uid, metadata, null, downloadedBuffer);
    } catch (error) {
      console.warn(`   ⚠️ PDF download failed: ${error.message}`);
    }
  }

  // Strategy 4: No PDF available, return metadata only
  console.log(`   📝 No PDF available - metadata only`);
  return {
    success: true,
    file_content: null,
    size_bytes: 0,
    metadata: metadata,
    has_pdf: false
  };
}

// ===================================================
// HELPER: SAVE TO STORAGE AND DATABASE
// ===================================================
async function saveDocumentToStorage(uid, processResult, metadata, itemType, parentId) {
  const { file_content, size_bytes, has_pdf } = processResult;
  
  // Always get storage strategy (for both PDF and metadata-only)
  const { strategy, provider: storageProvider, requiresQuotaCheck, cloudEmail } = 
    await getStorageStrategyForUser(uid);
  
  console.log(`   🎯 Storage: ${storageProvider}`);
  
  // If no PDF, create metadata-only entry with correct provider
  if (!has_pdf || !file_content) {
    console.log(`💾 Saving metadata-only document to ${storageProvider}...`);
    
    const itemData = {
      parent_id: parentId,
      name: metadata.title || 'Unknown Document',
      type: 'file',
      file_url: null,
      size_bytes: 0,
      provider: storageProvider,  // ✅ Use actual storage preference
      has_pdf: false,
      metadata: {
        ...metadata,
        source: itemType,
        cloud_email: cloudEmail || null  // ✅ Track cloud account
      }
    };

    const item = await storageService.createStorageItem(uid, itemData);
    return {
      success: true,
      item: item,
      has_pdf: false,
      message: `Document saved to ${storageProvider} (metadata only - no PDF available)`
    };
  }

  // If we have PDF, upload to storage
  console.log(`📤 Uploading PDF (${size_bytes} bytes)...`);

  // Check quota if local
  if (requiresQuotaCheck) {
    await checkUserQuota(uid, size_bytes);
  }

  // Convert hex to buffer
  const fileBuffer = Buffer.from(file_content, 'hex');

  // Create fake file object
  const fakeFile = {
    originalname: `${metadata.title.substring(0, 50)}.pdf`,
    buffer: fileBuffer,
    size: size_bytes,
    mimetype: 'application/pdf'
  };

  // Upload
  storageService.setStrategy(strategy);
  const uploadResult = await storageService.uploadFile(fakeFile);

  // Format URL
  let publicUrl;
  if (storageProvider === 'local') {
    publicUrl = uploadResult.url.replace(/\\/g, '/').replace('./uploads', '/uploads');
  } else {
    publicUrl = uploadResult.url;
  }

  // Save to database
  const itemData = {
    parent_id: parentId,
    name: metadata.title || 'Unknown Document',
    type: 'file',
    file_url: publicUrl,
    size_bytes: size_bytes,
    provider: storageProvider,
    has_pdf: true,
    metadata: {
      ...metadata,
      source: itemType,
      cloud_email: cloudEmail || null
    }
  };

  const item = await storageService.createStorageItem(uid, itemData);

  // Update cloud space if needed
  if (!requiresQuotaCheck) {
    await updateCloudUsedSpace(uid, storageProvider, size_bytes);
  }

  return {
    success: true,
    item: item,
    has_pdf: true,
    size_bytes: size_bytes,
    message: `Document saved successfully with PDF (${(size_bytes / 1024).toFixed(2)} KB)`
  };
}

// ===================================================
// HELPER: PARSE BIBTEX
// ===================================================
function parseBibTeX(content) {
  const entries = [];
  // Regex để match các entry @article{key, ...}
  const entryRegex = /@(\w+)\{([^,]+),\s*([\s\S]*?)\n\}/gm;
  let match;

  while ((match = entryRegex.exec(content)) !== null) {
    const entryType = match[1]; // article, book, etc.
    const citationKey = match[2];
    const fieldsStr = match[3];

    const entry = {
      type: entryType.toLowerCase(),
      citationKey: citationKey,
      title: '',
      authors: [],
      year: null,
      journal: '',
      doi: '',
      abstract: '',
      publisher: ''
    };

    // Parse các field
    const fieldRegex = /(\w+)\s*=\s*\{([^}]*)\}/g;
    let fieldMatch;

    while ((fieldMatch = fieldRegex.exec(fieldsStr)) !== null) {
      const fieldName = fieldMatch[1].toLowerCase();
      const fieldValue = fieldMatch[2].trim();

      switch (fieldName) {
        case 'title':
          entry.title = fieldValue;
          break;
        case 'author':
          // Split by 'and'
          entry.authors = fieldValue.split(' and ').map(a => a.trim());
          break;
        case 'year':
          entry.year = parseInt(fieldValue) || null;
          break;
        case 'journal':
          entry.journal = fieldValue;
          break;
        case 'doi':
          entry.doi = fieldValue;
          break;
        case 'abstract':
          entry.abstract = fieldValue;
          break;
        case 'publisher':
          entry.publisher = fieldValue;
          break;
      }
    }

    if (entry.title) {
      entries.push(entry);
    }
  }

  return entries;
}

// ===================================================
// HELPER: PARSE RIS
// ===================================================
function parseRIS(content) {
  const entries = [];
  const lines = content.split('\n');
  let currentEntry = null;

  for (const line of lines) {
    const trimmed = line.trim();
    
    if (trimmed.startsWith('TY  -')) {
      // Bắt đầu 1 entry mới
      if (currentEntry && currentEntry.title) {
        entries.push(currentEntry);
      }
      currentEntry = {
        type: trimmed.substring(6).trim().toLowerCase(),
        title: '',
        authors: [],
        year: null,
        journal: '',
        doi: '',
        abstract: '',
        publisher: ''
      };
    } else if (currentEntry) {
      if (trimmed.startsWith('TI  -')) {
        currentEntry.title = trimmed.substring(6).trim();
      } else if (trimmed.startsWith('T1  -')) {
        currentEntry.title = trimmed.substring(6).trim();
      } else if (trimmed.startsWith('AU  -') || trimmed.startsWith('A1  -')) {
        currentEntry.authors.push(trimmed.substring(6).trim());
      } else if (trimmed.startsWith('PY  -') || trimmed.startsWith('Y1  -')) {
        const yearMatch = trimmed.match(/\d{4}/);
        if (yearMatch) {
          currentEntry.year = parseInt(yearMatch[0]);
        }
      } else if (trimmed.startsWith('JO  -') || trimmed.startsWith('T2  -')) {
        currentEntry.journal = trimmed.substring(6).trim();
      } else if (trimmed.startsWith('DO  -')) {
        currentEntry.doi = trimmed.substring(6).trim();
      } else if (trimmed.startsWith('AB  -') || trimmed.startsWith('N2  -')) {
        currentEntry.abstract = trimmed.substring(6).trim();
      } else if (trimmed.startsWith('PB  -')) {
        currentEntry.publisher = trimmed.substring(6).trim();
      } else if (trimmed === 'ER  -') {
        // End of entry
        if (currentEntry.title) {
          entries.push(currentEntry);
        }
        currentEntry = null;
      }
    }
  }

  // Push last entry if exists
  if (currentEntry && currentEntry.title) {
    entries.push(currentEntry);
  }

  return entries;
}

// ===================================================
// API 1: IMPORT BY IDENTIFIER (ISBN, PMID, arXiv)
// ===================================================
const importByIdentifier = async (req, res) => {
  const { uid } = req.user;
  const { type, value, parent_id } = req.body;

  if (!type || !value) {
    return res.status(400).json({ 
      success: false, 
      error: 'Type and value are required' 
    });
  }

  try {
    console.log(`📝 Processing ${type.toUpperCase()}: ${value} for user ${uid}`);

    let metadata = {
      title: '',
      authors: [],
      year: null,
      doi: '',
      journal: '',
      abstract: '',
      publisher: '',
      identifier_type: type,
      identifier_value: value
    };

    let pdfUrl = null;
    let fileBuffer = null;
    let fileSize = 0;

    // ===================================================
    // SWITCH-CASE THEO TYPE
    // ===================================================
    switch (type.toLowerCase()) {
      case 'isbn':
        // ✅ Google Books API with retry logic
        console.log(`📚 Fetching from Google Books API...`);
        try {
          const googleBooksUrl = `https://www.googleapis.com/books/v1/volumes?q=isbn:${value}`;
          
          // Retry logic with exponential backoff for rate limiting
          let response = null;
          let lastError = null;
          const maxRetries = 3;
          
          for (let attempt = 1; attempt <= maxRetries; attempt++) {
            try {
              response = await axios.get(googleBooksUrl, { timeout: 10000 });
              break; // Success, exit retry loop
            } catch (err) {
              lastError = err;
              
              if (err.response?.status === 429 && attempt < maxRetries) {
                // Rate limited, wait and retry
                const waitTime = Math.pow(2, attempt) * 1000; // Exponential backoff: 2s, 4s, 8s
                console.log(`⏳ Rate limited. Retrying in ${waitTime/1000}s (attempt ${attempt}/${maxRetries})...`);
                await new Promise(resolve => setTimeout(resolve, waitTime));
              } else {
                throw err; // Other error or max retries reached
              }
            }
          }

          if (!response) {
            throw lastError;
          }

          if (response.data.totalItems > 0) {
            const book = response.data.items[0].volumeInfo;
            metadata.title = book.title || 'Unknown Title';
            metadata.authors = book.authors || [];
            metadata.year = book.publishedDate ? parseInt(book.publishedDate.substring(0, 4)) : null;
            metadata.publisher = book.publisher || '';
            metadata.abstract = book.description || '';
            metadata.isbn = value;

            console.log(`✅ Found book: ${metadata.title}`);
          } else {
            return res.status(404).json({ 
              success: false, 
              error: 'ISBN not found in Google Books' 
            });
          }
        } catch (error) {
          console.error('❌ Google Books API error:', error.message);
          
          if (error.response?.status === 429) {
            return res.status(429).json({ 
              success: false, 
              error: 'Google Books API rate limit exceeded. Please try again in a few minutes.',
              retry_after: 60 // seconds
            });
          }
          
          return res.status(500).json({ 
            success: false, 
            error: 'Failed to fetch from Google Books API. Please check the ISBN or try again later.' 
          });
        }
        break;

      case 'pmid':
        // ✅ PubMed E-utilities API
        console.log(`🧬 Fetching from PubMed API...`);
        try {
          // Step 1: Get article details
          const pubmedUrl = `https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=pubmed&id=${value}&retmode=json`;
          const response = await axios.get(pubmedUrl, { timeout: 10000 });

          if (response.data.result && response.data.result[value]) {
            const article = response.data.result[value];
            metadata.title = article.title || 'Unknown Title';
            metadata.authors = article.authors ? article.authors.map(a => a.name) : [];
            metadata.year = article.pubdate ? parseInt(article.pubdate.substring(0, 4)) : null;
            metadata.journal = article.fulljournalname || article.source || '';
            metadata.pmid = value;

            // Try to get DOI
            if (article.articleids) {
              const doiObj = article.articleids.find(id => id.idtype === 'doi');
              if (doiObj) {
                metadata.doi = doiObj.value;
              }
            }

            // Step 2: Get abstract
            try {
              const abstractUrl = `https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&id=${value}&retmode=xml`;
              const abstractResponse = await axios.get(abstractUrl, { timeout: 10000 });
              const abstractMatch = abstractResponse.data.match(/<AbstractText[^>]*>(.*?)<\/AbstractText>/s);
              if (abstractMatch) {
                metadata.abstract = abstractMatch[1].replace(/<[^>]*>/g, '').trim();
              }
            } catch (abstractError) {
              console.warn('⚠️ Could not fetch abstract:', abstractError.message);
            }

            console.log(`✅ Found article: ${metadata.title}`);
          } else {
            return res.status(404).json({ 
              success: false, 
              error: 'PMID not found in PubMed' 
            });
          }
        } catch (error) {
          console.error('❌ PubMed API error:', error.message);
          return res.status(500).json({ 
            success: false, 
            error: 'Failed to fetch from PubMed API. Network error.' 
          });
        }
        break;

      case 'arxiv':
        // ✅ arXiv API
        console.log(`🔬 Fetching from arXiv API...`);
        try {
          const arxivUrl = `http://export.arxiv.org/api/query?id_list=${value}`;
          const response = await axios.get(arxivUrl, { timeout: 10000 });

          // Parse XML response
          const titleMatch = response.data.match(/<title>(.*?)<\/title>/s);
          const summaryMatch = response.data.match(/<summary>(.*?)<\/summary>/s);
          const publishedMatch = response.data.match(/<published>(.*?)<\/published>/);
          const authorMatches = response.data.match(/<author>[\s\S]*?<name>(.*?)<\/name>[\s\S]*?<\/author>/g);

          if (titleMatch) {
            metadata.title = titleMatch[1].trim();
            metadata.abstract = summaryMatch ? summaryMatch[1].trim() : '';
            metadata.year = publishedMatch ? parseInt(publishedMatch[1].substring(0, 4)) : null;
            metadata.arxiv = value;

            if (authorMatches) {
              metadata.authors = authorMatches.map(match => {
                const nameMatch = match.match(/<name>(.*?)<\/name>/);
                return nameMatch ? nameMatch[1].trim() : '';
              });
            }

            // arXiv PDF URL
            pdfUrl = `https://arxiv.org/pdf/${value}.pdf`;

            console.log(`✅ Found arXiv paper: ${metadata.title}`);
          } else {
            return res.status(404).json({ 
              success: false, 
              error: 'arXiv ID not found' 
            });
          }
        } catch (error) {
          console.error('❌ arXiv API error:', error.message);
          return res.status(500).json({ 
            success: false, 
            error: 'Failed to fetch from arXiv API. Network error.' 
          });
        }
        break;

      default:
        return res.status(400).json({ 
          success: false, 
          error: `Unsupported identifier type: ${type}` 
        });
    }

    // ===================================================
    // STEP 2: PROCESS THROUGH AI ENGINE
    // ===================================================
    console.log(`\n🤖 Processing document through AI Engine...`);
    const processResult = await processDocumentThroughAI(uid, metadata, pdfUrl, fileBuffer);

    if (!processResult.success) {
      return res.status(500).json({
        success: false,
        error: 'Failed to process document through AI Engine'
      });
    }

    // Update metadata with AI-enriched data
    metadata = {
      ...metadata,
      ...processResult.metadata
    };

    // ===================================================
    // STEP 3: SAVE TO STORAGE AND DATABASE
    // ===================================================
    let cleanParentId = parent_id;
    if (cleanParentId === "null" || cleanParentId === "" || cleanParentId === undefined) {
      cleanParentId = null;
    }

    const saveResult = await saveDocumentToStorage(
      uid, 
      processResult, 
      metadata, 
      'identifier_import', 
      cleanParentId
    );

    console.log(`✅ Document saved: ${saveResult.item.id}`);

    // Calculate quota info
    let quotaInfo = null;
    if (saveResult.has_pdf) {
      const quotaQuery = `
        SELECT COALESCE(SUM(size_bytes), 0) as total_used
        FROM storage_items
        WHERE user_id = $1::TEXT AND provider = 'local'
      `;
      const quotaResult = await db.query(quotaQuery, [uid]);
      const totalUsed = parseInt(quotaResult.rows[0]?.total_used || 0);
      const usedMB = (totalUsed / 1024 / 1024).toFixed(2);
      const limitMB = (QUOTA_LIMIT_BYTES / 1024 / 1024).toFixed(2);

      quotaInfo = {
        used_mb: parseFloat(usedMB),
        limit_mb: parseFloat(limitMB),
        remaining_mb: parseFloat((limitMB - usedMB).toFixed(2)),
        percentage: parseFloat(((totalUsed / QUOTA_LIMIT_BYTES) * 100).toFixed(2))
      };
    }

    // Return response
    res.status(201).json({
      success: true,
      message: saveResult.message,
      data: saveResult.item,
      has_pdf: saveResult.has_pdf,
      quota: quotaInfo
    });

  } catch (error) {
    if (error.status === 403) {
      return res.status(403).json({
        success: false,
        error: error.message,
        used_mb: error.used_mb,
        limit_mb: error.limit_mb
      });
    }

    if (error.response?.status === 429) {
      return res.status(429).json({
        success: false,
        error: 'API rate limit exceeded. Please try again in a few minutes.',
        retry_after: 60
      });
    }

    console.error('❌ Import Error:', error);
    res.status(500).json({ 
      success: false, 
      error: error.message || 'Internal server error' 
    });
  }
};

// ===================================================
// API 2: IMPORT FROM FILE (.bib, .ris)
// ===================================================
const importFromFile = async (req, res) => {
  const { uid } = req.user;
  const { parent_id } = req.body;
  const file = req.file;

  if (!file) {
    return res.status(400).json({ 
      success: false, 
      error: 'No file provided' 
    });
  }

  const fileName = file.originalname.toLowerCase();
  if (!fileName.endsWith('.bib') && !fileName.endsWith('.ris')) {
    return res.status(400).json({ 
      success: false, 
      error: 'Only .bib and .ris files are supported' 
    });
  }

  try {
    console.log(`📂 Importing file: ${file.originalname} for user ${uid}`);

    const content = file.buffer.toString('utf-8');
    let entries = [];

    // Parse file based on extension
    if (fileName.endsWith('.bib')) {
      console.log(`📚 Parsing BibTeX file...`);
      entries = parseBibTeX(content);
    } else if (fileName.endsWith('.ris')) {
      console.log(`📄 Parsing RIS file...`);
      entries = parseRIS(content);
    }

    if (entries.length === 0) {
      return res.status(400).json({ 
        success: false, 
        error: 'No valid entries found in file. Check file format.' 
      });
    }

    console.log(`✅ Found ${entries.length} entries`);

    // Insert entries into database
    let cleanParentId = parent_id;
    if (cleanParentId === "null" || cleanParentId === "" || cleanParentId === undefined) {
      cleanParentId = null;
    }

    const insertedItems = [];
    const errors = [];

    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      console.log(`\n📄 Processing entry ${i + 1}/${entries.length}: ${entry.title}`);
      
      try {
        // Try to process through AI if entry has DOI
        if (entry.doi) {
          console.log(`   🔍 Entry has DOI: ${entry.doi} - processing through AI...`);
          try {
            const processResult = await processDocumentThroughAI(uid, entry, null, null);
            
            if (processResult.success) {
              const saveResult = await saveDocumentToStorage(
                uid,
                processResult,
                { ...entry, ...processResult.metadata },
                'file_import',
                cleanParentId
              );
              
              insertedItems.push(saveResult.item);
              console.log(`   ✅ Saved with ${saveResult.has_pdf ? 'PDF' : 'metadata only'}`);
              continue;
            }
          } catch (aiError) {
            console.warn(`   ⚠️ AI processing failed: ${aiError.message}, fallback to metadata only`);
          }
        }

        // Fallback: Save metadata only
        const fullMetadata = {
          ...entry,
          source: 'file_import',
          import_file: file.originalname
        };

        // ✅ Detect storage preference (don't hard-code 'local')
        const { provider: storageProvider, cloudEmail } = await getStorageStrategyForUser(uid);

        const itemData = {
          parent_id: cleanParentId,
          name: entry.title || 'Unknown Title',
          type: 'file',
          file_url: null,
          size_bytes: 0,
          provider: storageProvider,  // ✅ Use actual storage setting
          has_pdf: false,
          metadata: {
            ...fullMetadata,
            cloud_email: cloudEmail || null
          }
        };

        const item = await storageService.createStorageItem(uid, itemData);
        insertedItems.push(item);
        console.log(`   ✅ Saved metadata only to ${storageProvider}`);
      } catch (error) {
        console.error(`   ❌ Failed to insert entry: ${entry.title}`, error.message);
        errors.push({
          title: entry.title,
          error: error.message
        });
      }

      // Small delay to avoid overwhelming the system
      if (i < entries.length - 1 && entry.doi) {
        await new Promise(resolve => setTimeout(resolve, 1000)); // 1 second delay between DOI lookups
      }
    }

    res.status(201).json({
      success: true,
      message: `Imported ${insertedItems.length} out of ${entries.length} entries`,
      data: {
        total: entries.length,
        success: insertedItems.length,
        failed: errors.length,
        items: insertedItems,
        errors: errors
      }
    });

  } catch (error) {
    console.error('❌ File Import Error:', error);
    res.status(500).json({ 
      success: false, 
      error: error.message || 'Failed to parse file' 
    });
  }
};

// ===================================================
// API 3: MANUAL ENTRY
// ===================================================
const importManual = async (req, res) => {
  const { uid } = req.user;
  const { 
    title, 
    authors, 
    year, 
    publisher, 
    abstract, 
    journal,
    doi,
    item_type, 
    parent_id 
  } = req.body;

  if (!title) {
    return res.status(400).json({ 
      success: false, 
      error: 'Title is required' 
    });
  }

  try {
    console.log(`✍️ Manual entry: "${title}" for user ${uid}`);

    let cleanParentId = parent_id;
    if (cleanParentId === "null" || cleanParentId === "" || cleanParentId === undefined) {
      cleanParentId = null;
    }

    // Parse authors (comma-separated string to array)
    let authorsList = [];
    if (authors) {
      if (typeof authors === 'string') {
        authorsList = authors.split(',').map(a => a.trim()).filter(a => a);
      } else if (Array.isArray(authors)) {
        authorsList = authors;
      }
    }

    const metadata = {
      title: title,
      authors: authorsList,
      year: year ? parseInt(year) : null,
      publisher: publisher || '',
      abstract: abstract || '',
      journal: journal || '',
      doi: doi || '',
      item_type: item_type || 'article',
      source: 'manual_entry'
    };

    // ✅ If DOI is provided, try to find and process PDF
    if (doi && doi.trim()) {
      console.log(`   🔍 Manual entry has DOI: ${doi} - attempting to find PDF...`);
      try {
        const processResult = await processDocumentThroughAI(uid, metadata, null, null);
        
        if (processResult.success) {
          const saveResult = await saveDocumentToStorage(
            uid,
            processResult,
            { ...metadata, ...processResult.metadata },
            'manual_entry',
            cleanParentId
          );

          console.log(`✅ Manual entry saved with ${saveResult.has_pdf ? 'PDF' : 'metadata'}: ${saveResult.item.id}`);

          return res.status(201).json({
            success: true,
            message: saveResult.message,
            data: saveResult.item,
            has_pdf: saveResult.has_pdf
          });
        }
      } catch (aiError) {
        console.warn(`   ⚠️ Failed to find PDF for DOI: ${aiError.message}, saving metadata only`);
        // Continue to fallback
      }
    }

    // Fallback: Save metadata only (no DOI or PDF not found)
    // ✅ Detect storage preference (don't hard-code 'local')
    const { provider: storageProvider, cloudEmail } = await getStorageStrategyForUser(uid);

    const itemData = {
      parent_id: cleanParentId,
      name: title,
      type: 'file',
      file_url: null,
      size_bytes: 0,
      provider: storageProvider,  // ✅ Use actual storage setting
      has_pdf: false,
      metadata: {
        ...metadata,
        cloud_email: cloudEmail || null
      }
    };

    const item = await storageService.createStorageItem(uid, itemData);

    console.log(`✅ Manual entry saved (metadata only) to ${storageProvider}: ${item.id}`);

    res.status(201).json({
      success: true,
      message: 'Document created manually',
      data: item,
      has_pdf: false
    });

  } catch (error) {
    console.error('❌ Manual Entry Error:', error);
    res.status(500).json({ 
      success: false, 
      error: error.message || 'Internal server error' 
    });
  }
};

module.exports = {
  importByIdentifier,
  importFromFile,
  importManual,
  processDocumentThroughAI,  // ✅ Export for extension controller
  saveDocumentToStorage      // ✅ Export for extension controller
};
