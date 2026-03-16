const express = require('express');
const multer = require('multer');
const router = express.Router();
const userController = require('../controllers/userController');
const verifyToken = require('../middleware/authMiddleware');

const upload = multer({ storage: multer.memoryStorage() });

router.post('/keys', verifyToken, userController.updateApiKeys);
router.get('/keys/status', verifyToken, userController.getKeyStatus);
router.post('/avatar', verifyToken, upload.single('file'), userController.uploadAvatar);
router.patch('/profile', verifyToken, userController.updateProfile);
router.get('/profile', verifyToken, userController.getProfile);

// Storage preference routes
router.get('/storage-preference', verifyToken, userController.getStoragePreference);
router.patch('/storage-preference', verifyToken, userController.updateStoragePreference);

// Debug: Test storage strategy
router.get('/test-storage-strategy', verifyToken, async (req, res) => {
  try {
    const { getStorageStrategyForUser } = require('../helpers/storageStrategyHelper');
    const result = await getStorageStrategyForUser(req.user.uid);
    res.json({
      success: true,
      user_id: req.user.uid,
      user_email: req.user.email,
      provider: result.provider,
      requiresQuotaCheck: result.requiresQuotaCheck,
      cloudEmail: result.cloudEmail || null,
      decoded_token: {
        uid: req.user.uid,
        email: req.user.email,
        name: req.user.name
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// 🔑 Debug: Get current Firebase token info (for testing)
router.get('/debug/token-info', verifyToken, (req, res) => {
  res.json({
    success: true,
    token_valid: true,
    user: {
      uid: req.user.uid,
      email: req.user.email,
      name: req.user.name,
      picture: req.user.picture
    },
    message: 'Token is valid and decoded successfully'
  });
});

module.exports = router;
