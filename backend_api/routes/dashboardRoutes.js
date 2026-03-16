const express = require('express');
const router = express.Router();
const dashboardController = require('../controllers/dashboardController');
const verifyToken = require('../middleware/authMiddleware');

router.get('/stats', verifyToken, dashboardController.getStats);
router.get('/overview', verifyToken, dashboardController.getOverview);

module.exports = router;
