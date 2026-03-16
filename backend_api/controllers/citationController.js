const db = require('../config/db');
const citationService = require('../services/citationService');
const { Parser } = require('json2csv');

/**
 * ===================================================
 * CITATION CONTROLLER - XỬ LÝ API TRÍCH DẪN & EXPORT
 * ===================================================
 */

// ✅ GENERATE CITATION FOR SINGLE ITEM
const generateCitation = async (req, res) => {
  const { uid } = req.user;
  const { item_id } = req.params;
  const { style = 'apa' } = req.query;

  try {
    console.log(`📝 [Citation] Generate citation: item=${item_id}, style=${style}, user=${uid}`);

    // Get item metadata from database
    const query = `
      SELECT id, name, metadata
      FROM storage_items
      WHERE id = $1 AND user_id = $2::TEXT AND type = 'file'
    `;
    const result = await db.query(query, [item_id, uid]);

    if (result.rows.length === 0) {
      return res.status(404).json({ 
        success: false, 
        error: 'Item not found' 
      });
    }

    const item = result.rows[0];
    const metadata = item.metadata || {};

    // Validate: Check if metadata has minimal info
    if (!metadata.title && !metadata.authors) {
      return res.status(400).json({
        success: false,
        error: 'Insufficient metadata for citation. Please add title and authors.',
        hint: 'You can edit the metadata in the document details.'
      });
    }

    // Generate citation
    const citation = citationService.generateCitation(metadata, style);

    console.log(`✅ [Citation] Generated: ${citation.substring(0, 100)}...`);

    res.json({
      success: true,
      data: {
        citation: citation,
        style: style,
        item_id: item_id,
        title: metadata.title || item.name
      }
    });

  } catch (error) {
    console.error('❌ [Citation] Generate error:', error);
    res.status(500).json({ 
      success: false, 
      error: error.message,
      hint: 'Citation generation failed. Check if metadata is properly formatted.'
    });
  }
};

// ✅ EXPORT LIBRARY (ALL ITEMS)
const exportLibrary = async (req, res) => {
  const { uid } = req.user;
  const { format = 'bib' } = req.query;

  try {
    console.log(`📦 [Citation] Export library: format=${format}, user=${uid}`);

    // Get all user's documents with metadata
    const query = `
      SELECT id, name, metadata, file_url, created_at
      FROM storage_items
      WHERE user_id = $1::TEXT AND type = 'file'
      ORDER BY created_at DESC
    `;
    const result = await db.query(query, [uid]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'No documents found in your library'
      });
    }

    const items = result.rows;
    console.log(`📚 [Citation] Found ${items.length} documents to export`);

    // Generate export based on format
    if (format === 'bib' || format === 'bibtex') {
      // BibTeX format
      const bibContent = citationService.generateBibTeX(items);

      res.setHeader('Content-Type', 'text/plain; charset=utf-8');
      res.setHeader('Content-Disposition', 'attachment; filename="refmind-library.bib"');
      res.send(bibContent);

      console.log(`✅ [Citation] Exported ${items.length} items as BibTeX`);

    } else if (format === 'csv') {
      // CSV format
      const csvData = items.map(item => citationService.metadataToCSVRow(item));

      const fields = [
        'id', 'title', 'authors', 'year', 'journal', 'publisher',
        'volume', 'issue', 'pages', 'doi', 'url', 'abstract', 'created_at'
      ];

      const parser = new Parser({ fields });
      const csv = parser.parse(csvData);

      res.setHeader('Content-Type', 'text/csv; charset=utf-8');
      res.setHeader('Content-Disposition', 'attachment; filename="refmind-library.csv"');
      res.send(csv);

      console.log(`✅ [Citation] Exported ${items.length} items as CSV`);

    } else {
      return res.status(400).json({
        success: false,
        error: 'Invalid format. Use "bib" or "csv"'
      });
    }

  } catch (error) {
    console.error('❌ [Citation] Export error:', error);
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
};

// ✅ PLUGIN API: SEARCH DOCUMENTS
const pluginSearch = async (req, res) => {
  const { uid } = req.user;
  const { q = '' } = req.query;

  try {
    console.log(`🔍 [Plugin] Search: query="${q}", user=${uid}`);

    // Search in title, authors, abstract
    const query = `
      SELECT 
        id, 
        name, 
        metadata,
        created_at
      FROM storage_items
      WHERE user_id = $1::TEXT 
        AND type = 'file'
        AND (
          name ILIKE $2
          OR metadata->>'title' ILIKE $2
          OR metadata->>'abstract' ILIKE $2
          OR metadata->>'authors' ILIKE $2
        )
      ORDER BY created_at DESC
      LIMIT 50
    `;

    const searchPattern = `%${q}%`;
    const result = await db.query(query, [uid, searchPattern]);

    const documents = result.rows.map(item => ({
      id: item.id,
      title: item.metadata?.title || item.name,
      authors: item.metadata?.authors || [],
      year: item.metadata?.year,
      abstract: item.metadata?.abstract,
      doi: item.metadata?.doi,
      created_at: item.created_at
    }));

    console.log(`✅ [Plugin] Found ${documents.length} documents`);

    res.json({
      success: true,
      data: {
        query: q,
        count: documents.length,
        documents: documents
      }
    });

  } catch (error) {
    console.error('❌ [Plugin] Search error:', error);
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
};

// ✅ PLUGIN API: GET HIGHLIGHTS FOR ITEM
const pluginGetHighlights = async (req, res) => {
  const { uid } = req.user;
  const { item_id } = req.params;

  try {
    console.log(`📝 [Plugin] Get highlights: item=${item_id}, user=${uid}`);

    // Get item info
    const itemQuery = `
      SELECT id, name, metadata
      FROM storage_items
      WHERE id = $1 AND user_id = $2::TEXT AND type = 'file'
    `;
    const itemResult = await db.query(itemQuery, [item_id, uid]);

    if (itemResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Document not found'
      });
    }

    const item = itemResult.rows[0];

    // Get highlights
    const highlightsQuery = `
      SELECT id, text, note, color, page_number, created_at
      FROM highlights
      WHERE item_id = $1 AND user_id = $2::TEXT
      ORDER BY page_number ASC, created_at ASC
    `;
    const highlightsResult = await db.query(highlightsQuery, [item_id, uid]);

    console.log(`✅ [Plugin] Found ${highlightsResult.rows.length} highlights`);

    res.json({
      success: true,
      data: {
        document: {
          id: item.id,
          title: item.metadata?.title || item.name,
          authors: item.metadata?.authors || [],
          year: item.metadata?.year
        },
        highlights: highlightsResult.rows
      }
    });

  } catch (error) {
    console.error('❌ [Plugin] Get highlights error:', error);
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
};

// ✅ GET CITATION STYLES LIST
const getCitationStyles = async (req, res) => {
  try {
    const styles = [
      { id: 'apa', name: 'APA 7th', example: 'Smith, J. (2020). Title. Journal.' },
      { id: 'apa6', name: 'APA 6th', example: 'Smith, J. (2020). Title. Journal, 10(2).' },
      { id: 'ieee', name: 'IEEE', example: '[1] J. Smith, "Title," Journal, 2020.' },
      { id: 'harvard', name: 'Harvard', example: 'Smith, J. 2020, \'Title\', Journal.' },
      { id: 'mla', name: 'MLA', example: 'Smith, John. "Title." Journal 2020.' },
      { id: 'chicago', name: 'Chicago', example: 'Smith, John. "Title." Journal 10 (2020): 1-10.' },
      { id: 'vancouver', name: 'Vancouver', example: 'Smith J. Title. Journal. 2020;10(2):1-10.' },
      { id: 'nature', name: 'Nature', example: 'Smith, J. Title. Journal 10, 1-10 (2020).' },
      { id: 'acs', name: 'ACS (Chemistry)', example: 'Smith, J. Title. Journal 2020, 10, 1-10.' },
      { id: 'bibtex', name: 'BibTeX', example: '@article{smith2020, author={Smith}, ...}' }
    ];

    res.json({
      success: true,
      data: styles
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
};

module.exports = {
  generateCitation,
  exportLibrary,
  pluginSearch,
  pluginGetHighlights,
  getCitationStyles
};
