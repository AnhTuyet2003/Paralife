const db = require('../config/db');
const { 
  GoogleDriveStrategy, 
  DropboxStrategy,
  OneDriveStrategy,
  LocalStorageStrategy 
} = require('../services/storageService');

/**
 * ===================================================
 * HELPER: QUẢN LÝ CLOUD STORAGE STRATEGY
 * ===================================================
 */

/**
 * Kiểm tra xem user có liên kết cloud storage nào không
 * Nếu có, trả về Strategy tương ứng
 * Nếu không, trả về LocalStorageStrategy
 */
async function getStorageStrategyForUser(userId) {
  try {
    // Step 1: Get user's storage preference
    const prefQuery = `
      SELECT preferred_storage 
      FROM users 
      WHERE firebase_uid = $1
    `;
    const prefResult = await db.query(prefQuery, [userId]);
    const preferredStorage = prefResult.rows.length > 0 
      ? (prefResult.rows[0].preferred_storage || 'auto')
      : 'auto';

    console.log(`🎯 [Strategy] User ${userId} preference: ${preferredStorage}`);

    // Step 2: If user prefers local, return local storage immediately
    if (preferredStorage === 'local') {
      console.log(`📦 [Strategy] User chose Local Storage`);
      return {
        strategy: new LocalStorageStrategy(),
        provider: 'local',
        requiresQuotaCheck: true
      };
    }

    // Step 3: Query cloud connections
    let query;
    let queryParams;

    if (preferredStorage === 'auto') {
      // Auto mode: get first active cloud connection (original behavior)
      query = `
        SELECT 
          provider,
          access_token,
          refresh_token,
          email,
          total_space_bytes,
          used_space_bytes
        FROM user_cloud_connections
        WHERE user_id = $1::TEXT AND is_active = true
        ORDER BY created_at DESC
        LIMIT 1
      `;
      queryParams = [userId];
    } else {
      // Specific provider mode: get that specific provider if active
      query = `
        SELECT 
          provider,
          access_token,
          refresh_token,
          email,
          total_space_bytes,
          used_space_bytes
        FROM user_cloud_connections
        WHERE user_id = $1::TEXT 
          AND provider = $2 
          AND is_active = true
        LIMIT 1
      `;
      queryParams = [userId, preferredStorage];
    }
    
    const result = await db.query(query, queryParams);
    
    // Step 4: Handle case when no connection found
    if (result.rows.length === 0) {
      if (preferredStorage !== 'auto') {
        console.log(`⚠️ [Strategy] User wants ${preferredStorage} but connection not found. Fallback to Local`);
      } else {
        console.log(`📦 [Strategy] User ${userId}: No cloud connection. Using Local Storage`);
      }
      return {
        strategy: new LocalStorageStrategy(),
        provider: 'local',
        requiresQuotaCheck: true
      };
    }
    
    const connection = result.rows[0];
    
    // Step 5: Return appropriate strategy based on provider
    switch (connection.provider) {
      case 'gdrive':
        console.log(`☁️ [Strategy] User ${userId}: Google Drive (${connection.email})`);
        return {
          strategy: new GoogleDriveStrategy({
            access_token: connection.access_token,
            refresh_token: connection.refresh_token,
            email: connection.email
          }),
          provider: 'gdrive',
          requiresQuotaCheck: false,
          cloudEmail: connection.email
        };
        
      case 'dropbox':
        console.log(`☁️ [Strategy] User ${userId}: Dropbox (${connection.email})`);
        return {
          strategy: new DropboxStrategy({
            access_token: connection.access_token,
            refresh_token: connection.refresh_token,
            email: connection.email
          }),
          provider: 'dropbox',
          requiresQuotaCheck: false,
          cloudEmail: connection.email
        };
        
      case 'onedrive':
        console.log(`☁️ [Strategy] User ${userId}: OneDrive (${connection.email})`);
        return {
          strategy: new OneDriveStrategy({
            access_token: connection.access_token,
            refresh_token: connection.refresh_token,
            email: connection.email
          }),
          provider: 'onedrive',
          requiresQuotaCheck: false,
          cloudEmail: connection.email
        };
        
      default:
        console.log(`⚠️ [Strategy] Unknown provider: ${connection.provider}. Fallback to Local`);
        return {
          strategy: new LocalStorageStrategy(),
          provider: 'local',
          requiresQuotaCheck: true
        };
    }
    
  } catch (error) {
    console.error(`❌ [Strategy] Get strategy error:`, error);
    
    // Fallback về Local nếu có lỗi
    return {
      strategy: new LocalStorageStrategy(),
      provider: 'local',
      requiresQuotaCheck: true
    };
  }
}

/**
 * Cập nhật thông tin used_space_bytes sau khi upload thành công
 */
async function updateCloudUsedSpace(userId, provider, additionalBytes) {
  try {
    if (provider === 'local') return; // Skip nếu là local storage
    
    const query = `
      UPDATE user_cloud_connections
      SET 
        used_space_bytes = used_space_bytes + $1,
        updated_at = NOW()
      WHERE user_id = $2::TEXT AND provider = $3 AND is_active = true
    `;
    
    await db.query(query, [additionalBytes, userId, provider]);
    console.log(`✅ [Strategy] Updated ${provider} used space: +${additionalBytes} bytes`);
    
  } catch (error) {
    console.error(`❌ [Strategy] Update used space error:`, error);
    // Không throw error để không ảnh hưởng upload flow
  }
}

module.exports = {
  getStorageStrategyForUser,
  updateCloudUsedSpace
};
