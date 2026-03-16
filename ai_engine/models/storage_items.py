from sqlalchemy import Column, DateTime, String, Boolean, ForeignKey, BigInteger, UUID, func
from sqlalchemy.dialects.postgresql import JSONB
import uuid

from config.database import Base

class StorageItem(Base):
    __tablename__ = "storage_items"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(String, ForeignKey("users.firebase_uid", ondelete="CASCADE"), index=True)
    parent_id = Column(UUID(as_uuid=True), ForeignKey("storage_items.id"), nullable=True)
    name = Column(String)
    type = Column(String) # 'folder' or 'file'
    file_url = Column(String, nullable=True)
    size_bytes = Column(BigInteger, default=0)
    metadata_info = Column("metadata", JSONB, default={}) 
    is_favorite = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())