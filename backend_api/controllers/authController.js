const db = require('../config/db');

const syncUser = async (req, res) => {
  const { uid, email, name, picture } = req.user; 

  try {
    const query = `
      INSERT INTO users (firebase_uid, email, full_name, avatar_url, last_login)
      VALUES ($1, $2, $3, $4, NOW())
      ON CONFLICT (firebase_uid) 
      DO UPDATE SET 
        email = EXCLUDED.email,
        full_name = EXCLUDED.full_name,
        avatar_url = EXCLUDED.avatar_url,
        last_login = NOW()
      RETURNING *;
    `;

    const values = [uid, email, name || 'No Name', picture || ''];
    const result = await db.query(query, values);

    res.status(200).json({ 
      success: true, 
      message: 'User synced successfully!',
      data: result.rows[0]
    });
  } catch (error) {
    console.error("❌ Sync User Error:", error.message);
    res.status(500).json({ success: false, error: error.message });
  }
};

// ✅ THÊM MIDDLEWARE TỰ ĐỘNG SYNC USER
const autoSyncUser = async (req, res, next) => {
  if (!req.user || !req.user.uid) {
    return next();
  }

  try {
    const checkQuery = 'SELECT * FROM users WHERE firebase_uid = $1';
    const result = await db.query(checkQuery, [req.user.uid]);

    if (result.rows.length === 0) {
      console.log(`⚠️ User ${req.user.uid} không tồn tại. Đang tạo...`);
      
      await db.query(`
        INSERT INTO users (firebase_uid, email, full_name, avatar_url)
        VALUES ($1, $2, $3, $4)
        ON CONFLICT (firebase_uid) DO NOTHING
      `, [
        req.user.uid,
        req.user.email || `${req.user.uid}@temp.com`,
        req.user.name || 'Unnamed User',
        req.user.picture || ''
      ]);
      
      console.log(`✅ Đã tạo user ${req.user.uid}`);
    }
  } catch (error) {
    console.error('❌ Auto Sync User Error:', error.message);
  }

  next();
};

module.exports = { syncUser, autoSyncUser };