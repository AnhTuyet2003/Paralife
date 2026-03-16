/**
 * REFMIND WEB CLIPPER - BACKGROUND SERVICE WORKER
 * 
 * Handles extension lifecycle events (Manifest V3)
 */

// Extension installed/updated
chrome.runtime.onInstalled.addListener((details) => {
  if (details.reason === 'install') {
    console.log('🎉 Refmind Web Clipper installed!');
    
    // Open welcome page (optional)
    // chrome.tabs.create({ url: 'welcome.html' });
  }
  
  if (details.reason === 'update') {
    console.log('🔄 Refmind Web Clipper updated!');
  }
  
  // Create context menu
  try {
    chrome.contextMenus.create({
      id: 'save-to-refmind',
      title: 'Save to Refmind',
      contexts: ['page', 'selection', 'link']
    });
    console.log('✅ Context menu created');
  } catch (error) {
    console.error('❌ Failed to create context menu:', error);
  }
});

// Handle context menu clicks
if (chrome.contextMenus && chrome.contextMenus.onClicked) {
  chrome.contextMenus.onClicked.addListener((info, tab) => {
    if (info.menuItemId === 'save-to-refmind') {
      // Open popup or trigger save action
      chrome.action.openPopup();
    }
  });
}

// Listen for messages from content script or popup
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === 'saveToRefmind') {
    // Could handle background save here if needed
    console.log('Background: Save request received', request.data);
  }
  
  return true;
});

// Extension icon clicked (optional: show badge with save count)
chrome.action.onClicked.addListener((tab) => {
  // This won't fire if popup is defined, but useful for debugging
  console.log('Extension icon clicked for tab:', tab.id);
});

// Keep service worker alive (Manifest V3 requirement)
if (chrome.alarms) {
  chrome.alarms.create('keepAlive', { periodInMinutes: 1 });
  chrome.alarms.onAlarm.addListener((alarm) => {
    if (alarm.name === 'keepAlive') {
      // Periodic heartbeat to prevent service worker from sleeping
      console.log('🔄 Service worker keepalive');
    }
  });
}

console.log('🚀 Refmind background service worker loaded');
