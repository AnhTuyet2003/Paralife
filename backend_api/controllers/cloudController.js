const db = require('../config/db');
const { google } = require('googleapis');
const { Dropbox } = require('dropbox');
const fetch = require('node-fetch');

/**
 * ===================================================
 * CLOUD CONTROLLER - Quản lý liên kết Cloud Providers
 * ===================================================
 */

// ✅ LẤY DANH SÁCH CLOUD PROVIDERS ĐÃ LIÊN KẾT
const getCloudStatus = async (req, res) => {
  const { uid } = req.user;

  try {
    console.log(`📊 Getting cloud status for user: ${uid}`);

    // Query danh sách các cloud đã liên kết
    const query = `
      SELECT 
        id,
        provider,
        email,
        total_space_bytes,
        used_space_bytes,
        is_active,
        created_at
      FROM user_cloud_connections
      WHERE user_id = $1::TEXT AND is_active = true
      ORDER BY created_at DESC
    `;
    
    const result = await db.query(query, [uid]);
    const connections = result.rows;

    // Đếm số file đã upload qua từng provider
    const providers = await Promise.all(
      connections.map(async (conn) => {
        const countQuery = `
          SELECT COUNT(*) as item_count
          FROM storage_items
          WHERE user_id = $1::TEXT AND provider = $2
        `;
        const countResult = await db.query(countQuery, [uid, conn.provider]);
        
        return {
          id: conn.id,
          provider: conn.provider,
          email: conn.email,
          total_space_bytes: conn.total_space_bytes,
          used_space_bytes: conn.used_space_bytes,
          item_count: parseInt(countResult.rows[0]?.item_count || 0),
          is_active: conn.is_active,
          created_at: conn.created_at
        };
      })
    );

    res.status(200).json({
      success: true,
      providers: providers
    });

  } catch (error) {
    console.error('❌ Get cloud status error:', error);
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
};

// ✅ SINH OAUTH URL CHO GOOGLE DRIVE
const getGoogleDriveAuthUrl = async (req, res) => {
  try {
    const oauth2Client = new google.auth.OAuth2(
      process.env.GOOGLE_CLIENT_ID,
      process.env.GOOGLE_CLIENT_SECRET,
      process.env.GOOGLE_REDIRECT_URI
    );

    // Scopes: Quyền truy cập Google Drive
    const scopes = [
      'https://www.googleapis.com/auth/drive.file', // Tạo và quản lý file
      'https://www.googleapis.com/auth/drive.readonly', // Đọc file
      'https://www.googleapis.com/auth/userinfo.email' // Lấy email
    ];

    const authUrl = oauth2Client.generateAuthUrl({
      access_type: 'offline', // Để có refresh_token
      scope: scopes,
      prompt: 'consent', // Force hiển thị màn hình consent
      state: req.user.uid // Truyền user_id qua state để xác thực callback
    });

    console.log(`🔗 Generated Google OAuth URL for user: ${req.user.uid}`);

    res.status(200).json({
      success: true,
      auth_url: authUrl,
      message: 'Open this URL in browser to authorize'
    });

  } catch (error) {
    console.error('❌ Generate Google auth URL error:', error);
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
};

// ✅ CALLBACK XỬ LÝ SAU KHI USER ỦY QUYỀN GOOGLE DRIVE
const googleDriveCallback = async (req, res) => {
  const { code, state } = req.query; // state = user_id

  if (!code || !state) {
    return res.status(400).json({ 
      success: false, 
      error: 'Missing authorization code or state' 
    });
  }

  try {
    const userId = state;
    console.log(`✅ Google OAuth callback for user: ${userId}`);

    const oauth2Client = new google.auth.OAuth2(
      process.env.GOOGLE_CLIENT_ID,
      process.env.GOOGLE_CLIENT_SECRET,
      process.env.GOOGLE_REDIRECT_URI
    );

    // Đổi authorization code → access_token & refresh_token
    const { tokens } = await oauth2Client.getToken(code);
    oauth2Client.setCredentials(tokens);

    // Lấy thông tin user từ Google
    const oauth2 = google.oauth2({ version: 'v2', auth: oauth2Client });
    const userInfo = await oauth2.userinfo.get();

    // Lấy thông tin Drive storage
    const drive = google.drive({ version: 'v3', auth: oauth2Client });
    const aboutResponse = await drive.about.get({ fields: 'storageQuota, user' });
    
    const totalBytes = parseInt(aboutResponse.data.storageQuota.limit || 0);
    const usedBytes = parseInt(aboutResponse.data.storageQuota.usage || 0);

    // Lưu vào database
    const query = `
      INSERT INTO user_cloud_connections 
      (user_id, provider, email, access_token, refresh_token, token_expires_at, total_space_bytes, used_space_bytes)
      VALUES ($1::TEXT, 'gdrive', $2, $3, $4, $5, $6, $7)
      ON CONFLICT (user_id, provider) 
      DO UPDATE SET
        email = EXCLUDED.email,
        access_token = EXCLUDED.access_token,
        refresh_token = EXCLUDED.refresh_token,
        token_expires_at = EXCLUDED.token_expires_at,
        total_space_bytes = EXCLUDED.total_space_bytes,
        used_space_bytes = EXCLUDED.used_space_bytes,
        is_active = true,
        updated_at = NOW()
      RETURNING *;
    `;

    const expiresAt = new Date(Date.now() + (tokens.expiry_date || 3600 * 1000));

    const result = await db.query(query, [
      userId,
      userInfo.data.email,
      tokens.access_token,
      tokens.refresh_token,
      expiresAt,
      totalBytes,
      usedBytes
    ]);

    console.log(`✅ Google Drive linked: ${userInfo.data.email} (${totalBytes} bytes total)`);

    // Redirect về Flutter app hoặc success page
    res.send(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>Liên kết thành công - Refmind</title>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
            text-align: center; 
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            margin: 0;
            display: flex;
            align-items: center;
            justify-content: center;
          }
          .container {
            background: white;
            border-radius: 16px;
            padding: 40px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            max-width: 500px;
          }
          .success-icon {
            font-size: 64px;
            margin-bottom: 20px;
            animation: bounceIn 0.6s;
          }
          @keyframes bounceIn {
            0% { transform: scale(0); }
            50% { transform: scale(1.1); }
            100% { transform: scale(1); }
          }
          .title { 
            color: #4CAF50; 
            font-size: 28px; 
            font-weight: bold;
            margin-bottom: 10px; 
          }
          .subtitle {
            color: #666;
            font-size: 16px;
            margin-bottom: 30px;
          }
          .info-card {
            background: #f5f5f5;
            border-radius: 8px;
            padding: 20px;
            margin: 20px 0;
            text-align: left;
          }
          .info-row {
            display: flex;
            justify-content: space-between;
            margin: 10px 0;
            color: #333;
          }
          .label { font-weight: bold; }
          .footer {
            color: #999;
            font-size: 14px;
            margin-top: 30px;
          }
          .close-btn {
            background: #667eea;
            color: white;
            border: none;
            border-radius: 8px;
            padding: 12px 30px;
            font-size: 16px;
            cursor: pointer;
            margin-top: 20px;
          }
          .close-btn:hover {
            background: #5568d3;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="success-icon">✅</div>
          <div class="title">Liên kết thành công!</div>
          <div class="subtitle">Google Drive đã được kết nối với Refmind</div>
          
          <div class="info-card">
            <div class="info-row">
              <span class="label">📧 Email:</span>
              <span>${userInfo.data.email}</span>
            </div>
            <div class="info-row">
              <span class="label">💾 Dung lượng:</span>
              <span>${(totalBytes / 1024 / 1024 / 1024).toFixed(2)} GB</span>
            </div>
            <div class="info-row">
              <span class="label">📦 Đã sử dụng:</span>
              <span>${(usedBytes / 1024 / 1024 / 1024).toFixed(2)} GB</span>
            </div>
          </div>

          <button class="close-btn" onclick="window.close()">Đóng cửa sổ này</button>
          
          <div class="footer">
            Quay lại ứng dụng Refmind và nhấn "Kiểm tra kết nối"<br>
            để hoàn tất thiết lập.
          </div>
        </div>
      </body>
      </html>
    `);

  } catch (error) {
    console.error('❌ Google Drive callback error:', error);
    res.status(500).send(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>Lỗi liên kết - Refmind</title>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
            text-align: center; 
            padding: 20px;
            background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
            min-height: 100vh;
            margin: 0;
            display: flex;
            align-items: center;
            justify-content: center;
          }
          .container {
            background: white;
            border-radius: 16px;
            padding: 40px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            max-width: 500px;
          }
          .error-icon { font-size: 64px; margin-bottom: 20px; }
          .title { 
            color: #f5576c; 
            font-size: 24px; 
            font-weight: bold;
            margin-bottom: 20px; 
          }
          .message {
            color: #666;
            font-size: 16px;
            margin: 20px 0;
            padding: 15px;
            background: #ffebee;
            border-radius: 8px;
          }
          .close-btn {
            background: #f5576c;
            color: white;
            border: none;
            border-radius: 8px;
            padding: 12px 30px;
            font-size: 16px;
            cursor: pointer;
            margin-top: 20px;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="error-icon">❌</div>
          <div class="title">Lỗi liên kết Google Drive</div>
          <div class="message">${error.message}</div>
          <p style="color: #999;">Vui lòng thử lại hoặc liên hệ hỗ trợ nếu lỗi vẫn tiếp diễn.</p>
          <button class="close-btn" onclick="window.close()">Đóng cửa sổ</button>
        </div>
      </body>
      </html>
    `);
  }
};

// ✅ XÓA LIÊN KẾT CLOUD PROVIDER
const disconnectCloudProvider = async (req, res) => {
  const { uid } = req.user;
  const { connection_id } = req.params;

  try {
    console.log(`🔌 Disconnecting cloud provider: ${connection_id}`);

    // DELETE record thay vì set is_active = false để user có thể link lại account khác
    const query = `
      DELETE FROM user_cloud_connections
      WHERE id = $1 AND user_id = $2::TEXT
      RETURNING *;
    `;

    const result = await db.query(query, [connection_id, uid]);

    if (result.rows.length === 0) {
      return res.status(404).json({ 
        success: false, 
        error: 'Connection not found' 
      });
    }

    console.log(`✅ Deleted cloud connection: ${result.rows[0].provider} (${result.rows[0].email})`);

    res.status(200).json({
      success: true,
      message: 'Cloud provider disconnected and removed',
      data: result.rows[0]
    });

  } catch (error) {
    console.error('❌ Disconnect cloud error:', error);
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
};

// ✅ SINH OAUTH URL CHO DROPBOX
const getDropboxAuthUrl = async (req, res) => {
  try {
    // Manual OAuth URL construction (no PKCE required)
    const params = new URLSearchParams({
      client_id: process.env.DROPBOX_CLIENT_ID,
      response_type: 'code',
      redirect_uri: process.env.DROPBOX_REDIRECT_URI,
      state: req.user.uid,
      token_access_type: 'offline', // Get refresh token
      force_reapprove: 'true'
    });

    const authUrl = `https://www.dropbox.com/oauth2/authorize?${params.toString()}`;

    console.log(`🔗 Generated Dropbox OAuth URL for user: ${req.user.uid}`);
    console.log(`📋 Auth URL: ${authUrl}`);

    res.status(200).json({
      success: true,
      auth_url: authUrl,
      message: 'Open this URL in browser to authorize'
    });

  } catch (error) {
    console.error('❌ Generate Dropbox auth URL error:', error);
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
};

const dropboxCallback = async (req, res) => {
  const { code, state } = req.query; // state = user_id

  if (!code || !state) {
    return res.status(400).json({ 
      success: false, 
      error: 'Missing authorization code or state' 
    });
  }

  try {
    const userId = state;
    console.log(`✅ Dropbox OAuth callback for user: ${userId}`);

    // Manual token exchange
    const tokenUrl = 'https://api.dropboxapi.com/oauth2/token';
    const params = new URLSearchParams({
      code: code,
      grant_type: 'authorization_code',
      client_id: process.env.DROPBOX_CLIENT_ID,
      client_secret: process.env.DROPBOX_CLIENT_SECRET,
      redirect_uri: process.env.DROPBOX_REDIRECT_URI
    });

    const tokenResponse = await fetch(tokenUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: params.toString()
    });

    if (!tokenResponse.ok) {
      const errorData = await tokenResponse.json();
      throw new Error(`Token exchange failed: ${JSON.stringify(errorData)}`);
    }

    const tokenData = await tokenResponse.json();
    const accessToken = tokenData.access_token;
    const refreshToken = tokenData.refresh_token;

    // Get user info and storage quota
    const dbx = new Dropbox({ accessToken });
    
    // Get account info
    const accountInfo = await dbx.usersGetCurrentAccount();
    const email = accountInfo.result.email;
    
    // Get space usage
    const spaceUsage = await dbx.usersGetSpaceUsage();
    const totalBytes = spaceUsage.result.allocation.allocated || 0;
    const usedBytes = spaceUsage.result.used || 0;

    // Lưu vào database
    const query = `
      INSERT INTO user_cloud_connections 
      (user_id, provider, email, access_token, refresh_token, total_space_bytes, used_space_bytes)
      VALUES ($1::TEXT, 'dropbox', $2, $3, $4, $5, $6)
      ON CONFLICT (user_id, provider) 
      DO UPDATE SET
        email = EXCLUDED.email,
        access_token = EXCLUDED.access_token,
        refresh_token = EXCLUDED.refresh_token,
        total_space_bytes = EXCLUDED.total_space_bytes,
        used_space_bytes = EXCLUDED.used_space_bytes,
        is_active = true,
        updated_at = NOW()
      RETURNING *;
    `;

    await db.query(query, [
      userId,
      email,
      accessToken,
      refreshToken,
      totalBytes,
      usedBytes
    ]);

    console.log(`✅ Dropbox linked: ${email} (${totalBytes} bytes total)`);

    // Success page
    res.send(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>Liên kết thành công - Refmind</title>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
            text-align: center; 
            padding: 20px;
            background: linear-gradient(135deg, #0061ff 0%, #60efff 100%);
            min-height: 100vh;
            margin: 0;
            display: flex;
            align-items: center;
            justify-content: center;
          }
          .container {
            background: white;
            border-radius: 16px;
            padding: 40px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            max-width: 500px;
          }
          .success-icon {
            font-size: 64px;
            margin-bottom: 20px;
            animation: bounceIn 0.6s;
          }
          @keyframes bounceIn {
            0% { transform: scale(0); }
            50% { transform: scale(1.1); }
            100% { transform: scale(1); }
          }
          .title { 
            color: #0061ff; 
            font-size: 28px; 
            font-weight: bold;
            margin-bottom: 10px; 
          }
          .subtitle {
            color: #666;
            font-size: 16px;
            margin-bottom: 30px;
          }
          .info-card {
            background: #f5f5f5;
            border-radius: 8px;
            padding: 20px;
            margin: 20px 0;
            text-align: left;
          }
          .info-row {
            display: flex;
            justify-content: space-between;
            margin: 10px 0;
            color: #333;
          }
          .label { font-weight: bold; }
          .footer {
            color: #999;
            font-size: 14px;
            margin-top: 30px;
          }
          .close-btn {
            background: #0061ff;
            color: white;
            border: none;
            border-radius: 8px;
            padding: 12px 30px;
            font-size: 16px;
            cursor: pointer;
            margin-top: 20px;
          }
          .close-btn:hover {
            background: #0052d9;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="success-icon">✅</div>
          <div class="title">Liên kết thành công!</div>
          <div class="subtitle">Dropbox đã được kết nối với Refmind</div>
          
          <div class="info-card">
            <div class="info-row">
              <span class="label">📧 Email:</span>
              <span>${email}</span>
            </div>
            <div class="info-row">
              <span class="label">💾 Dung lượng:</span>
              <span>${(totalBytes / 1024 / 1024 / 1024).toFixed(2)} GB</span>
            </div>
            <div class="info-row">
              <span class="label">📦 Đã sử dụng:</span>
              <span>${(usedBytes / 1024 / 1024 / 1024).toFixed(2)} GB</span>
            </div>
          </div>

          <button class="close-btn" onclick="window.close()">Đóng cửa sổ này</button>
          
          <div class="footer">
            Quay lại ứng dụng Refmind và nhấn "Kiểm tra kết nối"<br>
            để hoàn tất thiết lập.<br><br>
            <small>Cửa sổ sẽ tự động đóng sau 3 giây...</small>
          </div>
        </div>
        <script>
          // Auto-close after 3 seconds
          setTimeout(() => {
            window.close();
          }, 3000);
        </script>
      </body>
      </html>
    `);

  } catch (error) {
    console.error('❌ Dropbox callback error:', error);
    res.status(500).send(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>Lỗi liên kết - Refmind</title>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
            text-align: center; 
            padding: 20px;
            background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
            min-height: 100vh;
            margin: 0;
            display: flex;
            align-items: center;
            justify-content: center;
          }
          .container {
            background: white;
            border-radius: 16px;
            padding: 40px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            max-width: 500px;
          }
          .error-icon { font-size: 64px; margin-bottom: 20px; }
          .title { 
            color: #f5576c; 
            font-size: 24px; 
            font-weight: bold;
            margin-bottom: 20px; 
          }
          .message {
            color: #666;
            font-size: 16px;
            margin: 20px 0;
            padding: 15px;
            background: #ffebee;
            border-radius: 8px;
          }
          .close-btn {
            background: #f5576c;
            color: white;
            border: none;
            border-radius: 8px;
            padding: 12px 30px;
            font-size: 16px;
            cursor: pointer;
            margin-top: 20px;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="error-icon">❌</div>
          <div class="title">Lỗi liên kết Dropbox</div>
          <div class="message">${error.message}</div>
          <p style="color: #999;">Vui lòng thử lại hoặc liên hệ hỗ trợ nếu lỗi vẫn tiếp diễn.</p>
          <button class="close-btn" onclick="window.close()">Đóng cửa sổ</button>
        </div>
      </body>
      </html>
    `);
  }
};

// ✅ ONEDRIVE AUTH (PLACEHOLDER)
const getOneDriveAuthUrl = async (req, res) => {
  try {
    const tenant = process.env.ONEDRIVE_TENANT || 'common';
    const params = new URLSearchParams({
      client_id: process.env.ONEDRIVE_CLIENT_ID,
      response_type: 'code',
      redirect_uri: process.env.ONEDRIVE_REDIRECT_URI,
      response_mode: 'query',
      scope: 'Files.ReadWrite Files.ReadWrite.All User.Read offline_access',
      state: req.user.uid
    });

    const authUrl = `https://login.microsoftonline.com/${tenant}/oauth2/v2.0/authorize?${params.toString()}`;

    console.log(`🔗 Generated OneDrive OAuth URL for user: ${req.user.uid}`);
    console.log(`📋 Auth URL: ${authUrl}`);

    res.status(200).json({
      success: true,
      auth_url: authUrl,
      message: 'Open this URL in browser to authorize'
    });

  } catch (error) {
    console.error('❌ Generate OneDrive auth URL error:', error);
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
};

const oneDriveCallback = async (req, res) => {
  const { code, state, error: oauthError, error_description } = req.query;

  if (oauthError) {
    console.error('❌ OneDrive OAuth error:', oauthError, error_description);
    return res.status(400).send(`
      <!DOCTYPE html>
      <html>
      <head><title>Lỗi xác thực - Refmind</title></head>
      <body style="font-family: sans-serif; text-align: center; padding: 50px;">
        <h2>❌ Lỗi xác thực OneDrive</h2>
        <p>${error_description || oauthError}</p>
        <button onclick="window.close()">Đóng</button>
      </body>
      </html>
    `);
  }

  if (!code || !state) {
    return res.status(400).json({ 
      success: false, 
      error: 'Missing authorization code or state' 
    });
  }

  try {
    const userId = state;
    console.log(`✅ OneDrive OAuth callback for user: ${userId}`);

    // Exchange code for token
    const tenant = process.env.ONEDRIVE_TENANT || 'common';
    const tokenUrl = `https://login.microsoftonline.com/${tenant}/oauth2/v2.0/token`;
    
    const params = new URLSearchParams({
      client_id: process.env.ONEDRIVE_CLIENT_ID,
      client_secret: process.env.ONEDRIVE_CLIENT_SECRET,
      code: code,
      redirect_uri: process.env.ONEDRIVE_REDIRECT_URI,
      grant_type: 'authorization_code',
      scope: 'Files.ReadWrite Files.ReadWrite.All User.Read offline_access'
    });

    const tokenResponse = await fetch(tokenUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: params.toString()
    });

    if (!tokenResponse.ok) {
      const errorData = await tokenResponse.json();
      throw new Error(`Token exchange failed: ${JSON.stringify(errorData)}`);
    }

    const tokenData = await tokenResponse.json();
    const accessToken = tokenData.access_token;
    const refreshToken = tokenData.refresh_token;

    // Get user info from Microsoft Graph
    const userInfoResponse = await fetch('https://graph.microsoft.com/v1.0/me', {
      headers: {
        'Authorization': `Bearer ${accessToken}`
      }
    });

    if (!userInfoResponse.ok) {
      throw new Error('Failed to get user info from Microsoft Graph');
    }

    const userInfo = await userInfoResponse.json();
    const email = userInfo.mail || userInfo.userPrincipalName;

    // Get drive quota from Microsoft Graph
    const driveResponse = await fetch('https://graph.microsoft.com/v1.0/me/drive', {
      headers: {
        'Authorization': `Bearer ${accessToken}`
      }
    });

    if (!driveResponse.ok) {
      throw new Error('Failed to get drive info from Microsoft Graph');
    }

    const driveInfo = await driveResponse.json();
    const totalBytes = driveInfo.quota?.total || 0;
    const usedBytes = driveInfo.quota?.used || 0;

    // Save to database
    const query = `
      INSERT INTO user_cloud_connections 
      (user_id, provider, email, access_token, refresh_token, total_space_bytes, used_space_bytes)
      VALUES ($1::TEXT, 'onedrive', $2, $3, $4, $5, $6)
      ON CONFLICT (user_id, provider) 
      DO UPDATE SET
        email = EXCLUDED.email,
        access_token = EXCLUDED.access_token,
        refresh_token = EXCLUDED.refresh_token,
        total_space_bytes = EXCLUDED.total_space_bytes,
        used_space_bytes = EXCLUDED.used_space_bytes,
        is_active = true,
        updated_at = NOW()
      RETURNING *;
    `;

    await db.query(query, [
      userId,
      email,
      accessToken,
      refreshToken,
      totalBytes,
      usedBytes
    ]);

    console.log(`✅ OneDrive linked: ${email} (${totalBytes} bytes total)`);

    // Success page with OneDrive green branding
    res.send(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>Liên kết thành công - Refmind</title>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
            text-align: center; 
            padding: 20px;
            background: linear-gradient(135deg, #0078d4 0%, #107c41 100%);
            min-height: 100vh;
            margin: 0;
            display: flex;
            align-items: center;
            justify-content: center;
          }
          .container {
            background: white;
            border-radius: 16px;
            padding: 40px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            max-width: 500px;
          }
          .success-icon {
            font-size: 64px;
            margin-bottom: 20px;
            animation: bounceIn 0.6s;
          }
          @keyframes bounceIn {
            0% { transform: scale(0); }
            50% { transform: scale(1.1); }
            100% { transform: scale(1); }
          }
          .title { 
            color: #0078d4; 
            font-size: 28px; 
            font-weight: bold;
            margin-bottom: 10px; 
          }
          .subtitle {
            color: #666;
            font-size: 16px;
            margin-bottom: 30px;
          }
          .info-card {
            background: #f5f5f5;
            border-radius: 8px;
            padding: 20px;
            margin: 20px 0;
            text-align: left;
          }
          .info-row {
            display: flex;
            justify-content: space-between;
            margin: 10px 0;
            color: #333;
          }
          .label { font-weight: bold; }
          .footer {
            color: #999;
            font-size: 14px;
            margin-top: 30px;
          }
          .close-btn {
            background: #0078d4;
            color: white;
            border: none;
            border-radius: 8px;
            padding: 12px 30px;
            font-size: 16px;
            cursor: pointer;
            margin-top: 20px;
          }
          .close-btn:hover {
            background: #106ebe;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="success-icon">✅</div>
          <div class="title">Liên kết thành công!</div>
          <div class="subtitle">OneDrive đã được kết nối với Refmind</div>
          
          <div class="info-card">
            <div class="info-row">
              <span class="label">📧 Email:</span>
              <span>${email}</span>
            </div>
            <div class="info-row">
              <span class="label">💾 Dung lượng:</span>
              <span>${(totalBytes / 1024 / 1024 / 1024).toFixed(2)} GB</span>
            </div>
            <div class="info-row">
              <span class="label">📦 Đã sử dụng:</span>
              <span>${(usedBytes / 1024 / 1024 / 1024).toFixed(2)} GB</span>
            </div>
          </div>

          <button class="close-btn" onclick="window.close()">Đóng cửa sổ này</button>
          
          <div class="footer">
            Quay lại ứng dụng Refmind và nhấn "Kiểm tra kết nối"<br>
            để hoàn tất thiết lập.<br><br>
            <small>Cửa sổ sẽ tự động đóng sau 3 giây...</small>
          </div>
        </div>
        <script>
          // Auto-close after 3 seconds
          setTimeout(() => {
            window.close();
          }, 3000);
        </script>
      </body>
      </html>
    `);

  } catch (error) {
    console.error('❌ OneDrive callback error:', error);
    res.status(500).send(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>Lỗi liên kết - Refmind</title>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
            text-align: center; 
            padding: 20px;
            background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
            min-height: 100vh;
            margin: 0;
            display: flex;
            align-items: center;
            justify-content: center;
          }
          .container {
            background: white;
            border-radius: 16px;
            padding: 40px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            max-width: 500px;
          }
          .error-icon {
            font-size: 64px;
            margin-bottom: 20px;
          }
          .title { 
            color: #f5576c; 
            font-size: 28px; 
            font-weight: bold;
            margin-bottom: 10px; 
          }
          .error-message {
            color: #666;
            font-size: 14px;
            background: #f5f5f5;
            padding: 15px;
            border-radius: 8px;
            margin: 20px 0;
            word-break: break-word;
          }
          .close-btn {
            background: #f5576c;
            color: white;
            border: none;
            border-radius: 8px;
            padding: 12px 30px;
            font-size: 16px;
            cursor: pointer;
            margin-top: 20px;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="error-icon">❌</div>
          <div class="title">Không thể liên kết OneDrive</div>
          <div class="error-message">
            ${error.message || 'Đã xảy ra lỗi không xác định'}
          </div>
          <button class="close-btn" onclick="window.close()">Đóng cửa sổ này</button>
        </div>
      </body>
      </html>
    `);
  }
};

// ✅ REFRESH CLOUD QUOTA
const refreshCloudQuota = async (req, res) => {
  const { uid } = req.user;
  const { connection_id } = req.params;

  try {
    console.log(`🔄 Refreshing cloud quota: ${connection_id}`);

    const query = `
      SELECT provider, access_token, refresh_token
      FROM user_cloud_connections
      WHERE id = $1 AND user_id = $2::TEXT AND is_active = true
    `;

    const result = await db.query(query, [connection_id, uid]);

    if (result.rows.length === 0) {
      return res.status(404).json({ 
        success: false, 
        error: 'Connection not found' 
      });
    }

    const connection = result.rows[0];

    // TODO: Implement refresh logic cho từng provider
    // Giờ chỉ trả về placeholder
    res.status(200).json({
      success: true,
      message: 'Quota refresh not implemented yet',
      provider: connection.provider
    });

  } catch (error) {
    console.error('❌ Refresh quota error:', error);
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
};

module.exports = {
  getCloudStatus,
  getGoogleDriveAuthUrl,
  googleDriveCallback,
  disconnectCloudProvider: disconnectCloudProvider,
  disconnectCloud: disconnectCloudProvider, // Alias cho cloudRoutes
  getDropboxAuthUrl,
  dropboxCallback,
  getOneDriveAuthUrl,
  oneDriveCallback,
  refreshCloudQuota
};
