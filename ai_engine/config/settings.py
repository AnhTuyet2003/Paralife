import os
from dotenv import load_dotenv

load_dotenv()

# Database
DB_HOST = os.getenv('DB_HOST', 'localhost')
DB_PORT = int(os.getenv('DB_PORT', 5432))
DB_NAME = os.getenv('DB_NAME', 'refmind_db')
DB_USER = os.getenv('DB_USER', 'admin')
DB_PASSWORD = os.getenv('DB_PASSWORD', 'adminpassword123')

# API Keys
GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')
ENCRYPTION_KEY = os.getenv('ENCRYPTION_KEY')

# Server
PORT = int(os.getenv('PORT', 8000))
ALLOWED_ORIGINS = [
    "http://localhost:3000",
    "http://127.0.0.1:3000",
    "http://10.0.2.2:3000"
]

# Embedding
EMBEDDING_MODEL = "models/gemini-embedding-001"  # ✅ MODEL ĐÚNG
EMBEDDING_DIMENSIONS = 3072  # ✅ THÊM CONFIG CHO DIMENSIONS
CHUNK_SIZE = 1000
CHUNK_OVERLAP = 200
