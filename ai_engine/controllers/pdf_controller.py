from fastapi import UploadFile, File, Form, HTTPException
from utils.pdf_processor import extract_text_from_pdf, ai_extract_metadata
from utils.vector_store import process_and_save_embeddings

async def process_pdf_handler(
    file: UploadFile = File(...),
    provider: str = Form("gemini"),
    api_key: str = Form(...),
    file_id: str = Form(...),  
    user_id: str = Form(...)   
):
    """PDF processing with PostgreSQL vector storage"""
    try:
        print(f"\n🤖 Processing PDF: {file.filename}")
        
        content = await file.read()
        if len(content) == 0:
            raise HTTPException(status_code=400, detail="Empty file")

        print("📄 Extracting text from PDF...")
        text_content, pages_data = extract_text_from_pdf(content)
        
        if not text_content or len(text_content.strip()) < 50:
            raise HTTPException(status_code=422, detail="Could not extract sufficient text")

        print(f"🤖 Calling AI ({provider})...")
        metadata = await ai_extract_metadata(text_content, provider, api_key)

        print("🔄 Starting Vector Ingestion...")
        await process_and_save_embeddings(pages_data, file_id, user_id, api_key)
        print("✅ Vector Ingestion completed!")

        return metadata

    except Exception as e:
        print(f"❌ PDF Processing Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
