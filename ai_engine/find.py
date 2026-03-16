import google.generativeai as genai
import os
from dotenv import load_dotenv

# Load API Key
load_dotenv()
api_key = os.getenv("GEMINI_API_KEY")
genai.configure(api_key=api_key)

print("🔍 Đang tìm kiếm các mô hình hỗ trợ Chat & Tóm tắt (generateContent)...\n")

for m in genai.list_models():
    # Lọc ra những model hỗ trợ tạo văn bản
    if 'generateContent' in m.supported_generation_methods:
        print(f"✅ {m.name}")