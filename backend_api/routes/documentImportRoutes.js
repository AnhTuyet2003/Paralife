const express = require('express');
const multer = require('multer');
const router = express.Router();
const documentImportController = require('../controllers/documentImportController');
const verifyToken = require('../middleware/authMiddleware');

// ✅ CẤU HÌNH MULTER CHO FILE IMPORT (.bib, .ris)
const upload = multer({ 
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024 // 10MB (đủ cho file text)
  },
  fileFilter: (req, file, cb) => {
    const fileName = file.originalname.toLowerCase();
    if (fileName.endsWith('.bib') || fileName.endsWith('.ris')) {
      cb(null, true);
    } else {
      cb(new Error('Only .bib and .ris files are allowed'), false);
    }
  }
});

// ===================================================
// ROUTES
// ===================================================

// 1. Import by Identifier (ISBN, PMID, arXiv)
// POST /api/import/identifier
// Body: { type: 'isbn'|'pmid'|'arxiv', value: '...', parent_id: '...' }
router.post('/identifier', verifyToken, documentImportController.importByIdentifier);

// 2. Import from File (.bib, .ris)
// POST /api/import/file
// Form-data: file (multipart)
router.post('/file', verifyToken, upload.single('file'), documentImportController.importFromFile);

// 3. Manual Entry
// POST /api/import/manual
// Body: { title, authors, year, publisher, abstract, journal, doi, item_type, parent_id }
router.post('/manual', verifyToken, documentImportController.importManual);

module.exports = router;
