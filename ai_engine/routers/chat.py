from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
import traceback
import os
from dotenv import load_dotenv
from supabase import create_client, Client

from utils.rag_chain import search_similar_documents, generate_answer
from utils.security import decrypt_data
from models.chat_request import ChatRequest

load_dotenv()

router = APIRouter(tags=["Chat"])

supabase_url = os.getenv("SUPABASE_URL")
supabase_key = os.getenv("SUPABASE_KEY")
supabase: Client = create_client(supabase_url, supabase_key)

@router.post("/chat-document")
async def chat_with_document(data: ChatRequest):
    print(f"\n🔵 === CHAT REQUEST ===")
    print(f"👤 User: {data.user_id}")
    print(f"📄 File: {data.file_id}")
    print(f"📝 Content: {data.content[:100]}...")

    try:
        # 1. API Key handling
        final_api_key = data.api_key
        sys_key = os.getenv("GEMINI_API_KEY")

        if final_api_key and final_api_key.startswith('gAAAA'):
            try: 
                final_api_key = decrypt_data(final_api_key)
            except: 
                final_api_key = sys_key
        
        if not final_api_key or final_api_key.startswith("sk-") or len(final_api_key) < 20:
            final_api_key = sys_key

        if not final_api_key:
            raise HTTPException(status_code=500, detail="Missing API Key")

        # 2. Determine search scope
        target_file_id = data.file_id
        if target_file_id in ["global", "online", "library", "null", None, ""]:
            print("🌍 Global Search Mode")
            target_file_id = None 

        # 3. Search documents
        print("🔍 Searching...")
        context_chunks = search_similar_documents(
            query=data.content,
            file_id=target_file_id,   
            user_id=data.user_id,     
            api_key=final_api_key,    
            top_k=5
        )

        if not context_chunks:
            print("⚠️ No results found")
            return {
                "answer": "Tôi không tìm thấy thông tin liên quan trong tài liệu của bạn.",
                "citations": []
            }

        print(f"✅ Found {len(context_chunks)} chunks")

        # 4. Fetch file names for context
        file_ids = list(set([c.get('file_id') for c in context_chunks if c.get('file_id')]))
        
        file_map = {}
        if file_ids:
            try:
                print(f"   📂 Fetching {len(file_ids)} file names...")
                files_res = supabase.table("storage_items") \
                    .select("id, name") \
                    .in_("id", file_ids) \
                    .execute()

                for f in files_res.data:
                    file_map[f['id']] = f['name']
                    
                print(f"   ✅ Loaded {len(file_map)} file names")
            except Exception as e:
                print(f"⚠️ Error fetching file names: {e}")

        # 5. Add file names to metadata
        for chunk in context_chunks:
            fid = chunk.get('file_id')
            if 'metadata' not in chunk:
                chunk['metadata'] = {}
            chunk['metadata']['file_name'] = file_map.get(fid, "Tài liệu")

        # 6. Generate answer
        print("🤖 Generating answer...")
        answer = await generate_answer(
            query=data.content,
            context_chunks=context_chunks,
            api_key=final_api_key
        )
        print("✅ Done")

        # 7. Format citations
        formatted_citations = []
        for chunk in context_chunks[:3]:
            meta = chunk.get("metadata", {})
            formatted_citations.append({
                "chunk_id": chunk.get("id"),
                "content": chunk.get("content", "")[:150] + "...",
                "metadata": meta
            })

        return {
            "answer": answer,
            "citations": formatted_citations
        }

    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ CHAT ERROR: {str(e)}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))