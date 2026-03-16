const axios = require('axios');
const db = require('../config/db');
const storageService = require('../services/storageService');
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

  console.log(`📊 User ${uid} quota: ${totalUsed} / ${QUOTA_LIMIT_BYTES} bytes`);

  if (totalUsed + fileSize > QUOTA_LIMIT_BYTES) {
    const usedMB = (totalUsed / 1024 / 1024).toFixed(2);
    const limitMB = (QUOTA_LIMIT_BYTES / 1024 / 1024).toFixed(2);
    const fileSizeMB = (fileSize / 1024 / 1024).toFixed(2);

    throw {
      status: 403,
      message: `Storage quota exceeded. Used ${usedMB}MB / ${limitMB}MB. File size: ${fileSizeMB}MB`,
      used_mb: parseFloat(usedMB),
      limit_mb: parseFloat(limitMB)
    };
  }

  return totalUsed;
}

const processDOI = async (req, res) => {
  const { uid } = req.user;
  const { doi, parent_id } = req.body;

  if (!doi) {
    return res.status(400).json({ success: false, error: 'DOI required' });
  }

  try {
    console.log(`📝 Processing DOI: ${doi} for user ${uid}`);

    // ✅ LẤY API KEY TỪ USER
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

    // ✅ GỌI AI ENGINE
    const aiEngineResponse = await axios.post('http://localhost:8000/process-doi', {
      doi,
      user_id: uid,
      parent_id: parent_id || null,
      api_key: apiKey,
      provider: provider
    }, {
      timeout: 120000 // 2 minutes
    });

    if (!aiEngineResponse.data.success) {
      return res.status(400).json({
        success: false,
        message: aiEngineResponse.data.message,
        metadata: aiEngineResponse.data.metadata
      });
    }

    const { 
      file_id, 
      file_content,  // Hex string
      size_bytes, 
      metadata,
      has_pdf,
      file_extension 
    } = aiEngineResponse.data;

    // ✅ XÁC ĐỊNH STORAGE STRATEGY (CLOUD hoặc LOCAL)
    const { strategy, provider: storageProvider, requiresQuotaCheck, cloudEmail } = await getStorageStrategyForUser(uid);
    console.log(`🎯 [DOI Controller] Selected strategy for user ${uid}: provider=${storageProvider}, requiresQuotaCheck=${requiresQuotaCheck}`);

    // ✅ KIỂM TRA QUOTA (chỉ khi dùng Local Storage và có PDF)
    if (has_pdf && requiresQuotaCheck) {
      await checkUserQuota(uid, size_bytes);
    } else if (!requiresQuotaCheck) {
      console.log(`☁️ Using cloud storage (${storageProvider}) - Skip local quota check`);
    }

    // ✅ CONVERT HEX STRING THÀNH BUFFER
    const fileBuffer = Buffer.from(file_content, 'hex');

    // ✅ TẠO FAKE FILE OBJECT
    const fileName = has_pdf 
      ? `${doi.replace(/\//g, '_')}.pdf`
      : `${doi.replace(/\//g, '_')}_abstract.txt`;

    const fakeFile = {
      originalname: fileName,
      buffer: fileBuffer,
      size: size_bytes,
      mimetype: has_pdf ? 'application/pdf' : 'text/plain'
    };

    // ✅ UPLOAD FILE BẰNG STRATEGY (Cloud hoặc Local)
    storageService.setStrategy(strategy);
    const uploadResult = await storageService.uploadFile(fakeFile);

    // ✅ FORMAT URL DỰA TRÊN PROVIDER
    let publicUrl;
    if (storageProvider === 'local') {
      // Local: Convert Windows path to URL path
      publicUrl = uploadResult.url
        .replace(/\\/g, '/')
        .replace('./uploads', '/uploads');
    } else {
      // Cloud: Giữ nguyên custom URL scheme (gdrive://, dropbox://, onedrive://)
      publicUrl = uploadResult.url;
    }

    console.log(`✅ Upload result: provider=${storageProvider}, url=${publicUrl}`);

    // ✅ CẬP NHẬT file_url TRONG DATABASE (với provider và URL phù hợp)
    await db.query(`
      UPDATE storage_items
      SET file_url = $1, size_bytes = $2, provider = $3
      WHERE id = $4::uuid AND user_id = $5::TEXT
    `, [publicUrl, size_bytes, storageProvider, file_id, uid]);

    console.log(`✅ DOI processed: ${file_id} (${has_pdf ? 'with PDF' : 'abstract only'})`);

    // ✅ TÍNH QUOTA (chỉ cho PDF)
    let quotaInfo = null;
    if (has_pdf) {
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

    res.status(200).json({
      success: true,
      message: has_pdf 
        ? `DOI processed successfully with PDF (${(size_bytes / 1024).toFixed(2)} KB)` 
        : `DOI processed - Closed access paper (abstract only)`,
      data: {
        file_id,
        file_url: publicUrl,
        size_bytes,
        has_pdf,
        metadata: {
          ...metadata,
          citation_count: metadata.citation_count || 0,
          keywords: metadata.keywords || [],
          source: metadata.source || 'crossref'
        }
      },
      quota: quotaInfo
    });

  } catch (error) {
    if (error.status === 403) {
      return res.status(403).json({
        success: false,
        error: 'Storage quota exceeded',
        ...error
      });
    }

    console.error('❌ DOI Processing Error:', error);
    res.status(500).json({ 
      success: false, 
      error: error.message || 'Unknown error' 
    });
  }
};

// ✅ INTERNAL ENDPOINT - Dành cho Python AI Engine (không cần Firebase auth)
const processDOIInternal = async (req, res) => {
  const { user_id, doi, parent_id } = req.body;

  if (!user_id || !doi) {
    return res.status(400).json({ success: false, error: 'user_id and doi required' });
  }

  try {
    console.log(`📝 [INTERNAL] Processing DOI: ${doi} for user ${user_id}`);

    // ✅ LẤY API KEY TỪ USER
    const userResult = await db.query(`
      SELECT gemini_key, openai_key, use_own_key, active_provider 
      FROM users 
      WHERE firebase_uid = $1
    `, [user_id]);

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

    // ✅ GỌI AI ENGINE
    const aiEngineResponse = await axios.post('http://localhost:8000/process-doi', {
      doi,
      user_id: user_id,
      parent_id: parent_id || null,
      api_key: apiKey,
      provider: provider
    }, {
      timeout: 120000
    });

    if (!aiEngineResponse.data.success) {
      return res.status(400).json({
        success: false,
        message: aiEngineResponse.data.message,
        metadata: aiEngineResponse.data.metadata
      });
    }

    const { 
      file_id, 
      file_content,
      size_bytes, 
      metadata,
      has_pdf,
      file_extension 
    } = aiEngineResponse.data;

    // ✅ XÁC ĐỊNH STORAGE STRATEGY
    const { strategy, provider: storageProvider, requiresQuotaCheck, cloudEmail } = await getStorageStrategyForUser(user_id);
    console.log(`🎯 [DOI Controller] Selected strategy for user ${user_id}: provider=${storageProvider}, requiresQuotaCheck=${requiresQuotaCheck}`);

    // ✅ KIỂM TRA QUOTA (chỉ khi dùng Local Storage và có PDF)
    if (has_pdf && requiresQuotaCheck) {
      await checkUserQuota(user_id, size_bytes);
    } else if (!requiresQuotaCheck) {
      console.log(`☁️ Using cloud storage (${storageProvider}) - Skip local quota check`);
    }

    // ✅ CONVERT HEX STRING THÀNH BUFFER
    const fileBuffer = Buffer.from(file_content, 'hex');

    const fileName = has_pdf 
      ? `${doi.replace(/\//g, '_')}.pdf`
      : `${doi.replace(/\//g, '_')}_abstract.txt`;

    const fakeFile = {
      originalname: fileName,
      buffer: fileBuffer,
      size: size_bytes,
      mimetype: has_pdf ? 'application/pdf' : 'text/plain'
    };

    // ✅ UPLOAD FILE BẰNG STRATEGY
    storageService.setStrategy(strategy);
    const uploadResult = await storageService.uploadFile(fakeFile);

    // ✅ FORMAT URL DỰA TRÊN PROVIDER
    let publicUrl;
    if (storageProvider === 'local') {
      // Local: Convert Windows path to URL path
      publicUrl = uploadResult.url
        .replace(/\\/g, '/')
        .replace('./uploads', '/uploads');
    } else {
      // Cloud: Giữ nguyên custom URL scheme (gdrive://, dropbox://, onedrive://)
      publicUrl = uploadResult.url;
    }

    console.log(`✅ Upload result: provider=${storageProvider}, url=${publicUrl}`);

    // ✅ CẬP NHẬT file_url TRONG DATABASE (với provider từ Strategy)
    await db.query(`
      UPDATE storage_items
      SET file_url = $1, size_bytes = $2, provider = $3
      WHERE id = $4::uuid AND user_id = $5::TEXT
    `, [publicUrl, size_bytes, storageProvider, file_id, user_id]);

    // ✅ CẬP NHẬT CLOUD USED SPACE (nếu dùng cloud)
    if (!requiresQuotaCheck && has_pdf) {
      await updateCloudUsedSpace(user_id, storageProvider, size_bytes);
    }

    console.log(`✅ [INTERNAL] DOI processed: ${file_id} (${has_pdf ? 'with PDF' : 'abstract only'}) → ${storageProvider.toUpperCase()}`);

    // ✅ TÍNH QUOTA (chỉ cho Local Storage)
    let quotaInfo = null;
    if (requiresQuotaCheck && has_pdf) {
      const quotaQuery = `
        SELECT COALESCE(SUM(size_bytes), 0) as total_used
        FROM storage_items
        WHERE user_id = $1::TEXT AND provider = 'local'
      `;
      const quotaResult = await db.query(quotaQuery, [user_id]);
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

    res.status(200).json({
      success: true,
      message: has_pdf 
        ? `DOI processed successfully with PDF (${(size_bytes / 1024).toFixed(2)} KB) → ${storageProvider.toUpperCase()}` 
        : `DOI processed - Closed access paper (abstract only) → ${storageProvider.toUpperCase()}`,
      data: {
        file_id,
        file_url: publicUrl,
        size_bytes,
        has_pdf,
        metadata: {
          ...metadata,
          citation_count: metadata.citation_count || 0,
          keywords: metadata.keywords || [],
          source: metadata.source || 'crossref',
          cloud_email: cloudEmail || null
        }
      },
      quota: quotaInfo,
      storage: {
        provider: storageProvider,
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

    console.error('❌ [INTERNAL] DOI Processing Error:', error);
    res.status(500).json({ 
      success: false, 
      error: error.message || 'Unknown error' 
    });
  }
};

module.exports = { processDOI, processDOIInternal };
