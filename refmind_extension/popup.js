/**
 * REFMIND WEB CLIPPER - POPUP LOGIC
 * 
 * Xử lý UI logic, authentication, và gửi dữ liệu về backend
 */

// ============================================
// CONFIGURATION & STATE
// ============================================

let currentMetadata = null;
let authToken = null;
let refreshToken = null;
let firebaseApiKey = null;
let backendUrl = 'http://localhost:3000';
let userEmail = null;

// ============================================
// DOM ELEMENTS
// ============================================

const elements = {
  loadingState: document.getElementById('loading-state'),
  loginScreen: document.getElementById('login-screen'),
  mainScreen: document.getElementById('main-screen'),
  
  // Login form
  emailInput: document.getElementById('email'),
  passwordInput: document.getElementById('password'),
  backendUrlInput: document.getElementById('backend-url'),
  loginBtn: document.getElementById('login-btn'),
  loginError: document.getElementById('login-error'),
  
  // Main screen
  userEmailSpan: document.getElementById('user-email'),
  logoutBtn: document.getElementById('logout-btn'),
  
  // Page info
  pageTitle: document.getElementById('page-title'),
  pageAuthors: document.getElementById('page-authors'),
  pageDoi: document.getElementById('page-doi'),
  pagePdf: document.getElementById('page-pdf'),
  pageUrl: document.getElementById('page-url'),
  authorsSection: document.getElementById('authors-section'),
  doiSection: document.getElementById('doi-section'),
  pdfSection: document.getElementById('pdf-section'),
  
  // User input
  tagsInput: document.getElementById('tags'),
  notesInput: document.getElementById('notes'),
  
  // Actions
  saveBtn: document.getElementById('save-btn'),
  successMessage: document.getElementById('success-message'),
  errorMessage: document.getElementById('error-message')
};

// ============================================
// INITIALIZATION
// ============================================

document.addEventListener('DOMContentLoaded', async () => {
  console.log('🚀 Refmind Web Clipper initialized');
  
  // Load saved credentials
  await loadSavedAuth();
  
  // Check if already logged in
  if (authToken) {
    await showMainScreen();
  } else {
    showLoginScreen();
  }
  
  // Setup event listeners
  setupEventListeners();
});

// ============================================
// AUTH MANAGEMENT
// ============================================

async function loadSavedAuth() {
  const data = await chrome.storage.local.get(['authToken', 'refreshToken', 'firebaseApiKey', 'backendUrl', 'userEmail']);
  if (data.authToken) {
    authToken = data.authToken;
    refreshToken = data.refreshToken;
    firebaseApiKey = data.firebaseApiKey;
    backendUrl = data.backendUrl || 'http://localhost:3000';
    userEmail = data.userEmail;
    console.log('✅ Loaded saved auth');
  }
}

async function saveAuth(token, refresh, apiKey, email, url) {
  authToken = token;
  refreshToken = refresh;
  firebaseApiKey = apiKey;
  userEmail = email;
  backendUrl = url;
  
  await chrome.storage.local.set({
    authToken: token,
    refreshToken: refresh,
    firebaseApiKey: apiKey,
    userEmail: email,
    backendUrl: url
  });
  
  console.log('✅ Auth saved');
}

async function clearAuth() {
  authToken = null;
  refreshToken = null;
  firebaseApiKey = null;
  userEmail = null;
  
  await chrome.storage.local.remove(['authToken', 'refreshToken', 'firebaseApiKey', 'userEmail']);
  console.log('✅ Auth cleared');
}

// ============================================
// UI STATE MANAGEMENT
// ============================================

function showLoadingState() {
  elements.loadingState.style.display = 'flex';
  elements.loginScreen.style.display = 'none';
  elements.mainScreen.style.display = 'none';
}

function showLoginScreen() {
  elements.loadingState.style.display = 'none';
  elements.loginScreen.style.display = 'block';
  elements.mainScreen.style.display = 'none';
  
  // Pre-fill backend URL if saved
  if (backendUrl) {
    elements.backendUrlInput.value = backendUrl;
  }
}

async function showMainScreen() {
  elements.loadingState.style.display = 'none';
  elements.loginScreen.style.display = 'none';
  elements.mainScreen.style.display = 'block';
  
  // Display user email
  elements.userEmailSpan.textContent = userEmail || 'User';
  
  // Extract metadata from current tab
  await extractAndDisplayMetadata();
}

// ============================================
// METADATA EXTRACTION
// ============================================

async function extractAndDisplayMetadata() {
  try {
    // Get current active tab
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    
    if (!tab || !tab.id) {
      throw new Error('Cannot access current tab');
    }
    
    // Send message to content script to extract metadata
    const response = await chrome.tabs.sendMessage(tab.id, { action: 'extractMetadata' });
    
    if (response && response.success) {
      currentMetadata = response.data;
      displayMetadata(currentMetadata);
    } else {
      throw new Error(response.error || 'Failed to extract metadata');
    }
    
  } catch (error) {
    console.error('Error extracting metadata:', error);
    
    // Fallback: basic info from tab
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    currentMetadata = {
      url: tab.url,
      title: tab.title,
      page_type: 'webpage'
    };
    displayMetadata(currentMetadata);
  }
}

function displayMetadata(metadata) {
  // Title
  elements.pageTitle.textContent = metadata.title || 'Untitled';
  
  // Authors
  if (metadata.authors && metadata.authors.length > 0) {
    elements.authorsSection.style.display = 'block';
    elements.pageAuthors.textContent = metadata.authors.join(', ');
  } else {
    elements.authorsSection.style.display = 'none';
  }
  
  // DOI
  if (metadata.doi) {
    elements.doiSection.style.display = 'block';
    elements.pageDoi.textContent = metadata.doi;
  } else {
    elements.doiSection.style.display = 'none';
  }
  
  // PDF URL
  if (metadata.pdf_url) {
    elements.pdfSection.style.display = 'block';
  } else {
    elements.pdfSection.style.display = 'none';
  }
  
  // URL
  elements.pageUrl.textContent = metadata.url;
  
  console.log('✅ Metadata displayed:', metadata);
}

// ============================================
// EVENT LISTENERS
// ============================================

function setupEventListeners() {
  // Login button
  elements.loginBtn.addEventListener('click', handleLogin);
  
  // Enter key in login form
  elements.passwordInput.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') handleLogin();
  });
  
  // Logout button
  elements.logoutBtn.addEventListener('click', handleLogout);
  
  // Save button
  elements.saveBtn.addEventListener('click', handleSave);
}

// ============================================
// LOGIN HANDLER
// ============================================

async function handleLogin() {
  const email = elements.emailInput.value.trim();
  const password = elements.passwordInput.value.trim();
  const backend = elements.backendUrlInput.value.trim() || 'http://localhost:3000';
  
  // Validation
  if (!email || !password) {
    showError('Please enter email and password', elements.loginError);
    return;
  }
  
  // Show loading
  elements.loginBtn.disabled = true;
  elements.loginBtn.classList.add('loading');
  elements.loginError.style.display = 'none';
  
  try {
    // Get Firebase API key from backend
    const configResponse = await fetch(`${backend}/api/extension/config`);
    if (!configResponse.ok) {
      throw new Error('Cannot connect to backend. Check URL and ensure server is running.');
    }
    
    const config = await configResponse.json();
    const firebaseApiKey = config.firebase_api_key;
    
    if (!firebaseApiKey) {
      throw new Error('Backend configuration error: Missing Firebase API key');
    }
    
    // Login with Firebase
    const loginResponse = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${firebaseApiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: email,
          password: password,
          returnSecureToken: true
        })
      }
    );
    
    const loginData = await loginResponse.json();
    
    if (!loginResponse.ok) {
      throw new Error(loginData.error?.message || 'Login failed');
    }
    
    // Save auth (including refreshToken and firebaseApiKey)
    await saveAuth(loginData.idToken, loginData.refreshToken, firebaseApiKey, email, backend);
    
    // Switch to main screen
    await showMainScreen();
    
    console.log('✅ Login successful');
    
  } catch (error) {
    console.error('Login error:', error);
    showError(error.message, elements.loginError);
  } finally {
    elements.loginBtn.disabled = false;
    elements.loginBtn.classList.remove('loading');
  }
}

// ============================================
// TOKEN REFRESH
// ============================================

/**
 * Refresh expired Firebase ID token using refresh token
 */
async function refreshAuthToken() {
  if (!refreshToken || !firebaseApiKey) {
    throw new Error('No refresh token available');
  }
  
  try {
    console.log('🔄 Refreshing Firebase token...');
    
    const response = await fetch(
      `https://securetoken.googleapis.com/v1/token?key=${firebaseApiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          grant_type: 'refresh_token',
          refresh_token: refreshToken
        })
      }
    );
    
    const data = await response.json();
    
    if (!response.ok) {
      throw new Error(data.error?.message || 'Token refresh failed');
    }
    
    // Update tokens
    authToken = data.id_token;
    refreshToken = data.refresh_token;
    
    // Save to storage
    await chrome.storage.local.set({
      authToken: data.id_token,
      refreshToken: data.refresh_token
    });
    
    console.log('✅ Token refreshed successfully');
    return data.id_token;
    
  } catch (error) {
    console.error('❌ Token refresh failed:', error);
    throw error;
  }
}

// ============================================
// LOGOUT HANDLER
// ============================================

async function handleLogout() {
  await clearAuth();
  showLoginScreen();
  console.log('✅ Logged out');
}

// ============================================
// SAVE HANDLER
// ============================================

async function handleSave(retrying = false) {
  if (!currentMetadata) {
    showError('No metadata available', elements.errorMessage);
    return;
  }
  
  // Get user inputs
  const tags = elements.tagsInput.value.trim();
  const notes = elements.notesInput.value.trim();
  
  // Prepare payload
  const payload = {
    ...currentMetadata,
    tags: tags ? tags.split(',').map(t => t.trim()) : [],
    notes: notes
  };
  
  // Show loading
  elements.saveBtn.disabled = true;
  elements.saveBtn.classList.add('loading');
  elements.successMessage.style.display = 'none';
  elements.errorMessage.style.display = 'none';
  
  try {
    const response = await fetch(`${backendUrl}/api/extension/save`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${authToken}`
      },
      body: JSON.stringify(payload)
    });
    
    const data = await response.json();
    
    if (!response.ok) {
      // Check if token expired - Try to refresh once
      if (response.status === 401 && !retrying && refreshToken) {
        console.log('🔄 Token expired, attempting refresh...');
        try {
          await refreshAuthToken();
          // Retry save with new token
          return await handleSave(true);
        } catch (refreshError) {
          // Refresh failed, clear auth and logout
          console.error('❌ Token refresh failed:', refreshError);
          await clearAuth();
          showLoginScreen();
          throw new Error('Session expired. Please login again.');
        }
      }
      
      // Other errors or refresh already attempted
      if (response.status === 401) {
        await clearAuth();
        showLoginScreen();
        throw new Error('Session expired. Please login again.');
      }
      
      throw new Error(data.error || 'Failed to save');
    }
    
    // Success!
    console.log('✅ Saved successfully:', data);
    
    showSuccess(`✅ Saved to Refmind!${data.has_pdf ? ' (with PDF)' : ''}`, elements.successMessage);
    
    // Clear inputs
    elements.tagsInput.value = '';
    elements.notesInput.value = '';
    
    // Auto-close after 2 seconds
    setTimeout(() => {
      window.close();
    }, 2000);
    
  } catch (error) {
    console.error('Save error:', error);
    showError(error.message, elements.errorMessage);
  } finally {
    elements.saveBtn.disabled = false;
    elements.saveBtn.classList.remove('loading');
  }
}

// ============================================
// UTILITY FUNCTIONS
// ============================================

function showError(message, element) {
  element.textContent = message;
  element.style.display = 'block';
  
  // Auto-hide after 5 seconds
  setTimeout(() => {
    element.style.display = 'none';
  }, 5000);
}

function showSuccess(message, element) {
  element.textContent = message;
  element.style.display = 'block';
}
