const db = require('../config/db');
const storageService = require('../services/storageService');

// Update API keys
const updateApiKeys = async (req, res) => {
  const { uid } = req.user;
  const { openai_key, gemini_key, use_own_key, active_provider } = req.body;

  try {
    const query = `
      UPDATE users 
      SET openai_key = $1, gemini_key = $2, use_own_key = $3, active_provider = $4
      WHERE firebase_uid = $5
      RETURNING user_id, email, use_own_key, active_provider
    `;
    const result = await db.query(query, [
      openai_key || null,
      gemini_key || null,
      use_own_key,
      active_provider,
      uid
    ]);

    res.status(200).json({ success: true, data: result.rows[0] });
  } catch (error) {
    console.error('❌ Update API Keys Error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

// Get key status
const getKeyStatus = async (req, res) => {
  const { uid } = req.user;

  try {
    const query = `
      SELECT 
        use_own_key, 
        active_provider,
        CASE WHEN openai_key IS NOT NULL THEN true ELSE false END as has_openai_key,
        CASE WHEN gemini_key IS NOT NULL THEN true ELSE false END as has_gemini_key
      FROM users 
      WHERE firebase_uid = $1
    `;
    const result = await db.query(query, [uid]);

    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }

    res.status(200).json({ success: true, data: result.rows[0] });
  } catch (error) {
    console.error('❌ Get Key Status Error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

// Upload avatar - ✅ FIX UPDATE QUERY
const uploadAvatar = async (req, res) => {
  const { uid } = req.user;
  const file = req.file;

  if (!file) {
    return res.status(400).json({ success: false, error: 'No file provided' });
  }

  try {
    const uploadResult = await storageService.uploadFile(file);

    let publicUrl = uploadResult.url
      .replace(/\\/g, '/')
      .replace('./uploads', '/uploads');

    if (!publicUrl.startsWith('/')) {
      publicUrl = '/' + publicUrl;
    }

    console.log(`📸 Uploading avatar for user ${uid}: ${publicUrl}`);

    // ✅ UPDATE BY firebase_uid
    const query = `
      UPDATE users 
      SET avatar_url = $1
      WHERE firebase_uid = $2
      RETURNING user_id, firebase_uid, email, full_name, avatar_url
    `;
    const result = await db.query(query, [publicUrl, uid]);

    if (result.rows.length === 0) {
      console.error(`❌ User not found: ${uid}`);
      return res.status(404).json({ success: false, error: 'User not found' });
    }

    console.log(`✅ Avatar updated in DB: ${result.rows[0].avatar_url}`);

    res.status(200).json({
      success: true,
      message: 'Avatar uploaded successfully',
      avatar_url: publicUrl,
      user: result.rows[0]
    });
  } catch (error) {
    console.error('❌ Upload Avatar Error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

// Update profile - ✅ FIX UPDATE QUERY
const updateProfile = async (req, res) => {
  const { uid } = req.user;
  const { full_name, is_dark_mode, enable_notifications, text_scale_factor } = req.body;

  console.log(`📝 Updating profile for user ${uid}:`, { full_name, is_dark_mode, enable_notifications, text_scale_factor });

  try {
    // ✅ UPDATE BY firebase_uid
    const query = `
      UPDATE users 
      SET 
        full_name = COALESCE($1, full_name),
        is_dark_mode = COALESCE($2, is_dark_mode),
        enable_notifications = COALESCE($3, enable_notifications),
        text_scale_factor = COALESCE($4, text_scale_factor)
      WHERE firebase_uid = $5
      RETURNING user_id, firebase_uid, email, full_name, avatar_url, is_dark_mode, enable_notifications, text_scale_factor
    `;
    const result = await db.query(query, [
      full_name || null,
      is_dark_mode !== undefined ? is_dark_mode : null,
      enable_notifications !== undefined ? enable_notifications : null,
      text_scale_factor !== undefined ? text_scale_factor : null,
      uid
    ]);

    if (result.rows.length === 0) {
      console.error(`❌ User not found: ${uid}`);
      return res.status(404).json({ success: false, error: 'User not found' });
    }

    console.log(`✅ Profile updated successfully:`, result.rows[0]);

    res.status(200).json({ success: true, data: result.rows[0] });
  } catch (error) {
    console.error('❌ Update Profile Error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

// Get profile - ✅ FIX RESPONSE FORMAT
const getProfile = async (req, res) => {
  const { uid } = req.user;

  try {
    const query = `
      SELECT 
        user_id, firebase_uid, email, full_name, 
        avatar_url,
        role,
        use_own_key, active_provider, is_dark_mode, enable_notifications, text_scale_factor,
        preferred_storage,
        created_at, last_login
      FROM users 
      WHERE firebase_uid = $1
    `;
    const result = await db.query(query, [uid]);

    if (result.rows.length === 0) {
      console.log(`⚠️ User ${uid} không tìm thấy. Đang tạo...`);
      
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
      
      const newResult = await db.query(query, [uid]);
      
      // ✅ TRẢ VỀ user OBJECT, KHÔNG PHẢI data
      return res.status(200).json({ 
        success: true, 
        user: newResult.rows[0] 
      });
    }

    // ✅ TRẢ VỀ user OBJECT
    res.status(200).json({ 
      success: true, 
      user: result.rows[0] 
    });
  } catch (error) {
    console.error('❌ Get Profile Error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

// Get storage preference
const getStoragePreference = async (req, res) => {
  const { uid } = req.user;

  try {
    const query = `
      SELECT preferred_storage
      FROM users 
      WHERE firebase_uid = $1
    `;
    const result = await db.query(query, [uid]);

    if (result.rows.length === 0) {
      return res.status(404).json({ 
        success: false, 
        error: 'User not found' 
      });
    }

    const preference = result.rows[0].preferred_storage || 'auto';

    res.status(200).json({ 
      success: true, 
      preferred_storage: preference
    });
  } catch (error) {
    console.error('❌ Get Storage Preference Error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

// Update storage preference
const updateStoragePreference = async (req, res) => {
  const { uid } = req.user;
  const { preferred_storage } = req.body;

  // Validate input
  const validOptions = ['auto', 'local', 'gdrive', 'dropbox', 'onedrive'];
  if (!preferred_storage || !validOptions.includes(preferred_storage)) {
    return res.status(400).json({ 
      success: false, 
      error: `Invalid storage preference. Must be one of: ${validOptions.join(', ')}` 
    });
  }

  try {
    const query = `
      UPDATE users 
      SET preferred_storage = $1
      WHERE firebase_uid = $2
      RETURNING preferred_storage
    `;
    const result = await db.query(query, [preferred_storage, uid]);

    if (result.rows.length === 0) {
      return res.status(404).json({ 
        success: false, 
        error: 'User not found' 
      });
    }

    console.log(`✅ Storage preference updated for user ${uid}: ${preferred_storage}`);

    res.status(200).json({ 
      success: true, 
      preferred_storage: result.rows[0].preferred_storage,
      message: 'Storage preference updated successfully'
    });
  } catch (error) {
    console.error('❌ Update Storage Preference Error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

module.exports = {
  updateApiKeys,
  getKeyStatus,
  uploadAvatar,
  updateProfile,
  getProfile,
  getStoragePreference,
  updateStoragePreference
};
