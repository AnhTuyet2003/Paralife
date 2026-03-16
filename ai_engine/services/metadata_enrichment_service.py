import requests
import os
from typing import Dict, Optional

# ✅ API KEYS (có thể thêm vào .env sau)
SCOPUS_API_KEY = os.getenv("SCOPUS_API_KEY", "")
IEEE_API_KEY = os.getenv("IEEE_API_KEY", "")

def detect_publisher_from_doi(doi: str) -> str:
    """Phát hiện publisher dựa vào DOI prefix"""
    doi_lower = doi.lower()
    
    if doi_lower.startswith("10.1109/"):
        return "ieee"
    elif any(prefix in doi_lower for prefix in ["10.1016/", "10.1006/", "10.1053/", "10.1067/"]):
        return "elsevier"
    else:
        return "generic"

async def fetch_crossref_metadata(doi: str) -> Optional[Dict]:
    """Lấy metadata từ Crossref API"""
    try:
        url = f"https://api.crossref.org/works/{doi}"
        resp = requests.get(url, timeout=10)
        
        if resp.status_code != 200:
            return None
        
        data = resp.json().get("message", {})
        
        # Extract authors
        authors = []
        for author in data.get("author", []):
            given = author.get("given", "")
            family = author.get("family", "")
            authors.append(f"{given} {family}".strip())
        
        # Extract abstract
        abstract = data.get("abstract", "")
        if abstract:
            # Remove HTML tags if present
            import re
            abstract = re.sub('<[^<]+?>', '', abstract)
        
        return {
            "title": data.get("title", ["Unknown"])[0] if data.get("title") else "Unknown",
            "authors": authors,
            "year": data.get("published", {}).get("date-parts", [[None]])[0][0],
            "journal": data.get("container-title", ["Unknown"])[0] if data.get("container-title") else "Unknown",
            "doi": doi,
            "abstract": abstract or "No abstract available",
            "citation_count": data.get("is-referenced-by-count", 0),
            "publisher": data.get("publisher", "Unknown"),
            "keywords": [],  # Crossref không có keywords
            "source": "crossref"
        }
    except Exception as e:
        print(f"   ⚠️ Crossref fetch error: {e}")
        return None

async def fetch_ieee_metadata(doi: str) -> Optional[Dict]:
    """Lấy metadata từ IEEE Xplore API"""
    if not IEEE_API_KEY:
        print("   ⚠️ IEEE API key not configured")
        return None
    
    try:
        # IEEE API endpoint
        url = f"https://ieeexploreapi.ieee.org/api/v1/search/articles"
        params = {
            "apikey": IEEE_API_KEY,
            "doi": doi,
            "format": "json"
        }
        
        resp = requests.get(url, params=params, timeout=10)
        
        if resp.status_code != 200 or resp.json().get("total_records", 0) == 0:
            return None
        
        article = resp.json().get("articles", [{}])[0]
        
        authors = []
        for author in article.get("authors", {}).get("authors", []):
            authors.append(author.get("full_name", ""))
        
        return {
            "title": article.get("title", "Unknown"),
            "authors": authors,
            "year": article.get("publication_year"),
            "journal": article.get("publication_title", "Unknown"),
            "doi": doi,
            "abstract": article.get("abstract", "No abstract available"),
            "citation_count": article.get("citing_paper_count", 0),
            "publisher": "IEEE",
            "keywords": article.get("index_terms", {}).get("author_terms", {}).get("terms", []),
            "source": "ieee"
        }
    except Exception as e:
        print(f"   ⚠️ IEEE fetch error: {e}")
        return None

async def fetch_scopus_metadata(doi: str) -> Optional[Dict]:
    """Lấy metadata từ Scopus API"""
    if not SCOPUS_API_KEY:
        print("   ⚠️ Scopus API key not configured")
        return None
    
    try:
        # Scopus Search API
        url = "https://api.elsevier.com/content/search/scopus"
        params = {
            "query": f"DOI({doi})",
            "apiKey": SCOPUS_API_KEY
        }
        headers = {
            "Accept": "application/json"
        }
        
        resp = requests.get(url, params=params, headers=headers, timeout=10)
        
        if resp.status_code != 200:
            return None
        
        results = resp.json().get("search-results", {}).get("entry", [])
        if not results:
            return None
        
        article = results[0]
        
        # Get author names
        authors = []
        author_str = article.get("dc:creator", "")
        if author_str:
            authors = [author_str]
        
        # Get citation count
        citation_count = int(article.get("citedby-count", 0))
        
        # Abstract might need separate API call to Abstract Retrieval API
        abstract = article.get("dc:description", "No abstract available")
        
        return {
            "title": article.get("dc:title", "Unknown"),
            "authors": authors,
            "year": article.get("prism:coverDate", "")[:4] if article.get("prism:coverDate") else None,
            "journal": article.get("prism:publicationName", "Unknown"),
            "doi": doi,
            "abstract": abstract,
            "citation_count": citation_count,
            "publisher": article.get("prism:publisher", "Unknown"),
            "keywords": article.get("authkeywords", "").split(" | ") if article.get("authkeywords") else [],
            "source": "scopus"
        }
    except Exception as e:
        print(f"   ⚠️ Scopus fetch error: {e}")
        return None

async def enrich_metadata(doi: str) -> Dict:
    """
    Lấy metadata từ nhiều nguồn và merge lại
    Priority: Scopus/IEEE > Crossref
    """
    print(f"   🔍 Enriching metadata for DOI: {doi}")
    
    publisher = detect_publisher_from_doi(doi)
    print(f"   📚 Detected publisher: {publisher}")
    
    metadata = None
    
    # Try IEEE first if applicable
    if publisher == "ieee":
        metadata = await fetch_ieee_metadata(doi)
        if metadata:
            print("   ✅ Got enriched metadata from IEEE")
            return metadata
    
    # Try Scopus if Elsevier or as fallback
    if publisher == "elsevier" or not metadata:
        scopus_meta = await fetch_scopus_metadata(doi)
        if scopus_meta:
            metadata = scopus_meta
            print("   ✅ Got enriched metadata from Scopus")
            return metadata
    
    # Fallback to Crossref
    crossref_meta = await fetch_crossref_metadata(doi)
    if crossref_meta:
        print("   ✅ Got metadata from Crossref")
        return crossref_meta
    
    # Last resort - minimal metadata
    print("   ⚠️ Could not fetch metadata from any source")
    return {
        "title": f"DOI: {doi}",
        "authors": ["Unknown"],
        "year": None,
        "journal": "Unknown",
        "doi": doi,
        "abstract": "Metadata not available",
        "citation_count": 0,
        "publisher": "Unknown",
        "keywords": [],
        "source": "none"
    }
