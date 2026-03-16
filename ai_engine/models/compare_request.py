from pydantic import BaseModel
from typing import List

class CompareRequest(BaseModel):
    file_ids: List[str]
    user_id: str