-- ✅ MIGRATION: Add highlights table for PDF annotations
-- Run this script to create the highlights table

CREATE TABLE IF NOT EXISTS highlights (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    item_id UUID NOT NULL REFERENCES storage_items(id) ON DELETE CASCADE,
    
    -- Highlight content
    text TEXT NOT NULL,
    note TEXT,
    color VARCHAR(20) DEFAULT 'yellow',
    
    -- Position info
    page_number INTEGER NOT NULL,
    position_data JSONB, -- Store bounding box or additional position info
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for fast queries
CREATE INDEX IF NOT EXISTS idx_highlights_user_id ON highlights(user_id);
CREATE INDEX IF NOT EXISTS idx_highlights_item_id ON highlights(item_id);
CREATE INDEX IF NOT EXISTS idx_highlights_created_at ON highlights(created_at DESC);

-- Add trigger to update updated_at
CREATE OR REPLACE FUNCTION update_highlights_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_highlights_timestamp ON highlights;
CREATE TRIGGER trigger_update_highlights_timestamp
    BEFORE UPDATE ON highlights
    FOR EACH ROW
    EXECUTE FUNCTION update_highlights_updated_at();

COMMENT ON TABLE highlights IS 'Stores user highlights and notes for PDF documents';
COMMENT ON COLUMN highlights.text IS 'The selected/highlighted text from PDF';
COMMENT ON COLUMN highlights.note IS 'User note/comment for this highlight';
COMMENT ON COLUMN highlights.color IS 'Highlight color: yellow, green, blue, red, purple';
COMMENT ON COLUMN highlights.position_data IS 'JSON with bounding box coordinates for rendering';
