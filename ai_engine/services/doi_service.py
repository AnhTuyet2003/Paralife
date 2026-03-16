import re
import requests
from typing import Tuple, Optional, Dict, Any, List
from urllib.parse import urlparse, urljoin


def _is_pdf_response(resp: requests.Response) -> bool:
    """Check if response looks like a real PDF."""
    content_type = (resp.headers.get("Content-Type") or "").lower()
    if "application/pdf" in content_type:
        return True

    # Some publishers return octet-stream for PDFs.
    if "application/octet-stream" in content_type:
        return True

    # Fallback: check PDF magic bytes.
    return bool(resp.content[:4] == b"%PDF")


def _build_candidate_pdf_urls(doi: str, data: Dict[str, Any]) -> List[str]:
    """Build prioritized list of candidate PDF URLs from Unpaywall + known publisher patterns."""
    candidates: List[str] = []

    best = data.get("best_oa_location") or {}
    if best.get("url_for_pdf"):
        candidates.append(best["url_for_pdf"])

    for loc in data.get("oa_locations", []) or []:
        pdf_url = loc.get("url_for_pdf")
        if pdf_url and pdf_url not in candidates:
            candidates.append(pdf_url)

    # PLOS fallback (often works when pmc direct link is 403).
    doi_lower = doi.lower()
    if doi_lower.startswith("10.1371/journal.pone."):
        plos_url = f"https://journals.plos.org/plosone/article/file?id={doi}&type=printable"
        if plos_url not in candidates:
            candidates.append(plos_url)

    return candidates


def _append_unique(urls: List[str], value: Optional[str]) -> None:
    if value and value not in urls:
        urls.append(value)


def _extract_pdf_links_from_html(base_url: str, html: str) -> List[str]:
    """Extract likely PDF links from HTML response body."""
    if not html:
        return []

    links: List[str] = []

    # href="...pdf..."
    for match in re.findall(r'href=["\']([^"\']+)["\']', html, flags=re.IGNORECASE):
        lower = match.lower()
        if ".pdf" in lower or "download" in lower or "pdf" in lower:
            _append_unique(links, urljoin(base_url, match))

    return links


def _build_domain_specific_variants(url: str, doi: str) -> List[str]:
    """Generate domain-specific alternate PDF URLs."""
    variants: List[str] = []
    parsed = urlparse(url)
    host = (parsed.netloc or "").lower()
    path = parsed.path or ""

    doi_lower = doi.lower()

    # PLOS
    if "journals.plos.org" in host and "plosone" in host + path:
        _append_unique(variants, f"https://journals.plos.org/plosone/article/file?id={doi}&type=printable")

    # Frontiers
    if "frontiersin.org" in host:
        if path.endswith("/full"):
            _append_unique(variants, url.replace("/full", "/pdf"))
        _append_unique(variants, f"https://www.frontiersin.org/articles/{doi_lower}/pdf")

    # MDPI
    if "mdpi.com" in host:
        if not path.endswith("/pdf"):
            _append_unique(variants, f"{parsed.scheme}://{parsed.netloc}{path.rstrip('/')}/pdf")

    # Wiley
    if "onlinelibrary.wiley.com" in host:
        _append_unique(variants, f"https://onlinelibrary.wiley.com/doi/pdf/{doi}")
        _append_unique(variants, f"https://onlinelibrary.wiley.com/doi/pdfdirect/{doi}")

    # Springer
    if "link.springer.com" in host and "/article/" in path:
        springer_pdf = path.replace("/article/", "/content/pdf/") + ".pdf"
        _append_unique(variants, f"https://link.springer.com{springer_pdf}")

    # Nature
    if "nature.com" in host:
        if not path.endswith(".pdf"):
            _append_unique(variants, f"{parsed.scheme}://{parsed.netloc}{path}.pdf")
        _append_unique(variants, f"{parsed.scheme}://{parsed.netloc}{path}.pdf?download=true")

    # Generic toggles
    _append_unique(variants, url + ("&download=1" if "?" in url else "?download=1"))
    _append_unique(variants, url + ("&download=true" if "?" in url else "?download=true"))

    return variants


def _download_pdf_with_fallback(candidates: List[str], doi: str) -> Tuple[Optional[bytes], Optional[str], Optional[int]]:
    """Try downloading PDF with browser-like headers and publisher-specific fallbacks."""
    if not candidates:
        return None, None, None

    headers_list = [
        {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                         "(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
            "Accept": "application/pdf,application/octet-stream;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.9",
            "Connection": "keep-alive",
        },
        {
            "User-Agent": "Mozilla/5.0 (compatible; Refmind/1.0; +https://refmind.local)",
            "Accept": "application/pdf,*/*;q=0.8",
        },
    ]

    last_status = None

    for url in candidates:
        # Some hosts are strict with referer.
        parsed = urlparse(url)
        referer = f"{parsed.scheme}://{parsed.netloc}/" if parsed.scheme and parsed.netloc else None

        for base_headers in headers_list:
            headers = dict(base_headers)
            if referer:
                headers["Referer"] = referer

            try:
                resp = requests.get(url, timeout=30, allow_redirects=True, headers=headers)
                last_status = resp.status_code

                if resp.status_code == 200 and _is_pdf_response(resp):
                    return resp.content, url, resp.status_code

                # Domain-specific fallbacks for 401/403/non-PDF responses.
                if resp.status_code in (200, 401, 403):
                    variants = _build_domain_specific_variants(url, doi)

                    # If server returned HTML, try extracting embedded PDF links.
                    content_type = (resp.headers.get("Content-Type") or "").lower()
                    if "text/html" in content_type and resp.text:
                        for html_link in _extract_pdf_links_from_html(url, resp.text):
                            _append_unique(variants, html_link)

                    for alt_url in variants:
                        try:
                            alt_parsed = urlparse(alt_url)
                            alt_headers = dict(headers)
                            if alt_parsed.scheme and alt_parsed.netloc:
                                alt_headers["Referer"] = f"{alt_parsed.scheme}://{alt_parsed.netloc}/"

                            alt_resp = requests.get(alt_url, timeout=30, allow_redirects=True, headers=alt_headers)
                            last_status = alt_resp.status_code

                            if alt_resp.status_code == 200 and _is_pdf_response(alt_resp):
                                return alt_resp.content, alt_url, alt_resp.status_code
                        except Exception:
                            continue

            except Exception:
                # Move to next header / next URL.
                continue

    return None, None, last_status

async def fetch_pdf_from_doi(doi: str) -> Tuple[Optional[bytes], Dict[str, Any], bool]:
    """
    Tải PDF từ Unpaywall API
    Returns: (pdf_bytes, basic_metadata, is_open_access)
    """
    unpaywall_url = f"https://api.unpaywall.org/v2/{doi}?email=your@email.com"
    
    try:
        resp = requests.get(unpaywall_url, timeout=10)
        data = resp.json()
        
        is_oa = data.get("is_oa", False)
        
        metadata = {
            "title": data.get("title", "Unknown"),
            "authors": [a.get("family", "") for a in data.get("z_authors", [])],
            "year": data.get("year"),
            "doi": doi,
            "journal": data.get("journal_name"),
            "is_open_access": is_oa
        }
        
        # Build candidate URLs from Unpaywall + known publisher patterns.
        candidate_urls = _build_candidate_pdf_urls(doi, data)
        metadata["pdf_url"] = candidate_urls[0] if candidate_urls else None
        metadata["pdf_candidates"] = candidate_urls

        if not candidate_urls:
            print(f"   ⚠️ No PDF available (Paywall) - DOI: {doi}")
            return None, metadata, False

        if len(candidate_urls) > 0:
            print(f"   🔗 Tìm thấy Link PDF: {candidate_urls[0]}")
            if len(candidate_urls) > 1:
                print(f"   🔁 Có {len(candidate_urls)} candidate URLs, sẽ thử fallback nếu cần")
        print(f"   ⬇️ Đang tải file...")

        pdf_content, final_url, final_status = _download_pdf_with_fallback(candidate_urls, doi)

        if pdf_content:
            metadata["pdf_url"] = final_url
            print(f"   ✅ PDF downloaded: {len(pdf_content)} bytes")
            print(f"   ✅ Final PDF URL: {final_url}")
            return pdf_content, metadata, True

        if final_status:
            print(f"   ⚠️ PDF download failed: HTTP {final_status}")
        else:
            print("   ⚠️ PDF download failed: unknown network error")
        return None, metadata, False
        
    except Exception as e:
        print(f"   ❌ Unpaywall Error: {e}")
        return None, {"error": str(e), "doi": doi}, False
