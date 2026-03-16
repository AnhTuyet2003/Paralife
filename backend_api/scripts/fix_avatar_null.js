require('dotenv').config();
const db = require('../config/db');

async function fixAvatarNull() {
    console.log('🔧 Fixing avatar_url for all users...\n');
    
    try {
        // Set empty string thành NULL
        const updateEmpty = await db.query(`
            UPDATE users 
            SET avatar_url = NULL 
            WHERE avatar_url = ''
        `);
        console.log(`✅ Set ${updateEmpty.rowCount} empty avatars to NULL`);
        
        // Kiểm tra users
        const users = await db.query(`
            SELECT firebase_uid, email, full_name, avatar_url
            FROM users
            ORDER BY created_at DESC
        `);
        
        console.log(`\n📊 Total users: ${users.rows.length}\n`);
        
        users.rows.forEach((user, index) => {
            const avatarStatus = user.avatar_url 
                ? `✅ ${user.avatar_url.substring(0, 30)}...` 
                : '❌ NULL (will show default icon)';
                
            console.log(`${index + 1}. ${user.email || user.firebase_uid}`);
            console.log(`   Name: ${user.full_name || 'N/A'}`);
            console.log(`   Avatar: ${avatarStatus}\n`);
        });
        
        console.log('✅ Done! Restart backend and test.');
        process.exit(0);
    } catch (error) {
        console.error('❌ Error:', error);
        process.exit(1);
    }
}

fixAvatarNull();
