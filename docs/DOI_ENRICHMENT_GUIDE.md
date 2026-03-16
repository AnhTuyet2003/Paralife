# 📚 DOI Processing Enhancement Guide

## ✨ New Features

### 1. **Metadata Enrichment** (Multi-Source)
Hệ thống giờ tự động lấy metadata từ nhiều nguồn:
- **Crossref** (fallback mặc định)
- **IEEE Xplore API** (cho DOI bắt đầu với `10.1109/`)
- **Scopus API** (cho DOI của Elsevier: `10.1016/`, `10.1006/`, etc.)

**Dữ liệu thu thập được:**
- Title, Authors, Year, Journal
- **Abstract** (Tóm tắt đầy đủ)
- **Citation Count** (Số lần trích dẫn)
- **Keywords** (Từ khóa)
- Publisher

### 2. **Paywall Fallback** (Xử lý bài báo bị khóa)
- **Có PDF Open Access**: Tải PDF xuống như bình thường
- **Không có PDF (Paywall)**: 
  - ✅ KHÔNG báo lỗi
  - ✅ Tự động tạo file `.txt` chứa Abstract + Metadata
  - ✅ Vẫn lưu vào database với `has_pdf = false`
  - ✅ Vẫn tạo vector embeddings từ abstract

### 3. **Local Storage Integration**
- Tất cả file (PDF hoặc TXT) đều lưu vào `/uploads`
- Database field `provider = 'local'`
- Field `metadata` chứa đầy đủ thông tin enriched

---

## 🔧 Configuration

### Cấu hình API Keys (Optional nhưng nên có)

Tạo file `.env` trong thư mục `ai_engine/`:

```bash
# Crossref - Không cần API key (public)

# IEEE Xplore API (Optional)
IEEE_API_KEY=your_ieee_api_key_here

# Scopus API (Optional)
SCOPUS_API_KEY=your_scopus_api_key_here
```

### Lấy API Keys:

#### **IEEE Xplore API**
1. Truy cập: https://developer.ieee.org/
2. Đăng ký tài khoản
3. Tạo API Key mới
4. Giới hạn: 200 requests/day (free tier)

#### **Scopus API**
1. Truy cập: https://dev.elsevier.com/
2. Đăng ký tài khoản
3. Tạo API Key (cần email tổ chức)
4. Giới hạn: Phụ thuộc vào subscription

**Lưu ý:** Nếu không config API keys:
- Hệ thống vẫn hoạt động bình thường
- Chỉ sử dụng Crossref API (vẫn rất tốt)
- Có thể thiếu một số metadata như citation count

---

## 📊 Database Schema Changes

Bảng `storage_items` giờ lưu metadata đầy đủ hơn:

```json
{
  "doi": "10.1109/CVPR.2023.12345",
  "authors": ["John Doe", "Jane Smith"],
  "year": 2023,
  "journal": "IEEE Conference on Computer Vision",
  "abstract": "Full abstract text here...",
  "citation_count": 42,
  "publisher": "IEEE",
  "keywords": ["computer vision", "deep learning", "CNN"],
  "source": "ieee",
  "is_open_access": true
}
```

---

## 🚀 Usage Examples

### Ví dụ 1: IEEE Paper (Open Access)
```json
POST /api/storage/add_by_doi
{
  "doi": "10.1109/CVPR.2023.12345",
  "parent_id": null
}
```

**Kết quả:**
- ✅ Fetch metadata từ IEEE Xplore API
- ✅ Tải PDF từ Open Access
- ✅ Lưu file `10.1109_CVPR.2023.12345.pdf` vào `/uploads`
- ✅ Tạo vector embeddings
- ✅ Response bao gồm citation count, keywords

### Ví dụ 2: Elsevier Paper (Paywall)
```json
POST /api/storage/add_by_doi
{
  "doi": "10.1016/j.neuron.2023.01.001",
  "parent_id": "folder-uuid"
}
```

**Kết quả:**
- ✅ Fetch metadata từ Scopus API
- ⚠️ Không có PDF (bị paywall)
- ✅ Tạo file `.txt` chứa Abstract + Metadata
- ✅ Lưu file `paper_title_[Abstract Only].txt` vào `/uploads`
- ✅ Tạo vector embeddings từ abstract
- ✅ `has_pdf = false` trong database

---

## 📝 Response Format

### Thành công với PDF:
```json
{
  "success": true,
  "message": "DOI processed successfully with PDF (1245 KB)",
  "data": {
    "file_id": "uuid-here",
    "file_url": "/uploads/1234567890-paper.pdf",
    "size_bytes": 1274880,
    "has_pdf": true,
    "metadata": {
      "title": "Paper Title",
      "authors": ["Author 1", "Author 2"],
      "citation_count": 42,
      "keywords": ["AI", "ML"],
      "source": "ieee"
    }
  },
  "quota": { ... }
}
```

### Thành công với Abstract:
```json
{
  "success": true,
  "message": "DOI processed - Closed access paper (abstract only)",
  "data": {
    "file_id": "uuid-here",
    "file_url": "/uploads/1234567890-paper_abstract.txt",
    "size_bytes": 2048,
    "has_pdf": false,
    "metadata": {
      "title": "Closed Access Paper",
      "abstract": "Full abstract...",
      "citation_count": 15,
      "source": "crossref"
    }
  },
  "quota": null
}
```

---

## 🔍 Implementation Files

### Python (AI Engine)
- `services/metadata_enrichment_service.py` - Fetch metadata từ nhiều nguồn
- `services/doi_service.py` - Fetch PDF từ Unpaywall
- `controllers/doi_controller.py` - Main logic xử lý DOI

### Node.js (Backend)
- `controllers/doiController.js` - Handle request từ client
- `routes/storageRoutes.js` - Route `/add_by_doi`

---

## 🎯 Benefits

1. **Tăng thông tin**: Citation count, keywords, abstract đầy đủ
2. **Không bỏ sót**: Vẫn lưu được paper paywall (abstract)
3. **Tìm kiếm tốt hơn**: Vector embeddings từ abstract
4. **UX tốt hơn**: Không báo lỗi khi gặp paywall

---

## 🐛 Troubleshooting

### IEEE/Scopus API không hoạt động?
- Kiểm tra API key trong `.env`
- Hệ thống tự động fallback về Crossref

### Không tải được PDF?
- Kiểm tra response: `has_pdf = false`
- File `.txt` vẫn được tạo với abstract

### Citation count = 0?
- Bài báo mới, chưa có citation
- Hoặc API không trả về thông tin này

---

## 📞 Support

Nếu cần thêm publisher khác (Springer, Wiley, etc.), hãy thêm function tương tự trong `metadata_enrichment_service.py`.
