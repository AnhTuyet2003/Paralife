/**
 * EXTENSION ROUTES
 * 
 * Routes for Refmind Web Clipper Chrome/Edge extension
 */

const express = require('express');
const router = express.Router();
const { getConfig, saveFromExtension } = require('../controllers/extensionController');
const verifyToken = require('../middleware/authMiddleware');

// ============================================
// PUBLIC ROUTES
// ============================================

/**
 * GET /api/extension/config
 * Get Firebase API key for extension authentication
 * No auth required
 */
router.get('/config', getConfig);

// ============================================
// PROTECTED ROUTES (require authentication)
// ============================================

/**
 * POST /api/extension/save
 * Save article/webpage from browser extension
 * Requires authentication (Bearer token)
 */
router.post('/save', verifyToken, saveFromExtension);

module.exports = router;
