-- =================================================================================
-- 1. SETUP SCHEMAS & EXTENSIONS
-- =================================================================================

-- Tạo schema riêng cho các tiện ích mở rộng để không làm rác schema public
CREATE SCHEMA IF NOT EXISTS extensions;
GRANT USAGE ON SCHEMA extensions TO public;

-- Cài đặt các extensions cần thiết vào schema extensions
CREATE EXTENSION IF NOT EXISTS vector SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" SCHEMA extensions;

-- Thiết lập đường dẫn tìm kiếm mặc định cho database (Thay refmind_db bằng tên DB của bạn nếu khác)
ALTER DATABASE refmind_db SET search_path TO public, extensions;

-- Set search_path cho phiên chạy hiện tại để các lệnh dưới hoạt động đúng
SET search_path = public, extensions;

-- =================================================================================
-- 2. TẠO BẢNG USERS
-- =================================================================================
CREATE TABLE IF NOT EXISTS users (
    user_id SERIAL PRIMARY KEY,
    firebase_uid VARCHAR(128) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    full_name VARCHAR(255),
    avatar_url TEXT,
    role VARCHAR(20) DEFAULT 'student',
    
    -- API Keys & Settings
    openai_key TEXT,
    gemini_key TEXT,
    use_own_key BOOLEAN DEFAULT FALSE,
    active_provider VARCHAR(20) DEFAULT 'system',
    
    -- App Preferences
    is_dark_mode BOOLEAN DEFAULT FALSE,
    enable_notifications BOOLEAN DEFAULT TRUE,
    preferred_storage VARCHAR(20) DEFAULT 'auto' CHECK (preferred_storage IN ('auto', 'local', 'gdrive', 'dropbox', 'onedrive')),
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP WITH TIME ZONE
);

-- =================================================================================
-- 3. TẠO BẢNG STORAGE_ITEMS (Lưu trữ file)
-- =================================================================================
CREATE TABLE IF NOT EXISTS storage_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id TEXT NOT NULL, -- ✅ Đúng: dùng firebase_uid
    parent_id UUID REFERENCES storage_items(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    type VARCHAR(20) NOT NULL CHECK (type IN ('folder', 'file')), 
    file_url TEXT,
    size_bytes BIGINT DEFAULT 0,
    
    provider TEXT DEFAULT 'local', 
    has_pdf BOOLEAN DEFAULT TRUE,  
    
    metadata JSONB DEFAULT '{}'::JSONB, 
    is_favorite BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ✅ Index để truy vấn nhanh
CREATE INDEX IF NOT EXISTS idx_parent_id ON storage_items(parent_id);
CREATE INDEX IF NOT EXISTS idx_user_id ON storage_items(user_id);

-- ✅ THÊM FOREIGN KEY với bảng users (đúng cột firebase_uid)
ALTER TABLE storage_items 
ADD CONSTRAINT fk_storage_user 
FOREIGN KEY (user_id) REFERENCES users(firebase_uid) ON DELETE CASCADE;

-- =================================================================================
-- 4. TẠO BẢNG DOCUMENT_EMBEDDINGS (Vector AI)
-- =================================================================================
CREATE TABLE IF NOT EXISTS document_embeddings (
    id BIGSERIAL PRIMARY KEY,
    file_id UUID REFERENCES storage_items(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL,
    content TEXT NOT NULL,
    embedding vector(768), -- Kích thước vector của mô hình Gemini
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =================================================================================
-- 5. TẠO BẢNG CHAT_SESSIONS (Phiên hội thoại)
-- =================================================================================
CREATE TABLE IF NOT EXISTS chat_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id TEXT NOT NULL,
    related_file_id UUID REFERENCES storage_items(id) ON DELETE CASCADE,
    title TEXT DEFAULT 'Trò chuyện mới',
    type TEXT DEFAULT 'single_doc',
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =================================================================================
-- 6. TẠO BẢNG CHAT_MESSAGES (Tin nhắn)
-- =================================================================================
CREATE TABLE IF NOT EXISTS chat_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID REFERENCES chat_sessions(id) ON DELETE CASCADE,
    role TEXT NOT NULL,
    content TEXT NOT NULL,
    citations JSONB DEFAULT '[]'::jsonb, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =================================================================================
-- 7. TẠO HÀM TÌM KIẾM VECTOR (Đã fix bảo mật schema và hỗ trợ file_id)
-- =================================================================================
CREATE OR REPLACE FUNCTION match_documents (
    query_embedding vector(768),
    match_threshold float,
    match_count int,
    filter_user_id TEXT,
    filter_file_id uuid
)
RETURNS TABLE (
    id bigint,
    content text,
    metadata jsonb,
    similarity float,
    file_id uuid
)
LANGUAGE plpgsql STABLE
SET search_path = public, extensions -- Fix lỗi bảo mật search_path
AS $$
BEGIN
    RETURN QUERY
    SELECT
        document_embeddings.id,
        document_embeddings.content,
        document_embeddings.metadata,
        1 - (document_embeddings.embedding <=> query_embedding) AS similarity,
        document_embeddings.file_id
    FROM document_embeddings
    WHERE 1 - (document_embeddings.embedding <=> query_embedding) > match_threshold
    -- Lọc theo User
    AND (filter_user_id IS NULL OR document_embeddings.user_id = filter_user_id)
    -- Lọc theo File (Nếu NULL thì tìm toàn bộ)
    AND (filter_file_id IS NULL OR document_embeddings.file_id = filter_file_id)
    ORDER BY document_embeddings.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;