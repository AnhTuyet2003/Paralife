import fitz  # PyMuPDF
from google import genai
from openai import AsyncOpenAI
import json
import re

COMMON_PROMPT = """
You are an expert academic metadata extractor. Analyze the following academic paper text and extract ALL metadata fields.

IMPORTANT EXTRACTION RULES:
1. **Title**: Usually appears at the top, often in larger font. Look for the main paper title (not conference/journal name).
2. **Authors**: Names listed near the title, often with affiliations. Extract ALL author names as separate items.
3. **Year**: Publication year - check header, footer, copyright notice, or within citation format.
4. **DOI**: Look for "DOI:", "doi.org/", or "https://doi.org/" followed by identifier (e.g., 10.1234/example).
5. **Journal**: Publication venue - look for journal name, conference proceedings, or publisher.
6. **Abstract**: Section labeled "Abstract", "Summary", or similar. Extract complete text (max 200 words).

SEARCH LOCATIONS:
- Check first 3 pages thoroughly
- Look at headers and footers
- Check copyright sections
- Look for "Keywords:", "Published in:", "Proceedings of:" sections

OUTPUT FORMAT (raw JSON only, no markdown):
{{
  "title": "Full paper title here",
  "authors": ["First Author", "Second Author", "Third Author"],
  "year": 2024,
  "doi": "10.1234/example.2024.5678",
  "journal": "Journal Name or Conference Proceedings",
  "abstract": "Complete abstract text here..."
}}

If a field is truly not found after thorough search, use null (not "N/A" or empty string).

EXAMPLE INPUT TEXT:
"Deep Learning for Image Recognition
John Smith¹, Jane Doe², Michael Chen³
¹MIT, ²Stanford, ³Berkeley
DOI: 10.1109/CVPR.2023.12345
Published in: IEEE Conference on Computer Vision and Pattern Recognition (CVPR) 2023
Abstract: This paper presents a novel approach..."

EXAMPLE OUTPUT:
{{
  "title": "Deep Learning for Image Recognition",
  "authors": ["John Smith", "Jane Doe", "Michael Chen"],
  "year": 2023,
  "doi": "10.1109/CVPR.2023.12345",
  "journal": "IEEE Conference on Computer Vision and Pattern Recognition (CVPR)",
  "abstract": "This paper presents a novel approach..."
}}

NOW EXTRACT FROM THIS TEXT:
{text_content}
"""

def extract_text_from_pdf(file_content: bytes):
    """
    Trả về 2 giá trị:
    1. full_text: Toàn bộ văn bản (để tóm tắt/lấy metadata)
    2. pages_data: Danh sách [{"text": "...", "page_number": 1}, ...] (để tạo vector)
    """
    doc = fitz.open(stream=file_content, filetype="pdf")
    full_text = ""
    pages_data = []

    for i, page in enumerate(doc):
        text = page.get_text()
        text = text.replace('\x00', '') 
        
        full_text += text + "\n"

        pages_data.append({
            "text": text,
            "page_number": i + 1 
        })
        
    return full_text, pages_data

def clean_json_string(json_str):
    """Hàm làm sạch chuỗi JSON do AI trả về"""
    try:
        match = re.search(r'\{.*\}', json_str, re.DOTALL)
        if match:
            json_str = match.group(0)

        json_str = json_str.replace("```json", "").replace("```", "").strip()
        
        parsed = json.loads(json_str)

        if parsed.get("title") == "N/A" or not parsed.get("title"):
            parsed["title"] = "Untitled Document"
        
        if not isinstance(parsed.get("authors"), list) or parsed.get("authors") == ["N/A"]:
            parsed["authors"] = ["Unknown"]

        if parsed.get("year") == "N/A" or parsed.get("year") == "null":
            parsed["year"] = None

        if parsed.get("doi") == "N/A" or parsed.get("doi") == "":
            parsed["doi"] = None
        if parsed.get("journal") == "N/A" or parsed.get("journal") == "":
            parsed["journal"] = None
        
        return parsed
    except Exception as e:
        print(f"⚠️ JSON Parse Error: {e} | Content: {json_str[:100]}...")
        return None

async def ai_extract_metadata(text_content: str, provider: str, api_key: str):
    """Extract metadata using AI"""
    
    if not api_key or api_key.strip() == '':
        print("❌ No API key provided")
        return {
            "title": "Untitled Document",
            "authors": ["Unknown"],
            "abstract": "No API key available for metadata extraction.",
            "year": None,
            "doi": None,
            "journal": None
        }

    truncated_text = text_content[:25000]
    final_prompt = COMMON_PROMPT.format(text_content=truncated_text)

    raw_response = ""

    try:
        if provider == 'openai':
            print(f"   Using OpenAI API (key: {api_key[:10]}...)")
            client = AsyncOpenAI(api_key=api_key)
            response = await client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": "You are an expert academic metadata extractor. Always return valid JSON with complete information."},
                    {"role": "user", "content": final_prompt}
                ],
                response_format={"type": "json_object"},
                temperature=0.3  
            )
            raw_response = response.choices[0].message.content

        else:  
            print(f"   Using Gemini API (key: {api_key[:10]}...)")
            client = genai.Client(api_key=api_key)
            # ✅ Dùng model ổn định hơn
            response = await client.aio.models.generate_content(
                model='models/gemini-2.5-flash',
                contents=final_prompt,
                config=genai.types.GenerateContentConfig(
                    temperature=0.3,
                    response_mime_type="application/json"
                )
            )
            raw_response = response.text

        print(f"   AI Response length: {len(raw_response)} chars")
        
        metadata = clean_json_string(raw_response)
        
        if metadata:
            print(f"✅ Extracted metadata successfully")
            return metadata
        else:
            raise Exception("Empty JSON after cleaning")

    except Exception as e:
        print(f"❌ AI Extraction Error ({provider}): {e}")
        return {
            "title": "Untitled Document",
            "authors": ["Unknown"],
            "abstract": f"Could not extract metadata: {str(e)}",
            "year": None,
            "doi": None,
            "journal": None
        }