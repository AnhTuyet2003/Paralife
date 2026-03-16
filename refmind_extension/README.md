# Refmind Web Clipper - Chrome/Edge Extension

Quick save academic articles and web pages from your browser to Refmind.

## Features

- 🎓 **Academic Metadata Extraction**: Automatically detects DOI, authors, PDF URLs, abstracts
- 🌐 **Multi-Site Support**: Works on arXiv, PubMed, IEEE, Nature, Science, ScienceDirect, Springer, and more
- 📄 **Smart PDF Discovery**: Finds downloadable PDFs using same AI pipeline as main app
- 🏷️ **Tags & Notes**: Add custom tags and notes while saving
- ☁️ **Cloud Storage**: Respects your Refmind storage settings (Dropbox/Google Drive/OneDrive/Local)
- 🔒 **Secure**: Uses Firebase authentication with JWT tokens

## Installation

### 1. Load Extension (Developer Mode)

1. Open Chrome/Edge browser
2. Navigate to **chrome://extensions** (or **edge://extensions** for Edge)
3. Enable **Developer mode** (toggle in top right)
4. Click **Load unpacked**
5. Select the `refmind_extension` folder
6. Extension icon should appear in toolbar

### 2. Pin Extension (Optional)

- Click the **Extensions puzzle icon** in toolbar
- Find **Refmind Web Clipper**
- Click the **pin icon** to keep it visible

## Usage

### First Time Setup

1. Click the **Refmind extension icon** in toolbar
2. Enter your **email and password** (same as Refmind app)
3. Enter **Backend URL**:
   - Development: `http://localhost:3000`
   - Production: `https://your-domain.com`
4. Click **Login**

### Save an Article

1. Navigate to any webpage (academic article or regular page)
2. Click the **Refmind extension icon**
3. Review extracted metadata:
   - Title
   - Authors (if available)
   - DOI (if available)
   - PDF availability
4. Add **tags** (comma-separated): `machine learning, transformers, nlp`
5. Add **notes** (optional): Personal thoughts, summary, etc.
6. Click **Save to Refmind**
7. Success message → Extension closes automatically

### What Gets Extracted?

The extension looks for:
- **Title**: Citation title, Open Graph title, page title
- **Authors**: Citation authors, Dublin Core creators
- **DOI**: Citation DOI, page metadata, URL patterns
- **PDF URL**: Citation PDF, fulltext links, download buttons
- **Abstract**: Citation abstract, meta description
- **Journal/Conference**: Publication venue
- **Year**: Publication date
- **Keywords**: Article keywords

### Special Site Handling

- **arXiv.org**: Auto-generates PDF URL (https://arxiv.org/pdf/XXXX.pdf)
- **PubMed**: Sets publisher to "PubMed"
- **IEEE Explore**: Sets publisher to "IEEE"
- **Nature/Science**: Marks as article type

## Backend Processing

After clicking Save:

1. **Extension** sends metadata to backend API
2. **Backend** checks if DOI exists:
   - **If DOI found**: Use AI pipeline to search Unpaywall/Sci-Hub for full PDF
   - **If PDF URL found**: Download PDF directly
   - **Otherwise**: Save as webpage with URL + notes
3. **Storage**: Saved to your configured storage (Dropbox/Google Drive/OneDrive/Local)
4. **Success**: Document appears in Refmind app

## Testing

### Test Articles

Try these URLs to verify extraction:

**arXiv:**
```
https://arxiv.org/abs/1706.03762
```
Expected: Extracts "Attention is All You Need" + authors + DOI + generates PDF URL

**PubMed:**
```
https://pubmed.ncbi.nlm.nih.gov/23193287/
```
Expected: Extracts PMID article with authors + abstract

**Nature:**
```
https://www.nature.com/articles/s41586-021-03819-2
```
Expected: Extracts article with DOI + authors

**IEEE:**
```
https://ieeexplore.ieee.org/document/8408403
```
Expected: Extracts paper with DOI

**Regular Webpage:**
```
https://blog.google/technology/ai/google-gemini-ai/
```
Expected: Extracts as webpage (no DOI, no authors)

## Troubleshooting

### "Cannot connect to backend"

- Check backend URL is correct and server is running
- Development: Ensure `http://localhost:3000` is accessible
- Production: Check CORS settings allow extension origin

### "Session expired. Please login again."

- JWT token expired (1-hour validity)
- Click Logout → Login again
- Extension will save credentials for future use

### "No metadata available"

- Content script may not have loaded
- Refresh page and try again
- Check browser console for errors (F12 → Console)

### "Failed to extract metadata"

- Site may block content script injection
- Site may not have standard meta tags
- Extension will still save URL + title as webpage

### Extension Icon Not Showing

- Check Extensions page: Icon should be **blue with book symbol**
- If error: Click "Details" → Check error messages
- Manifest V3 required: Chrome 88+ or Edge 88+

## File Structure

```
refmind_extension/
├── manifest.json          # Extension config (Manifest V3)
├── popup.html             # UI (login + main screen)
├── popup.css              # Styling
├── popup.js               # Logic (auth, save handler)
├── content_script.js      # Metadata extraction
├── background.js          # Service worker
├── icons/
│   ├── icon16.png         # 16x16 toolbar icon
│   ├── icon48.png         # 48x48 management icon
│   └── icon128.png        # 128x128 store icon
└── README.md              # This file
```

## Development

### Console Logging

Enable verbose logging:

1. Open **Extensions page** (chrome://extensions)
2. Find **Refmind Web Clipper** → Click **Details**
3. Click **Inspect views: background page** (for service worker logs)
4. Or open any webpage → **F12** → Console (for content script logs)

### Test Content Script

Open any article page → Console:
```javascript
window.__refmindMetadata
```
Should show extracted metadata object.

### Reload Extension

After code changes:
1. Go to **chrome://extensions**
2. Find **Refmind Web Clipper**
3. Click **Reload icon** (circular arrow)
4. Refresh any open webpages to reload content script

## Backend Integration

Extension calls:

**POST /api/extension/config**
- Get Firebase API key for authentication
- No auth required

**POST /api/extension/save**
- Headers: `Authorization: Bearer {firebase_jwt_token}`
- Body:
```json
{
  "url": "https://arxiv.org/abs/1706.03762",
  "title": "Attention is All You Need",
  "authors": ["Ashish Vaswani", "Noam Shazeer"],
  "doi": "10.48550/arXiv.1706.03762",
  "pdf_url": "https://arxiv.org/pdf/1706.03762.pdf",
  "abstract": "...",
  "journal": "Neural Information Processing Systems",
  "year": "2017",
  "keywords": ["transformer", "attention"],
  "tags": ["machine learning", "nlp"],
  "notes": "Foundational paper for transformers"
}
```
- Response:
```json
{
  "success": true,
  "document_id": "abc123",
  "has_pdf": true,
  "storage_provider": "dropbox"
}
```

## Icons

Icons not included in this repo. Create 3 PNG files:

- **icon16.png** (16x16): Toolbar icon
- **icon48.png** (48x48): Extension management page
- **icon128.png** (128x128): Chrome Web Store

Recommended design: Blue background with white book/document symbol, "R" letter, or Refmind logo.

## Documentation

### Testing Guides

- **[Vietnamese Testing Guide](../docs/HUONG_DAN_TEST_EXTENSION.md)** - Comprehensive testing documentation in Vietnamese with detailed test cases, troubleshooting, and checklists
- **[Quick Reference](../docs/TEST_EXTENSION_QUICK_REFERENCE.md)** - Quick testing reference for common scenarios
- **[Web Clipper Complete](../docs/WEB_CLIPPER_COMPLETE.md)** - Full implementation documentation
- **[Quick Start](../docs/WEB_CLIPPER_QUICKSTART.md)** - 5-minute quick start guide

## License

Part of Refmind project. See main project LICENSE.

## Support

For issues or questions:
1. Check this README troubleshooting section
2. Check [comprehensive testing guide](../docs/HUONG_DAN_TEST_EXTENSION.md) for detailed troubleshooting
3. Check backend logs for API errors
4. Check browser console for extension errors
5. Verify backend is running and accessible
