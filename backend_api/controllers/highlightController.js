const db = require('../config/db');

/**
 * ✅ CREATE HIGHLIGHT
 * POST /api/items/:id/highlights
 */
const createHighlight = async (req, res) => {
  const { uid } = req.user;
  const { id: itemId } = req.params;
  const { text, note, color, page_number, position_data } = req.body;

  try {
    // Validate input
    if (!text || !page_number) {
      return res.status(400).json({
        success: false,
        error: 'Text and page_number are required'
      });
    }

    // Verify item belongs to user
    const itemCheck = await db.query(
      'SELECT id FROM storage_items WHERE id = $1 AND user_id = $2::TEXT',
      [itemId, uid]
    );

    if (itemCheck.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Item not found or access denied'
      });
    }

    // Insert highlight
    const result = await db.query(
      `INSERT INTO highlights 
       (user_id, item_id, text, note, color, page_number, position_data) 
       VALUES ($1::TEXT, $2, $3, $4, $5, $6, $7) 
       RETURNING *`,
      [
        uid,
        itemId,
        text,
        note || null,
        color || 'yellow',
        page_number,
        position_data ? JSON.stringify(position_data) : null
      ]
    );

    res.status(201).json({
      success: true,
      data: result.rows[0]
    });

  } catch (error) {
    console.error('❌ Create Highlight Error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
};

/**
 * ✅ GET ALL HIGHLIGHTS FOR AN ITEM
 * GET /api/items/:id/highlights
 */
const getHighlights = async (req, res) => {
  const { uid } = req.user;
  const { id: itemId } = req.params;

  try {
    const result = await db.query(
      `SELECT * FROM highlights 
       WHERE item_id = $1 AND user_id = $2::TEXT 
       ORDER BY page_number ASC, created_at ASC`,
      [itemId, uid]
    );

    res.status(200).json({
      success: true,
      data: result.rows
    });

  } catch (error) {
    console.error('❌ Get Highlights Error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
};

/**
 * ✅ UPDATE HIGHLIGHT
 * PUT /api/highlights/:highlightId
 */
const updateHighlight = async (req, res) => {
  const { uid } = req.user;
  const { highlightId } = req.params;
  const { note, color } = req.body;

  try {
    const result = await db.query(
      `UPDATE highlights 
       SET note = COALESCE($1, note), 
           color = COALESCE($2, color),
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $3 AND user_id = $4::TEXT 
       RETURNING *`,
      [note, color, highlightId, uid]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Highlight not found or access denied'
      });
    }

    res.status(200).json({
      success: true,
      data: result.rows[0]
    });

  } catch (error) {
    console.error('❌ Update Highlight Error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
};

/**
 * ✅ DELETE HIGHLIGHT
 * DELETE /api/highlights/:highlightId
 */
const deleteHighlight = async (req, res) => {
  const { uid } = req.user;
  const { highlightId } = req.params;

  try {
    const result = await db.query(
      'DELETE FROM highlights WHERE id = $1 AND user_id = $2::TEXT RETURNING id',
      [highlightId, uid]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Highlight not found or access denied'
      });
    }

    res.status(200).json({
      success: true,
      message: 'Highlight deleted successfully'
    });

  } catch (error) {
    console.error('❌ Delete Highlight Error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
};

module.exports = {
  createHighlight,
  getHighlights,
  updateHighlight,
  deleteHighlight
};
