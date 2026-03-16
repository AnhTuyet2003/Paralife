// Quick migration runner for highlights table
const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

const pool = new Pool({
    user: process.env.DB_USER,
    host: process.env.DB_HOST,
    database: process.env.DB_NAME,
    password: process.env.DB_PASSWORD,
    port: process.env.DB_PORT,
});

async function runMigration() {
    try {
        console.log('📦 Connecting to database...');
        console.log(`   Host: ${process.env.DB_HOST}`);
        console.log(`   Database: ${process.env.DB_NAME}`);
        console.log(`   User: ${process.env.DB_USER}`);
        
        const sqlPath = path.join(__dirname, '../database_setup/add_highlights_table.sql');
        const sql = fs.readFileSync(sqlPath, 'utf8');
        
        console.log('\n🔨 Running migration: add_highlights_table.sql');
        await pool.query(sql);
        
        console.log('✅ Migration completed successfully!');
        
        // Verify table was created
        const result = await pool.query(`
            SELECT column_name, data_type 
            FROM information_schema.columns 
            WHERE table_name = 'highlights'
            ORDER BY ordinal_position
        `);
        
        console.log('\n📋 Highlights table columns:');
        result.rows.forEach(col => {
            console.log(`   ✓ ${col.column_name}: ${col.data_type}`);
        });
        
        console.log('\n✨ Ready to use PDF highlights feature!');
        
    } catch (error) {
        console.error('\n❌ Migration failed:', error.message);
        if (error.code) console.error(`   Error code: ${error.code}`);
        process.exit(1);
    } finally {
        await pool.end();
    }
}

runMigration();
