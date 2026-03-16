require('dotenv').config();
const db = require('../config/db');

async function testUserUpdate() {
    console.log('🧪 Testing user update...\n');
    
    try {
        // 1. Lấy user đầu tiên
        const users = await db.query('SELECT * FROM users LIMIT 1');
        
        if (users.rows.length === 0) {
            console.log('❌ No users found in database');
            process.exit(1);
        }
        
        const testUser = users.rows[0];
        console.log('📋 Test user:', testUser);
        console.log('');
        
        // 2. Test update full_name
        console.log('1️⃣ Testing full_name update...');
        const newName = `Test User ${Date.now()}`;
        
        const updateResult = await db.query(`
            UPDATE users 
            SET full_name = $1
            WHERE firebase_uid = $2
            RETURNING *
        `, [newName, testUser.firebase_uid]);
        
        if (updateResult.rows.length > 0) {
            console.log('✅ Update successful:', updateResult.rows[0]);
        } else {
            console.log('❌ Update failed - no rows returned');
        }
        
        console.log('');
        
        // 3. Verify update
        console.log('2️⃣ Verifying update...');
        const verifyResult = await db.query(`
            SELECT * FROM users WHERE firebase_uid = $1
        `, [testUser.firebase_uid]);
        
        console.log('📊 Current data:', verifyResult.rows[0]);
        
        if (verifyResult.rows[0].full_name === newName) {
            console.log('✅ Verification successful!');
        } else {
            console.log('❌ Verification failed!');
        }
        
        process.exit(0);
    } catch (error) {
        console.error('❌ Error:', error);
        process.exit(1);
    }
}

testUserUpdate();
