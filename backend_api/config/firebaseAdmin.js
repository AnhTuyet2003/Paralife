const admin = require('firebase-admin');
const path = require('path');

// Kiểm tra xem Firebase Admin đã được khởi tạo chưa
if (!admin.apps.length) {
  try {
    // Đường dẫn tới file service account key
    const serviceAccountPath = path.join(__dirname, 'serviceAccountKey.json');
    
    const serviceAccount = require(serviceAccountPath);

    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });

    console.log('✅ Firebase Admin SDK initialized successfully');
  } catch (error) {
    console.error('❌ Firebase Admin SDK initialization error:', error.message);
    console.log('⚠️ Make sure serviceAccountKey.json exists in backend_api/config/');
  }
}

module.exports = admin;
