import os
import httpx
import time
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from bs4 import BeautifulSoup

from config.database import get_db
from models.user_model import User
from models.storage_items import StorageItem
from schemas.storage_schema import FolderCreate, AddByDOI, AddByUrl, MoveItem
from utils.dependencies import verify_firebase_token
from utils.pdf_processor import extract_text_from_pdf, ai_extract_metadata
from utils.security import decrypt_data
from config.supabase_client import supabase_storage

router = APIRouter(prefix="/api/storage", tags=["Storage"])

@router.post("/upload")
async def upload_document(
    file: UploadFile = File(...),
    parent_id: str = Form(None),
    user_data: dict = Depends(verify_firebase_token),
    db: AsyncSession = Depends(get_db)
):
    uid = user_data.get('uid')
    # 1. Logic lấy User & Decrypt Key
    result = await db.execute(select(User).where(User.firebase_uid == uid))
    user = result.scalars().first()
    
    target_provider = "gemini"
    target_key = os.getenv("GEMINI_API_KEY")

    if user and user.active_provider == "openai" and user.openai_key:
        target_provider = "openai"
        target_key = decrypt_data(user.openai_key)
    elif user and user.active_provider == "gemini" and user.gemini_key:
        target_provider = "gemini"
        target_key = decrypt_data(user.gemini_key)

    # 2. Logic AI Process
    content = await file.read()
    text_content = extract_text_from_pdf(content)
    metadata = await ai_extract_metadata(text_content, target_provider, target_key)
    
    display_name = metadata.get("title") or file.filename
    if display_name == "Untitled Document": display_name = file.filename

    # 3. Upload Supabase
    timestamp = int(time.time())
    file_path = f"{uid}/{timestamp}_{file.filename}"
    supabase_storage.storage.from_("documents").upload(
        file=content, path=file_path, file_options={"content-type": "application/pdf"}
    )
    file_url = supabase_storage.storage.from_("documents").get_public_url(file_path)

    # 4. Save DB
    new_item = StorageItem(
        user_id=uid,
        parent_id=parent_id if parent_id != "null" else None,
        name=display_name,
        type="file",
        file_url=file_url,
        size_bytes=len(content),
        metadata_info=metadata
    )
    db.add(new_item)
    await db.commit()
    return {"success": True, "item": new_item}

@router.get("/items")
async def get_items(
    parent_id: str = None, 
    user_data: dict = Depends(verify_firebase_token),
    db: AsyncSession = Depends(get_db)
):
    uid = user_data.get('uid')
    query = select(StorageItem).where(
        StorageItem.user_id == uid, 
        StorageItem.parent_id == (parent_id if parent_id else None)
    ).order_by(StorageItem.type.asc(), StorageItem.name.asc())
    result = await db.execute(query)
    return result.scalars().all()

@router.post("/create_folder")
async def create_folder(
    folder_data: FolderCreate,
    user_data: dict = Depends(verify_firebase_token),
    db: AsyncSession = Depends(get_db)
):
    uid = user_data.get('uid')
    new_folder = StorageItem(
        user_id=uid,
        parent_id=folder_data.parent_id if folder_data.parent_id else None,
        name=folder_data.name,
        type="folder", size_bytes=0
    )
    db.add(new_folder)
    await db.commit()
    return {"success": True}

@router.post("/add_by_doi")
async def add_by_doi(
    data: AddByDOI,
    user_data: dict = Depends(verify_firebase_token),
    db: AsyncSession = Depends(get_db)
):
    uid = user_data.get('uid')
    clean_doi = data.doi.replace("https://doi.org/", "").strip()
    api_url = f"https://api.crossref.org/works/{clean_doi}"
    
    async with httpx.AsyncClient() as client:
        resp = await client.get(api_url)
        if resp.status_code != 200: raise HTTPException(status_code=404, detail="DOI not found")
        work = resp.json().get("message", {})

    title = work.get("title", ["Untitled"])[0]
    authors = [f"{a.get('given','')} {a.get('family','')}".strip() for a in work.get("author", [])]
    
    metadata = {
        "title": title, "authors": authors, "doi": clean_doi,
        "year": work.get("created", {}).get("date-parts", [[None]])[0][0],
        "journal": work.get("container-title", [""])[0],
        "abstract": "Abstract not available via public API"
    }

    new_item = StorageItem(
        user_id=uid, parent_id=data.parent_id if data.parent_id else None,
        name=title[:200], type="file", file_url=f"https://doi.org/{clean_doi}",
        size_bytes=0, metadata_info=metadata
    )
    db.add(new_item)
    await db.commit()
    return {"success": True, "item": new_item}

@router.post("/add_by_url")
async def add_by_url(
    data: AddByUrl,
    user_data: dict = Depends(verify_firebase_token),
    db: AsyncSession = Depends(get_db)
):
    uid = user_data.get('uid')
    title = "External Link"
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.get(data.url, follow_redirects=True, timeout=5.0)
            if resp.status_code == 200:
                soup = BeautifulSoup(resp.text, 'html.parser')
                if soup.title: title = soup.title.string.strip()
    except: pass

    new_item = StorageItem(
        user_id=uid, parent_id=data.parent_id if data.parent_id else None,
        name=title, type="file", file_url=data.url, size_bytes=0,
        metadata_info={"url": data.url, "source": "web_manual"}
    )
    db.add(new_item)
    await db.commit()
    return {"success": True}

@router.delete("/items/{item_id}")
async def delete_item(
    item_id: str,
    user_data: dict = Depends(verify_firebase_token),
    db: AsyncSession = Depends(get_db)
):
    uid = user_data.get('uid')
    result = await db.execute(select(StorageItem).where(StorageItem.id == item_id, StorageItem.user_id == uid))
    item = result.scalars().first()
    if not item: raise HTTPException(status_code=404, detail="Item not found")

    if item.type == 'file' and item.file_url and "supabase.co" in item.file_url:
        try:
            file_path = item.file_url.split("/documents/")[-1]
            from urllib.parse import unquote
            supabase_storage.storage.from_("documents").remove([unquote(file_path)])
        except: pass

    await db.delete(item)
    await db.commit()
    return {"success": True}

@router.patch("/items/{item_id}/move")
async def move_item(
    item_id: str, data: MoveItem, user_data: dict = Depends(verify_firebase_token), db: AsyncSession = Depends(get_db)
):
    uid = user_data.get('uid')
    stmt = update(StorageItem).where(StorageItem.id == item_id, StorageItem.user_id == uid).values(parent_id=data.new_parent_id)
    await db.execute(stmt)
    await db.commit()
    return {"success": True}

@router.patch("/items/{item_id}/favorite")
async def toggle_favorite(
    item_id: str, user_data: dict = Depends(verify_firebase_token), db: AsyncSession = Depends(get_db)
):
    uid = user_data.get('uid')
    result = await db.execute(select(StorageItem).where(StorageItem.id == item_id, StorageItem.user_id == uid))
    item = result.scalars().first()
    if item:
        item.is_favorite = not item.is_favorite
        await db.commit()
    return {"success": True}

@router.get("/folders")
async def get_all_folders(user_data: dict = Depends(verify_firebase_token), db: AsyncSession = Depends(get_db)):
    uid = user_data.get('uid')
    result = await db.execute(select(StorageItem).where(StorageItem.user_id == uid, StorageItem.type == 'folder'))
    return result.scalars().all()