import requests

async def fetch_pdf_from_doi(doi: str):
    """Tải PDF từ Unpaywall API"""
    unpaywall_url = f"https://api.unpaywall.org/v2/{doi}?email=your@email.com"
    
    try:
        resp = requests.get(unpaywall_url, timeout=10)
        data = resp.json()
        
        pdf_url = data.get("best_oa_location", {}).get("url_for_pdf")
        
        metadata = {
            "title": data.get("title", "Unknown"),
            "authors": [a.get("family", "") for a in data.get("z_authors", [])],
            "year": data.get("year"),
            "doi": doi,
            "journal": data.get("journal_name"),
            "pdf_url": pdf_url
        }
        
        if not pdf_url:
            return None, metadata
        
        print(f"   🔗 Tìm thấy Link PDF: {pdf_url}")
        print(f"   ⬇️ Đang tải file...")
        
        pdf_resp = requests.get(pdf_url, timeout=30)
        return pdf_resp.content, metadata
        
    except Exception as e:
        print(f"   ❌ Unpaywall Error: {e}")
        return None, {"error": str(e)}
