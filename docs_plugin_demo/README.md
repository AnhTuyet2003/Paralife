# Refmind Google Docs Add-on

This add-on allows you to search your Refmind library and insert citations and highlights directly into Google Docs.

---

## 🚀 Quick Start (Lần Sau Bật Lại)

**Cách 1: Double-click file (Windows)**
```
START.bat
```

**Cách 2: PowerShell**
```powershell
cd docs_plugin_demo
.\start-dev-server.ps1
```

**Cách 3: Auto-restart watchdog (Nếu hay bị disconnect)**
```powershell
.\watchdog.ps1
# Tự động monitor và restart khi backend/tunnel dừng
```

**Lần đầu trong ngày:** Mở https://refmind-api.loca.lt → Click "Continue"

📚 **Troubleshooting:** Xem [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

---

## Features

- 🔍 **Search Documents**: Search your Refmind library from within Google Docs
- 📝 **Insert Citations**: Generate and insert citations in APA, IEEE, Harvard, MLA, or BibTeX format
- ✨ **Insert Highlights**: Browse and insert your saved highlights
- 🔐 **Secure Authentication**: Token-based authentication with your Refmind account

## Installation

### 1. Create Google Apps Script Project

1. Open [Google Apps Script](https://script.google.com)
2. Click "New Project"
3. Name your project "Refmind Add-on"

### 2. Add Script Files

Copy the following files into your Apps Script project:

- **Code.gs**: Copy the entire content of `Code.gs` from this folder
- **Sidebar.html**: Create HTML file, copy content from `Sidebar.html`
- **Settings.html**: Create HTML file, copy content from `Settings.html`

### 3. Get Public API URL

**⚠️ Important:** Google Apps Script **cannot access localhost**. You need a public URL.

**Quick Start (Recommended):**

```powershell
# Option 1: LocalTunnel (Easiest)
npm install -g localtunnel
cd docs_plugin_demo
.\start-dev-server.ps1

# Option 2: Cloudflare Tunnel (Most Stable)
.\start-dev-cloudflare.ps1
```

**See [DEPLOYMENT_OPTIONS.md](DEPLOYMENT_OPTIONS.md) for all deployment options:**
- LocalTunnel (Free, no signup)
- Cloudflare Tunnel (Free, most stable)
- Railway.app (Production, $5/mo)
- Render.com (Production, free tier)

### 4. Configure API URL in Code.gs

Copy your public URL and update `Code.gs`:

```javascript
// Example with LocalTunnel:
const API_BASE_URL = 'https://refmind-api.loca.lt/api/citation';

// Example with Cloudflare:
const API_BASE_URL = 'https://your-url.trycloudflare.com/api/citation';

// Production:
const API_BASE_URL = 'https://your-app.railway.app/api/citation';
```

### 5. Deploy and Test the Add-on

1. **Start your backend with public URL** (using one of the scripts above)
2. **Update Code.gs** with your public URL
3. In Apps Script:
   - Click **Save** (💾)
   - **Optional:** Test script by running `testConnection` function
   - Click **Deploy** → **Test deployments** → **Install**
4. Open a Google Doc (any document)
5. You should see **Add-ons** → **Refmind** in the menu
6. Go to **Settings** and enter your Refmind auth token
7. Open **Refmind Sidebar** to start searching and citing

**⚠️ Note:** `onOpen()` cannot be tested from Script Editor - it only runs when opened from an actual Google Doc.

## Usage

### First-Time Setup

1. Open any Google Doc
2. Go to **Add-ons** → **Refmind** → **Settings**
3. Enter your Refmind authentication token
4. Click **Save Token**

**How to get your token:**

**Option 1: From Flutter App (Easiest)**
1. Open Refmind mobile app
2. Go to **Settings** → **Developer** section
3. Tap **API Token** 
4. Tap **Copy Token**
5. Paste into Google Docs Settings dialog

**Option 2: From Firebase Console**
- Login to Firebase Console
- Navigate to Authentication
- Copy user's ID Token

### Searching and Citing

1. Open **Add-ons** → **Refmind** → **Open Refmind Sidebar**
2. Type your search query and press Enter
3. Browse search results
4. Click **📝 Cite** to insert a citation at your cursor
5. Select your preferred citation style (APA, IEEE, etc.)
6. Click **Insert Citation**

### Inserting Highlights

1. Search for a document
2. Click **✨ Highlights** on any result
3. Browse through saved highlights
4. Click **Insert** to add highlight text to your document

## API Endpoints Used

The add-on connects to the following Refmind backend endpoints:

- `GET /api/citation/plugin/search?q={query}` - Search documents
- `GET /api/citation/plugin/highlights/{item_id}` - Get highlights
- `GET /api/citation/items/{item_id}/cite?style={style}` - Generate citation

## Deployment (Optional)

### Deploy as Add-on

To make this available to multiple users:

1. In Apps Script, click **Deploy** → **New deployment**
2. Select type: **Add-on**
3. Configure deployment:
   - Add-on title: "Refmind - Citation Manager"
   - Short description: "Insert citations and highlights from your Refmind library"
   - Add logo/icon (512x512px)
4. Click **Deploy**

### Publish to Marketplace

To publish on Google Workspace Marketplace:

1. Complete add-on deployment
2. Go to [Google Workspace Marketplace SDK](https://console.cloud.google.com/apis/api/appsmarket-component.googleapis.com)
3. Create new listing
4. Submit for review

## Development Notes

### File Structure

```
docs_plugin_demo/
├── Code.gs           # Backend functions (Apps Script)
├── Sidebar.html      # Main UI for search and citations
├── Settings.html     # Token configuration dialog
└── README.md         # This file
```

### Security

- Authentication tokens are stored in PropertiesService (user-specific)
- Tokens are sent as Bearer tokens in Authorization header
- All API calls use HTTPS in production

### Error Handling

- Network errors show user-friendly messages
- Missing metadata falls back to default formatting
- Invalid tokens prompt user to reconfigure settings

## Troubleshooting

### "Authorization required" error

- Go to Settings and enter your authentication token
- Make sure the token is valid and not expired

### "Cannot connect to server" error

- Check that API_BASE_URL is correct in Code.gs
- Verify your backend server is running
- Check network connectivity

### "No results found"

- Verify you have documents in your Refmind library
- Try different search terms
- Check that your token has proper permissions

## Support

For issues or questions:
- Email: support@refmind.com
- Documentation: https://docs.refmind.com
- GitHub: https://github.com/refmind/refmind

## License

Copyright © 2024 Refmind. All rights reserved.
