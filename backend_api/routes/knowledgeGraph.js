/**
 * Knowledge Graph Routes
 * API endpoints for citation network visualization and AI suggestions
 */

const express = require('express');
const router = express.Router();
const { getKnowledgeGraph, getAIMissingLinks } = require('../controllers/knowledgeGraphController');
const verifyToken = require('../middleware/authMiddleware');

// Apply authentication middleware
router.use(verifyToken);

/**
 * GET /api/graph
 * Get knowledge graph (nodes + links)
 */
router.get('/graph', getKnowledgeGraph);

/**
 * GET /api/ai/missing-links
 * Get AI-suggested connections
 */
router.get('/ai/missing-links', getAIMissingLinks);

module.exports = router;
