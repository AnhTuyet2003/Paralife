const express = require('express');
const router = express.Router();
const doiController = require('../controllers/doiController');
const verifyToken = require('../middleware/authMiddleware');

// ✅ Route cho Flutter app (cần auth)
router.post('/process-doi', verifyToken, doiController.processDOI);

// ✅ Route cho Python AI Engine (internal, không cần auth)
router.post('/process-doi-internal', doiController.processDOIInternal);

module.exports = router;
