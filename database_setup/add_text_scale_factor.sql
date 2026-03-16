-- Add text_scale_factor column to users table for accessibility feature
-- Default: 1.0 (100%), Range: 0.8 - 1.5

ALTER TABLE users 
ADD COLUMN IF NOT EXISTS text_scale_factor DECIMAL(3,2) DEFAULT 1.0 CHECK (text_scale_factor >= 0.8 AND text_scale_factor <= 1.5);

COMMENT ON COLUMN users.text_scale_factor IS 'User font size preference (0.8 to 1.5, default 1.0)';
