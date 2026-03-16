const { Pool } = require('pg');

const pool = new Pool({
    user: process.env.DB_USER,
    host: process.env.DB_HOST,
    database: process.env.DB_NAME,
    password: process.env.DB_PASSWORD,
    port: process.env.DB_PORT,
});

// Log idle client errors to avoid silent process-level crashes.
pool.on('error', (err) => {
  console.error('❌ Unexpected PostgreSQL pool error:', err);
});

// Test kết nối
pool.connect((err, client, release) => {
  if (err) {
    console.error('❌ PostgreSQL connection error:', err.stack);
    // Không throw error để server vẫn chạy được
  } else {
    console.log('✅ PostgreSQL connected successfully!');
    release();
  }
});

module.exports = {
    query: (text, params) => pool.query(text, params),
    getClient: () => pool.connect() 
};