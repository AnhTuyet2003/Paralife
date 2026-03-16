from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import update, select
from config.database import get_db
from models.user_model import User
from utils.dependencies import verify_firebase_token
from schemas.user_schema import UserKeyUpdate, UserProfileUpdate
from utils.security import encrypt_data
from config.supabase_client import supabase_storage
import time

router = APIRouter(prefix="/api/user", tags=["User"])

@router.post("/keys")
async def update_user_keys(
    key_data: UserKeyUpdate,
    user_data: dict = Depends(verify_firebase_token),
    db: AsyncSession = Depends(get_db)
):
    uid = user_data.get('uid')
    encrypted_openai = encrypt_data(key_data.openai_key) if key_data.openai_key else None
    encrypted_gemini = encrypt_data(key_data.gemini_key) if key_data.gemini_key else None
    
    update_values = {"active_provider": key_data.active_provider}
    if encrypted_openai: update_values["openai_key"] = encrypted_openai
    if encrypted_gemini: update_values["gemini_key"] = encrypted_gemini

    stmt = update(User).where(User.firebase_uid == uid).values(**update_values)
    await db.execute(stmt)
    await db.commit()
    return {"success": True}

@router.get("/keys/status")
async def get_user_key_status(
    user_data: dict = Depends(verify_firebase_token),
    db: AsyncSession = Depends(get_db)
):
    uid = user_data.get('uid')
    result = await db.execute(select(User).where(User.firebase_uid == uid))
    user = result.scalars().first()
    return {
        "active_provider": user.active_provider or "system", 
        "has_openai": bool(user.openai_key),
        "has_gemini": bool(user.gemini_key)
    }

@router.post("/avatar")
async def upload_avatar(
    file: UploadFile = File(...),
    user_data: dict = Depends(verify_firebase_token),
    db: AsyncSession = Depends(get_db)
):
    uid = user_data.get('uid')
    content = await file.read()
    timestamp = int(time.time())
    file_extension = file.filename.split('.')[-1]
    file_path = f"avatars/{uid}_{timestamp}.{file_extension}"

    try:
        supabase_storage.storage.from_("documents").upload(
            file=content, path=file_path, file_options={"content-type": file.content_type}
        )
        avatar_url = supabase_storage.storage.from_("documents").get_public_url(file_path)
        
        stmt = update(User).where(User.firebase_uid == uid).values(avatar_url=avatar_url)
        await db.execute(stmt)
        await db.commit()
        return {"success": True, "avatar_url": avatar_url}
    except Exception as e:
        print(f"Error: {e}")
        raise HTTPException(status_code=500, detail="Failed to upload avatar")

@router.patch("/profile")
async def update_profile(
    data: UserProfileUpdate,
    user_data: dict = Depends(verify_firebase_token),
    db: AsyncSession = Depends(get_db)
):
    uid = user_data.get('uid')
    update_data = {k: v for k, v in data.dict().items() if v is not None}
    if update_data:
        stmt = update(User).where(User.firebase_uid == uid).values(**update_data)
        await db.execute(stmt)
        await db.commit()
    return {"success": True}