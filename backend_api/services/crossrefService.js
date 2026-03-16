/**
 * Crossref Service
 * Query Crossref API to validate DOI existence
 */

const axios = require('axios');

class CrossrefService {
  constructor() {
    this.baseURL = 'https://api.crossref.org/works';
    this.timeout = 10000; // 10 seconds
  }

  /**
   * Validate a single DOI
   * @param {string} doi - DOI identifier
   * @returns {Promise<{isValid: boolean, metadata: object|null}>}
   */
  async validateDOI(doi) {
    try {
      const cleanDOI = doi.trim().replace(/^https?:\/\/(dx\.)?doi\.org\//, '');
      
      const response = await axios.get(`${this.baseURL}/${encodeURIComponent(cleanDOI)}`, {
        timeout: this.timeout,
        headers: {
          'User-Agent': 'Refmind/1.0 (mailto:support@refmind.app)'
        }
      });

      if (response.status === 200 && response.data) {
        const work = response.data.message;
        return {
          isValid: true,
          metadata: {
            doi: work.DOI,
            title: work.title?.[0] || 'No title',
            authors: work.author?.map(a => `${a.given || ''} ${a.family || ''}`).join(', ') || 'Unknown',
            year: work.published?.['date-parts']?.[0]?.[0] || null,
            journal: work['container-title']?.[0] || null,
            type: work.type || 'unknown'
          }
        };
      }

      return { isValid: false, metadata: null };
    } catch (error) {
      if (error.response?.status === 404) {
        return { isValid: false, metadata: null };
      }
      
      console.error(`Error validating DOI ${doi}:`, error.message);
      return { isValid: null, metadata: null }; // null = unknown (network error)
    }
  }

  /**
   * Search metadata by document title on Crossref (trusted scholarly source).
   * @param {string} title
   * @returns {Promise<{found: boolean, metadata: object|null}>}
   */
  async searchByTitle(title) {
    try {
      if (!title || typeof title !== 'string' || !title.trim()) {
        return { found: false, metadata: null };
      }

      const response = await axios.get(this.baseURL, {
        timeout: this.timeout,
        headers: {
          'User-Agent': 'Refmind/1.0 (mailto:support@refmind.app)'
        },
        params: {
          query: title.trim(),
          rows: 1,
          select: 'DOI,title,author,published,container-title,type,abstract'
        }
      });

      const item = response.data?.message?.items?.[0];
      if (!item) {
        return { found: false, metadata: null };
      }

      return {
        found: true,
        metadata: {
          doi: item.DOI || null,
          title: item.title?.[0] || title,
          authors: item.author?.map(a => `${a.given || ''} ${a.family || ''}`).join(', ') || 'Unknown',
          year: item.published?.['date-parts']?.[0]?.[0] || null,
          journal: item['container-title']?.[0] || null,
          abstract: item.abstract || null,
          type: item.type || 'unknown'
        }
      };
    } catch (error) {
      console.error(`Error searching Crossref by title "${title}":`, error.message);
      return { found: false, metadata: null };
    }
  }

  /**
   * Extract DOIs from text using regex
   * @param {string} text - Text content to search
   * @returns {string[]} - Array of unique DOI strings
   */
  extractDOIs(text) {
    if (!text || typeof text !== 'string') return [];

    // Regex patterns for DOI formats
    const patterns = [
      /\b(10\.\d{4,}(?:\.\d+)*\/(?:(?!["&\'<>])\S)+)\b/gi, // Standard DOI
      /doi:\s*(10\.\d{4,}(?:\.\d+)*\/(?:(?!["&\'<>])\S)+)/gi, // DOI: prefix
      /https?:\/\/(?:dx\.)?doi\.org\/(10\.\d{4,}(?:\.\d+)*\/(?:(?!["&\'<>])\S)+)/gi // URL format
    ];

    const dois = new Set();
    
    patterns.forEach(pattern => {
      const matches = text.matchAll(pattern);
      for (const match of matches) {
        const doi = match[1] || match[0];
        // Clean up DOI
        const cleanDOI = doi
          .replace(/^doi:\s*/i, '')
          .replace(/^https?:\/\/(?:dx\.)?doi\.org\//, '')
          .replace(/[.,;)\]]+$/, ''); // Remove trailing punctuation
        
        if (cleanDOI.startsWith('10.')) {
          dois.add(cleanDOI);
        }
      }
    });

    return Array.from(dois);
  }

  /**
   * Validate multiple DOIs in batch
   * @param {string[]} dois - Array of DOI strings
   * @returns {Promise<Array>} - Array of validation results
   */
  async validateBatch(dois) {
    if (!Array.isArray(dois) || dois.length === 0) {
      return [];
    }

    // Limit batch size to avoid rate limiting
    const batchSize = 10;
    const results = [];

    for (let i = 0; i < dois.length; i += batchSize) {
      const batch = dois.slice(i, i + batchSize);
      const batchPromises = batch.map(doi => 
        this.validateDOI(doi).then(result => ({ doi, ...result }))
      );
      
      const batchResults = await Promise.all(batchPromises);
      results.push(...batchResults);
      
      // Rate limiting: wait between batches
      if (i + batchSize < dois.length) {
        await new Promise(resolve => setTimeout(resolve, 1000)); // 1 second delay
      }
    }

    return results;
  }
}

module.exports = new CrossrefService();
