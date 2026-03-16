/**
 * Fact Check Routes
 * API endpoints for DOI validation and hallucination detection
 */

const express = require('express');
const router = express.Router();
const { factCheckDocument, validateSingleDOI } = require('../controllers/factCheckController');
const verifyToken = require('../middleware/authMiddleware');

// Apply authentication middleware to all routes
router.use(verifyToken);

/**
 * POST /api/items/:id/fact-check
 * Check all DOIs in a document
 */
router.post('/items/:id/fact-check', factCheckDocument);

/**
 * POST /api/fact-check/validate-doi
 * Validate a single DOI
 */
router.post('/fact-check/validate-doi', validateSingleDOI);

module.exports = router;
