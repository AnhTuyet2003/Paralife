const express = require('express');
const multer = require('multer');
const router = express.Router();
const storageController = require('../controllers/storageController');
const doiController = require('../controllers/doiController');
const verifyToken = require('../middleware/authMiddleware');
const { verifyTokenFlexible } = require('../middleware/authMiddleware');

// ✅ CẤU HÌNH MULTER VỚI MEMORY STORAGE & FILE SIZE LIMIT
const upload = multer({ 
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 50 * 1024 * 1024 // 50MB
  }
});

// ✅ ROUTES
// Upload file mới với quota check
router.post('/upload', verifyToken, upload.single('file'), storageController.uploadFile);

// Upload document (legacy - giữ lại để tương thích)
router.post('/upload-document', verifyToken, upload.single('file'), storageController.uploadDocument);

// Get items
router.get('/items', verifyToken, storageController.getItems);
router.get('/items/:item_id', verifyToken, storageController.getItemDetails);

// Stream cloud file (for PDF viewer) - accepts token in query param
router.get('/cloud-file/:item_id', verifyTokenFlexible, storageController.streamCloudFile);

// Folders
router.get('/folders', verifyToken, storageController.getAllFolders);
router.post('/create_folder', verifyToken, storageController.createFolder);

// Add by DOI/URL
router.post('/add_by_doi', verifyToken, doiController.processDOI);
router.post('/add_by_url', verifyToken, storageController.addByUrl);

// Move, Delete, Favorite, Update Metadata
router.patch('/items/:item_id/move', verifyToken, storageController.moveItem);
router.delete('/items/:item_id', verifyToken, storageController.deleteItem);
router.patch('/items/:item_id/favorite', verifyToken, storageController.toggleFavorite);
router.put('/items/:item_id/metadata', verifyToken, storageController.updateItemMetadata);

module.exports = router;