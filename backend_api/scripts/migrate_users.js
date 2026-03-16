require('dotenv').config();
const admin = require('../config/firebaseAdmin');
const db = require('../config/db');

async function migrateUsers() {
    console.log('🔄 Bắt đầu migrate users từ Firebase sang PostgreSQL...\n');
    
    try {
        // Lấy tất cả users từ Firebase
        const listUsersResult = await admin.auth().listUsers(1000);
        
        console.log(`📊 Tìm thấy ${listUsersResult.users.length} users trong Firebase`);
        
        for (const user of listUsersResult.users) {
            try {
                await db.query(`
                    INSERT INTO users (firebase_uid, email, full_name, avatar_url, created_at)
                    VALUES ($1, $2, $3, $4, NOW())
                    ON CONFLICT (firebase_uid) DO UPDATE SET
                        email = EXCLUDED.email,
                        full_name = EXCLUDED.full_name,
                        avatar_url = EXCLUDED.avatar_url
                `, [
                    user.uid,
                    user.email || `${user.uid}@temp.com`,
                    user.displayName || 'Unnamed User',
                    user.photoURL || ''
                ]);
                
                console.log(`✅ Migrated: ${user.email || user.uid}`);
            } catch (error) {
                console.error(`❌ Error migrating ${user.uid}:`, error.message);
            }
        }
        
        console.log('\n✅ Migration hoàn tất!');
        process.exit(0);
    } catch (error) {
        console.error('❌ Migration error:', error);
        process.exit(1);
    }
}

migrateUsers();
