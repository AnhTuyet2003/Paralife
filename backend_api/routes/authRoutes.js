const express = require('express');
const router = express.Router();
const verifyToken = require('../middleware/authMiddleware');
const { syncUser } = require('../controllers/authController');

// POST http://localhost:3000/api/auth/sync
router.post('/sync', verifyToken, syncUser);

module.exports = router;