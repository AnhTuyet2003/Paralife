import uvicorn
from fastapi import FastAPI, Request, UploadFile, File, Form
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from config.settings import PORT, ALLOWED_ORIGINS
from controllers import (
    pdf_controller,
    summary_controller,
    doi_controller,
    chat_controller,
    url_controller
)
from routers import chat_online, tools
from models.schemas import SummaryRequest, DOIRequest, ChatRequest, URLProcessRequest
import traceback

app = FastAPI(title="Refmind AI Engine", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ✅ ĐĂNG KÝ ROUTER
app.include_router(chat_online.router)
app.include_router(tools.router)

@app.middleware("http")
async def log_requests(request: Request, call_next):
    print(f"\n📡 [INCOMING] {request.method} {request.url}")
    try:
        response = await call_next(request)
        print(f"✅ [RESPONSE] Status: {response.status_code}")
        return response
    except Exception as e:
        print(f"❌ [SERVER ERROR] {str(e)}")
        traceback.print_exc()
        return JSONResponse(status_code=500, content={"detail": str(e)})

@app.get("/")
def root():
    return {"status": "ok", "message": "Refmind AI Engine (PostgreSQL) Running"}

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    print(f"⚠️ [VALIDATION ERROR] {exc.errors()}")
    return JSONResponse(status_code=422, content={"detail": exc.errors()})

# ✅ ROUTES
@app.post("/process-pdf")
async def process_pdf(
    file: UploadFile = File(...),
    provider: str = Form("gemini"),
    api_key: str = Form(...),
    file_id: str = Form(...),  
    user_id: str = Form(...)
):
    return await pdf_controller.process_pdf_handler(file, provider, api_key, file_id, user_id)

@app.post("/summarize-document")
async def summarize_document(request: SummaryRequest):
    return await summary_controller.summarize_document_handler(request)

@app.post("/process-doi")
async def process_doi(request: DOIRequest):
    return await doi_controller.process_doi_handler(request)

@app.post("/process-url")
async def process_url(request: URLProcessRequest):
    return await url_controller.process_url_handler(request)

@app.post("/chat")
async def chat(request: ChatRequest):
    return await chat_controller.chat_handler(request)

@app.post("/extract-metadata")
async def extract_metadata(
    file: UploadFile = File(...),
    provider: str = Form("gemini"),
    api_key: str = Form(...),
    extract_only: str = Form("false")  # ✅ Flag để chỉ extract metadata
):
    """Extract metadata from PDF without creating embeddings"""
    try:
        print(f"\n🔍 Extracting metadata from: {file.filename}")
        
        # Read PDF
        file_content = await file.read()
        
        # Extract text
        from utils.pdf_processor import extract_text_from_pdf, ai_extract_metadata
        full_text, pages_data = extract_text_from_pdf(file_content)
        
        # Extract metadata using AI
        metadata = await ai_extract_metadata(full_text, provider, api_key)
        
        return {
            "success": True,
            "metadata": metadata,
            "page_count": len(pages_data)
        }
        
    except Exception as e:
        print(f"❌ Extract Metadata Error: {e}")
        return JSONResponse(
            status_code=500,
            content={"success": False, "error": str(e)}
        )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=PORT, reload=True)