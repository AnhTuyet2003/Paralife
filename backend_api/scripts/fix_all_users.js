require('dotenv').config();
const db = require('../config/db');

async function fixAllUsers() {
    console.log('🔧 Fixing all users in database...\n');
    
    try {
        // 1. Set avatar_url NULL cho empty string
        const updateResult = await db.query(`
            UPDATE users 
            SET avatar_url = NULL 
            WHERE avatar_url = ''
        `);
        console.log(`✅ Updated ${updateResult.rowCount} users with empty avatar\n`);
        
        // 2. Liệt kê tất cả users
        const users = await db.query(`
            SELECT firebase_uid, email, full_name, avatar_url, last_login
            FROM users
            ORDER BY created_at DESC
        `);
        
        console.log(`📊 Total users: ${users.rows.length}\n`);
        
        users.rows.forEach((user, index) => {
            console.log(`${index + 1}. ${user.email || user.firebase_uid}`);
            console.log(`   Name: ${user.full_name || 'N/A'}`);
            console.log(`   Avatar: ${user.avatar_url ? '✅' : '❌ NULL'}`);
            console.log(`   Last login: ${user.last_login || 'Never'}`);
            console.log('');
        });
        
        console.log('✅ Done!');
        process.exit(0);
    } catch (error) {
        console.error('❌ Error:', error);
        process.exit(1);
    }
}

fixAllUsers();
