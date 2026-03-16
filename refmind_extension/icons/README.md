# Extension Icons

Icons for Refmind Web Clipper Chrome/Edge extension.

## Required Sizes

- **icon16.png** (16x16 pixels) - Toolbar icon
- **icon48.png** (48x48 pixels) - Extension management page
- **icon128.png** (128x128 pixels) - Chrome Web Store listing

## Design Guidelines

### Colors
- **Primary:** Blue (#2D60FF)
- **Background:** White or transparent
- **Accent:** Light blue (#F0F4FF) for background

### Icon Style
Option 1: **Book/Document Symbol**
- Simple outline of a book or document
- Blue color with white background
- Minimalist design

Option 2: **"R" Letter Mark**
- Bold "R" for Refmind
- Circular or rounded square background
- Blue on white or white on blue

Option 3: **Bookmark + Plus**
- Bookmark icon with small "+" badge
- Represents "save/add to collection"
- Blue bookmark icon

### Tools to Create Icons

**Online Tools:**
- [Favicon.io](https://favicon.io/) - Generate from text/image
- [Canva](https://www.canva.com/) - Design icons from scratch
- [Figma](https://www.figma.com/) - Professional design tool

**Quick Generation (for testing):**

Use Favicon.io with text "R":
1. Go to: https://favicon.io/favicon-generator/
2. Text: **R**
3. Background: **#2D60FF** (Circular)
4. Font Family: **Roboto**
5. Font Size: **80**
6. Font Color: **#FFFFFF**
7. Download → Extract → Rename files to icon16.png, icon48.png, icon128.png

## Temporary Placeholder

For development/testing, you can use placeholder icons:

**Create simple colored squares:**

```bash
# Linux/Mac (requires ImageMagick)
convert -size 16x16 xc:#2D60FF icon16.png
convert -size 48x48 xc:#2D60FF icon48.png
convert -size 128x128 xc:#2D60FF icon128.png

# Or use this Python script:
python3 <<EOF
from PIL import Image

# Create blue squares
for size in [16, 48, 128]:
    img = Image.new('RGB', (size, size), color='#2D60FF')
    img.save(f'icon{size}.png')
    print(f'✅ Created icon{size}.png')
EOF
```

## File Structure

```
refmind_extension/
├── icons/
│   ├── icon16.png     # 16x16 - Toolbar
│   ├── icon48.png     # 48x48 - Management
│   └── icon128.png    # 128x128 - Store listing
└── manifest.json      # References icons/
```

## Manifest Reference

The icons are already configured in `manifest.json`:

```json
{
  "icons": {
    "16": "icons/icon16.png",
    "48": "icons/icon48.png",
    "128": "icons/icon128.png"
  },
  "action": {
    "default_icon": {
      "16": "icons/icon16.png",
      "48": "icons/icon48.png"
    }
  }
}
```

## Browser Requirements

**Chrome/Edge:**
- PNG format required
- Exact sizes (16x16, 48x48, 128x128)
- Transparent or solid background
- File size: <100KB each

**Chrome Web Store:**
- 128x128 icon required for listing
- High quality, clear design
- Represents app functionality
- No blurry or pixelated images

## Production Checklist

Before submitting to Chrome Web Store:

- [ ] Create professional 16x16 icon
- [ ] Create professional 48x48 icon
- [ ] Create professional 128x128 icon
- [ ] Test icon visibility in toolbar (dark + light theme)
- [ ] Test icon in chrome://extensions page
- [ ] Ensure icons match Refmind brand
- [ ] Optimize file sizes (<100KB)
- [ ] Test on Windows, Mac, Linux

## Quick Fix for Testing

If you just want to test the extension without proper icons:

**Option 1:** Use simple text file as icon (will show default icon)
```bash
# Extension will still work, just shows default browser icon
```

**Option 2:** Copy icons from another extension
```bash
# Find another extension's icons:
# chrome://extensions → Details → View in Finder/Explorer
# Copy icon files to refmind_extension/icons/
```

**Option 3:** Use emoji as icon (not recommended)
```bash
# Create PNG from emoji using online tools
# Search: "emoji to png converter"
# Use bookmark emoji (🔖) or book emoji (📚)
```

## Final Note

Icons are **optional for development/testing**. Extension will work without them (shows default icon).

For production release, proper icons are **required** for professional appearance and Chrome Web Store approval.
