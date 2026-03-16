const axios = require('axios');

async function testAPI() {
    console.log('🧪 Testing API Response Format...\n');
    
    const testToken = 'YOUR_FIREBASE_TOKEN_HERE'; // Replace with real token
    
    try {
        // Test 1: Get Items
        console.log('1️⃣ Testing GET /api/storage/items');
        const itemsRes = await axios.get('http://localhost:3000/api/storage/items', {
            headers: { Authorization: `Bearer ${testToken}` }
        });
        
        console.log('   Response type:', Array.isArray(itemsRes.data) ? 'Array ✅' : 'Object ❌');
        console.log('   Data:', itemsRes.data);
        
        // Test 2: Get Folders
        console.log('\n2️⃣ Testing GET /api/storage/folders');
        const foldersRes = await axios.get('http://localhost:3000/api/storage/folders', {
            headers: { Authorization: `Bearer ${testToken}` }
        });
        
        console.log('   Response type:', Array.isArray(foldersRes.data) ? 'Array ✅' : 'Object ❌');
        console.log('   Data:', foldersRes.data);
        
        // Test 3: Get Profile
        console.log('\n3️⃣ Testing GET /api/user/profile');
        const profileRes = await axios.get('http://localhost:3000/api/user/profile', {
            headers: { Authorization: `Bearer ${testToken}` }
        });
        
        console.log('   Response:', profileRes.data);
        console.log('   Avatar URL:', profileRes.data.data?.avatar_url || 'NULL');
        
    } catch (error) {
        console.error('❌ Test Error:', error.response?.data || error.message);
    }
}

testAPI();
