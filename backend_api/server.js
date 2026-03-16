// 1. KHỞI TẠO
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');

// ✅ IMPORT FIREBASE ADMIN NGAY SAU DOTENV
const admin = require('./config/firebase');

// Import DB
const db = require('./config/db');

const app = express();

// 3. MIDDLEWARE
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  exposedHeaders: ['Content-Length', 'Content-Type'],
  credentials: false
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// 4. ROUTES TEST CƠ BẢN
app.get('/', (req, res) => {
  res.json({ 
    message: 'Refmind API Gateway is running!', 
    status: 'healthy',
    database: 'PostgreSQL Local'
  });
});

// 5. CÁC ROUTES CHÍNH 
const authRoutes = require('./routes/authRoutes');
const userRoutes = require('./routes/userRoutes');
const storageRoutes = require('./routes/storageRoutes');
const dashboardRoutes = require('./routes/dashboardRoutes');
const chatRoutes = require('./routes/chatRoutes');
const doiRoutes = require('./routes/doiRoutes');
const cloudRoutes = require('./routes/cloudRoutes');
const documentImportRoutes = require('./routes/documentImportRoutes'); // ✅ THÊM
const extensionRoutes = require('./routes/extensionRoutes'); // ✅ WEB CLIPPER
const aiRoutes = require('./routes/aiRoutes'); // ✅ AI SUGGEST TAGS
const highlightRoutes = require('./routes/highlightRoutes'); // ✅ PDF HIGHLIGHTS
const citationRoutes = require('./routes/citationRoutes'); // ✅ CITATION & EXPORT
const factCheckRoutes = require('./routes/factCheck'); // ✅ FACT CHECK & DOI VALIDATION
const knowledgeGraphRoutes = require('./routes/knowledgeGraph'); // ✅ KNOWLEDGE GRAPH

app.use('/api/auth', authRoutes);
app.use('/api/user', userRoutes);
app.use('/api/storage', storageRoutes);
app.use('/api/dashboard', dashboardRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/doi', doiRoutes);
app.use('/api/cloud', cloudRoutes);
app.use('/api/import', documentImportRoutes); // ✅ THÊM
app.use('/api/extension', extensionRoutes); // ✅ WEB CLIPPER
app.use('/api/ai', aiRoutes); // ✅ AI SUGGEST TAGS
app.use('/api', highlightRoutes); // ✅ PDF HIGHLIGHTS
app.use('/api/citation', citationRoutes); // ✅ CITATION & EXPORT
app.use('/api', factCheckRoutes); // ✅ FACT CHECK
app.use('/api', knowledgeGraphRoutes); // ✅ KNOWLEDGE GRAPH

// Error middleware to centralize unexpected runtime errors.
app.use((err, req, res, next) => {
  console.error('❌ Unhandled Express Error:', err);
  if (res.headersSent) {
    return next(err);
  }
  res.status(err.status || 500).json({
    success: false,
    error: err.message || 'Internal server error'
  });
});

// Xử lý 404
app.use((req, res) => {
  res.status(404).json({ error: 'Endpoint not found', path: req.path });
});

// 6. KHỞI ĐỘNG SERVER (Đây là chốt chặn giữ server không bị tắt)
const PORT = process.env.PORT || 3000;
const server = app.listen(PORT, () => {
  console.log(`\n✅ Node.js API Gateway đang chạy tại http://localhost:${PORT}`);
});

process.on('unhandledRejection', (reason) => {
  console.error('❌ Unhandled Promise Rejection:', reason);
});

process.on('uncaughtException', (error) => {
  console.error('❌ Uncaught Exception:', error);
});

process.on('SIGTERM', () => {
  console.log('ℹ️ SIGTERM received, closing HTTP server...');
  server.close(() => {
    console.log('ℹ️ HTTP server closed.');
  });
});