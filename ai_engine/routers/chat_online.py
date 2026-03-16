"""
Router cho chức năng "Chat Online tìm tài liệu học thuật"
Endpoint 1: POST /chat-online/search - Tìm kiếm và hiển thị danh sách
Endpoint 2: POST /chat-online/process - Xử lý các DOI đã chọn
"""
from fastapi import APIRouter
from models.schemas import ChatOnlineRequest, ProcessSelectedDOIsRequest
from controllers.chat_online_controller import chat_online_search_handler, process_selected_dois_handler

router = APIRouter(tags=["Chat Online"])


@router.post("/chat-online/search")
async def chat_online_search(request: ChatOnlineRequest):
    """
    🔍 BƯỚC 1: TÌM KIẾM TÀI LIỆU HỌC THUẬT (KHÔNG XỬ LÝ)
    
    User chat bằng ngôn ngữ tự nhiên → Gemini tóm tắt → Crossref search → Trả về danh sách
    
    Request Body:
        {
            "message": "tìm bài báo về AI trong y tế",
            "user_id": "uuid-123",
            "api_key": "optional",
            "max_results": 3
        }
    
    Response:
        {
            "success": true,
            "message": "Tìm thấy 5 tài liệu. Vui lòng chọn tài liệu muốn thêm.",
            "search_query": "Artificial Intelligence in Healthcare",
            "papers": [
                {
                    "doi": "10.1109/...",
                    "title": "AI in Medical Diagnosis",
                    "authors": "John Doe, Jane Smith",
                    "year": "2024",
                    "journal": "IEEE Transactions"
                },
                ...
            ]
        }
    """
    return await chat_online_search_handler(request)


@router.post("/chat-online/process")
async def process_selected_dois(request: ProcessSelectedDOIsRequest):
    """
    📥 BƯỚC 2: XỬ LÝ CÁC DOI ĐÃ CHỌN
    
    User chọn DOI muốn thêm → Gọi Node.js xử lý từng DOI → Trả về kết quả
    
    Request Body:
        {
            "user_id": "uuid-123",
            "selected_dois": ["10.1109/...", "10.1016/...", "10.1007/..."]
        }
    
    Response:
        {
            "success": true,
            "message": "✅ Đã thêm 3 tài liệu vào thư viện!",
            "total": 3,
            "success_count": 3,
            "failed_count": 0,
            "results": [
                {
                    "doi": "10.1109/...",
                    "status": "success",
                    "file_id": "uuid...",
                    "file_name": "AI_Medical_Diagnosis.pdf",
                    "message": "✅ Đã thêm vào thư viện"
                },
                {
                    "doi": "10.1016/...",
                    "status": "paywall",
                    "message": "⚠️ Paywall - Chỉ có Abstract"
                },
                ...
            ]
        }
    
    Error Cases:
        - 403: User hết quota 300MB → Dừng xử lý
        - 404: PDF paywall → Ghi nhận, tiếp tục DOI tiếp theo
        - Timeout: Quá 2 phút/DOI → Skip
        - Node.js offline → Dừng toàn bộ
    """
    return await process_selected_dois_handler(request)
