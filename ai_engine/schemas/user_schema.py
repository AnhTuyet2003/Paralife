from pydantic import BaseModel
from typing import Optional

class UserKeyUpdate(BaseModel):
    openai_key: Optional[str] = None
    gemini_key: Optional[str] = None
    active_provider: str = "system"

class UserProfileUpdate(BaseModel):
    full_name: Optional[str] = None
    is_dark_mode: Optional[bool] = None
    enable_notifications: Optional[bool] = None