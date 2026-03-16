from sqlalchemy import Boolean, Column, String, DateTime, Text
from sqlalchemy.sql import func
from config.database import Base

class User(Base):
    __tablename__ = "users" 

    firebase_uid = Column(String, primary_key=True, index=True) 
    email = Column(String, unique=True, index=True)
    full_name = Column(String, nullable=True) 
    avatar_url = Column(String, nullable=True) 
    last_login = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    openai_key = Column(Text, nullable=True) 
    gemini_key = Column(Text, nullable=True)
    use_own_key = Column(Boolean, default=False)

    active_provider = Column(String, default="system")  # 'system', 'openai', 'gemini'
    is_dark_mode = Column(Boolean, default=False)
    enable_notifications = Column(Boolean, default=True)