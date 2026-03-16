import os
import json
from dotenv import load_dotenv
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_google_genai import GoogleGenerativeAIEmbeddings
import asyncpg
import asyncio
import time
from config.settings import EMBEDDING_MODEL, CHUNK_SIZE, CHUNK_OVERLAP

load_dotenv()

DB_CONFIG = {
    'user': os.getenv('DB_USER', 'admin'),
    'password': os.getenv('DB_PASSWORD', 'adminpassword123'),
    'database': os.getenv('DB_NAME', 'refmind_db'),
    'host': os.getenv('DB_HOST', 'localhost'),
    'port': int(os.getenv('DB_PORT', 5432))
}

def get_embeddings_model(api_key: str):
    return GoogleGenerativeAIEmbeddings(
        model="models/gemini-embedding-001",
        google_api_key=api_key
    )

async def get_db_connection():
    """Tạo kết nối PostgreSQL KHÔNG DÙNG register_vector"""
    return await asyncpg.connect(**DB_CONFIG)

async def save_vectors_to_db(file_id: str, user_id: str, chunks: list, vectors: list):
    """Lưu vectors vào PostgreSQL DÙNG STRING FORMAT"""
    conn = await get_db_connection()
    try:
        for i, chunk in enumerate(chunks):
            metadata_json = json.dumps({
                'page_number': chunk.get('page_number', 0),
                'chunk_index': i
            })
            
            # ✅ CONVERT LIST THÀNH STRING (GIỐNG TEST PASS)
            vector_str = '[' + ','.join(map(str, vectors[i])) + ']'
            
            await conn.execute('''
                INSERT INTO document_embeddings 
                (file_id, user_id, content, embedding, metadata)
                VALUES ($1::uuid, $2::text, $3, $4::vector, $5::jsonb)
            ''', 
                file_id,
                user_id,
                chunk['text'],
                vector_str,  # ✅ STRING FORMAT
                metadata_json
            )
        print(f"   ✅ Saved {len(chunks)} vectors to PostgreSQL")
    finally:
        await conn.close()

async def process_and_save_embeddings(pages_data: list, file_id: str, user_id: str, api_key: str):
    """Tạo embeddings cho từng chunk và lưu vào PostgreSQL"""
    print(f"🔄 Starting vector ingestion for File: {file_id}")
    
    try:
        embeddings_model = get_embeddings_model(api_key)
        
        text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=CHUNK_SIZE,
            chunk_overlap=CHUNK_OVERLAP,
            separators=["\n\n", "\n", ". ", " ", ""]
        )
        
        all_chunks = []
        print("📄 Processing pages to preserve page numbers...")
        
        for page_data in pages_data:
            page_num = page_data['page_number']
            page_text = page_data['text']
            
            page_chunks = text_splitter.split_text(page_text)
            
            for chunk_text in page_chunks:
                all_chunks.append({
                    'text': chunk_text,
                    'page_number': page_num
                })
        
        print(f"✂️ Total chunks generated: {len(all_chunks)}")
        
        # ✅ GIẢM BATCH SIZE ĐỂ TRÁNH RATE LIMIT
        batch_size = 5  # Từ 10 → 5
        request_count = 0
        max_requests_per_minute = 90  # Giữ buffer 10 requests
        
        for i in range(0, len(all_chunks), batch_size):
            batch = all_chunks[i:i + batch_size]
            batch_texts = [chunk['text'] for chunk in batch]
            
            print(f"   ...Embedding batch {i} to {i+len(batch)} (request #{request_count+1})...")
            
            # ✅ RETRY LOGIC KHI BỊ RATE LIMIT
            retry_count = 0
            max_retries = 3
            
            while retry_count < max_retries:
                try:
                    vectors = embeddings_model.embed_documents(batch_texts)
                    await save_vectors_to_db(file_id, user_id, batch, vectors)
                    request_count += 1
                    break  # Success → exit retry loop
                    
                except Exception as e:
                    error_str = str(e)
                    
                    # ✅ KIỂM TRA LỖI RATE LIMIT
                    if '429' in error_str or 'RESOURCE_EXHAUSTED' in error_str:
                        retry_count += 1
                        
                        # Extract retry delay từ error message
                        import re
                        delay_match = re.search(r'retry in (\d+)\.?\d*s', error_str)
                        wait_time = int(delay_match.group(1)) + 2 if delay_match else 20
                        
                        print(f"   ⚠️ Rate limit hit. Waiting {wait_time}s before retry {retry_count}/{max_retries}...")
                        await asyncio.sleep(wait_time)
                    else:
                        # Lỗi khác → raise ngay
                        raise e
            
            # ✅ RATE LIMITING: Nếu đã gần đến limit → chờ 1 phút
            if request_count >= max_requests_per_minute:
                print(f"   ⏳ Reached {request_count} requests. Waiting 60s to reset quota...")
                await asyncio.sleep(60)
                request_count = 0
            else:
                # ✅ DELAY NHỎ GIỮA CÁC BATCH ĐỂ TRÁNH BURST
                await asyncio.sleep(0.7)  # ~85 requests/phút
        
        print(f"✅ [DONE] Đã lưu {len(all_chunks)} vectors vào PostgreSQL!")
        
    except Exception as e:
        print(f"❌ Error saving vectors: {e}")
        raise e

async def search_similar_chunks(query: str, user_id: str, api_key: str, file_id: str = None, top_k: int = 5):
    """Tìm kiếm chunks tương tự"""
    embeddings_model = get_embeddings_model(api_key)
    query_vector = embeddings_model.embed_query(query)
    
    # ✅ CONVERT QUERY VECTOR THÀNH STRING
    query_vector_str = '[' + ','.join(map(str, query_vector)) + ']'
    
    conn = await get_db_connection()
    try:
        # ✅ THỨ TỰ THAM SỐ: query_embedding, match_threshold, match_count, filter_user_id, filter_file_id
        if file_id:
            results = await conn.fetch('''
                SELECT * FROM match_documents($1::vector, $2, $3, $4, $5::uuid)
            ''', query_vector_str, 0.5, top_k, user_id, file_id)
        else:
            results = await conn.fetch('''
                SELECT * FROM match_documents($1::vector, $2, $3, $4, NULL)
            ''', query_vector_str, 0.5, top_k, user_id)
        
        # ✅ PARSE METADATA (PostgreSQL trả về JSON dưới dạng dict hoặc string)
        parsed_results = []
        for row in results:
            row_dict = dict(row)
            # Metadata đã là dict (asyncpg tự động parse JSONB)
            if isinstance(row_dict.get('metadata'), str):
                import json
                row_dict['metadata'] = json.loads(row_dict['metadata'])
            parsed_results.append(row_dict)
        
        return parsed_results
    finally:
        await conn.close()