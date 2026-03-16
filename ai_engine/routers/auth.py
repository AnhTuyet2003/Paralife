from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy import func
from config.database import get_db
from models.user_model import User
from utils.dependencies import verify_firebase_token

router = APIRouter(prefix="/api/auth", tags=["Auth"])

@router.post("/sync")
async def sync_user(
    user_data: dict = Depends(verify_firebase_token),
    db: AsyncSession = Depends(get_db)
):
    uid = user_data.get('uid')
    email = user_data.get('email')
    name = user_data.get('name') or 'No Name'
    picture = user_data.get('picture') or ''

    stmt = insert(User).values(
        firebase_uid=uid,
        email=email,
        full_name=name,
        avatar_url=picture
    )
    stmt = stmt.on_conflict_do_update(
        index_elements=[User.firebase_uid],
        set_=dict(
            full_name=stmt.excluded.full_name,
            avatar_url=stmt.excluded.avatar_url,
            last_login=func.now() 
        )
    )
    try:
        await db.execute(stmt)
        await db.commit()
        return {"success": True, "message": "Synced"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))