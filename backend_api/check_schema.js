// Check users table schema
const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
    user: process.env.DB_USER,
    host: process.env.DB_HOST,
    database: process.env.DB_NAME,
    password: process.env.DB_PASSWORD,
    port: process.env.DB_PORT,
});

async function checkSchema() {
    try {
        console.log('📋 Checking users table schema...\n');
        
        const result = await pool.query(`
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns 
            WHERE table_name = 'users'
            ORDER BY ordinal_position
        `);
        
        if (result.rows.length === 0) {
            console.log('❌ Table "users" does not exist!');
        } else {
            console.log('✅ Users table columns:');
            result.rows.forEach(col => {
                console.log(`   ${col.column_name}: ${col.data_type} ${col.is_nullable === 'NO' ? 'NOT NULL' : ''}`);
            });
        }
        
        console.log('\n📋 Checking storage_items table schema...\n');
        const items = await pool.query(`
            SELECT column_name, data_type 
            FROM information_schema.columns 
            WHERE table_name = 'storage_items'
            ORDER BY ordinal_position
            LIMIT 5
        `);
        
        console.log('✅ Storage_items table (first 5 columns):');
        items.rows.forEach(col => {
            console.log(`   ${col.column_name}: ${col.data_type}`);
        });
        
    } catch (error) {
        console.error('❌ Error:', error.message);
    } finally {
        await pool.end();
    }
}

checkSchema();
