const { Cite } = require('@citation-js/core');
require('@citation-js/plugin-bibtex');
require('@citation-js/plugin-csl');

/**
 * ===================================================
 * CITATION SERVICE - XỬ LÝ TRÍCH DẪN
 * ===================================================
 */

class CitationService {
  /**
   * Generate citation string from metadata
   * @param {Object} metadata - Document metadata
   * @param {string} style - Citation style (apa, ieee, harvard, bibtex)
   * @returns {string} - Formatted citation
   */
  generateCitation(metadata, style = 'apa') {
    try {
      // Chuẩn hóa metadata sang format CSL-JSON
      const cslData = this._metadataToCSL(metadata);

      // Tạo citation object
      const cite = new Cite(cslData);

      // Format theo style
      let output;
      switch (style.toLowerCase()) {
        case 'apa':
        case 'apa7':
          output = cite.format('bibliography', {
            format: 'text',
            template: 'apa',
            lang: 'en-US'
          });
          break;

        case 'apa6':
          output = cite.format('bibliography', {
            format: 'text',
            template: 'apa-6th-edition',
            lang: 'en-US'
          });
          break;

        case 'ieee':
          output = cite.format('bibliography', {
            format: 'text',
            template: 'ieee',
            lang: 'en-US'
          });
          break;

        case 'harvard':
          output = cite.format('bibliography', {
            format: 'text',
            template: 'harvard1',
            lang: 'en-US'
          });
          break;

        case 'chicago':
          output = cite.format('bibliography', {
            format: 'text',
            template: 'chicago-author-date',
            lang: 'en-US'
          });
          break;

        case 'vancouver':
          output = cite.format('bibliography', {
            format: 'text',
            template: 'vancouver',
            lang: 'en-US'
          });
          break;

        case 'nature':
          output = cite.format('bibliography', {
            format: 'text',
            template: 'nature',
            lang: 'en-US'
          });
          break;

        case 'acs':
          output = cite.format('bibliography', {
            format: 'text',
            template: 'american-chemical-society',
            lang: 'en-US'
          });
          break;

        case 'bibtex':
          output = cite.format('bibtex');
          break;

        case 'mla':
          output = cite.format('bibliography', {
            format: 'text',
            template: 'modern-language-association',
            lang: 'en-US'
          });
          break;

        default:
          // Default to APA
          output = cite.format('bibliography', {
            format: 'text',
            template: 'apa',
            lang: 'en-US'
          });
      }

      return output.trim();

    } catch (error) {
      console.error('❌ [Citation Service] Generation error:', error);
      
      // Fallback: Tạo citation thủ công nếu library lỗi
      return this._generateFallbackCitation(metadata, style);
    }
  }

  /**
   * Convert Refmind metadata to CSL-JSON format
   * @private
   */
  _metadataToCSL(metadata) {
    const csl = {
      type: 'article-journal', // Default type
      id: metadata.doi || metadata.url || 'unknown'
    };

    // Title
    if (metadata.title) {
      csl.title = metadata.title;
    }

    // Authors
    if (metadata.authors && Array.isArray(metadata.authors)) {
      csl.author = metadata.authors.map(author => {
        if (typeof author === 'string') {
          // Parse "Last, First" or "First Last" format
          const parts = author.split(',').map(p => p.trim());
          if (parts.length === 2) {
            return { family: parts[0], given: parts[1] };
          } else {
            const names = author.split(' ');
            return {
              family: names[names.length - 1],
              given: names.slice(0, -1).join(' ')
            };
          }
        }
        return author;
      });
    }

    // Year
    if (metadata.year) {
      csl.issued = { 'date-parts': [[parseInt(metadata.year)]] };
    }

    // Journal/Publisher
    if (metadata.journal) {
      csl['container-title'] = metadata.journal;
    } else if (metadata.publisher) {
      csl.publisher = metadata.publisher;
    }

    // Volume, Issue, Pages
    if (metadata.volume) csl.volume = metadata.volume;
    if (metadata.issue) csl.issue = metadata.issue;
    if (metadata.pages) csl.page = metadata.pages;

    // DOI
    if (metadata.doi) {
      csl.DOI = metadata.doi;
    }

    // URL
    if (metadata.url) {
      csl.URL = metadata.url;
    }

    return csl;
  }

  /**
   * Fallback citation generation (manual template)
   * @private
   */
  _generateFallbackCitation(metadata, style) {
    const authors = this._formatAuthors(metadata.authors || []);
    const year = metadata.year || 'n.d.';
    const title = metadata.title || 'Untitled';
    const journal = metadata.journal || metadata.publisher || '';
    const doi = metadata.doi ? `https://doi.org/${metadata.doi}` : '';

    switch (style.toLowerCase()) {
      case 'apa':
        return `${authors} (${year}). ${title}. ${journal}. ${doi}`.trim();

      case 'ieee':
        return `${authors}, "${title}," ${journal}, ${year}. ${doi}`.trim();

      case 'harvard':
        return `${authors} ${year}, '${title}', ${journal}. Available at: ${doi}`.trim();

      case 'mla':
        return `${authors}. "${title}." ${journal} ${year}. ${doi}`.trim();

      case 'bibtex':
        const key = (metadata.authors && metadata.authors[0] 
          ? metadata.authors[0].split(' ')[0].toLowerCase() 
          : 'unknown') + year;
        return `@article{${key},\n  author = {${authors}},\n  title = {${title}},\n  journal = {${journal}},\n  year = {${year}},\n  doi = {${metadata.doi || ''}}\n}`;

      default:
        return `${authors} (${year}). ${title}. ${journal}. ${doi}`.trim();
    }
  }

  /**
   * Format authors for citation
   * @private
   */
  _formatAuthors(authors) {
    if (!authors || authors.length === 0) return 'Unknown Author';
    
    if (authors.length === 1) return authors[0];
    if (authors.length === 2) return `${authors[0]} & ${authors[1]}`;
    if (authors.length > 2) return `${authors[0]} et al.`;
    
    return authors.join(', ');
  }

  /**
   * Generate BibTeX entry for multiple items
   */
  generateBibTeX(items) {
    const entries = items.map(item => {
      const metadata = item.metadata || {};
      return this.generateCitation(metadata, 'bibtex');
    });

    return entries.join('\n\n');
  }

  /**
   * Convert metadata to CSV row
   */
  metadataToCSVRow(item) {
    const metadata = item.metadata || {};
    
    return {
      id: item.id,
      title: metadata.title || 'Untitled',
      authors: Array.isArray(metadata.authors) ? metadata.authors.join('; ') : '',
      year: metadata.year || '',
      journal: metadata.journal || '',
      publisher: metadata.publisher || '',
      volume: metadata.volume || '',
      issue: metadata.issue || '',
      pages: metadata.pages || '',
      doi: metadata.doi || '',
      url: metadata.url || item.file_url || '',
      abstract: metadata.abstract || '',
      created_at: item.created_at,
    };
  }
}

module.exports = new CitationService();
