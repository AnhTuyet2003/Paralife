import os
from dotenv import load_dotenv
import asyncpg
from config.settings import DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD

load_dotenv()

async def get_db_connection():
    """Tạo kết nối PostgreSQL"""
    return await asyncpg.connect(
        host=DB_HOST,
        port=DB_PORT,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD
    )