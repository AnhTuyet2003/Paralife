from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc
from config.database import get_db
from models.storage_items import StorageItem
from utils.dependencies import verify_firebase_token

router = APIRouter(prefix="/api/dashboard", tags=["Dashboard"])

@router.get("/overview")
async def get_dashboard_overview(
    user_data: dict = Depends(verify_firebase_token),
    db: AsyncSession = Depends(get_db)
):
    uid = user_data.get('uid')
    
    usage_query = select(func.sum(StorageItem.size_bytes)).where(StorageItem.user_id == uid)
    usage_result = await db.execute(usage_query)
    total_usage = usage_result.scalar() or 0
    
    # 2. Favorites
    fav_query = select(StorageItem).where(
        StorageItem.user_id == uid, StorageItem.is_favorite == True
    ).order_by(desc(StorageItem.created_at)).limit(5)
    fav_result = await db.execute(fav_query)
    favorites = fav_result.scalars().all()

    # 3. Recent Files
    recent_query = select(StorageItem).where(
        StorageItem.user_id == uid, StorageItem.type == 'file' 
    ).order_by(desc(StorageItem.created_at)).limit(5)
    recent_result = await db.execute(recent_query)
    recents = recent_result.scalars().all()

    # Helper serializer
    def item_to_dict(item):
        return {
            "id": str(item.id),
            "name": item.name,
            "type": item.type,
            "size_bytes": item.size_bytes,
            "file_url": item.file_url,
            "created_at": str(item.created_at),
            "metadata_info": item.metadata_info, 
            "is_favorite": item.is_favorite
        }

    return {
        "usage_bytes": int(total_usage),
        "favorites": [item_to_dict(i) for i in favorites],
        "recents": [item_to_dict(i) for i in recents]
    }