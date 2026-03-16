# EXTENSION WORKFLOW & ARCHITECTURE

Minh họa cách extension hoạt động từ đầu đến cuối.

## 📊 OVERALL ARCHITECTURE

```
┌─────────────────────────────────────────────────────────────────┐
│                        USER'S BROWSER                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │   popup.js   │  │content_script│  │ background.js│         │
│  │  (UI Logic)  │  │ (Extraction) │  │(Service Wkr) │         │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘         │
│         │                  │                  │                 │
└─────────┼──────────────────┼──────────────────┼─────────────────┘
          │                  │                  │
          └──────────────────┴──────────────────┘
                             │
                             ▼
          ┌─────────────────────────────────┐
          │   Backend API (Node.js)         │
          │   http://localhost:3000         │
          └─────────────────┬───────────────┘
                           │
                           ▼
          ┌─────────────────────────────────┐
          │   AI Engine (Python)            │
          │   http://localhost:8000         │
          │   - DOI lookup                  │
          │   - PDF download                │
          │   - Unpaywall/Sci-Hub           │
          └─────────────────┬───────────────┘
                           │
                           ▼
          ┌─────────────────────────────────┐
          │   Storage (Dropbox/GDrive/etc)  │
          │   - PDFs                        │
          │   - Metadata                    │
          └─────────────────────────────────┘
```

---

## 🔄 COMPLETE USER FLOW

### Flow 1: First Time Setup

```
User Opens Browser
       │
       ▼
Installs Extension (Load unpacked)
       │
       ▼
Clicks Extension Icon
       │
       ▼
┌──────────────────────┐
│   LOGIN SCREEN       │
│  - Email input       │
│  - Password input    │
│  - Backend URL       │
│  - Login button      │
└──────┬───────────────┘
       │
       ▼
Enters Credentials + Clicks Login
       │
       ▼
popup.js sends POST to /api/auth/login
       │
       ▼
Backend validates credentials (Firebase)
       │
       ├── ✅ Success
       │   │
       │   ▼
       │   Returns JWT token
       │   │
       │   ▼
       │   popup.js saves to chrome.storage.local
       │   │
       │   ▼
       │   Shows MAIN SCREEN
       │
       └── ❌ Failed
           │
           ▼
           Shows Error: "Invalid credentials"
```

### Flow 2: Save Academic Paper

```
User navigates to arXiv.org/abs/1706.03762
       │
       ▼
Page loads → content_script.js auto-extracts metadata
       │
       ▼
Metadata cached in window.__refmindMetadata
       │
       ▼
User clicks Extension Icon
       │
       ▼
popup.js requests metadata from content_script
       │
       ▼
content_script returns:
       {
         title: "Attention Is All You Need",
         authors: ["Ashish Vaswani", ...],
         doi: "10.48550/arXiv.1706.03762",
         pdf_url: "https://arxiv.org/pdf/1706.03762.pdf",
         page_type: "article"
       }
       │
       ▼
┌──────────────────────┐
│   MAIN SCREEN        │
│  - Title displayed   │
│  - Authors displayed │
│  - DOI displayed     │
│  - PDF icon ✓       │
│  - Tags input        │
│  - Notes textarea    │
│  - [Save] button     │
└──────┬───────────────┘
       │
       ▼
User adds tags: "machine learning, nlp"
User adds notes: "Important paper"
       │
       ▼
Clicks "Save to Refmind"
       │
       ▼
popup.js sends POST /api/extension/save
       Headers: Authorization: Bearer {jwt_token}
       Body: {metadata + tags + notes}
       │
       ▼
Backend receives request
       │
       ├── Check DOI exists?
       │   │
       │   ├── ✅ DOI found: 10.48550/arXiv.1706.03762
       │   │   │
       │   │   ▼
       │   │   Forward to AI Engine /api/doi/process
       │   │   │
       │   │   ▼
       │   │   AI Engine:
       │   │   1. Try Unpaywall API
       │   │   2. If fails, try Sci-Hub
       │   │   3. Download PDF
       │   │   4. Upload to storage (Dropbox/GDrive)
       │   │   5. Save metadata to Supabase
       │   │   │
       │   │   ▼
       │   │   Returns: {success: true, document_id: "abc123", has_pdf: true}
       │   │
       │   └── ❌ No DOI
       │       │
       │       ▼
       │       Check PDF URL exists?
       │       │
       │       ├── ✅ PDF URL found
       │       │   │
       │       │   ▼
       │       │   Download PDF directly
       │       │   Upload to storage
       │       │   Save metadata
       │       │
       │       └── ❌ No PDF
       │           │
       │           ▼
       │           Save as webpage
       │           (URL + title + notes only)
       │
       ▼
Backend returns response to extension
       │
       ├── ✅ Success
       │   │
       │   ▼
       │   popup.js shows: "Saved successfully!"
       │   │
       │   ▼
       │   Auto-close popup after 2s
       │
       └── ❌ Failed
           │
           ▼
           Shows error message
```

### Flow 3: Save Regular Webpage

```
User navigates to blog.google.com
       │
       ▼
content_script extracts basic info:
       {
         title: "Google AI Blog",
         url: "https://blog.google/technology/ai/",
         page_type: "webpage"
       }
       │
       ▼
User clicks extension → Adds notes
       │
       ▼
Clicks "Save to Refmind"
       │
       ▼
Backend receives (no DOI, no PDF)
       │
       ▼
Saves as webpage:
       - Metadata to Supabase
       - Like a bookmark
       │
       ▼
Returns success (very fast, <5s)
       │
       ▼
Extension shows success message
```

---

## 🎯 COMPONENT RESPONSIBILITIES

### 1. content_script.js

**Chạy trong:** Mọi webpage user mở

**Nhiệm vụ:**
- Extract metadata từ `<meta>` tags
- Tìm DOI trong HTML
- Tìm PDF links
- Xử lý đặc biệt cho arXiv, PubMed, Nature, v.v.
- Cache metadata trong `window.__refmindMetadata`
- Lắng nghe messages từ popup

**Không làm:**
- Không có UI
- Không gọi backend
- Không lưu dữ liệu

### 2. popup.js

**Chạy trong:** Extension popup window

**Nhiệm vụ:**
- Hiển thị UI (login screen / main screen)
- Xử lý authentication
- Lưu JWT token vào chrome.storage
- Request metadata từ content_script
- Hiển thị metadata trong UI
- Gửi save request đến backend
- Hiển thị success/error messages

**Không làm:**
- Không extract metadata (delegate cho content_script)
- Không download PDF (delegate cho backend)

### 3. background.js

**Chạy trong:** Service worker (background)

**Nhiệm vụ:**
- Lifecycle events (install, update)
- Context menu registration
- Keepalive service worker
- Message relay (nếu cần)

**Không làm:**
- Không có UI
- Không xử lý save logic (popup làm)

---

## 🔐 AUTHENTICATION FLOW

```
┌─────────────────────────────────────────────┐
│ 1. User enters email + password in popup    │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│ 2. popup.js: POST /api/auth/login          │
│    Body: {email, password}                  │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│ 3. Backend: Validate with Firebase Auth    │
│    - Check email/password                   │
│    - Generate JWT token (1hr expiry)        │
└─────────────────┬───────────────────────────┘
                  │
                  ├── ✅ Valid
                  │   │
                  │   ▼
                  │   ┌───────────────────────────┐
                  │   │ Return: {                 │
                  │   │   token: "eyJhbG...",    │
                  │   │   user: {email, uid}      │
                  │   │ }                         │
                  │   └─────────┬─────────────────┘
                  │             │
                  │             ▼
                  │   ┌───────────────────────────┐
                  │   │ popup.js saves to:        │
                  │   │ chrome.storage.local      │
                  │   │   authToken: "eyJhbG..."  │
                  │   │   userEmail: "user@..."   │
                  │   │   backendUrl: "http://..."│
                  │   └─────────┬─────────────────┘
                  │             │
                  │             ▼
                  │   ┌───────────────────────────┐
                  │   │ Show MAIN SCREEN          │
                  │   └───────────────────────────┘
                  │
                  └── ❌ Invalid
                      │
                      ▼
                      ┌───────────────────────────┐
                      │ Return 401 Unauthorized   │
                      └─────────┬─────────────────┘
                                │
                                ▼
                      ┌───────────────────────────┐
                      │ Show error message        │
                      └───────────────────────────┘

┌─────────────────────────────────────────────┐
│ For subsequent save requests:               │
│                                             │
│ popup.js includes:                          │
│   Headers: {                                │
│     Authorization: "Bearer eyJhbG..."       │
│   }                                         │
│                                             │
│ Backend verifies JWT on every request       │
└─────────────────────────────────────────────┘
```

---

## 📊 DATA FLOW DIAGRAM

### Metadata Extraction Pipeline

```
┌────────────────┐
│  Webpage HTML  │
└───────┬────────┘
        │
        ▼
┌──────────────────────────────────────┐
│ content_script.js: querySelector()   │
│                                      │
│ Priorities (in order):               │
│ 1. citation_title                    │
│ 2. og:title                          │
│ 3. twitter:title                     │
│ 4. <title> tag                       │
└───────┬──────────────────────────────┘
        │
        ▼
┌──────────────────────────────────────┐
│ Extract Authors:                     │
│ 1. citation_author (multiple tags)   │
│ 2. DC.Creator                        │
│ 3. author meta tag                   │
└───────┬──────────────────────────────┘
        │
        ▼
┌──────────────────────────────────────┐
│ Extract DOI:                         │
│ 1. citation_doi                      │
│ 2. DC.Identifier                     │
│ 3. Regex in URL                      │
│ 4. Regex in page content             │
└───────┬──────────────────────────────┘
        │
        ▼
┌──────────────────────────────────────┐
│ Extract PDF URL:                     │
│ 1. citation_pdf_url                  │
│ 2. citation_fulltext_html_url        │
│ 3. <a> tags with .pdf                │
│ 4. Special handling (arXiv, etc)     │
└───────┬──────────────────────────────┘
        │
        ▼
┌──────────────────────────────────────┐
│ Return metadata object:              │
│ {                                    │
│   url, title, authors,               │
│   doi, pdf_url, abstract,            │
│   journal, year, keywords            │
│ }                                    │
└──────────────────────────────────────┘
```

### Save Pipeline

```
Extension sends metadata
        │
        ▼
┌──────────────────────┐
│ Backend receives     │
└──────┬───────────────┘
       │
       ▼
  Has DOI?
   /      \
  YES     NO
  │       │
  │       ▼
  │   Has PDF URL?
  │     /      \
  │    YES     NO
  │    │       │
  │    │       ▼
  │    │   Save as webpage
  │    │   (quick, <5s)
  │    │
  │    ▼
  │   Download PDF
  │   directly
  │   (10-15s)
  │
  ▼
Forward to AI Engine
  │
  ▼
┌─────────────────────┐
│ DOI Service:        │
│ 1. Check Unpaywall  │
│ 2. Try Sci-Hub      │
│ 3. Download PDF     │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Embedding Service:  │
│ - Generate vectors  │
│ - Chunk text        │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Storage Service:    │
│ - Upload to cloud   │
│ - Save metadata DB  │
└──────┬──────────────┘
       │
       ▼
Return {
  success: true,
  document_id: "abc123",
  has_pdf: true
}
```

---

## 🎨 UI STATE MACHINE

```
┌─────────────┐
│   LOADING   │ (Initial state, <1s)
└──────┬──────┘
       │
       ▼
  Has authToken?
   /          \
  YES         NO
  │           │
  │           ▼
  │   ┌────────────────┐
  │   │  LOGIN SCREEN  │
  │   │                │
  │   │ - Email input  │
  │   │ - Password     │
  │   │ - Backend URL  │
  │   │ - Login button │
  │   └────────┬───────┘
  │            │
  │            ▼
  │        User clicks Login
  │            │
  │            ├─ ✅ Success
  │            │      │
  └────────────┘      │
       │              │
       ▼              │
┌──────────────────┐  │
│   MAIN SCREEN    │◄─┘
│                  │
│ - User email     │
│ - Page metadata  │
│ - Tags input     │
│ - Notes input    │
│ - Save button    │
│ - Logout button  │
└────────┬─────────┘
         │
         ├── User clicks Logout
         │   │
         │   ▼
         │   Back to LOGIN SCREEN
         │
         ├── User clicks Save
         │   │
         │   ▼
         │   ┌────────────────┐
         │   │    SAVING      │
         │   │ - Button       │
         │   │   disabled     │
         │   │ - Loading...   │
         │   └────────┬───────┘
         │            │
         │            ├─ ✅ Success
         │            │      │
         │            │      ▼
         │            │   ┌──────────────┐
         │            │   │   SUCCESS    │
         │            │   │ - Green msg  │
         │            │   │ - Auto-close │
         │            │   └──────────────┘
         │            │
         │            └─ ❌ Failed
         │                   │
         │                   ▼
         │            ┌──────────────┐
         │            │    ERROR     │
         │            │ - Red msg    │
         │            │ - Stay open  │
         │            └──────┬───────┘
         │                   │
         └───────────────────┘
                Back to MAIN SCREEN
```

---

## 🔧 DEBUGGING FLOW

Khi có lỗi, debug theo thứ tự:

```
1. Extension Console (popup)
   ↓
   Right-click icon → "Inspect popup"
   Check for:
   - ✅ Login successful
   - 🔍 Refmind: Extracted metadata
   - 📤 Sending to backend
   - ✅ Document saved successfully
   - ❌ Any errors

2. Content Script Console (webpage)
   ↓
   F12 on webpage → Console tab
   Check for:
   - Content script loaded
   - Metadata extraction
   - Message passing errors

3. Background Service Worker
   ↓
   chrome://extensions → Service worker
   Check for:
   - Service worker active
   - Context menu registered
   - Keepalive running

4. Backend Logs (Node.js)
   ↓
   Terminal running node server.js
   Check for:
   - Request received
   - Auth token valid
   - API calls to AI Engine
   - Errors/warnings

5. AI Engine Logs (Python)
   ↓
   Terminal running python main.py
   Check for:
   - DOI processing
   - PDF download
   - Unpaywall/Sci-Hub calls
   - Storage upload

6. Network Tab (Chrome DevTools)
   ↓
   F12 → Network tab
   Check for:
   - POST /api/extension/save: 200 OK
   - Response payload
   - Timing
```

---

## 📝 SUMMARY

**3 Components:**
1. **content_script.js** - Extracts metadata (runs in webpage)
2. **popup.js** - UI + orchestration (runs in popup)
3. **background.js** - Lifecycle + context menu (service worker)

**2 Screens:**
1. **Login Screen** - Auth + credentials
2. **Main Screen** - Metadata + save

**3 Backend Endpoints:**
1. `POST /api/auth/login` - Authentication
2. `POST /api/extension/save` - Save document
3. `POST /api/doi/process` - AI processing (via backend)

**Key Features:**
- ✅ Auto metadata extraction
- ✅ Multi-site support (arXiv, PubMed, Nature, etc)
- ✅ Smart PDF discovery
- ✅ Tags + notes
- ✅ Cloud storage integration
- ✅ JWT authentication

---

Xem thêm:
- [Hướng dẫn test chi tiết](./HUONG_DAN_TEST_EXTENSION.md)
- [Quick reference](./TEST_EXTENSION_QUICK_REFERENCE.md)
- [Testing checklist](./EXTENSION_TESTING_CHECKLIST.md)
