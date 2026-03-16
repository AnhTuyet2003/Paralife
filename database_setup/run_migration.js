// Quick migration runner
const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

const pool = new Pool({
    user: 'admin',
    host: 'localhost',
    database: 'refmind_db',
    password: 'adminpassword123',
    port: 5432,
});

async function runMigration() {
    try {
        console.log('📦 Connecting to database...');
        const sql = fs.readFileSync(path.join(__dirname, 'add_highlights_table.sql'), 'utf8');
        
        console.log('🔨 Running migration: add_highlights_table.sql');
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
            console.log(`   - ${col.column_name}: ${col.data_type}`);
        });
        
    } catch (error) {
        console.error('❌ Migration failed:', error.message);
        process.exit(1);
    } finally {
        await pool.end();
    }
}

runMigration();
