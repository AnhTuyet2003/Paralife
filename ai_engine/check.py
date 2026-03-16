import google.generativeai as genai
import os
from dotenv import load_dotenv

# Load API Key từ file .env
load_dotenv()
api_key = os.getenv("GEMINI_API_KEY")
genai.configure(api_key=api_key)

print("🔍 Đang tìm kiếm các mô hình hỗ trợ Embedding...\n")

# Lấy danh sách tất cả các models
for m in genai.list_models():
    # Lọc ra những model có hỗ trợ hàm 'embedContent'
    if 'embedContent' in m.supported_generation_methods:
        print(f"✅ Tên Model: {m.name}")
        print(f"   Phương thức hỗ trợ: {m.supported_generation_methods}\n")