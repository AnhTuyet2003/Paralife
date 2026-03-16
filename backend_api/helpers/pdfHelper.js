const axios = require('axios');
const storageService = require('../services/storageService');

/**
 * ✅ HELPER: EXTRACT METADATA TỪ PDF
 * Gọi AI Engine để extract metadata từ PDF buffer
 */
async function extractMetadataFromPDF(fileBuffer, apiKey, provider = 'gemini') {
  try {
    console.log(`🔍 Extracting metadata from PDF (${fileBuffer.length} bytes)...`);

    const FormData = require('form-data');
    const formData = new FormData();
    formData.append('file', fileBuffer, { filename: 'document.pdf' });
    formData.append('provider', provider);
    formData.append('api_key', apiKey);
    formData.append('extract_only', 'true'); // ✅ Chỉ extract metadata, không tạo vector

    const response = await axios.post('http://localhost:8000/extract-metadata', formData, {
      headers: formData.getHeaders(),
      timeout: 60000 // 1 minute
    });

    if (response.data.success) {
      console.log(`✅ Metadata extracted:`, response.data.metadata);
      return response.data.metadata;
    } else {
      throw new Error(response.data.error || 'Failed to extract metadata');
    }
  } catch (error) {
    console.error(`❌ Extract metadata error:`, error.message);
    // Return default metadata nếu fail
    return {
      title: 'Untitled Document',
      authors: ['Unknown'],
      year: null,
      doi: null,
      journal: null,
      abstract: 'Could not extract metadata'
    };
  }
}

/**
 * ✅ HELPER: LƯU FILE VỚI METADATA VÀO DATABASE
 */
async function saveFileWithMetadata(uid, file, parentId, metadata, pdfBuffer) {
  // 1. Upload file vào /uploads
  const uploadResult = await storageService.uploadFile(file);

  const publicUrl = uploadResult.url
    .replace(/\\/g, '/')
    .replace('./uploads', '/uploads');

  let cleanParentId = parentId;
  if (cleanParentId === "null" || cleanParentId === "" || cleanParentId === undefined) {
    cleanParentId = null;
  }

  // 2. Merge metadata
  const fullMetadata = {
    mimetype: file.mimetype,
    ...metadata, // authors, year, doi, journal, abstract
    source: 'upload'
  };

  // 3. Lưu vào database
  const itemData = {
    parent_id: cleanParentId,
    name: metadata.title || file.originalname,
    type: 'file',
    file_url: publicUrl,
    size_bytes: uploadResult.size_bytes,
    provider: uploadResult.provider,
    has_pdf: true,
    metadata: fullMetadata
  };

  const item = await storageService.createStorageItem(uid, itemData);

  // 4. Background processing cho vector embeddings
  if (file.mimetype === 'application/pdf' && pdfBuffer) {
    processFileInBackground(item.id, uid, pdfBuffer);
  }

  return { item, uploadResult };
}

/**
 * ✅ HELPER: BACKGROUND PROCESSING CHO VECTOR EMBEDDINGS
 */
async function processFileInBackground(fileId, userId, fileBuffer) {
  const db = require('../config/db');
  
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
        }
      }
    }

    if (!apiKey || apiKey.trim() === '') {
      console.error(`❌ No valid API key for user ${userId}`);
      return;
    }

    const FormData = require('form-data');
    const formData = new FormData();
    formData.append('file', fileBuffer, { filename: 'document.pdf' });
    formData.append('provider', provider);
    formData.append('api_key', apiKey);
    formData.append('file_id', fileId);
    formData.append('user_id', userId);

    // ✅ TĂNG TIMEOUT & THÊM RETRY LOGIC
    let retryCount = 0;
    const maxRetries = 2;
    
    while (retryCount <= maxRetries) {
      try {
        await axios.post('http://localhost:8000/process-pdf', formData, {
          headers: formData.getHeaders(),
          timeout: 300000, // ✅ 5 phút (tăng từ 2 phút)
          maxContentLength: Infinity,
          maxBodyLength: Infinity
        });

        console.log(`✅ File ${fileId} vectors created`);
        return; // Success → exit
        
      } catch (axiosError) {
        if (axiosError.code === 'ECONNABORTED' && retryCount < maxRetries) {
          retryCount++;
          console.log(`⚠️ Timeout. Retry ${retryCount}/${maxRetries}...`);
          await new Promise(resolve => setTimeout(resolve, 5000)); // Wait 5s
        } else {
          throw axiosError; // Fail sau khi retry hết
        }
      }
    }
    
  } catch (error) {
    console.error(`❌ Background processing error:`, error.message);
    
    // ✅ LƯU LỖI VÀO DATABASE ĐỂ USER BIẾT
    try {
      await db.query(`
        UPDATE storage_items
        SET metadata = metadata || '{"processing_error": $1}'::jsonb
        WHERE id = $2::uuid
      `, [error.message, fileId]);
    } catch (dbError) {
      console.error(`❌ Failed to save error to DB:`, dbError.message);
    }
  }
}

module.exports = {
  extractMetadataFromPDF,
  saveFileWithMetadata,
  processFileInBackground
};
