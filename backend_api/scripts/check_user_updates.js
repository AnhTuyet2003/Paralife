require('dotenv').config();
const db = require('../config/db');

async function checkUserUpdates() {
    console.log('🔍 Checking user updates in database...\n');
    
    try {
        const users = await db.query(`
            SELECT firebase_uid, email, full_name, avatar_url, last_login
            FROM users
            ORDER BY last_login DESC NULLS LAST
        `);
        
        console.log(`📊 Total users: ${users.rows.length}\n`);
        
        users.rows.forEach((user, index) => {
            console.log(`${index + 1}. ${user.email}`);
            console.log(`   Firebase UID: ${user.firebase_uid}`);
            console.log(`   Full Name: ${user.full_name || 'N/A'}`);
            console.log(`   Avatar: ${user.avatar_url || 'NULL'}`);
            console.log(`   Last Login: ${user.last_login || 'Never'}`);
            console.log('');
        });
        
        process.exit(0);
    } catch (error) {
        console.error('❌ Error:', error);
        process.exit(1);
    }
}

checkUserUpdates();
