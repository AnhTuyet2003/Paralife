const admin = require('firebase-admin');
const path = require('path');

// ✅ KHỞI TẠO FIREBASE ADMIN SDK
if (!admin.apps.length) {
  try {
    const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT || 
                               path.join(__dirname, '../config/serviceAccountKey.json');
    
    const serviceAccount = require(serviceAccountPath);
    
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    
    console.log('✅ Firebase Admin SDK initialized');
  } catch (error) {
    console.error('❌ Firebase Admin init error:', error.message);
    console.log('⚠️ Place serviceAccountKey.json in backend_api/config/');
  }
}

module.exports = admin;