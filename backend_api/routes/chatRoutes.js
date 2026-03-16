const express = require('express');
const router = express.Router();
const chatController = require('../controllers/chatController');
const verifyToken = require('../middleware/authMiddleware');

router.post('/sessions', verifyToken, chatController.createSession);
router.post('/messages', verifyToken, chatController.sendMessage);
router.get('/messages/:session_id', verifyToken, chatController.getMessages);
router.post('/summary', verifyToken, chatController.getSummary);
router.post('/explain', verifyToken, chatController.explainTerm);
router.post('/compare', verifyToken, chatController.compareDocuments);

module.exports = router;