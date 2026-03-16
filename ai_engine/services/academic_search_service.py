"""
Service tìm kiếm tài liệu học thuật qua Crossref API
Crossref là cơ sở dữ liệu DOI lớn nhất, chứa metadata từ IEEE, Springer, Elsevier, etc.
"""
import httpx
from typing import List, Dict
import asyncio


async def search_academic_papers(query: str, limit: int = 3) -> List[Dict[str, str]]:
    """
    Tìm kiếm bài báo khoa học qua Crossref API
    
    Args:
        query: Từ khóa tìm kiếm (tiếng Anh chuẩn học thuật)
        limit: Số lượng kết quả tối đa (mặc định 3)
    
    Returns:
        List[Dict]: Danh sách bài báo có định dạng:
            [
                {
                    "doi": "10.1109/...",
                    "title": "Tên bài báo",
                    "authors": "Tác giả 1, Tác giả 2",
                    "year": "2024",
                    "journal": "Tên tạp chí"
                },
                ...
            ]
    """
    # API Crossref - Không cần key, rate limit 50 requests/giây
    url = f"https://api.crossref.org/works"
    
    params = {
        "query": query,
        "rows": limit,  # Giới hạn số kết quả
        "select": "DOI,title,author,published,container-title"  # Chỉ lấy thông tin cần thiết
    }
    
    try:
        print(f"🔍 Đang tìm kiếm: '{query}' trên Crossref...")
        
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.get(url, params=params)
            response.raise_for_status()
            
            data = response.json()
            items = data.get("message", {}).get("items", [])
            
            if not items:
                print(f"   ⚠️ Không tìm thấy kết quả cho: {query}")
                return []
            
            # Parse kết quả
            results = []
            for item in items:
                # DOI
                doi = item.get("DOI", "")
                if not doi:
                    continue  # Skip nếu không có DOI
                
                # Title
                title_list = item.get("title", [])
                title = title_list[0] if title_list else "Unknown Title"
                
                # Authors
                authors_data = item.get("author", [])
                authors = ", ".join([
                    f"{a.get('given', '')} {a.get('family', '')}".strip()
                    for a in authors_data[:3]  # Giới hạn 3 tác giả đầu
                ])
                if len(authors_data) > 3:
                    authors += " et al."
                
                # Year
                published = item.get("published", {})
                date_parts = published.get("date-parts", [[]])
                year = str(date_parts[0][0]) if date_parts and date_parts[0] else "N/A"
                
                # Journal
                journal_list = item.get("container-title", [])
                journal = journal_list[0] if journal_list else "Unknown Journal"
                
                results.append({
                    "doi": doi,
                    "title": title,
                    "authors": authors or "Unknown Authors",
                    "year": year,
                    "journal": journal
                })
            
            print(f"   ✅ Tìm thấy {len(results)} bài báo")
            return results
            
    except httpx.TimeoutException:
        print(f"   ❌ Timeout khi tìm kiếm trên Crossref")
        return []
    except httpx.HTTPStatusError as e:
        print(f"   ❌ HTTP Error: {e.response.status_code}")
        return []
    except Exception as e:
        print(f"   ❌ Lỗi không xác định: {e}")
        return []


async def generate_search_query(user_message: str, api_key: str) -> str:
    """
    Dùng Gemini để chuyển câu chat của user thành từ khóa tìm kiếm học thuật
    
    Args:
        user_message: Câu hỏi của user (bất kỳ ngôn ngữ nào)
        api_key: Gemini API key
    
    Returns:
        str: Từ khóa tìm kiếm tiếng Anh chuẩn học thuật
    
    Example:
        Input: "tìm bài báo về AI trong y tế"
        Output: "Artificial Intelligence in Healthcare"
    """
    import google.generativeai as genai
    
    try:
        genai.configure(api_key=api_key)
        model = genai.GenerativeModel('gemini-2.5-flash')
        
        prompt = f"""
Bạn là chuyên gia tìm kiếm tài liệu học thuật. 
Nhiệm vụ: Chuyển câu hỏi của người dùng thành 1 cụm từ khóa tìm kiếm tiếng Anh chuẩn học thuật.

Quy tắc:
- Chỉ trả về CỤM TỪ KHÓA, không thêm giải thích
- Dùng thuật ngữ học thuật chuẩn (Academic English)
- Ngắn gọn, súc tích (3-7 từ)
- Không dùng dấu ngoặc kép

Ví dụ:
Input: "tìm bài báo về trí tuệ nhân tạo trong y tế"
Output: Artificial Intelligence in Healthcare

Input: "machine learning for cancer detection"
Output: Machine Learning Cancer Detection

Input: "nghiên cứu về blockchain và bảo mật"
Output: Blockchain Security Research

Câu hỏi của người dùng:
"{user_message}"

Từ khóa tìm kiếm:
"""
        
        response = model.generate_content(prompt)
        search_query = response.text.strip()
        
        # Loại bỏ dấu ngoặc kép nếu có
        search_query = search_query.replace('"', '').replace("'", "")
        
        print(f"🤖 Gemini đề xuất: '{search_query}'")
        return search_query
        
    except Exception as e:
        print(f"   ⚠️ Gemini Error, dùng input gốc: {e}")
        # Fallback: dùng input gốc của user
        return user_message
