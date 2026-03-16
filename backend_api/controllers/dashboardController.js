const db = require('../config/db');

// ✅ CONSTANTS
const STORAGE_QUOTA_BYTES = 300 * 1024 * 1024; // 300MB hard limit

// ✅ API 1: GET DASHBOARD STATISTICS (Usage, Articles, Topics)
const getStats = async (req, res) => {
  const { uid } = req.user;

  try {
    // ✅ 1. CALCULATE STORAGE USAGE
    const storageQuery = `
      SELECT COALESCE(SUM(size_bytes), 0) as used_bytes 
      FROM storage_items 
      WHERE user_id = $1::TEXT AND type = 'file'
    `;
    const storageResult = await db.query(storageQuery, [uid]);
    const usedBytes = parseInt(storageResult.rows[0]?.used_bytes || 0);
    const usagePercent = ((usedBytes / STORAGE_QUOTA_BYTES) * 100).toFixed(2);

    // ✅ 2. COUNT TOTAL ARTICLES
    const articlesQuery = `
      SELECT COUNT(*) as total_articles 
      FROM storage_items 
      WHERE user_id = $1::TEXT AND type = 'file'
    `;
    const articlesResult = await db.query(articlesQuery, [uid]);
    const totalArticles = parseInt(articlesResult.rows[0]?.total_articles || 0);

    // ✅ 3. TOPIC DISTRIBUTION (Group by tags in metadata)
    const topicsQuery = `
      SELECT 
        jsonb_array_elements_text(metadata->'tags') as topic,
        COUNT(*) as count
      FROM storage_items
      WHERE user_id = $1::TEXT 
        AND type = 'file'
        AND metadata ? 'tags'
        AND jsonb_array_length(metadata->'tags') > 0
      GROUP BY topic
      ORDER BY count DESC
      LIMIT 10
    `;
    const topicsResult = await db.query(topicsQuery, [uid]);
    const topicDistribution = topicsResult.rows.map(row => ({
      topic: row.topic,
      count: parseInt(row.count)
    }));

    res.status(200).json({
      success: true,
      stats: {
        used_bytes: usedBytes,
        total_bytes: STORAGE_QUOTA_BYTES,
        usage_percent: parseFloat(usagePercent),
        total_articles: totalArticles,
        topic_distribution: topicDistribution
      }
    });
  } catch (error) {
    console.error('❌ Get Stats Error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

const getOverview = async (req, res) => {
  const { uid } = req.user;

  try {
    // ✅ TẠO USER NẾU CHƯA TỒN TẠI
    const userCheck = await db.query('SELECT * FROM users WHERE firebase_uid = $1', [uid]);
    if (userCheck.rows.length === 0) {
      console.log(`⚠️ User ${uid} không tồn tại. Đang tạo...`);
      await db.query(`
        INSERT INTO users (firebase_uid, email, full_name, avatar_url)
        VALUES ($1, $2, $3, $4)
        ON CONFLICT (firebase_uid) DO NOTHING
      `, [
        uid,
        req.user.email || `${uid}@temp.com`,
        req.user.name || 'Unnamed User',
        req.user.picture || null
      ]);
    }

    // ✅ CAST user_id TRONG TẤT CẢ QUERY
    const filesQuery = `
      SELECT COUNT(*) as total_files 
      FROM storage_items 
      WHERE user_id = $1::TEXT AND type = 'file'
    `;
    const filesResult = await db.query(filesQuery, [uid]);

    const foldersQuery = `
      SELECT COUNT(*) as total_folders 
      FROM storage_items 
      WHERE user_id = $1::TEXT AND type = 'folder'
    `;
    const foldersResult = await db.query(foldersQuery, [uid]);

    const chatsQuery = `
      SELECT COUNT(*) as total_chats 
      FROM chat_sessions 
      WHERE user_id = $1::TEXT
    `;
    const chatsResult = await db.query(chatsQuery, [uid]);

    const storageQuery = `
      SELECT COALESCE(SUM(size_bytes), 0) as total_storage 
      FROM storage_items 
      WHERE user_id = $1::TEXT AND type = 'file'
    `;
    const storageResult = await db.query(storageQuery, [uid]);

    const favoritesQuery = `
      SELECT * FROM storage_items 
      WHERE user_id = $1::TEXT AND is_favorite = true
      ORDER BY updated_at DESC
      LIMIT 10
    `;
    const favoritesResult = await db.query(favoritesQuery, [uid]);

    const recentQuery = `
      SELECT * FROM storage_items 
      WHERE user_id = $1::TEXT AND type = 'file'
      ORDER BY created_at DESC
      LIMIT 10
    `;
    const recentResult = await db.query(recentQuery, [uid]);

    res.status(200).json({
      success: true,
      stats: {
        total_files: parseInt(filesResult.rows[0]?.total_files || 0),
        total_folders: parseInt(foldersResult.rows[0]?.total_folders || 0),
        total_chats: parseInt(chatsResult.rows[0]?.total_chats || 0),
        total_storage: parseInt(storageResult.rows[0]?.total_storage || 0)
      },
      favorites: favoritesResult.rows || [],
      recent_files: recentResult.rows || []
    });
  } catch (error) {
    console.error('❌ Get Overview Error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

module.exports = { getStats, getOverview };
