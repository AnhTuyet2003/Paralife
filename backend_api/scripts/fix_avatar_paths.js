require('dotenv').config();
const db = require('../config/db');

async function fixAvatarPaths() {
    console.log('🔧 Fixing avatar paths in database...\n');
    
    try {
        // 1. Lấy tất cả users có avatar không bắt đầu bằng `/`
        const users = await db.query(`
            SELECT firebase_uid, email, avatar_url 
            FROM users 
            WHERE avatar_url IS NOT NULL 
            AND avatar_url != ''
            AND avatar_url NOT LIKE '/%'
        `);
        
        console.log(`📊 Found ${users.rows.length} users với avatar path cần sửa\n`);
        
        for (const user of users.rows) {
            let newPath = user.avatar_url;
            
            // Xóa `./uploads` nếu có
            if (newPath.startsWith('./uploads')) {
                newPath = newPath.replace('./uploads', '/uploads');
            }
            // Xóa `uploads` nếu có
            else if (newPath.startsWith('uploads')) {
                newPath = '/' + newPath;
            }
            // Thêm `/` nếu chưa có
            else if (!newPath.startsWith('/')) {
                newPath = '/' + newPath;
            }
            
            // Update database
            await db.query(`
                UPDATE users 
                SET avatar_url = $1 
                WHERE firebase_uid = $2
            `, [newPath, user.firebase_uid]);
            
            console.log(`✅ Fixed: ${user.email}`);
            console.log(`   Old: ${user.avatar_url}`);
            console.log(`   New: ${newPath}\n`);
        }
        
        console.log('✅ Done! All avatar paths fixed.');
        process.exit(0);
    } catch (error) {
        console.error('❌ Error:', error);
        process.exit(1);
    }
}

fixAvatarPaths();
