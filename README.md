# Refmind

Refmind là nền tảng quản lý tài liệu học thuật theo mô hình monorepo, kết hợp ứng dụng khách đa nền tảng, API Gateway và AI Engine để tự động hóa toàn bộ vòng đời xử lý tài liệu: nhập liệu, trích xuất metadata, tạo embedding và hỗ trợ tra cứu thông minh.

## 1) Giới thiệu chức năng

Refmind tập trung vào trải nghiệm nghiên cứu học thuật theo hướng tự động và có thể mở rộng.

### Chức năng nổi bật

- Quản lý thư viện tài liệu tập trung: lưu trữ, phân loại, tìm kiếm, theo dõi dung lượng.
- Nhập tài liệu linh hoạt: DOI, ISBN, PMID, arXiv, file `.bib`/`.ris`, URL, upload PDF và nhập thủ công.
- Làm giàu dữ liệu tự động: đồng bộ metadata từ nhiều nguồn, bổ sung thông tin tham khảo.
- Xử lý PDF thông minh: trích xuất nội dung, tóm tắt, chat theo ngữ cảnh tài liệu.
- Fact-check DOI và phát hiện tham chiếu không hợp lệ (hallucination).
- Knowledge Graph: gợi ý mối liên kết giữa các tài liệu trong thư viện.
- Hỗ trợ tích hợp cloud storage: Google Drive, Dropbox, OneDrive.
- Hỗ trợ extension/web clipper để thu thập nội dung từ web.

## 2) Công nghệ nổi bật

| Nhóm | Công nghệ |
|---|---|
| Client | Flutter (Web/Mobile/Desktop), Provider |
| API Gateway | Node.js, Express |
| AI Engine | Python, FastAPI, Uvicorn |
| AI/LLM | Gemini API, LangChain |
| Cơ sở dữ liệu | PostgreSQL + pgvector |
| Xác thực | Firebase Admin |
| Tích hợp ngoài | Google APIs, Dropbox SDK, Microsoft Graph |
| Hạ tầng local | Docker Compose |

Điểm mạnh kỹ thuật của dự án:

- Kiến trúc tách lớp rõ ràng giữa phần nghiệp vụ API và phần AI xử lý chuyên sâu.
- Vector database với pgvector để phục vụ semantic search và RAG.
- Thiết kế mở để bổ sung nguồn dữ liệu học thuật hoặc nhà cung cấp AI mới.

## 3) Kiến trúc tổng quan

```text
Flutter app (app/)  <-->  Node API Gateway (backend_api/:3000)
                               |
                               +--> AI Engine (ai_engine/:8000)
                               |
                               +--> PostgreSQL + pgvector (5432)
                               |
                               +--> Firebase Admin, cloud providers (Drive/Dropbox/OneDrive)
```

## 4) Cấu trúc thư mục quan trọng

- `app/`: ứng dụng Flutter.
- `backend_api/`: API Gateway (Express).
- `ai_engine/`: dịch vụ AI (FastAPI).
- `database_setup/`: Docker + SQL migration cho PostgreSQL/pgvector.
- `docs/`: tài liệu nghiệp vụ và hướng dẫn tính năng.
- `refmind_extension/`: browser extension (web clipper).

## 5) Yêu cầu hệ thống

- Node.js 18+
- Python 3.10+ (khuyến nghị 3.11)
- Flutter SDK 3.10+
- Docker Desktop
- PowerShell (Windows)

## 6) Khởi động nhanh (local)

Thực hiện theo đúng thứ tự dưới đây.

### Bước 1: Chạy database (PostgreSQL + pgvector)

```powershell
cd database_setup
docker compose up -d
```

Thông tin mặc định:

- Host: `localhost`
- Port: `5432`
- DB: `refmind_db`
- User: `admin`
- Password: `adminpassword123`

### Bước 2: Chạy AI Engine (FastAPI, port 8000)

```powershell
cd ai_engine
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

### Bước 3: Chạy Node API Gateway (port 3000)

```powershell
cd backend_api
npm install
npm run dev
```

Nếu chưa có nodemon:

```powershell
npm start
```

### Bước 4: Chạy Flutter app

```powershell
cd app
flutter pub get
flutter run -d chrome
```

## 7) Biến môi trường cần thiết

Hiện tại dự án chưa có `.env.example` đồng bộ cho toàn bộ monorepo. Cần tạo `.env` riêng cho `backend_api/` và `ai_engine/`.

### 7.1 backend_api/.env

```env
PORT=3000

DB_HOST=localhost
DB_PORT=5432
DB_NAME=refmind_db
DB_USER=admin
DB_PASSWORD=adminpassword123

AI_ENGINE_URL=http://localhost:8000
GEMINI_API_KEY=your_gemini_key

FIREBASE_SERVICE_ACCOUNT=./config/serviceAccountKey.json
FIREBASE_API_KEY=your_firebase_web_api_key

GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret
GOOGLE_REDIRECT_URI=http://localhost:3000/api/cloud/google/callback

DROPBOX_CLIENT_ID=your_dropbox_client_id
DROPBOX_CLIENT_SECRET=your_dropbox_client_secret
DROPBOX_REDIRECT_URI=http://localhost:3000/api/cloud/dropbox/callback

ONEDRIVE_CLIENT_ID=your_onedrive_client_id
ONEDRIVE_CLIENT_SECRET=your_onedrive_client_secret
ONEDRIVE_REDIRECT_URI=http://localhost:3000/api/cloud/onedrive/callback
ONEDRIVE_TENANT=common

UPLOAD_DIR=./uploads
STORAGE_QUOTA_BYTES=314572800
NODE_ENV=development
```

### 7.2 ai_engine/.env

```env
PORT=8000

DB_HOST=localhost
DB_PORT=5432
DB_NAME=refmind_db
DB_USER=admin
DB_PASSWORD=adminpassword123

GEMINI_API_KEY=your_gemini_key
ENCRYPTION_KEY=your_32_byte_base64_or_secure_key

FIREBASE_SERVICE_ACCOUNT=.\config\serviceAccountKey.json

SUPABASE_URL=your_supabase_url
SUPABASE_KEY=your_supabase_key

SCOPUS_API_KEY=optional_scopus_key
IEEE_API_KEY=optional_ieee_key
```

Lưu ý:

- Firebase service account cần đúng đường dẫn và quyền truy cập.
- `GEMINI_API_KEY` đang được dùng ở cả backend API và AI Engine.

## 8) Kiểm tra sau khi chạy

```powershell
# Node API Gateway
curl http://localhost:3000/

# AI Engine
curl http://localhost:8000/
```

Kỳ vọng:

- `http://localhost:3000/` trả về trạng thái API Gateway hoạt động.
- `http://localhost:8000/` trả về `status: ok`.

## 9) Android emulator networking (nếu test mobile)

```powershell
$env:Path += ";$env:LOCALAPPDATA\Android\Sdk\platform-tools"
adb reverse tcp:3000 tcp:3000
adb reverse tcp:8000 tcp:8000
```

## 10) Các nhóm API chính

### backend_api (Express)

- `/api/auth`: đăng nhập/xác thực.
- `/api/user`: quản lý hồ sơ người dùng.
- `/api/storage`: quản lý kho tài liệu.
- `/api/dashboard`: thống kê.
- `/api/chat`: luồng chat.
- `/api/doi`: xử lý DOI.
- `/api/import`: nhập tài liệu (identifier/file/manual).
- `/api/cloud`: kết nối cloud storage.
- `/api/extension`: API cho extension/web clipper.
- `/api/citation`: trích dẫn/export.
- `/api/graph`, `/api/ai/...`: knowledge graph và AI suggestions.

### ai_engine (FastAPI)

- `POST /process-pdf`
- `POST /summarize-document`
- `POST /process-doi`
- `POST /process-url`
- `POST /chat`
- `POST /extract-metadata`

## 11) Tài liệu chi tiết

Xem thêm trong thư mục `docs/`:

- `QUICK_START_DOCUMENT_IMPORT.md`
- `QUICK_START_ADVANCED_FEATURES.md`
- `DOI_ENRICHMENT_GUIDE.md`
- `WEB_CLIPPER_IMPLEMENTATION.md`
- `EXTENSION_WORKFLOW.md`

## 12) Troubleshooting nhanh

- Lỗi kết nối DB:
  - Kiểm tra `docker compose ps` trong `database_setup/`.
  - Kiểm tra biến `DB_*` trong 2 file `.env`.
- Lỗi Firebase Admin:
  - Đặt file service account vào `backend_api/config/` hoặc `ai_engine/config/`.
  - Cập nhật `FIREBASE_SERVICE_ACCOUNT`.
- API 3000 chạy được nhưng tính năng AI lỗi:
  - Kiểm tra AI Engine có chạy port 8000 không.
  - Kiểm tra `AI_ENGINE_URL` trong `backend_api/.env`.
- Flutter không gọi được API:
  - Kiểm tra base URL trong app.
  - Nếu dùng emulator, chạy `adb reverse`.

## 13) Ghi chú

- Dự án đang trong giai đoạn tích hợp nhiều module, có thể có script/migration theo từng đợt release.
- Nên tách gọn `requirements.txt` của AI Engine cho môi trường production để giảm thời gian build và tránh xung đột dependency.