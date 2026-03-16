const express = require('express');
const router = express.Router();
const cloudController = require('../controllers/cloudController');
const verifyToken = require('../middleware/authMiddleware');

/**
 * ===================================================
 * CLOUD ROUTES - API cho chức năng Cloud Storage
 * ===================================================
 */

// ✅ Lấy danh sách cloud providers đã liên kết
router.get('/status', verifyToken, cloudController.getCloudStatus);

// ✅ Google Drive OAuth flow
router.get('/gdrive/auth', verifyToken, cloudController.getGoogleDriveAuthUrl);
router.get('/gdrive/callback', cloudController.googleDriveCallback); // Không cần verifyToken vì dùng state

// ✅ Dropbox OAuth flow (placeholder)
router.get('/dropbox/auth', verifyToken, cloudController.getDropboxAuthUrl);
router.get('/dropbox/callback', cloudController.dropboxCallback);

// ✅ OneDrive OAuth flow
router.get('/onedrive/auth', verifyToken, cloudController.getOneDriveAuthUrl);
router.get('/onedrive/callback', cloudController.oneDriveCallback);

// ✅ Ngắt kết nối cloud
router.delete('/:connection_id', verifyToken, cloudController.disconnectCloud);

// ✅ Cập nhật thông tin storage quota (manual refresh)
router.post('/refresh/:connection_id', verifyToken, cloudController.refreshCloudQuota);

module.exports = router;
