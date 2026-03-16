/**
 * Knowledge Graph Controller
 * Build citation network and suggest AI-powered connections
 */

const db = require('../config/db');
const { suggestMissingLinks } = require('../services/aiService');

/**
 * GET /api/graph
 * Get knowledge graph data (nodes + links)
 */
async function getKnowledgeGraph(req, res) {
  const userId = req.user.uid;

  try {
    // Get all user's documents
    const documentsResult = await db.query(
      `SELECT id, name, 
              COALESCE(metadata->>'title', name) AS title,
              metadata, created_at, updated_at
       FROM storage_items 
       WHERE user_id = $1 AND type = 'file'
       ORDER BY created_at DESC`,
      [userId]
    );

    if (documentsResult.rows.length === 0) {
      return res.json({
        success: true,
        nodes: [],
        links: [],
        stats: { totalNodes: 0, totalLinks: 0 }
      });
    }

    const documents = documentsResult.rows;

    // Build nodes
    const nodes = documents.map(doc => {
      const metadata = doc.metadata || {};
      
      // Determine node group based on metadata
      let group = 'default';
      if (metadata.type === 'journal-article') group = 'article';
      else if (metadata.type === 'book') group = 'book';
      else if (metadata.type === 'conference-paper') group = 'conference';
      
      return {
        id: doc.id.toString(),
        title: doc.title,
        type: metadata.type || 'unknown',
        group,
        year: metadata.year,
        authors: metadata.authors,
        keywords: metadata.keywords,
        abstract: metadata.abstract
      };
    });

    // Build links based on shared references, authors, keywords
    const links = [];
    const linkSet = new Set(); // Prevent duplicates

    for (let i = 0; i < documents.length; i++) {
      for (let j = i + 1; j < documents.length; j++) {
        const doc1 = documents[i];
        const doc2 = documents[j];
        const meta1 = doc1.metadata || {};
        const meta2 = doc2.metadata || {};

        // Check for shared authors
        const authors1 = Array.isArray(meta1.authors) ? meta1.authors : [];
        const authors2 = Array.isArray(meta2.authors) ? meta2.authors : [];
        
        if (authors1.length > 0 && authors2.length > 0) {
          const sharedAuthors = authors1.filter(a => authors2.includes(a));
          if (sharedAuthors.length > 0) {
            const linkId = `${doc1.id}-${doc2.id}-author`;
            if (!linkSet.has(linkId)) {
              links.push({
                source: doc1.id.toString(),
                target: doc2.id.toString(),
                type: 'shared_author',
                strength: Math.min(sharedAuthors.length / 3, 1), // 0-1 scale
                label: `${sharedAuthors.length} shared author(s)`
              });
              linkSet.add(linkId);
            }
          }
        }

        // Check for shared keywords
        const keywords1 = Array.isArray(meta1.keywords) ? meta1.keywords : 
                          typeof meta1.keywords === 'string' ? meta1.keywords.split(',').map(k => k.trim()) : [];
        const keywords2 = Array.isArray(meta2.keywords) ? meta2.keywords :
                          typeof meta2.keywords === 'string' ? meta2.keywords.split(',').map(k => k.trim()) : [];
        
        if (keywords1.length > 0 && keywords2.length > 0) {
          const sharedKeywords = keywords1.filter(k => 
            keywords2.some(k2 => k.toLowerCase() === k2.toLowerCase())
          );
          
          if (sharedKeywords.length > 0) {
            const linkId = `${doc1.id}-${doc2.id}-keyword`;
            if (!linkSet.has(linkId)) {
              links.push({
                source: doc1.id.toString(),
                target: doc2.id.toString(),
                type: 'shared_keyword',
                strength: Math.min(sharedKeywords.length / 5, 1),
                label: `${sharedKeywords.length} shared keyword(s)`
              });
              linkSet.add(linkId);
            }
          }
        }

        // Check for citations (if references metadata exists)
        const refs1 = Array.isArray(meta1.references) ? meta1.references : [];
        const refs2 = Array.isArray(meta2.references) ? meta2.references : [];
        
        // Simple check: if doc1 references doc2's DOI or title
        if (meta2.doi && refs1.some(ref => typeof ref === 'string' && ref.includes(meta2.doi))) {
          const linkId = `${doc1.id}-${doc2.id}-citation`;
          if (!linkSet.has(linkId)) {
            links.push({
              source: doc1.id.toString(),
              target: doc2.id.toString(),
              type: 'citation',
              strength: 1,
              label: 'Citations'
            });
            linkSet.add(linkId);
          }
        }
      }
    }

    console.log(`📊 Knowledge graph: ${nodes.length} nodes, ${links.length} links`);

    res.json({
      success: true,
      nodes,
      links,
      stats: {
        totalNodes: nodes.length,
        totalLinks: links.length,
        linkTypes: {
          shared_author: links.filter(l => l.type === 'shared_author').length,
          shared_keyword: links.filter(l => l.type === 'shared_keyword').length,
          citation: links.filter(l => l.type === 'citation').length
        }
      }
    });

  } catch (error) {
    console.error('❌ Knowledge Graph Error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to generate knowledge graph',
      details: error.message
    });
  }
}

/**
 * GET /api/ai/missing-links
 * Get AI-suggested connections between unconnected papers
 */
async function getAIMissingLinks(req, res) {
  const userId = req.user.uid;

  try {
    // Get API key from settings
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      return res.status(503).json({
        success: false,
        error: 'AI service not configured'
      });
    }

    // Get all user's documents with metadata
    const result = await db.query(
      `SELECT id, name,
              COALESCE(metadata->>'title', name) AS title,
              metadata
       FROM storage_items 
       WHERE user_id = $1 AND type = 'file'
       ORDER BY created_at DESC
       LIMIT 50`, // Limit for performance
      [userId]
    );

    if (result.rows.length < 2) {
      return res.json({
        success: true,
        suggestions: [],
        message: 'Need at least 2 documents for AI suggestions'
      });
    }

    // Prepare papers data for AI
    const papers = result.rows.map(row => ({
      id: row.id.toString(),
      title: row.title,
      abstract: row.metadata?.abstract || '',
      keywords: Array.isArray(row.metadata?.keywords) 
        ? row.metadata.keywords.join(', ')
        : row.metadata?.keywords || ''
    }));

    // Call AI service
    console.log(`🤖 Requesting AI suggestions for ${papers.length} papers...`);
    const suggestions = await suggestMissingLinks(papers, apiKey, 'gemini');

    console.log(`✨ AI suggested ${suggestions.length} missing links`);

    res.json({
      success: true,
      suggestions,
      count: suggestions.length
    });

  } catch (error) {
    console.error('❌ AI Missing Links Error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to generate AI suggestions',
      details: error.message
    });
  }
}

module.exports = {
  getKnowledgeGraph,
  getAIMissingLinks
};
