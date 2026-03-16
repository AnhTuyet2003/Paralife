const express = require('express');
const router = express.Router();
const verifyToken = require('../middleware/authMiddleware');
const {
  createHighlight,
  getHighlights,
  updateHighlight,
  deleteHighlight
} = require('../controllers/highlightController');

// ✅ HIGHLIGHT ROUTES

// Create highlight for an item
router.post('/items/:id/highlights', verifyToken, createHighlight);

// Get all highlights for an item
router.get('/items/:id/highlights', verifyToken, getHighlights);

// Update a specific highlight
router.put('/highlights/:highlightId', verifyToken, updateHighlight);

// Delete a specific highlight
router.delete('/highlights/:highlightId', verifyToken, deleteHighlight);

module.exports = router;
