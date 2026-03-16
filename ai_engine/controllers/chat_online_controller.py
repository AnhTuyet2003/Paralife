"""
Controller cho chức năng "Chat Online tìm tài liệu học thuật"
Workflow: 
  1. User chat → Gemini tóm tắt → Crossref search → Trả về danh sách
  2. User chọn DOI → Node.js process từng DOI đã chọn
"""
from fastapi import HTTPException
import httpx
from typing import List, Dict
from models.schemas import ChatOnlineRequest, ProcessSelectedDOIsRequest
from config.settings import GEMINI_API_KEY
from services.academic_search_service import search_academic_papers, generate_search_query


async def chat_online_search_handler(request: ChatOnlineRequest):
    """
    BƯỚC 1: TÌM KIẾM TÀI LIỆU (KHÔNG XỬ LÝ DOI)
    - Gemini tóm tắt câu hỏi thành từ khóa học thuật
    - Crossref search trả về danh sách DOI
    - User xem và chọn DOI nào muốn thêm
    """
    try:
        api_key = request.api_key or GEMINI_API_KEY
        if not api_key:
            raise HTTPException(status_code=400, detail="Gemini API key không tồn tại")
        
        print(f"\n🔍 === CHAT ONLINE SEARCH ===")
        print(f"User: {request.user_id}")
        print(f"Message: {request.message}")
        
        # Tóm tắt câu hỏi thành từ khóa
        search_query = await generate_search_query(request.message, api_key)
        
        if not search_query:
            return {
                "success": False,
                "message": "Không thể tạo từ khóa tìm kiếm. Vui lòng thử lại.",
                "papers": []
            }
        
        # Tìm kiếm trên Crossref
        papers = await search_academic_papers(search_query, limit=request.max_results)
        
        if not papers:
            return {
                "success": True,
                "message": f"Không tìm thấy tài liệu cho: '{search_query}'",
                "search_query": search_query,
                "papers": []
            }
        
        print(f"✅ Tìm thấy {len(papers)} tài liệu")
        
        return {
            "success": True,
            "message": f"Tìm thấy {len(papers)} tài liệu. Vui lòng chọn tài liệu muốn thêm.",
            "search_query": search_query,
            "papers": papers  # Danh sách để user chọn
        }
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ SEARCH ERROR: {e}")
        raise HTTPException(status_code=500, detail=f"Lỗi tìm kiếm: {str(e)}")


async def process_selected_dois_handler(request: ProcessSelectedDOIsRequest):
    """
    BƯỚC 2: XỬ LÝ CÁC DOI ĐÃ CHỌN
    - Gọi Node.js để download PDF + embed + lưu DB
    - Trả về kết quả từng DOI (thành công/thất bại)
    """
    try:
        if not request.selected_dois:
            raise HTTPException(status_code=400, detail="Chưa chọn DOI nào")
        
        print(f"\n📥 === PROCESSING SELECTED DOIs ===")
        print(f"User: {request.user_id}")
        print(f"Selected: {len(request.selected_dois)} DOIs")
        
        nodejs_url = "http://localhost:3000/api/doi/process-doi-internal"  # ✅ Internal endpoint (no auth)
        results = []
        
        async with httpx.AsyncClient(timeout=120.0) as client:
            for idx, doi in enumerate(request.selected_dois, 1):
                print(f"\n[{idx}/{len(request.selected_dois)}] Processing: {doi}")
                
                result_item = {"doi": doi}
                
                try:
                    response = await client.post(
                        nodejs_url,
                        json={"doi": doi, "user_id": request.user_id},
                        timeout=120.0
                    )
                    
                    if response.status_code == 200:
                        data = response.json()
                        
                        # ✅ CHECK HAS_PDF để phân loại
                        has_pdf = data.get('data', {}).get('has_pdf', False)
                        
                        if has_pdf:
                            # PDF đầy đủ
                            result_item.update({
                                "status": "success",
                                "file_id": data['data'].get('file_id'),
                                "file_name": data['data']['metadata'].get('title', 'Unknown'),
                                "message": "✅ Đã thêm vào thư viện (PDF)"
                            })
                            print(f"   ✅ Success with PDF")
                        else:
                            # Chỉ có abstract (paywall) nhưng vẫn thêm được
                            result_item.update({
                                "status": "success",
                                "file_id": data['data'].get('file_id'),
                                "file_name": data['data']['metadata'].get('title', 'Unknown'),
                                "message": "✅ Đã thêm (Abstract only - Paywall)",
                                "is_abstract_only": True
                            })
                            print(f"   ✅ Success with Abstract (Paywall)")
                    
                    elif response.status_code == 403:
                        error_data = response.json()
                        result_item.update({
                            "status": "quota_exceeded",
                            "message": "❌ Hết dung lượng 300MB"
                        })
                        print(f"   ❌ Quota exceeded")
                        break  # Dừng nếu hết quota
                    
                    else:
                        error_msg = response.json().get("error", "Unknown")
                        result_item.update({
                            "status": "error",
                            "message": f"❌ {error_msg}"
                        })
                        print(f"   ❌ Error {response.status_code}")
                
                except httpx.TimeoutException:
                    result_item.update({
                        "status": "timeout",
                        "message": "⏱️ Timeout (>2 phút)"
                    })
                    print(f"   ⏱️ Timeout")
                
                except httpx.ConnectError:
                    result_item.update({
                        "status": "node_offline",
                        "message": "❌ Node.js offline"
                    })
                    print(f"   ❌ Node.js offline")
                    results.append(result_item)
                    break
                
                except Exception as e:
                    result_item.update({
                        "status": "error",
                        "message": f"❌ {str(e)}"
                    })
                    print(f"   ❌ {e}")
                
                results.append(result_item)
        
        # Tổng kết
        success_count = len([r for r in results if r["status"] == "success"])
        failed_count = len(results) - success_count
        
        if success_count == 0:
            message = "❌ Không thể thêm tài liệu nào"
        elif success_count == len(results):
            message = f"✅ Đã thêm {success_count} tài liệu vào thư viện!"
        else:
            message = f"⚠️ Đã thêm {success_count}/{len(results)} tài liệu"
        
        print(f"\n📊 KẾT QUẢ: {success_count}/{len(results)} thành công")
        
        return {
            "success": True,
            "message": message,
            "total": len(results),
            "success_count": success_count,
            "failed_count": failed_count,
            "results": results
        }
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ PROCESS ERROR: {e}")
        raise HTTPException(status_code=500, detail=f"Lỗi xử lý: {str(e)}")
