from fastapi import HTTPException
from models.schemas import SummaryRequest
from config.database import get_db_connection
from config.settings import GEMINI_API_KEY
from services.llm_service import generate_summary
from utils.security import decrypt_data

async def summarize_document_handler(request: SummaryRequest):
    """Tóm tắt tài liệu"""
    print(f"📝 Summarizing File: {request.file_id}")
    
    try:
        final_api_key = request.api_key
        if final_api_key and final_api_key.startswith("gAAAA"):
            try:
                final_api_key = decrypt_data(final_api_key)
            except:
                pass
        
        if not final_api_key or final_api_key.startswith("sk-"):
             final_api_key = GEMINI_API_KEY

        conn = await get_db_connection()
        try:
            rows = await conn.fetch('''
                SELECT content FROM document_embeddings
                WHERE file_id = $1
                ORDER BY id
            ''', request.file_id)
            
            if not rows:
                return {"summary": "Không tìm thấy nội dung."}

            full_text = "\n".join([row['content'] for row in rows])
            if len(full_text) > 500000: 
                full_text = full_text[:500000] + "...(truncated)"
        finally:
            await conn.close()

        summary = await generate_summary(full_text, final_api_key, request.summary_type)
        return {"summary": summary}

    except Exception as e:
        print(f"❌ Summary Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
