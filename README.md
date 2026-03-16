# Refmind

Refmind la he thong quan ly tai lieu hoc thuat theo mo hinh monorepo, gom 3 thanh phan chinh:

- Flutter app cho client (web/mobile/desktop)
- Node.js API Gateway cho auth, storage, dashboard va business flow
- Python FastAPI AI Engine cho xu ly PDF, DOI/URL, embedding va chat

Muc tieu cua du an: tu dong hoa import tai lieu, enrich metadata, tao vector embedding, va ho tro chat/fact-check tren kho tai lieu.

## 1) Kien truc tong quan

```text
Flutter app (app/)  <-->  Node API Gateway (backend_api/:3000)
															 |
															 +--> AI Engine (ai_engine/:8000)
															 |
															 +--> PostgreSQL + pgvector (5432)
															 |
															 +--> Firebase Admin, cloud providers (Drive/Dropbox/OneDrive)
```

## 2) Cau truc thu muc quan trong

- `app/`: ung dung Flutter
- `backend_api/`: API Gateway (Express)
- `ai_engine/`: AI service (FastAPI)
- `database_setup/`: Docker + SQL migration cho PostgreSQL/pgvector
- `docs/`: tai lieu nghiep vu va huong dan tinh nang
- `refmind_extension/`: browser extension (web clipper)

## 3) Yeu cau he thong

- Node.js 18+
- Python 3.10+ (khuyen nghi 3.11)
- Flutter SDK 3.10+
- Docker Desktop (de chay PostgreSQL nhanh)
- PowerShell (Windows)

## 4) Khoi dong nhanh (local)

Thuc hien theo dung thu tu ben duoi.

### Buoc 1: Chay database (PostgreSQL + pgvector)

```powershell
cd database_setup
docker compose up -d
```

Thong tin mac dinh tu `docker-compose.yml`:

- Host: `localhost`
- Port: `5432`
- DB: `refmind_db`
- User: `admin`
- Password: `adminpassword123`

### Buoc 2: Chay AI Engine (FastAPI, port 8000)

```powershell
cd ai_engine
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

### Buoc 3: Chay Node API Gateway (port 3000)

```powershell
cd backend_api
npm install
npm run dev
```

Neu khong co nodemon:

```powershell
npm start
```

### Buoc 4: Chay Flutter app

```powershell
cd app
flutter pub get
flutter run -d chrome
```

## 5) Bien moi truong can thiet

Du an hien tai chua co `.env.example` dong bo cho toan bo monorepo. Ban can tao `.env` rieng cho `backend_api/` va `ai_engine/`.

### 5.1 backend_api/.env

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

### 5.2 ai_engine/.env

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

Luu y:

- Firebase service account can dat dung duong dan va dung quyen.
- `GEMINI_API_KEY` duoc dung o ca backend API va AI Engine.

## 6) Kiem tra he thong sau khi chay

### API health checks

```powershell
# Node API Gateway
curl http://localhost:3000/

# AI Engine
curl http://localhost:8000/
```

Ky vong:

- `http://localhost:3000/` tra ve thong bao API gateway healthy
- `http://localhost:8000/` tra ve `status: ok`

## 7) Android emulator networking (neu test mobile)

Neu app Flutter chay tren Android emulator va backend chay local tren may host:

```powershell
$env:Path += ";$env:LOCALAPPDATA\Android\Sdk\platform-tools"
adb reverse tcp:3000 tcp:3000
adb reverse tcp:8000 tcp:8000
```

## 8) Tunnel test nhanh (localtunnel password)

```powershell
(Invoke-WebRequest -Uri "https://loca.lt/mytunnelpassword" -UseBasicParsing -TimeoutSec 20).Content
$p=(Invoke-WebRequest -Uri "https://loca.lt/mytunnelpassword" -UseBasicParsing -TimeoutSec 20).Content; $p; Set-Clipboard $p
```

## 9) Cac nhom API chinh

### backend_api (Express)

- `/api/auth`: dang nhap/xac thuc
- `/api/user`: user profile
- `/api/storage`: quan ly kho tai lieu
- `/api/dashboard`: thong ke
- `/api/chat`: chat workflow
- `/api/doi`: DOI processing
- `/api/import`: import tai lieu (identifier/file/manual)
- `/api/cloud`: ket noi cloud storage
- `/api/extension`: browser extension APIs
- `/api/citation`: trich dan/export
- `/api/graph`, `/api/ai/...`: knowledge graph + AI suggestions

### ai_engine (FastAPI)

- `POST /process-pdf`
- `POST /summarize-document`
- `POST /process-doi`
- `POST /process-url`
- `POST /chat`
- `POST /extract-metadata`

## 10) Tai lieu chi tiet

Xem them trong thu muc `docs/`:

- `QUICK_START_DOCUMENT_IMPORT.md`
- `QUICK_START_ADVANCED_FEATURES.md`
- `DOI_ENRICHMENT_GUIDE.md`
- `WEB_CLIPPER_IMPLEMENTATION.md`
- `EXTENSION_WORKFLOW.md`

## 11) Troubleshooting nhanh

- Loi ket noi DB:
	- Kiem tra `docker compose ps` trong `database_setup/`
	- Kiem tra `DB_*` trong 2 file `.env`
- Loi Firebase Admin:
	- Dat file service account vao `backend_api/config/` hoac `ai_engine/config/`
	- Cap nhat bien `FIREBASE_SERVICE_ACCOUNT`
- API 3000 chay duoc nhung tinh nang AI loi:
	- Kiem tra AI Engine co dang chay port 8000
	- Kiem tra `AI_ENGINE_URL` trong `backend_api/.env`
- Flutter khong goi duoc API:
	- Kiem tra endpoint base URL trong code app
	- Neu emulator, dung `adb reverse`

## 12) Ghi chu

- Repo dang o giai doan phat trien tich hop nhieu module, co the ton tai mot so script/migration theo tung dot release.
- Nen tach rieng `requirements.txt` cua AI Engine de loai bo dependencies khong can thiet trong moi truong production.