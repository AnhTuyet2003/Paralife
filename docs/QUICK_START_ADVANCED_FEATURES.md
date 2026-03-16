# Quick Start: Advanced Features

## 🚀 Setup (5 minutes)

### 1. Backend Setup
```bash
cd backend_api

# Install axios if not already installed
npm install axios

# Add to .env
echo "GEMINI_API_KEY=your_api_key_here" >> .env
echo "AI_PROVIDER=gemini" >> .env

# Start server
npm run dev
```

### 2. Flutter Setup
```bash
cd app

# Packages already installed, just hot restart
# Press 'r' in Flutter terminal
```

---

## 📝 Testing the Features

### Feature 1: Fact Check (DOI Validation)

**Test with real document:**
```bash
# 1. Go to any document in your library
# 2. Tap Menu (3 dots) → Will see new option: "🔎 Fact Check References"
# 3. Tap it → Loading → Results

Expected:
- Summary card with stats
- List of DOIs color-coded:
  ✅ Green = Valid (real DOI)
  ❌ Red = Hallucination (fake DOI)
  ❓ Orange = Unknown (network error)
```

**Test API directly:**
```bash
# cURL test
curl -X POST http://localhost:3000/api/items/YOUR_ITEM_ID/fact-check \
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

### Feature 2: Knowledge Graph

**Quick Test:**
```bash
# 1. Add at least 2-3 documents to your library
# 2. Navigate to: Menu → Knowledge Graph (new menu item)
# 3. See 3 tabs:
#    - Network View: Grid of colored document nodes
#    - Connections: List of links between papers
#    - AI Suggestions: Empty at first

# 4. Tap FAB button "✨ AI Suggestions"
# 5. Wait ~5-10 seconds → See AI-generated connections
```

**Test API:**
```bash
# Get graph data
curl http://localhost:3000/api/graph \
  -H "Authorization: Bearer YOUR_TOKEN"

# Get AI suggestions
curl http://localhost:3000/api/ai/missing-links \
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

### Feature 3: Accessibility (Dark Mode + Font Size)

**Quick Test:**
```bash
# 1. Go to: Settings → Appearance section
# 2. Toggle "Dark Mode" switch → Instant theme change
# 3. Use "Text Size" slider:
#    - Drag left: Smaller text (80%)
#    - Drag right: Larger text (150%)
# 4. Check all screens → Text should scale globally
```

---

## 🎯 Where to Find New Features

### In App Navigation:

```
Main Screen
├── Library Tab → Select document
│   └── Menu (⋮) → "🔎 Fact Check References" [NEW]
│
├── Menu Button
│   └── "🌐 Knowledge Graph" [NEW]
│
└── Settings Tab
    └── Appearance Section
        ├── "Dark Mode" switch [EXISTING]
        └── "Text Size" slider [NEW]
```

---

## 🔍 Feature Demos

### Demo 1: Detect Fake DOI
```dart
// Create a test document with this content:
"""
References:
1. Real paper: doi:10.1038/nature12373
2. Fake paper: doi:10.9999/thisisfake12345
3. Real paper: https://doi.org/10.1145/3292500.3330949
"""

// Run Fact Check → Should show:
// ✅ 2 valid
// ❌ 1 invalid (hallucination)
```

### Demo 2: Knowledge Graph with AI
```bash
# Add these 3 papers to your library:
1. "Attention is All You Need" (Transformers)
2. "BERT: Pre-training of Deep Bidirectional Transformers"
3. "GPT-3: Language Models are Few-Shot Learners"

# Open Knowledge Graph:
- Network View: See 3 nodes
- Connections: May show shared keywords like "NLP", "Transformers"
- Tap AI Suggestions button → AI will suggest:
  "Similar methodology: All three papers use transformer architectures"
```

### Demo 3: Font Size in PDF Reader
```bash
# 1. Open Settings → Set Text Size to 150% (max)
# 2. Open any PDF document
# 3. Text annotations and UI should be larger
# 4. Return to Settings → Set to 80% (min)
# 5. Text should be smaller
```

---

## 🧪 API Testing with Postman

### Collection Setup:
```json
{
  "name": "Refmind Advanced Features",
  "item": [
    {
      "name": "Fact Check Document",
      "request": {
        "method": "POST",
        "url": "http://localhost:3000/api/items/{{itemId}}/fact-check",
        "header": [{"key": "Authorization", "value": "Bearer {{token}}"}]
      }
    },
    {
      "name": "Get Knowledge Graph",
      "request": {
        "method": "GET",
        "url": "http://localhost:3000/api/graph",
        "header": [{"key": "Authorization", "value": "Bearer {{token}}"}]
      }
    },
    {
      "name": "Get AI Missing Links",
      "request": {
        "method": "GET",
        "url": "http://localhost:3000/api/ai/missing-links",
        "header": [{"key": "Authorization", "value": "Bearer {{token}}"}]
      }
    }
  ]
}
```

---

## 🎨 UI Screenshots Guide

### Fact Check Screen:
```
┌─────────────────────────────────┐
│ ← Fact Check        🔄         │
│   Paper Title                   │
├─────────────────────────────────┤
│ ╔═══════════════════════════╗  │
│ ║  Fact Check Summary        ║  │
│ ║  Total: 10  ✅ 8  ❌ 2    ║  │
│ ╚═══════════════════════════╝  │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ ✅ Valid                    │ │
│ │ 🔗 10.1038/nature12373  🔗 │ │
│ │ Title: Observation of...    │ │
│ │ Authors: ATLAS Collab       │ │
│ └─────────────────────────────┘ │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ ❌ Hallucination Detected   │ │
│ │ 🔗 10.9999/fake            │ │
│ │ ⚠️ DOI not found in         │ │
│ │    Crossref database        │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

### Knowledge Graph Screen:
```
┌─────────────────────────────────┐
│ ← Knowledge Graph    🔄         │
│   50 documents • 120 links      │
├─────────────────────────────────┤
│ ╔═══════════════════════════╗  │
│ ║ 📄 50  🔗 120             ║  │
│ ║ 👥 Authors: 45            ║  │
│ ║ 🏷️ Keywords: 60           ║  │
│ ╚═══════════════════════════╝  │
│                                 │
│ [Network] [Connections] [AI]    │
│                                 │
│ ┌─────┐  ┌─────┐  ┌─────┐     │
│ │Paper│  │Paper│  │Paper│     │
│ │  1  │  │  2  │  │  3  │     │
│ │2024 │  │2023 │  │2024 │     │
│ └─────┘  └─────┘  └─────┘     │
│                                 │
│              [✨ AI Suggestions] │
└─────────────────────────────────┘
```

### Settings - Accessibility:
```
┌─────────────────────────────────┐
│ ← Settings                      │
├─────────────────────────────────┤
│ Appearance                      │
│                                 │
│ 🌙 Dark Mode          [ON/OFF] │
│                                 │
│ 📏 Text Size                    │
│    Adjust reading text size     │
│                                 │
│    A  ━━━●━━━━━━━  A          │
│    80%            150%          │
│                                 │
│    Current: 120%                │
└─────────────────────────────────┘
```

---

## 🐛 Troubleshooting

### Issue: "AI Service not configured"
```bash
# Fix: Add GEMINI_API_KEY to .env
echo "GEMINI_API_KEY=your_key" >> backend_api/.env

# Restart backend
npm run dev
```

### Issue: "No DOIs found"
```bash
# Document must contain DOI in these formats:
- 10.1234/example
- doi:10.1234/example
- https://doi.org/10.1234/example

# Add to document metadata or content
```

### Issue: Knowledge graph empty
```bash
# Need at least 2 documents
# Documents must have metadata:
- authors[] or keywords[] for connections
- DOI for citation links
```

### Issue: Font size not changing
```bash
# Hot restart Flutter app:
# Press 'r' in terminal

# Or full rebuild:
flutter clean
flutter run
```

---

## 📊 Performance Notes

### Fact Check:
- ~1 second per DOI (Crossref API)
- Batch processing: max 10 concurrent
- Rate limit: 1 second delay between batches

### Knowledge Graph:
- Fast for <100 documents
- For >100 documents: consider pagination
- AI suggestions: ~5-10 seconds (LLM call)

### Accessibility:
- Instant theme switching
- Smooth font size transitions
- No performance impact

---

## ✅ Success Criteria

### Fact Check Working:
- [ ] Can see "Fact Check" in document menu
- [ ] Loading screen appears
- [ ] Summary card shows stats
- [ ] Valid DOIs show green with metadata
- [ ] Invalid DOIs show red with warning

### Knowledge Graph Working:
- [ ] Can open Knowledge Graph screen
- [ ] Sees document nodes in grid
- [ ] Can tap node to see details
- [ ] Connections tab shows links
- [ ] AI button generates suggestions

### Accessibility Working:
- [ ] Dark mode switch toggles theme
- [ ] Text size slider moves smoothly
- [ ] Text scales in all screens
- [ ] Settings persist after restart

---

## 🎉 You're Done!

All features are now ready to use. Navigate through the app and explore:
1. **Fact Check** any research paper
2. **Visualize** your knowledge network
3. **Get AI insights** on missing connections
4. **Customize** your reading experience

**Need help?** Check [ADVANCED_FEATURES_COMPLETE.md](./ADVANCED_FEATURES_COMPLETE.md) for full documentation.
