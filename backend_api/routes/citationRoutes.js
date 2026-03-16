const express = require('express');
const router = express.Router();
const citationController = require('../controllers/citationController');
const verifyToken = require('../middleware/authMiddleware');

/**
 * ===================================================
 * CITATION ROUTES - API TRÍCH DẪN & EXPORT
 * ===================================================
 */

// ✅ Get available citation styles
router.get('/styles', verifyToken, citationController.getCitationStyles);

// ✅ Generate citation for single item
router.get('/items/:item_id/cite', verifyToken, citationController.generateCitation);

// ✅ Export entire library
router.get('/export', verifyToken, citationController.exportLibrary);

// ✅ Plugin API: Search documents
router.get('/plugin/search', verifyToken, citationController.pluginSearch);

// ✅ Plugin API: Get highlights for item
router.get('/plugin/highlights/:item_id', verifyToken, citationController.pluginGetHighlights);

module.exports = router;
