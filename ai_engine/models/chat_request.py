from pydantic import BaseModel
from typing import Optional

class ChatRequest(BaseModel):
    content: str
    file_id: Optional[str] = None   
    user_id: str                    
    api_key: Optional[str] = None
    session_id: Optional[str] = None