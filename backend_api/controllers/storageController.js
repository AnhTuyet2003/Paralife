const storageService = require('../services/storageService');
const db = require('../config/db');
const { 
  extractMetadataFromPDF, 
  saveFileWithMetadata 
} = require('../helpers/pdfHelper');
const { 
  getStorageStrategyForUser,
  updateCloudUsedSpace 
} = require('../helpers/storageStrategyHelper');

const QUOTA_LIMIT_BYTES = parseInt(process.env.STORAGE_QUOTA_BYTES || 314572800);

// ✅ HELPER: KIỂM TRA QUOTA
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

// ✅ UPLOAD FILE VỚI METADATA EXTRACTION
const uploadFile = async (req, res) => {
  const { uid } = req.user;
  const { parent_id } = req.body;
  const file = req.file;

  if (!file) {
    return res.status(400).json({ success: false, error: 'No file provided' });
  }

  try {
    // ✅ BƯỚC 1: XÁC ĐỊNH STORAGE STRATEGY (Local hoặc Cloud)
    const { strategy, provider, requiresQuotaCheck, cloudEmail } = await getStorageStrategyForUser(uid);
    console.log(`🎯 [Storage Controller] Selected strategy for user ${uid}: provider=${provider}, requiresQuotaCheck=${requiresQuotaCheck}`);
    
    // ✅ BƯỚC 2: CHECK QUOTA (chỉ khi dùng Local Storage)
    let totalUsed = 0;
    if (requiresQuotaCheck) {
      totalUsed = await checkUserQuota(uid, file.size);
    } else {
      console.log(`☁️ Using cloud storage (${provider}) - Skip local quota check`);
    }

    // ✅ BƯỚC 3: EXTRACT METADATA (nếu là PDF)
    let metadata = {
      title: file.originalname,
      authors: [],
      year: null,
      doi: null,
      journal: null,
      abstract: null
    };

    if (file.mimetype === 'application/pdf') {
      // ✅ LẤY API KEY
      const userResult = await db.query(`
        SELECT gemini_key, openai_key, use_own_key, active_provider 
        FROM users 
        WHERE firebase_uid = $1
      `, [uid]);

      let apiKey = process.env.GEMINI_API_KEY;
      let aiProvider = 'gemini';

      if (userResult.rows.length > 0) {
        const userData = userResult.rows[0];
        if (userData.use_own_key && userData.active_provider === 'openai') {
          aiProvider = 'openai';
          apiKey = userData.openai_key;
        } else if (userData.use_own_key) {
          apiKey = userData.gemini_key;
        }
      }

      // ✅ EXTRACT METADATA
      if (apiKey && apiKey.trim() !== '') {
        metadata = await extractMetadataFromPDF(file.buffer, apiKey, aiProvider);
      }
    }

    // ✅ BƯỚC 4: UPLOAD FILE BẰNG STRATEGY
    storageService.setStrategy(strategy);
    const uploadResult = await storageService.uploadFile(file);

    const publicUrl = uploadResult.url.replace(/\\/g, '/').replace('./uploads', '/uploads');

    // ✅ BƯỚC 4.5: CHECK DUPLICATE (DOI or ISBN)
    if (metadata.doi || metadata.isbn) {
      const duplicateQuery = `
        SELECT id, name, metadata->>'doi' as doi, metadata->>'isbn' as isbn
        FROM storage_items
        WHERE user_id = $1::TEXT
          AND type = 'file'
          AND (
            (metadata->>'doi' IS NOT NULL AND metadata->>'doi' = $2)
            OR
            (metadata->>'isbn' IS NOT NULL AND metadata->>'isbn' = $3)
          )
        LIMIT 1
      `;
      const duplicateResult = await db.query(duplicateQuery, [
        uid,
        metadata.doi || null,
        metadata.isbn || null
      ]);

      if (duplicateResult.rows.length > 0) {
        const existingDoc = duplicateResult.rows[0];
        console.log(`⚠️ Duplicate detected: ${existingDoc.name} (${existingDoc.doi || existingDoc.isbn})`);
        
        return res.status(409).json({
          success: false,
          error: 'Document already exists in your library',
          duplicate: {
            id: existingDoc.id,
            name: existingDoc.name,
            doi: existingDoc.doi,
            isbn: existingDoc.isbn
          }
        });
      }
    }

    // ✅ BƯỚC 5: LƯU VÀO DATABASE
    let cleanParentId = parent_id;
    if (cleanParentId === "null" || cleanParentId === "" || cleanParentId === undefined) {
      cleanParentId = null;
    }

    const fullMetadata = {
      mimetype: file.mimetype,
      ...metadata,
      source: 'upload',
      cloud_email: cloudEmail || null
    };

    const itemData = {
      parent_id: cleanParentId,
      name: metadata.title || file.originalname,
      type: 'file',
      file_url: publicUrl,
      size_bytes: uploadResult.size_bytes,
      provider: provider,
      has_pdf: true,
      metadata: fullMetadata
    };

    const item = await storageService.createStorageItem(uid, itemData);

    // ✅ BƯỚC 6: CẬP NHẬT CLOUD USED SPACE (nếu dùng cloud)
    if (!requiresQuotaCheck) {
      await updateCloudUsedSpace(uid, provider, file.size);
    }

    // ✅ BƯỚC 7: BACKGROUND PROCESSING CHO VECTOR EMBEDDINGS
    if (file.mimetype === 'application/pdf') {
      const { processFileInBackground } = require('../helpers/pdfHelper');
      processFileInBackground(item.id, uid, file.buffer);
    }

    // ✅ BƯỚC 8: TÍNH QUOTA RESPONSE
    let quotaInfo = null;
    if (requiresQuotaCheck) {
      const newTotalUsed = totalUsed + file.size;
      const usedMB = (newTotalUsed / 1024 / 1024).toFixed(2);
      const limitMB = (QUOTA_LIMIT_BYTES / 1024 / 1024).toFixed(2);
      
      quotaInfo = {
        used_mb: parseFloat(usedMB),
        limit_mb: parseFloat(limitMB),
        remaining_mb: parseFloat((limitMB - usedMB).toFixed(2)),
        percentage: parseFloat(((newTotalUsed / QUOTA_LIMIT_BYTES) * 100).toFixed(2))
      };
    }

    res.status(200).json({
      success: true,
      message: `File uploaded successfully to ${provider === 'local' ? 'local storage' : provider.toUpperCase()}`,
      data: item,
      quota: quotaInfo,
      storage: {
        provider: provider,
        cloud_email: cloudEmail || null
      }
    });
    
  } catch (error) {
    if (error.status === 403) {
      return res.status(403).json({
        success: false,
        error: 'Storage quota exceeded',
        ...error
      });
    }
    console.error('❌ Upload Error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

// Upload document (legacy)
const uploadDocument = async (req, res) => {
  const { uid } = req.user;
  const { parent_id, has_pdf } = req.body;
  const file = req.file;

  if (!file) {
    return res.status(400).json({ success: false, error: 'No file provided' });
  }

  if (!uid) {
    return res.status(400).json({ success: false, error: 'User ID required' });
  }

  try {
    const uploadResult = await storageService.uploadFile(file);

    const publicUrl = uploadResult.url
      .replace(/\\/g, '/')
      .replace('./uploads', '/uploads');

    let cleanParentId = parent_id;
    if (cleanParentId === "null" || cleanParentId === "" || cleanParentId === undefined) {
      cleanParentId = null;
    }

    const itemData = {
      parent_id: cleanParentId,
      name: file.originalname,
      type: 'file',
      file_url: publicUrl,
      size_bytes: uploadResult.size_bytes,
      provider: uploadResult.provider,
      has_pdf: has_pdf === 'true' || has_pdf === true,
      metadata: { mimetype: file.mimetype }
    };

    const item = await storageService.createStorageItem(uid, itemData);

    // ✅ GỌI AI ENGINE ĐỂ XỬ LÝ PDF (ASYNC - KHÔNG CHỜ)
    if (file.mimetype === 'application/pdf') {
      processFileInBackground(item.id, uid, file.buffer);
    }

    res.status(201).json({
      success: true,
      message: 'File uploaded successfully',
      data: item
    });
  } catch (error) {
    console.error('❌ Upload Error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

// ✅ HÀM XỬ LÝ PDF TRONG BACKGROUND
async function processFileInBackground(fileId, userId, fileBuffer) {
  try {
    console.log(`🔄 Processing file ${fileId} in background...`);

    const userResult = await db.query(`
      SELECT gemini_key, openai_key, use_own_key, active_provider 
      FROM users 
      WHERE firebase_uid = $1
    `, [userId]);

    let apiKey = process.env.GEMINI_API_KEY;
    let provider = 'gemini';

    if (userResult.rows.length > 0) {
      const userData = userResult.rows[0];
      
      if (userData.use_own_key === true) {
        provider = userData.active_provider || 'gemini';
        const userKey = provider === 'openai' ? userData.openai_key : userData.gemini_key;
        
        if (userKey && userKey.trim() !== '') {
          apiKey = userKey;
          console.log(`   ✅ Using user's ${provider} API key`);
        } else {
          console.log(`   ⚠️ User enabled own key but key is empty, using system key`);
        }
      } else {
        console.log(`   ✅ Using system ${provider} API key`);
      }
    }

    if (!apiKey || apiKey.trim() === '' || apiKey === 'undefined') {
      console.error(`❌ No valid API key available for user ${userId}`);
      throw new Error('No API key configured');
    }

    console.log(`   🔑 API key length: ${apiKey.length} chars`);

    const FormData = require('form-data');
    const formData = new FormData();
    formData.append('file', fileBuffer, { filename: 'document.pdf' });
    formData.append('provider', provider);
    formData.append('api_key', apiKey);
    formData.append('file_id', fileId);
    formData.append('user_id', userId);

    await axios.post('http://localhost:8000/process-pdf', formData, {
      headers: formData.getHeaders(),
      timeout: 120000 // 2 minutes
    });

    console.log(`✅ File ${fileId} processed successfully`);
  } catch (error) {
    console.error(`❌ Background processing error for file ${fileId}:`, error.message);
  }
};

// Get items - ✅ SỬA CAST
const getItems = async (req, res) => {
  const { uid } = req.user;
  const { parent_id } = req.query;

  try {
    // ✅ TẠO USER NẾU CHƯA TỒN TẠI - CAST RÕ RÀNG
    const userCheck = await db.query('SELECT * FROM users WHERE firebase_uid = $1', [uid]);
    if (userCheck.rows.length === 0) {
      console.log(`⚠️ User ${uid} không tồn tại. Đang tạo...`);
      await db.query(`
        INSERT INTO users (firebase_uid, email, full_name, avatar_url)
        VALUES ($1::TEXT, $2::TEXT, $3::TEXT, $4::TEXT)
        ON CONFLICT (firebase_uid) DO NOTHING
      `, [
        uid,
        req.user.email || `${uid}@temp.com`,
        req.user.name || 'Unnamed User',
        req.user.picture || null
      ]);
    }

    const items = await storageService.getStorageItems(uid, parent_id || null);
    res.status(200).json(items);
  } catch (error) {
    console.error('❌ Get Items Error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

// Get item details
const getItemDetails = async (req, res) => {
  const { uid } = req.user;
  const { item_id } = req.params;

  try {
    // ✅ CAST user_id
    const query = 'SELECT * FROM storage_items WHERE id = $1 AND user_id = $2::TEXT';
    const result = await db.query(query, [item_id, uid]);

    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Item not found' });
    }

    res.status(200).json({ success: true, data: result.rows[0] });
  } catch (error) {
    console.error('❌ Get Item Details Error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

// Get all folders
const getAllFolders = async (req, res) => {
  const { uid } = req.user;

  try {
    // ✅ CAST user_id
    const query = `
      SELECT * FROM storage_items 
      WHERE user_id = $1::TEXT AND type = 'folder'
      ORDER BY name ASC
    `;
    const result = await db.query(query, [uid]);
    res.status(200).json(result.rows);
  } catch (error) {
    console.error('❌ Get Folders Error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

// Create folder
const createFolder = async (req, res) => {
  const { uid } = req.user;
  const { name, parent_id } = req.body;

  if (!name) {
    return res.status(400).json({ success: false, error: 'Folder name required' });
  }

  try {
    // ✅ Detect storage preference (folders should respect user's cloud settings too)
    const { provider: storageProvider, cloudEmail } = await getStorageStrategyForUser(uid);

    const itemData = {
      parent_id: parent_id || null,
      name,
      type: 'folder',
      file_url: null,
      size_bytes: 0,
      provider: storageProvider,  // ✅ Use actual storage setting
      has_pdf: false,
      metadata: {
        cloud_email: cloudEmail || null
      }
    };

    const folder = await storageService.createStorageItem(uid, itemData);
    res.status(201).json({ success: true, data: folder });
  } catch (error) {
    console.error('❌ Create Folder Error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

// Add by DOI
const addByDOI = async (req, res) => {
  const { uid } = req.user;
  const { doi, parent_id } = req.body;

  if (!doi) {
    return res.status(400).json({ success: false, error: 'DOI required' });
  }

  try {
    const itemData = {
      parent_id: parent_id || null,
      name: `Paper: ${doi}`,
      type: 'file',
      file_url: null,
      size_bytes: 0,
      provider: 'doi',
      has_pdf: false,
      metadata: { doi, source: 'crossref' }
    };

    const item = await storageService.createStorageItem(uid, itemData);
    res.status(201).json({ success: true, data: item });
  } catch (error) {
    console.error('❌ Add by DOI Error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

// Add by URL
const addByUrl = async (req, res) => {
  const { uid } = req.user;
  const { url, parent_id } = req.body;

  if (!url) {
    return res.status(400).json({ success: false, error: 'URL required' });
  }

  try {
    const itemData = {
      parent_id: parent_id || null,
      name: `Link: ${url.substring(0, 50)}`,
      type: 'file',
      file_url: url,
      size_bytes: 0,
      provider: 'url',
      has_pdf: false,
      metadata: { original_url: url }
    };

    const item = await storageService.createStorageItem(uid, itemData);
    res.status(201).json({ success: true, data: item });
  } catch (error) {
    console.error('❌ Add by URL Error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

// Move item
const moveItem = async (req, res) => {
  const { uid } = req.user;
  const { item_id } = req.params;
  const { new_parent_id } = req.body;

  try {
    // ✅ CAST user_id
    const query = `
      UPDATE storage_items 
      SET parent_id = $1, updated_at = NOW()
      WHERE id = $2 AND user_id = $3::TEXT
      RETURNING *
    `;
    const result = await db.query(query, [new_parent_id || null, item_id, uid]);

    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Item not found' });
    }

    res.status(200).json({ success: true, data: result.rows[0] });
  } catch (error) {
    console.error('❌ Move Item Error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

// Delete item
const deleteItem = async (req, res) => {
  const { uid } = req.user;
  const { item_id } = req.params;

  try {
    // ✅ CAST user_id
    const getQuery = 'SELECT * FROM storage_items WHERE id = $1 AND user_id = $2::TEXT';
    const getResult = await db.query(getQuery, [item_id, uid]);

    if (getResult.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Item not found' });
    }

    const item = getResult.rows[0];

    if (item.type === 'file' && item.file_url && item.provider === 'local') {
      await storageService.deleteFile(item.file_url);
    }

    const deletedItem = await storageService.deleteStorageItem(item_id, uid);

    res.status(200).json({
      success: true,
      message: 'Item deleted successfully',
      data: deletedItem
    });
  } catch (error) {
    console.error('❌ Delete Item Error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

// ✅ UPDATE ITEM METADATA
const updateItemMetadata = async (req, res) => {
  const { uid } = req.user;
  const { item_id } = req.params;
  const { title, authors, year, doi, isbn, publisher, abstract, tags, journal } = req.body;

  try {
    // ✅ VERIFY OWNERSHIP
    const ownershipQuery = `
      SELECT id, name, metadata FROM storage_items 
      WHERE id = $1 AND user_id = $2::TEXT
    `;
    const ownershipResult = await db.query(ownershipQuery, [item_id, uid]);

    if (ownershipResult.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Item not found or access denied' });
    }

    const currentItem = ownershipResult.rows[0];
    const currentMetadata = currentItem.metadata || {};

    // ✅ BUILD UPDATED METADATA (Merge với metadata hiện tại)
    const updatedMetadata = {
      ...currentMetadata,
      ...(title && { title }),
      ...(authors && { authors: typeof authors === 'string' ? authors.split(',').map(a => a.trim()) : authors }),
      ...(year && { year: parseInt(year) || year }),
      ...(doi && { doi }),
      ...(isbn && { isbn }),
      ...(publisher && { publisher }),
      ...(abstract && { abstract }),
      ...(tags && { tags: typeof tags === 'string' ? tags.split(',').map(t => t.trim()) : tags }),
      ...(journal && { journal })
    };

    // ✅ UPDATE STORAGE_ITEMS
    const updateQuery = `
      UPDATE storage_items
      SET 
        name = COALESCE($1, name),
        metadata = $2,
        updated_at = NOW()
      WHERE id = $3 AND user_id = $4::TEXT
      RETURNING *
    `;

    const result = await db.query(updateQuery, [
      title || currentItem.name,
      JSON.stringify(updatedMetadata),
      item_id,
      uid
    ]);

    console.log(`✅ Updated metadata for item ${item_id}`);

    res.status(200).json({
      success: true,
      message: 'Metadata updated successfully',
      data: result.rows[0]
    });

  } catch (error) {
    console.error('❌ Update Metadata Error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

// Toggle favorite
const toggleFavorite = async (req, res) => {
  const { uid } = req.user;
  const { item_id } = req.params;
  // ✅ LẤY is_favorite TỪ BODY HOẶC TOGGLE TỰ ĐỘNG
  let { is_favorite } = req.body;

  try {
    // ✅ NẾU KHÔNG TRUYỀN is_favorite → TOGGLE TỰ ĐỘNG
    if (is_favorite === undefined) {
      const getCurrentQuery = `
        SELECT is_favorite FROM storage_items 
        WHERE id = $1 AND user_id = $2::TEXT
      `;
      const currentResult = await db.query(getCurrentQuery, [item_id, uid]);
      
      if (currentResult.rows.length === 0) {
        return res.status(404).json({ success: false, error: 'Item not found' });
      }
      
      is_favorite = !currentResult.rows[0].is_favorite; // Toggle
    }

    // ✅ UPDATE
    const query = `
      UPDATE storage_items 
      SET is_favorite = $1, updated_at = NOW()
      WHERE id = $2 AND user_id = $3::TEXT
      RETURNING *
    `;
    const result = await db.query(query, [is_favorite, item_id, uid]);

    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Item not found' });
    }

    console.log(`✅ Toggled favorite for item ${item_id}: ${is_favorite}`);

    res.status(200).json({ 
      success: true, 
      message: is_favorite ? 'Added to favorites' : 'Removed from favorites',
      data: result.rows[0] 
    });
  } catch (error) {
    console.error('❌ Toggle Favorite Error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

// ✅ STREAM CLOUD FILE (for PDF viewer)
const streamCloudFile = async (req, res) => {
  const { uid } = req.user;
  const { item_id } = req.params;

  try {
    console.log(`📥 [Storage Controller] Stream request for item: ${item_id} by user: ${uid}`);

    // Get item details from database
    const query = `
      SELECT id, user_id, name, file_url, provider
      FROM storage_items
      WHERE id = $1 AND user_id = $2::TEXT AND type = 'file'
    `;
    const result = await db.query(query, [item_id, uid]);

    if (result.rows.length === 0) {
      console.log(`❌ [Storage Controller] File not found: ${item_id}`);
      return res.status(404).json({ success: false, error: 'File not found' });
    }

    const item = result.rows[0];
    const { file_url, provider, name } = item;
    
    console.log(`📄 [Storage Controller] File details: name=${name}, provider=${provider}, file_url=${file_url}`);

    // Check if file is on cloud storage
    if (provider === 'local') {
      console.log(`📦 [Storage Controller] Local file, redirecting to: ${file_url}`);
      return res.redirect(file_url);
    }

    // For cloud files, get the specific cloud connection for this provider
    console.log(`☁️ [Storage Controller] Cloud file detected, fetching ${provider} connection...`);
    
    const cloudQuery = `
      SELECT access_token, refresh_token, email
      FROM user_cloud_connections
      WHERE user_id = $1::TEXT AND provider = $2 AND is_active = true
      LIMIT 1
    `;
    const cloudResult = await db.query(cloudQuery, [uid, provider]);

    if (cloudResult.rows.length === 0) {
      console.log(`❌ [Storage Controller] No active ${provider} connection found for user ${uid}`);
      return res.status(403).json({ 
        success: false, 
        error: `No active ${provider} connection found. Please reconnect your ${provider} account.` 
      });
    }

    const connection = cloudResult.rows[0];
    console.log(`✅ [Storage Controller] Found ${provider} connection: ${connection.email}`);

    // Create strategy based on provider
    let strategy;
    const storageService = require('../services/storageService');
    
    switch (provider) {
      case 'gdrive':
        strategy = new storageService.GoogleDriveStrategy({
          access_token: connection.access_token,
          refresh_token: connection.refresh_token,
          email: connection.email
        });
        break;
      case 'dropbox':
        strategy = new storageService.DropboxStrategy({
          access_token: connection.access_token,
          refresh_token: connection.refresh_token,
          email: connection.email
        });
        break;
      case 'onedrive':
        strategy = new storageService.OneDriveStrategy({
          access_token: connection.access_token,
          refresh_token: connection.refresh_token,
          email: connection.email
        });
        break;
      default:
        console.log(`❌ [Storage Controller] Unknown provider: ${provider}`);
        return res.status(400).json({ success: false, error: `Unknown provider: ${provider}` });
    }

    console.log(`📥 [Storage Controller] Downloading file from ${provider}...`);
    
    // Download file from cloud
    const fileBuffer = await strategy.download(file_url);

    console.log(`✅ [Storage Controller] File downloaded successfully`);

    // Set headers
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `inline; filename="${encodeURIComponent(name)}"`);
    res.setHeader('Cache-Control', 'private, max-age=3600');
    
    // Handle different return types from download methods
    if (Buffer.isBuffer(fileBuffer)) {
      // Dropbox and OneDrive return Buffer
      console.log(`📤 [Storage Controller] Sending buffer (${fileBuffer.length} bytes)`);
      res.setHeader('Content-Length', fileBuffer.length);
      res.send(fileBuffer);
    } else if (fileBuffer && typeof fileBuffer.pipe === 'function') {
      // Google Drive returns Stream
      console.log(`📤 [Storage Controller] Piping stream`);
      fileBuffer.pipe(res);
    } else {
      throw new Error('Invalid file data format');
    }

    console.log(`✅ [Storage Controller] Successfully streamed: ${name}`);

  } catch (error) {
    console.error('❌ [Storage Controller] Stream Cloud File Error:', error);
    console.error('Error stack:', error.stack);
    
    if (res.headersSent) {
      // If headers already sent, just end the response
      res.end();
    } else {
      res.status(500).json({ 
        success: false, 
        error: error.message,
        details: process.env.NODE_ENV === 'development' ? error.stack : undefined
      });
    }
  }
};

module.exports = {
  uploadFile,
  uploadDocument,
  getItems,
  getItemDetails,
  getAllFolders,
  createFolder,
  addByDOI,
  addByUrl,
  moveItem,
  deleteItem,
  updateItemMetadata,
  toggleFavorite,
  streamCloudFile
};