from fastapi import HTTPException
from models.schemas import ChatRequest
from config.settings import GEMINI_API_KEY
from config.database import get_db_connection
from services.embedding_service import search_similar_chunks
from services.llm_service import generate_answer

async def chat_handler(request: ChatRequest):
    """Chat với RAG - PostgreSQL"""
    try:
        api_key = request.api_key or GEMINI_API_KEY
        
        similar_chunks = await search_similar_chunks(
            query=request.message,
            user_id=request.user_id,
            api_key=api_key,
            file_id=request.file_id,
            top_k=5
        )
        
        # ✅ LẤY TÊN FILE NẾU CHAT TOÀN THƯ VIỆN
        file_names = {}
        if not request.file_id and similar_chunks:
            # Chat toàn thư viện - cần lấy tên file
            file_ids = list(set([chunk['file_id'] for chunk in similar_chunks]))
            conn = await get_db_connection()
            try:
                for fid in file_ids:
                    result = await conn.fetchrow(
                        'SELECT name FROM storage_items WHERE id = $1',
                        fid
                    )
                    if result:
                        file_names[str(fid)] = result['name']
            finally:
                await conn.close()
        
        # ✅ FORMAT CONTEXT KHÁC NHAU
        if request.file_id:
            # Chat 1 tài liệu - chỉ hiện page
            context = "\n\n".join([
                f"[Page {chunk['metadata']['page_number']}]: {chunk['content']}"
                for chunk in similar_chunks
            ])
        else:
            # Chat toàn thư viện - hiện tên file + page
            context = "\n\n".join([
                f"[{file_names.get(str(chunk['file_id']), 'Unknown')} - Page {chunk['metadata']['page_number']}]: {chunk['content']}"
                for chunk in similar_chunks
            ])
        
        answer = await generate_answer(context, request.message, api_key)
        
        return {
            "answer": answer,
            "citations": [
                {
                    "content": chunk['content'][:200],
                    "metadata": chunk['metadata'],
                    "similarity": chunk['similarity'],
                    "file_name": file_names.get(str(chunk['file_id']), None) if not request.file_id else None
                }
                for chunk in similar_chunks
            ]
        }
        
    except Exception as e:
        print(f"❌ Chat Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
