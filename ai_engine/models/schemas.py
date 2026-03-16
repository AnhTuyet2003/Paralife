from pydantic import BaseModel
from typing import Optional

class PDFProcessRequest(BaseModel):
    provider: str = "gemini"
    api_key: str
    file_id: str
    user_id: str

class SummaryRequest(BaseModel):
    file_id: str
    api_key: str
    summary_type: str = "detailed"

class URLProcessRequest(BaseModel):
    url: str
    user_id: str
    file_name: str
    parent_id: Optional[str] = None
    api_key: Optional[str] = None

class DOIRequest(BaseModel):
    doi: str
    user_id: str
    parent_id: Optional[str] = None
    api_key: Optional[str] = None
    provider: str = "gemini"

class ChatRequest(BaseModel):
    message: str
    user_id: str
    file_id: Optional[str] = None
    api_key: Optional[str] = None

class ChatOnlineRequest(BaseModel):
    """Request cho chức năng Chat Online tìm tài liệu học thuật"""
    message: str  # Câu hỏi của user
    user_id: str  # UUID của user
    api_key: Optional[str] = None  # Gemini API key
    max_results: int = 3  # Số lượng tài liệu tối đa

class ProcessSelectedDOIsRequest(BaseModel):
    """Request để xử lý các DOI đã được user lựa chọn"""
    user_id: str  # UUID của user
    selected_dois: list[str]  # Danh sách DOI user muốn thêm (VD: ["10.1109/...", "10.1016/..."])
