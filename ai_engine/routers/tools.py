import asyncio 
import json
import os
import google.generativeai as genai
from dotenv import load_dotenv
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List
from config.database import get_db_connection

load_dotenv()

router = APIRouter(tags=["Tools"])

# Models
class ExplainRequest(BaseModel):
    term: str
    context: str

class CompareRequest(BaseModel):
    file_ids: List[str]
    user_id: str

# TÍNH NĂNG 1: GIẢI THÍCH THUẬT NGỮ
@router.post("/explain-term")
async def explain_term_endpoint(req: ExplainRequest):
    print(f"🧐 Explaining: {req.term}")
    try:
        api_key = os.getenv("GEMINI_API_KEY") 
        genai.configure(api_key=api_key)
        # ✅ Dùng model ổn định hơn
        model = genai.GenerativeModel('models/gemini-2.5-flash')

        prompt = f"""
Giải thích thuật ngữ: "{req.term}"
Trong ngữ cảnh: "{req.context}"

Yêu cầu:
- Giải thích ngắn gọn (dưới 50 từ)
- Tập trung vào nghĩa học thuật
- Trả lời tiếng Việt
"""
        res = model.generate_content(prompt)
        return {"explanation": res.text.strip()}
    except Exception as e:
        print(f"❌ Explain Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# TÍNH NĂNG 2: MATRIX REVIEW
async def analyze_single_paper(file_id: str, user_id: str):
    """Phân tích 1 bài báo"""
    conn = None
    try:
        print(f"   📄 Analyzing file: {file_id}")

        conn = await get_db_connection()
        embedding_rows = await conn.fetch(
            """
            SELECT content, metadata
            FROM document_embeddings
            WHERE file_id = $1::uuid AND user_id = $2::text
            ORDER BY created_at DESC
            LIMIT 20
            """,
            file_id,
            user_id,
        )

        if not embedding_rows:
            print(f"   ⚠️ No data for {file_id}")
            return None

        full_text = "\n".join([row['content'] for row in embedding_rows if row.get('content')])

        # Lấy tên file
        file_row = await conn.fetchrow(
            """
            SELECT name
            FROM storage_items
            WHERE id = $1::uuid AND user_id = $2::text
            LIMIT 1
            """,
            file_id,
            user_id,
        )

        file_name = file_row['name'] if file_row and file_row.get('name') else "Tài liệu"

        api_key = os.getenv("GEMINI_API_KEY")
        if not api_key:
            raise ValueError("GEMINI_API_KEY is required for compare-documents")

        genai.configure(api_key=api_key)
        # ✅ Dùng model ổn định hơn
        model = genai.GenerativeModel('models/gemini-2.5-flash')
        
        prompt = f"""
Trích xuất thông tin từ bài báo sau để tạo Literature Matrix.
Văn bản: {full_text[:15000]}...

Trả về JSON với format chính xác:
{{
    "method": "Phương pháp nghiên cứu (ngắn gọn)",
    "data": "Dữ liệu/Mẫu sử dụng",
    "result": "Kết quả chính",
    "limitation": "Hạn chế/Thách thức"
}}

CHỈ TRẢ VỀ JSON, KHÔNG GIẢI THÍCH THÊM.
"""
        ai_res = model.generate_content(prompt)
        
        json_str = ai_res.text.replace("```json", "").replace("```", "").strip()
        data = json.loads(json_str)
        
        data['file_name'] = file_name
        data['file_id'] = file_id
        
        print(f"   ✅ Done: {file_name}")
        return data
        
    except Exception as e:
        print(f"   ❌ Error analyzing {file_id}: {e}")
        return {
            "file_name": "Lỗi",
            "file_id": file_id,
            "method": "N/A",
            "data": "N/A",
            "result": "Không thể phân tích",
            "limitation": str(e)
        }
    finally:
        if conn is not None:
            await conn.close()

@router.post("/compare-documents")
async def compare_documents_endpoint(req: CompareRequest):
    print(f"\n📊 Creating Matrix for {len(req.file_ids)} files...")
    
    if len(req.file_ids) > 10:
        raise HTTPException(status_code=400, detail="Tối đa 10 tài liệu")
    
    # Xử lý song song
    tasks = [analyze_single_paper(fid, req.user_id) for fid in req.file_ids]
    results = await asyncio.gather(*tasks)
    
    valid_matrix = [r for r in results if r is not None]
    
    print(f"✅ Matrix completed: {len(valid_matrix)} papers analyzed")
    return {"matrix": valid_matrix}
