/**
 * Fact Check Controller
 * Validate DOI references to detect hallucinations
 */

const db = require('../config/db');
const crossrefService = require('../services/crossrefService');

/**
 * POST /api/items/:id/fact-check
 * Check all DOIs in a document for validity
 */
async function factCheckDocument(req, res) {
  const { id } = req.params;
  const userId = req.user.uid;

  try {
    // Get document from database
    const result = await db.query(
      `SELECT id, name,
              COALESCE(metadata->>'title', name) AS title,
              metadata->>'content' AS content,
              metadata, file_url
       FROM storage_items 
       WHERE id = $1 AND user_id = $2 AND type = 'file'`,
      [id, userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ 
        success: false, 
        error: 'Document not found' 
      });
    }

    const document = result.rows[0];
    
    // Extract text content for DOI searching
    let textContent = '';
    
    // Combine all text sources
    if (document.content) {
      textContent += document.content + '\n\n';
    }
    
    if (document.metadata) {
      // Check for references in metadata
      if (document.metadata.references) {
        if (Array.isArray(document.metadata.references)) {
          textContent += document.metadata.references.join('\n') + '\n\n';
        } else if (typeof document.metadata.references === 'string') {
          textContent += document.metadata.references + '\n\n';
        }
      }
      
      // Check for abstract
      if (document.metadata.abstract) {
        textContent += document.metadata.abstract + '\n\n';
      }
    }

    // Extract DOIs from text
    const dois = crossrefService.extractDOIs(textContent);

    if (dois.length === 0) {
      return res.json({
        success: true,
        document: {
          id: document.id,
          title: document.title
        },
        summary: {
          total: 0,
          valid: 0,
          invalid: 0,
          unknown: 0
        },
        references: []
      });
    }

    console.log(`📝 Found ${dois.length} DOIs in document ${id}`);

    // Validate DOIs against Crossref API
    const validationResults = await crossrefService.validateBatch(dois);

    // Calculate summary stats
    const summary = {
      total: validationResults.length,
      valid: validationResults.filter(r => r.isValid === true).length,
      invalid: validationResults.filter(r => r.isValid === false).length,
      unknown: validationResults.filter(r => r.isValid === null).length
    };

    // Format response
    const references = validationResults.map(r => ({
      doi: r.doi,
      isValid: r.isValid,
      status: r.isValid === true ? 'valid' : (r.isValid === false ? 'hallucination' : 'unknown'),
      metadata: r.metadata,
      warning: r.isValid === false ? 'Possible hallucination - DOI not found in Crossref database' : null
    }));

    console.log(`✅ Fact check complete: ${summary.valid} valid, ${summary.invalid} invalid, ${summary.unknown} unknown`);

    res.json({
      success: true,
      document: {
        id: document.id,
        title: document.title
      },
      summary,
      references
    });

  } catch (error) {
    console.error('❌ Fact Check Error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to perform fact check',
      details: error.message
    });
  }
}

/**
 * POST /api/fact-check/validate-doi
 * Validate a single DOI (utility endpoint)
 */
async function validateSingleDOI(req, res) {
  const { doi } = req.body;

  if (!doi) {
    return res.status(400).json({
      success: false,
      error: 'DOI is required'
    });
  }

  try {
    const result = await crossrefService.validateDOI(doi);
    
    res.json({
      success: true,
      doi,
      isValid: result.isValid,
      status: result.isValid === true ? 'valid' : (result.isValid === false ? 'invalid' : 'unknown'),
      metadata: result.metadata
    });
  } catch (error) {
    console.error('❌ DOI Validation Error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to validate DOI',
      details: error.message
    });
  }
}

module.exports = {
  factCheckDocument,
  validateSingleDOI
};
