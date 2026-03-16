/**
 * ===================================================
 * REFMIND GOOGLE DOCS ADD-ON
 * Citation & Highlight Integration
 * ===================================================
 */

// Backend API configuration
const API_BASE_URL = 'https://refmind-api.loca.lt'; // Change to your production URL
const PROPERTY_AUTH_TOKEN = 'REFMIND_AUTH_TOKEN';

/**
 * Create menu when document opens
 * NOTE: Cannot be tested from Script Editor - must run from actual Google Doc
 */
function onOpen(e) {
  DocumentApp.getUi()
    .createAddonMenu()
    .addItem('Open Refmind Sidebar', 'showSidebar')
    .addItem('Settings', 'showSettings')
    .addToUi();
}

/**
 * Test function - Use this to verify script loads correctly
 * Run this from Script Editor instead of onOpen()
 */
function testConnection() {
  Logger.log('✅ Script loaded successfully!');
  Logger.log('API URL: ' + API_BASE_URL);
  
  // Test if token exists
  var token = getAuthToken();
  if (token) {
    Logger.log('✅ Auth token found: ' + token.substring(0, 20) + '...');
  } else {
    Logger.log('⚠️  No auth token set. User needs to configure Settings.');
  }
  
  return 'Test completed. Check Logs (Ctrl+Enter or View > Logs)';
}

/**
 * Run when add-on is installed
 */
function onInstall(e) {
  onOpen(e);
}

/**
 * Show main sidebar
 */
function showSidebar() {
  const html = HtmlService.createHtmlOutputFromFile('Sidebar')
    .setTitle('Refmind Citation Tool')
    .setWidth(350);
  
  DocumentApp.getUi().showSidebar(html);
}

/**
 * Show settings dialog
 */
function showSettings() {
  const html = HtmlService.createHtmlOutputFromFile('Settings')
    .setWidth(400)
    .setHeight(200);
  
  DocumentApp.getUi().showModalDialog(html, 'Refmind Settings');
}

/**
 * Save authentication token
 */
function saveAuthToken(token) {
  PropertiesService.getUserProperties().setProperty(PROPERTY_AUTH_TOKEN, token);
  return { success: true, message: 'Token saved successfully!' };
}

/**
 * Get saved authentication token
 */
function getAuthToken() {
  return PropertiesService.getUserProperties().getProperty(PROPERTY_AUTH_TOKEN);
}

/**
 * Search documents in Refmind library
 */
function searchDocuments(query) {
  const token = getAuthToken();
  
  if (!token) {
    return {
      success: false,
      error: 'Please set your API token in Settings first.'
    };
  }

  try {
    const response = UrlFetchApp.fetch(
      `${API_BASE_URL}/api/citation/plugin/search?q=${encodeURIComponent(query)}`,
      {
        method: 'get',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        muteHttpExceptions: true
      }
    );

    const responseText = response.getContentText();
    
    // Check if response is LocalTunnel click-to-continue page
    if (responseText.includes('localtunnel') || responseText.includes('Click to Continue')) {
      return {
        success: false,
        error: '⚠️ LocalTunnel chưa unlock! Mở https://refmind-api.loca.lt và click Continue.'
      };
    }
    
    // Check if response is empty
    if (!responseText || responseText.trim() === '') {
      return {
        success: false,
        error: 'Server returned empty response. Check if backend is running.'
      };
    }
    
    const data = JSON.parse(responseText);
    
    if (data.success) {
      return {
        success: true,
        documents: data.data.documents
      };
    } else {
      return {
        success: false,
        error: data.error || 'Search failed'
      };
    }
  } catch (e) {
    return {
      success: false,
      error: `Network error: ${e.toString()}`
    };
  }
}

/**
 * Get highlights for a document
 */
function getHighlights(itemId) {
  const token = getAuthToken();
  
  if (!token) {
    return {
      success: false,
      error: 'Authentication required'
    };
  }

  try {
    const response = UrlFetchApp.fetch(
      `${API_BASE_URL}/api/citation/plugin/highlights/${itemId}`,
      {
        method: 'get',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        muteHttpExceptions: true
      }
    );

    const responseText = response.getContentText();
    
    if (responseText.includes('localtunnel') || responseText.includes('Click to Continue')) {
      return { success: false, error: '⚠️ LocalTunnel chưa unlock! Mở URL và click Continue.' };
    }
    
    if (!responseText || responseText.trim() === '') {
      return { success: false, error: 'Empty response from server' };
    }
    
    const data = JSON.parse(responseText);
    
    if (data.success) {
      return {
        success: true,
        document: data.data.document,
        highlights: data.data.highlights
      };
    } else {
      return {
        success: false,
        error: data.error || 'Failed to fetch highlights'
      };
    }
  } catch (e) {
    return {
      success: false,
      error: `Network error: ${e.toString()}`
    };
  }
}

/**
 * Generate citation for a document
 */
function generateCitation(itemId, style) {
  const token = getAuthToken();
  
  if (!token) {
    return {
      success: false,
      error: 'Authentication required'
    };
  }

  try {
    const response = UrlFetchApp.fetch(
      `${API_BASE_URL}/api/citation/items/${itemId}/cite?style=${style}`,
      {
        method: 'get',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        muteHttpExceptions: true
      }
    );

    const responseText = response.getContentText();
    
    if (responseText.includes('localtunnel') || responseText.includes('Click to Continue')) {
      return { success: false, error: '⚠️ LocalTunnel chưa unlock!' };
    }
    
    if (!responseText || responseText.trim() === '') {
      return { success: false, error: 'Empty response from server' };
    }
    
    const data = JSON.parse(responseText);
    
    if (data.success) {
      return {
        success: true,
        citation: data.data.citation
      };
    } else {
      return {
        success: false,
        error: data.error || 'Citation generation failed'
      };
    }
  } catch (e) {
    return {
      success: false,
      error: `Network error: ${e.toString()}`
    };
  }
}

/**
 * Insert text at cursor position in Google Docs
 */
function insertTextAtCursor(text) {
  try {
    const doc = DocumentApp.getActiveDocument();
    const cursor = doc.getCursor();
    
    if (cursor) {
      const element = cursor.insertText(text);
      // Move cursor after inserted text
      const position = doc.newPosition(element, text.length);
      doc.setCursor(position);
      
      return { success: true };
    } else {
      // No cursor, append to end
      const body = doc.getBody();
      body.appendParagraph(text);
      
      return { success: true };
    }
  } catch (e) {
    return {
      success: false,
      error: e.toString()
    };
  }
}

/**
 * Get available citation styles
 */
function getCitationStyles() {
  return [
    { id: 'apa', name: 'APA' },
    { id: 'ieee', name: 'IEEE' },
    { id: 'harvard', name: 'Harvard' },
    { id: 'mla', name: 'MLA' },
    { id: 'bibtex', name: 'BibTeX' }
  ];
}
