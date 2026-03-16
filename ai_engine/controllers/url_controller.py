import requests
from fastapi import HTTPException
from models.schemas import URLProcessRequest
from config.database import get_db_connection
from config.settings import GEMINI_API_KEY
from services.embedding_service import process_and_save_embeddings
from utils.pdf_processor import extract_text_from_pdf
import json

async def ensure_user_exists(user_id: str):
    """✅ Đảm bảo user tồn tại trong database"""
    conn = await get_db_connection()
    try:
        exists = await conn.fetchval('''
            SELECT EXISTS(SELECT 1 FROM users WHERE firebase_uid = $1)
        ''', user_id)
        
        if not exists:
            print(f"   ⚠️ User {user_id} chưa tồn tại. Đang tạo...")
            await conn.execute('''
                INSERT INTO users (firebase_uid, email, full_name)
                VALUES ($1, $2, $3)
                ON CONFLICT (firebase_uid) DO NOTHING
            ''', user_id, f"{user_id}@temp.com", "Unnamed User")
            print(f"   ✅ Đã tạo user {user_id}")
    finally:
        await conn.close()

async def process_url_handler(request: URLProcessRequest):
    """Xử lý URL với PostgreSQL"""
    print(f"🌐 Processing URL: {request.url}")
    
    try:
        # ✅ Đảm bảo user tồn tại
        await ensure_user_exists(request.user_id)
        
        response = requests.get(request.url, timeout=30)
        if response.status_code != 200:
            raise HTTPException(status_code=400, detail="Không thể tải file từ URL này.")
        
        file_bytes = response.content
        file_size = len(file_bytes)
        
        conn = await get_db_connection()
        try:
            metadata_json = json.dumps({"source": "url_import"})
            
            new_file_id = await conn.fetchval('''
                INSERT INTO storage_items 
                (user_id, parent_id, name, type, size_bytes, file_url, provider, metadata)
                VALUES ($1, $2, $3, 'file', $4, $5, 'url', $6::jsonb)
                RETURNING id
            ''', 
                request.user_id,
                request.parent_id,
                request.file_name,
                file_size,
                request.url,
                metadata_json
            )
        finally:
            await conn.close()
        
        text_content, pages_data = extract_text_from_pdf(file_bytes)
        api_key = request.api_key or GEMINI_API_KEY
        await process_and_save_embeddings(pages_data, new_file_id, request.user_id, api_key)

        return {
            "status": "success", 
            "file_id": new_file_id, 
            "message": "Đã tải và xử lý tài liệu thành công!"
        }

    except Exception as e:
        print(f"❌ URL Process Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
