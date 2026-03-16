-- =================================================================================
-- Migration: Add storage preference to users table
-- Date: 2026-02-27
-- Description: Allow users to choose their preferred storage location
-- =================================================================================

-- Add preferred_storage column to users table
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS preferred_storage VARCHAR(20) DEFAULT 'auto' 
CHECK (preferred_storage IN ('auto', 'local', 'gdrive', 'dropbox', 'onedrive'));

-- Comment for documentation
COMMENT ON COLUMN users.preferred_storage IS 
'User preferred storage location: auto (use cloud if available), local, gdrive, dropbox, onedrive';

-- Set default to 'auto' for existing users (backward compatible)
UPDATE users 
SET preferred_storage = 'auto' 
WHERE preferred_storage IS NULL;

-- ✅ Migration complete
SELECT 'Storage preference column added successfully' AS status;
