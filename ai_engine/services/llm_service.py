from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.prompts import PromptTemplate
import time
import asyncio

# ✅ Đổi sang model ổn định hơn (gemini-2.0-flash đang có vấn đề quota)
PRIMARY_MODEL = "models/gemini-2.5-flash"
FALLBACK_MODEL = "models/gemini-2.5-pro"  # Model nhẹ hơn nếu primary hết quota

async def generate_summary(full_text: str, api_key: str, summary_type: str) -> str:
    """Tạo tóm tắt bằng Gemini với retry mechanism"""
    
    prompts = {
        "tldr": "Hãy tóm tắt tài liệu này theo phong cách **TL;DR**. Chỉ 1 đoạn văn ngắn (3-4 câu).",
        "bullet": "Hãy tóm tắt tài liệu này theo dạng **Các điểm chính**. Sử dụng gạch đầu dòng.",
        "detailed": """Hãy tóm tắt **chi tiết và có cấu trúc**.
- **Tiêu đề tài liệu**
- **Tổng quan**
- **Phương pháp nghiên cứu**
- **Các điểm chính**
- **Kết quả chính**
- **Kết luận & Ý nghĩa**"""
    }

    template = f"""
    Bạn là trợ lý nghiên cứu AI. Dựa vào văn bản sau:
    {{text}}
    
    {prompts.get(summary_type, prompts['detailed'])}
    
    Trả lời bằng tiếng Việt, định dạng Markdown đẹp.
    """
    
    # ✅ TRY PRIMARY MODEL FIRST
    models_to_try = [PRIMARY_MODEL, FALLBACK_MODEL]
    
    for model_name in models_to_try:
        try:
            print(f"   🤖 Trying model: {model_name}")
            
            llm = ChatGoogleGenerativeAI(
                model=model_name, 
                google_api_key=api_key,
                temperature=0.3,
                max_retries=2
            )
            
            prompt = PromptTemplate(template=template, input_variables=["text"])
            chain = prompt | llm
            summary_result = await chain.ainvoke({"text": full_text})
            
            print(f"   ✅ Success with {model_name}")
            return summary_result.content
            
        except Exception as e:
            error_msg = str(e)
            print(f"   ⚠️ Model {model_name} failed: {error_msg[:100]}")
            
            # Nếu là quota error và còn model để thử
            if "RESOURCE_EXHAUSTED" in error_msg or "429" in error_msg:
                if model_name != models_to_try[-1]:
                    print(f"   🔄 Quota exceeded, trying fallback model...")
                    await asyncio.sleep(2)  # Wait before retry
                    continue
                else:
                    return "❌ **Lỗi**: API key đã hết quota. Vui lòng:\n1. Đợi vài phút để quota reset\n2. Hoặc sử dụng API key khác trong Settings"
            
            # Các lỗi khác
            if model_name != models_to_try[-1]:
                continue
            else:
                return f"❌ **Lỗi**: {error_msg[:200]}"
    
    return "❌ Không thể tạo tóm tắt. Vui lòng thử lại sau."

async def generate_answer(context: str, query: str, api_key: str) -> str:
    """Tạo câu trả lời từ context với retry mechanism"""
    
    prompt_text = f"""Bạn là trợ lý nghiên cứu AI thông minh.

TÀI LIỆU THAM KHẢO:
{context}

CÂU HỎI: {query}

YÊU CẦU:
- Trả lời CHÍNH XÁC dựa trên tài liệu
- Trích dẫn rõ nguồn trang
- Nếu không có thông tin → Nói "Tài liệu không đề cập"
- Trả lời bằng tiếng Việt, định dạng Markdown
"""
    
    # ✅ TRY PRIMARY MODEL FIRST
    models_to_try = [PRIMARY_MODEL, FALLBACK_MODEL]
    
    for model_name in models_to_try:
        try:
            print(f"   🤖 Trying model: {model_name}")
            
            llm = ChatGoogleGenerativeAI(
                model=model_name,
                google_api_key=api_key,
                temperature=0.7,
                max_retries=2
            )
            
            response = await llm.ainvoke(prompt_text)
            
            print(f"   ✅ Success with {model_name}")
            return response.content
            
        except Exception as e:
            error_msg = str(e)
            print(f"   ⚠️ Model {model_name} failed: {error_msg[:100]}")
            
            # Nếu là quota error và còn model để thử
            if "RESOURCE_EXHAUSTED" in error_msg or "429" in error_msg:
                if model_name != models_to_try[-1]:
                    print(f"   🔄 Quota exceeded, trying fallback model...")
                    await asyncio.sleep(2)
                    continue
                else:
                    return "❌ **Lỗi**: API key đã hết quota. Vui lòng đợi vài phút hoặc sử dụng API key khác."
            
            # Các lỗi khác
            if model_name != models_to_try[-1]:
                continue
            else:
                return f"❌ **Lỗi**: {error_msg[:200]}"
    
    return "❌ Không thể trả lời câu hỏi. Vui lòng thử lại sau."
