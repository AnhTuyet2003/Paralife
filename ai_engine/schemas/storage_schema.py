from pydantic import BaseModel
from typing import Optional

class FolderCreate(BaseModel):
    name: str
    parent_id: Optional[str] = None

class AddByDOI(BaseModel):
    doi: str
    parent_id: Optional[str] = None

class AddByUrl(BaseModel):
    url: str
    parent_id: Optional[str] = None

class MoveItem(BaseModel):
    new_parent_id: Optional[str] = None