const express = require('express');
const router = express.Router();
const aiController = require('../controllers/aiController');
const verifyToken = require('../middleware/authMiddleware');

// ✅ POST /api/ai/suggest-tags
router.post('/suggest-tags', verifyToken, aiController.suggestTagsForDocument);

// ✅ POST /api/ai/paraphrase
router.post('/paraphrase', verifyToken, aiController.paraphraseTextAPI);

// ✅ POST /api/ai/critique
router.post('/critique', verifyToken, aiController.critiqueDocumentAPI);

module.exports = router;
