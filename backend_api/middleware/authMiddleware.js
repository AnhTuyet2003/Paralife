const admin = require('../config/firebase'); // ✅ IMPORT TỪ CONFIG

// ✅ KIỂM TRA TOKEN VÀ TỰ ĐỘNG REFRESH
const verifyToken = async (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ 
      success: false, 
      error: 'Unauthorized',
      code: 'NO_TOKEN'
    });
  }

  const token = authHeader.split('Bearer ')[1];

  try {
    // ✅ VERIFY TOKEN
    const decodedToken = await admin.auth().verifyIdToken(token, true); // checkRevoked = true
    
    req.user = {
      uid: decodedToken.uid,
      email: decodedToken.email,
      name: decodedToken.name,
      picture: decodedToken.picture
    };

    next();
    
  } catch (error) {
    console.error('❌ Token verification error:', error.message);

    // ✅ KIỂM TRA LOẠI LỖI
    if (error.code === 'auth/id-token-expired') {
      return res.status(401).json({ 
        success: false, 
        error: 'Token expired. Please refresh.',
        code: 'TOKEN_EXPIRED',
        message: 'Your session has expired. Please sign in again.'
      });
    }

    if (error.code === 'auth/argument-error') {
      return res.status(401).json({ 
        success: false, 
        error: 'Invalid token format',
        code: 'INVALID_TOKEN'
      });
    }

    return res.status(401).json({ 
      success: false, 
      error: 'Invalid token',
      code: 'AUTH_ERROR',
      details: error.message
    });
  }
};

// ✅ VERIFY TOKEN FROM HEADER OR QUERY (for streaming endpoints)
const verifyTokenFlexible = async (req, res, next) => {
  // Try to get token from Authorization header first
  let token = null;
  const authHeader = req.headers.authorization;
  
  if (authHeader && authHeader.startsWith('Bearer ')) {
    token = authHeader.split('Bearer ')[1];
  } else if (req.query.token) {
    // Fallback to query parameter (for PDF viewer which can't set headers)
    token = req.query.token;
  }

  if (!token) {
    return res.status(401).json({ 
      success: false, 
      error: 'Unauthorized',
      code: 'NO_TOKEN'
    });
  }

  try {
    // ✅ VERIFY TOKEN
    const decodedToken = await admin.auth().verifyIdToken(token, true);
    
    req.user = {
      uid: decodedToken.uid,
      email: decodedToken.email,
      name: decodedToken.name,
      picture: decodedToken.picture
    };

    next();
    
  } catch (error) {
    console.error('❌ Token verification error:', error.message);

    if (error.code === 'auth/id-token-expired') {
      return res.status(401).json({ 
        success: false, 
        error: 'Token expired',
        code: 'TOKEN_EXPIRED'
      });
    }

    return res.status(401).json({ 
      success: false, 
      error: 'Invalid token',
      code: 'AUTH_ERROR'
    });
  }
};

module.exports = verifyToken;
module.exports.verifyTokenFlexible = verifyTokenFlexible;