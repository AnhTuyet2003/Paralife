-- 1. XÓA CONSTRAINT CŨ
ALTER TABLE document_embeddings DROP CONSTRAINT IF EXISTS fk_doc_file;

-- 2. XÓA BẢNG CŨ VÀ TẠO LẠI VỚI DIMENSIONS ĐÚNG
DROP TABLE IF EXISTS document_embeddings CASCADE;

CREATE TABLE document_embeddings (
    id BIGSERIAL PRIMARY KEY,
    file_id UUID REFERENCES storage_items(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL,
    content TEXT NOT NULL,
    embedding vector(3072), -- ✅ ĐÚNG: 3072 dimensions cho gemini-embedding-001
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. TẠO LẠI FUNCTION SEARCH VỚI DIMENSIONS MỚI
CREATE OR REPLACE FUNCTION match_documents (
    query_embedding vector(3072), -- ✅ ĐỔI THÀNH 3072
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
SET search_path = public, extensions
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
    AND (filter_user_id IS NULL OR document_embeddings.user_id = filter_user_id)
    AND (filter_file_id IS NULL OR document_embeddings.file_id = filter_file_id)
    ORDER BY document_embeddings.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;
