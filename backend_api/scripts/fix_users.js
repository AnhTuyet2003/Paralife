require('dotenv').config();
const db = require('../config/db');

async function fixUsers() {
    console.log('🔧 Đang kiểm tra và sửa users...\n');
    
    try {
        // ✅ Cập nhật avatar_url empty string thành NULL
        const updateResult = await db.query(`
            UPDATE users 
            SET avatar_url = NULL 
            WHERE avatar_url = '' OR avatar_url IS NULL
        `);
        
        console.log(`✅ Đã cập nhật ${updateResult.rowCount} users có avatar empty/NULL`);
        
        // Kiểm tra tất cả users
        const users = await db.query('SELECT firebase_uid, email, full_name, avatar_url FROM users');
        console.log(`\n📊 Tổng số users: ${users.rows.length}\n`);
        
        users.rows.forEach(user => {
            const avatarStatus = user.avatar_url ? '✅ Có' : '❌ Không';
            console.log(`  - ${user.email || user.firebase_uid}`);
            console.log(`    Tên: ${user.full_name || 'N/A'}`);
            console.log(`    Avatar: ${avatarStatus}`);
            console.log('');
        });
        
        console.log('✅ Hoàn tất!');
        process.exit(0);
    } catch (error) {
        console.error('❌ Error:', error);
        process.exit(1);
    }
}

fixUsers();
