from langchain_google_genai import GoogleGenerativeAIEmbeddings
from langchain_text_splitters import RecursiveCharacterTextSplitter
from config.settings import EMBEDDING_MODEL, CHUNK_SIZE, CHUNK_OVERLAP
from config.database import get_db_connection
import json  # ✅ THÊM IMPORT

def get_embeddings_model(api_key: str):
    """Khởi tạo model embedding"""
    return GoogleGenerativeAIEmbeddings(
        model=EMBEDDING_MODEL,
        google_api_key=api_key
    )

async def save_vectors_to_db(file_id: str, user_id: str, chunks: list, vectors: list):
    """Lưu vectors vào PostgreSQL"""
    conn = await get_db_connection()
    try:
        for i, chunk in enumerate(chunks):
            # ✅ Chuyển dict thành JSON string
            metadata_json = json.dumps({
                'page_number': chunk.get('page_number', 0),
                'chunk_index': i
            })
            
            await conn.execute('''
                INSERT INTO document_embeddings 
                (file_id, user_id, content, embedding, metadata)
                VALUES ($1, $2, $3, $4, $5::jsonb)
            ''', 
                file_id,
                user_id,
                chunk['text'],
                vectors[i],
                metadata_json  # ✅ Truyền JSON string
            )
        print(f"   ✅ Saved {len(chunks)} vectors to PostgreSQL")
    finally:
        await conn.close()

async def process_and_save_embeddings(pages_data: list, file_id: str, user_id: str, api_key: str):
    """Tạo embeddings cho từng chunk và lưu vào PostgreSQL"""
    print(f"🔄 Starting vector ingestion for File: {file_id}")
    
    embeddings_model = get_embeddings_model(api_key)
    text_splitter = RecursiveCharacterTextSplitter(
        chunk_size=CHUNK_SIZE,
        chunk_overlap=CHUNK_OVERLAP,
        separators=["\n\n", "\n", ". ", " ", ""]
    )
    
    all_chunks = []
    for page_data in pages_data:
        page_num = page_data['page_number']
        page_chunks = text_splitter.split_text(page_data['text'])
        for chunk_text in page_chunks:
            all_chunks.append({'text': chunk_text, 'page_number': page_num})
    
    print(f"✂️ Total chunks generated: {len(all_chunks)}")
    
    batch_size = 10
    for i in range(0, len(all_chunks), batch_size):
        batch = all_chunks[i:i + batch_size]
        batch_texts = [chunk['text'] for chunk in batch]
        print(f"   ...Embedding batch {i} to {i+len(batch)}...")
        vectors = embeddings_model.embed_documents(batch_texts)
        await save_vectors_to_db(file_id, user_id, batch, vectors)
    
    print(f"✅ [DONE] Đã lưu {len(all_chunks)} vectors vào PostgreSQL!")

async def search_similar_chunks(query: str, user_id: str, api_key: str, file_id: str = None, top_k: int = 5):
    """Tìm kiếm chunks tương tự"""
    embeddings_model = get_embeddings_model(api_key)
    query_vector = embeddings_model.embed_query(query)
    
    # ✅ CONVERT QUERY VECTOR THÀNH STRING (pgvector yêu cầu format "[x,y,z,...]")
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
                row_dict['metadata'] = json.loads(row_dict['metadata'])
            parsed_results.append(row_dict)
        
        return parsed_results
    finally:
        await conn.close()
