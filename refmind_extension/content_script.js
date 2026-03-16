/**
 * REFMIND WEB CLIPPER - CONTENT SCRIPT
 * 
 * Script chạy ngầm trên mọi trang web để extract metadata
 * Ưu tiên cào các thẻ meta học thuật chuẩn (Google Scholar, PubMed, arXiv...)
 */

(function() {
  'use strict';

  /**
   * Extract metadata từ trang web hiện tại
   * @returns {Object} Metadata object
   */
  function extractMetadata() {
    const metadata = {
      url: window.location.href,
      title: '',
      authors: [],
      doi: '',
      pdf_url: '',
      abstract: '',
      publisher: '',
      journal: '',
      year: null,
      keywords: [],
      page_type: 'webpage' // default
    };

    // ============================================
    // 1. TITLE EXTRACTION
    // ============================================
    
    // Ưu tiên: citation_title (chuẩn học thuật)
    const citationTitle = document.querySelector('meta[name="citation_title"]');
    if (citationTitle) {
      metadata.title = citationTitle.content;
      metadata.page_type = 'article';
    }
    
    // Fallback: og:title (Open Graph)
    if (!metadata.title) {
      const ogTitle = document.querySelector('meta[property="og:title"]');
      if (ogTitle) metadata.title = ogTitle.content;
    }
    
    // Fallback: twitter:title
    if (!metadata.title) {
      const twitterTitle = document.querySelector('meta[name="twitter:title"]');
      if (twitterTitle) metadata.title = twitterTitle.content;
    }
    
    // Fallback: <title> tag
    if (!metadata.title) {
      metadata.title = document.title;
    }

    // ============================================
    // 2. AUTHORS EXTRACTION
    // ============================================
    
    // Chuẩn học thuật: citation_author (có thể có nhiều thẻ)
    const authorMetas = document.querySelectorAll('meta[name="citation_author"]');
    if (authorMetas.length > 0) {
      authorMetas.forEach(meta => {
        if (meta.content) metadata.authors.push(meta.content.trim());
      });
    }
    
    // Fallback: DC.Creator (Dublin Core)
    if (metadata.authors.length === 0) {
      const dcCreators = document.querySelectorAll('meta[name="DC.Creator"]');
      dcCreators.forEach(meta => {
        if (meta.content) metadata.authors.push(meta.content.trim());
      });
    }
    
    // Fallback: author meta tag
    if (metadata.authors.length === 0) {
      const authorMeta = document.querySelector('meta[name="author"]');
      if (authorMeta && authorMeta.content) {
        // Tách authors nếu có dấu phẩy hoặc "and"
        const authorStr = authorMeta.content;
        if (authorStr.includes(',')) {
          metadata.authors = authorStr.split(',').map(a => a.trim());
        } else if (authorStr.toLowerCase().includes(' and ')) {
          metadata.authors = authorStr.split(/\s+and\s+/i).map(a => a.trim());
        } else {
          metadata.authors = [authorStr];
        }
      }
    }

    // ============================================
    // 3. DOI EXTRACTION (Cực kỳ quan trọng!)
    // ============================================
    
    // Chuẩn: citation_doi
    const citationDoi = document.querySelector('meta[name="citation_doi"]');
    if (citationDoi) {
      metadata.doi = citationDoi.content.trim();
    }
    
    // Fallback: DC.Identifier (Dublin Core)
    if (!metadata.doi) {
      const dcIdentifier = document.querySelector('meta[name="DC.Identifier"]');
      if (dcIdentifier && dcIdentifier.content.includes('doi')) {
        metadata.doi = dcIdentifier.content.replace(/^doi:/, '').trim();
      }
    }
    
    // Fallback: tìm trong URL hoặc text
    if (!metadata.doi) {
      // Tìm trong URL: https://doi.org/10.1234/example
      const doiRegex = /10\.\d{4,}(?:\.\d+)*\/\S+/;
      const urlMatch = window.location.href.match(doiRegex);
      if (urlMatch) metadata.doi = urlMatch[0];
      
      // Tìm trong page content
      if (!metadata.doi) {
        const bodyText = document.body.innerText;
        const textMatch = bodyText.match(/DOI:\s*(10\.\d{4,}(?:\.\d+)*\/\S+)/i);
        if (textMatch) metadata.doi = textMatch[1];
      }
    }

    // ============================================
    // 4. PDF URL EXTRACTION (Cực kỳ quan trọng!)
    // ============================================
    
    // Chuẩn: citation_pdf_url
    const citationPdf = document.querySelector('meta[name="citation_pdf_url"]');
    if (citationPdf) {
      metadata.pdf_url = citationPdf.content;
    }
    
    // Fallback: citation_fulltext_html_url
    if (!metadata.pdf_url) {
      const fulltextUrl = document.querySelector('meta[name="citation_fulltext_html_url"]');
      if (fulltextUrl && fulltextUrl.content.toLowerCase().includes('.pdf')) {
        metadata.pdf_url = fulltextUrl.content;
      }
    }
    
    // Fallback: tìm link PDF trong page
    if (!metadata.pdf_url) {
      // Tìm các link có text chứa "PDF" hoặc href kết thúc bằng .pdf
      const pdfLinks = Array.from(document.querySelectorAll('a[href]')).filter(a => {
        const href = a.href.toLowerCase();
        const text = a.textContent.toLowerCase();
        return href.endsWith('.pdf') || 
               text.includes('pdf') || 
               text.includes('download');
      });
      
      if (pdfLinks.length > 0) {
        metadata.pdf_url = pdfLinks[0].href;
      }
    }

    // ============================================
    // 5. ABSTRACT EXTRACTION
    // ============================================
    
    // Chuẩn: citation_abstract hoặc description
    const abstractMeta = document.querySelector('meta[name="citation_abstract"]') ||
                         document.querySelector('meta[name="description"]') ||
                         document.querySelector('meta[property="og:description"]');
    if (abstractMeta) {
      metadata.abstract = abstractMeta.content;
    }

    // ============================================
    // 6. PUBLISHER & JOURNAL
    // ============================================
    
    // Journal name
    const journalMeta = document.querySelector('meta[name="citation_journal_title"]') ||
                       document.querySelector('meta[name="citation_conference_title"]');
    if (journalMeta) {
      metadata.journal = journalMeta.content;
    }
    
    // Publisher
    const publisherMeta = document.querySelector('meta[name="citation_publisher"]') ||
                         document.querySelector('meta[name="DC.Publisher"]');
    if (publisherMeta) {
      metadata.publisher = publisherMeta.content;
    }

    // ============================================
    // 7. PUBLICATION YEAR
    // ============================================
    
    const yearMeta = document.querySelector('meta[name="citation_publication_date"]') ||
                    document.querySelector('meta[name="citation_date"]') ||
                    document.querySelector('meta[name="DC.Date"]');
    if (yearMeta) {
      const yearMatch = yearMeta.content.match(/\d{4}/);
      if (yearMatch) metadata.year = parseInt(yearMatch[0]);
    }

    // ============================================
    // 8. KEYWORDS
    // ============================================
    
    const keywordsMeta = document.querySelector('meta[name="keywords"]') ||
                        document.querySelector('meta[name="citation_keywords"]');
    if (keywordsMeta) {
      metadata.keywords = keywordsMeta.content.split(',').map(k => k.trim());
    }

    // ============================================
    // 9. SPECIAL HANDLING FOR POPULAR SITES
    // ============================================
    
    // arXiv.org
    if (window.location.hostname.includes('arxiv.org')) {
      metadata.page_type = 'article';
      
      // arXiv PDF link
      const arxivId = window.location.pathname.match(/(\d{4}\.\d{4,5})/);
      if (arxivId) {
        metadata.pdf_url = `https://arxiv.org/pdf/${arxivId[1]}.pdf`;
        if (!metadata.doi) {
          metadata.doi = `10.48550/arXiv.${arxivId[1]}`;
        }
      }
    }
    
    // PubMed
    if (window.location.hostname.includes('pubmed.ncbi.nlm.nih.gov')) {
      metadata.page_type = 'article';
      metadata.publisher = 'PubMed';
    }
    
    // IEEE Xplore
    if (window.location.hostname.includes('ieee.org')) {
      metadata.page_type = 'article';
      metadata.publisher = 'IEEE';
    }
    
    // Nature, Science, etc.
    const academicDomains = ['nature.com', 'science.org', 'sciencedirect.com', 'springer.com', 'cell.com'];
    if (academicDomains.some(domain => window.location.hostname.includes(domain))) {
      metadata.page_type = 'article';
    }

    // ============================================
    // 10. CLEAN UP & RETURN
    // ============================================
    
    // Trim all string fields
    metadata.title = metadata.title.trim();
    metadata.doi = metadata.doi.trim();
    metadata.pdf_url = metadata.pdf_url.trim();
    metadata.abstract = metadata.abstract.trim();
    metadata.publisher = metadata.publisher.trim();
    metadata.journal = metadata.journal.trim();
    
    // Remove empty arrays
    if (metadata.authors.length === 0) delete metadata.authors;
    if (metadata.keywords.length === 0) delete metadata.keywords;

    console.log('🔍 Refmind: Extracted metadata:', metadata);
    
    return metadata;
  }

  // ============================================
  // MESSAGE LISTENER
  // ============================================
  
  chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (request.action === 'extractMetadata') {
      try {
        const metadata = extractMetadata();
        sendResponse({ success: true, data: metadata });
      } catch (error) {
        console.error('Error extracting metadata:', error);
        sendResponse({ success: false, error: error.message });
      }
    }
    return true; // Keep message channel open for async response
  });

  // Auto-extract metadata on page load (cache for quick access)
  window.addEventListener('load', () => {
    const metadata = extractMetadata();
    // Store in page context for quick retrieval
    window.__refmindMetadata = metadata;
  });

})();
