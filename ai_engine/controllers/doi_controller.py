from fastapi import HTTPException
from models.schemas import DOIRequest
from config.database import get_db_connection
from config.settings import GEMINI_API_KEY
from services.doi_service import fetch_pdf_from_doi
from services.metadata_enrichment_service import enrich_metadata
from utils.pdf_processor import extract_text_from_pdf, ai_extract_metadata
from utils.vector_store import process_and_save_embeddings
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

def create_abstract_text_content(metadata: dict) -> bytes:
    """Tạo nội dung text file từ metadata khi không có PDF"""
    content = f"""PAPER METADATA
{"=" * 80}

Title: {metadata.get('title', 'Unknown')}

Authors: {', '.join(metadata.get('authors', ['Unknown']))}

Year: {metadata.get('year', 'N/A')}

Journal: {metadata.get('journal', 'Unknown')}

DOI: {metadata.get('doi', 'N/A')}

Publisher: {metadata.get('publisher', 'Unknown')}

Citation Count: {metadata.get('citation_count', 0)}

Keywords: {', '.join(metadata.get('keywords', []))}

{"=" * 80}
ABSTRACT
{"=" * 80}

{metadata.get('abstract', 'No abstract available')}

{"=" * 80}
NOTE: This is a closed-access paper. Full PDF is not available via Open Access.
Data source: {metadata.get('source', 'Unknown')}
"""
    return content.encode('utf-8')

async def save_file_metadata_to_db(
    user_id: str, 
    parent_id: str, 
    doi: str, 
    metadata: dict, 
    file_size: int,
    has_pdf: bool
):
    """Lưu metadata vào PostgreSQL"""
    await ensure_user_exists(user_id)
    
    conn = await get_db_connection()
    try:
        # ✅ Chuẩn bị metadata JSON đầy đủ
        metadata_json = json.dumps({
            'doi': doi,
            'authors': metadata.get('authors', []),
            'year': metadata.get('year'),
            'journal': metadata.get('journal'),
            'abstract': metadata.get('abstract', ''),
            'citation_count': metadata.get('citation_count', 0),
            'publisher': metadata.get('publisher', 'Unknown'),
            'keywords': metadata.get('keywords', []),
            'source': metadata.get('source', 'crossref'),
            'is_open_access': has_pdf
        })
        
        # ✅ Tạo tên file phù hợp
        file_name = metadata.get('title', f'DOI_{doi.replace("/", "_")}')
        if not has_pdf:
            file_name += " [Abstract Only]"
        
        # ✅ INSERT vào database với provider='local'
        file_id = await conn.fetchval('''
            INSERT INTO storage_items 
            (user_id, parent_id, name, type, provider, has_pdf, size_bytes, metadata)
            VALUES ($1, $2, $3, 'file', 'local', $4, $5, $6::jsonb)
            RETURNING id
        ''',
            user_id,
            parent_id,
            file_name,
            has_pdf,  # True nếu có PDF, False nếu chỉ có abstract
            file_size,
            metadata_json
        )
        return file_id
    finally:
        await conn.close()

async def process_doi_handler(request: DOIRequest):
    """
    ✅ REFACTORED: Xử lý DOI với Metadata Enrichment & Paywall Fallback
    """
    print(f"\n🚀 [START] Processing DOI: {request.doi}")
    
    try:
        api_key = request.api_key or GEMINI_API_KEY
        provider = request.provider or 'gemini'
        
        if not api_key:
            raise HTTPException(status_code=400, detail="API key required")
        
        # ✅ BƯỚC 1: ENRICH METADATA từ Crossref/Scopus/IEEE
        print("   📚 Step 1: Enriching metadata...")
        enriched_metadata = await enrich_metadata(request.doi)
        
        # ✅ BƯỚC 2: TRY FETCH PDF từ Unpaywall
        print("   📄 Step 2: Checking PDF availability...")
        pdf_bytes, unpaywall_meta, is_open_access = await fetch_pdf_from_doi(request.doi)
        
        # Merge metadata từ unpaywall nếu có thông tin bổ sung
        if unpaywall_meta and 'error' not in unpaywall_meta:
            if not enriched_metadata.get('title') or enriched_metadata['title'] == f"DOI: {request.doi}":
                enriched_metadata['title'] = unpaywall_meta.get('title', enriched_metadata['title'])
        
        has_pdf = pdf_bytes is not None
        file_content = None
        file_extension = None
        
        if has_pdf:
            # ✅ CÓ PDF - Xử lý bình thường
            print(f"   ✅ PDF available: {len(pdf_bytes)} bytes")
            file_content = pdf_bytes
            file_extension = '.pdf'
            file_size = len(pdf_bytes)
        else:
            # ✅ KHÔNG CÓ PDF - Tạo text file từ abstract
            print("   📝 No PDF - Creating abstract text file...")
            file_content = create_abstract_text_content(enriched_metadata)
            file_extension = '.txt'
            file_size = len(file_content)
        
        # ✅ BƯỚC 3: LƯU VÀO DATABASE
        print("   💾 Step 3: Saving to database...")
        new_file_id = await save_file_metadata_to_db(
            user_id=request.user_id,
            parent_id=request.parent_id,
            doi=request.doi,
            metadata=enriched_metadata,
            file_size=file_size,
            has_pdf=has_pdf
        )
        
        # ✅ BƯỚC 4: TẠO VECTOR EMBEDDINGS (nếu có nội dung)
        if has_pdf:
            print("   🧠 Step 4: Creating vector embeddings from PDF...")
            full_text, pages_data = extract_text_from_pdf(pdf_bytes)
            
            if full_text and len(full_text.strip()) > 50:
                await process_and_save_embeddings(pages_data, new_file_id, request.user_id, api_key)
                print(f"   ✅ Processed {len(pages_data)} pages")
            else:
                print("   ⚠️ PDF text extraction failed - no embeddings created")
        else:
            print("   📝 Step 4: Creating embeddings from abstract...")
            # Tạo embeddings từ abstract text
            abstract_text = enriched_metadata.get('abstract', '')
            if abstract_text and len(abstract_text) > 20:
                # Tạo fake pages_data từ abstract (phải dùng 'text' key như pdf_processor)
                pages_data = [{
                    'page_number': 1,
                    'text': f"{enriched_metadata.get('title', '')}\n\n{abstract_text}"
                }]
                await process_and_save_embeddings(pages_data, new_file_id, request.user_id, api_key)
                print("   ✅ Embeddings created from abstract")
        
        # ✅ TRẢ VỀ KẾT QUẢ CHO BACKEND
        return {
            "success": True,
            "file_id": str(new_file_id),
            "message": f"Successfully processed DOI {'with PDF' if has_pdf else 'with abstract only'}",
            "has_pdf": has_pdf,
            "size_bytes": file_size,
            "file_content": file_content.hex(),  # Convert bytes to hex string
            "file_extension": file_extension,
            "metadata": enriched_metadata
        }
        
    except Exception as e:
        print(f"❌ CRITICAL ERROR: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))
