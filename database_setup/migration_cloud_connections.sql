-- =====================================================
-- MIGRATION: CREATE user_cloud_connections TABLE
-- Purpose: Store user's cloud provider connections
-- =====================================================

CREATE TABLE IF NOT EXISTS user_cloud_connections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL REFERENCES users(firebase_uid) ON DELETE CASCADE,
    provider VARCHAR(20) NOT NULL CHECK (provider IN ('gdrive', 'dropbox', 'onedrive')),
    email VARCHAR(255) NOT NULL,
    access_token TEXT NOT NULL,
    refresh_token TEXT,
    token_expires_at TIMESTAMP,
    total_space_bytes BIGINT DEFAULT 0,
    used_space_bytes BIGINT DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    -- Mỗi user chỉ có 1 connection per provider
    UNIQUE(user_id, provider)
);

-- Index for faster queries
CREATE INDEX idx_user_cloud_user_id ON user_cloud_connections(user_id);
CREATE INDEX idx_user_cloud_provider ON user_cloud_connections(provider);
CREATE INDEX idx_user_cloud_active ON user_cloud_connections(is_active);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_user_cloud_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_user_cloud_timestamp
    BEFORE UPDATE ON user_cloud_connections
    FOR EACH ROW
    EXECUTE FUNCTION update_user_cloud_timestamp();

-- Sample data for testing (optional)
-- INSERT INTO user_cloud_connections (user_id, provider, email, access_token, total_space_bytes, used_space_bytes)
-- VALUES 
--     ('test_user_123', 'gdrive', 'user@gmail.com', 'dummy_token', 16106127360, 8053063680),
--     ('test_user_123', 'dropbox', 'user@email.com', 'dummy_token', 2147483648, 536870912);

COMMENT ON TABLE user_cloud_connections IS 'Stores cloud storage provider connections for users';
COMMENT ON COLUMN user_cloud_connections.provider IS 'Cloud provider: gdrive, dropbox, onedrive';
COMMENT ON COLUMN user_cloud_connections.access_token IS 'OAuth2 access token for API calls';
COMMENT ON COLUMN user_cloud_connections.refresh_token IS 'OAuth2 refresh token to get new access token';
COMMENT ON COLUMN user_cloud_connections.total_space_bytes IS 'Total storage quota in bytes';
COMMENT ON COLUMN user_cloud_connections.used_space_bytes IS 'Used storage in bytes';
