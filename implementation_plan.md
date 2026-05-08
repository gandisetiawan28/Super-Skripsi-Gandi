# Super Skripsi Gandi Ecosystem — Implementation Plan

This plan covers the full build of the **Super Skripsi Gandi** research assistant ecosystem: a Flutter Desktop Manager + React Word Add-in, connected via a localhost HTTP bridge.

## User Review Required

> [!IMPORTANT]
> **Decisions requiring your input:**
> 1. **Flutter state management**: I'll use **Riverpod** (recommended for modularity). Is this okay, or do you prefer Provider?
> 2. **React state**: I'll use **Zustand** per your spec. Confirm?
> 3. **Google Apps Script Licensing Endpoint**: Do you have an existing Google Apps Script URL? I'll scaffold the client-side validation and you can plug in your URL later.
> 4. **GitHub Repo for OTA Updates**: What is the GitHub repository URL for release checking? I can use a placeholder and you swap it later.
> 5. **Local vector store**: I'll use **SQLite + cosine similarity** via `sqflite_common_ffi` for the local vector store (simpler than ObjectBox for embeddings). Do you prefer ObjectBox instead?
> 6. **HTTP Server Port**: Previous build used port `28145`. I'll keep this. Okay?

> [!WARNING]
> This is a **very large project**. I will build it incrementally — Phase 1 (scaffolding + core infra) first, then each subsequent phase. Each phase will be a separate execution block so you can test along the way.

---

## Proposed Changes

### Phase 1: Project Scaffolding

#### [NEW] Flutter Desktop Project
Create `d:\SUPER SKRIPSI GANDI\super_skripsi_manager\` via `flutter create`.

**Directory structure:**
```
super_skripsi_manager/
├── lib/
│   ├── main.dart                    # App entry + Glassmorphism theme
│   ├── app.dart                     # MaterialApp + router
│   ├── theme/
│   │   └── glassmorphism_theme.dart # iOS-style design tokens
│   ├── models/
│   │   ├── api_key_model.dart
│   │   ├── document_model.dart
│   │   └── license_model.dart
│   ├── services/
│   │   ├── license_service.dart     # Google Apps Script auth
│   │   ├── updater_service.dart     # GitHub OTA updates
│   │   ├── api_key_service.dart     # Store/retrieve API keys
│   │   ├── pdf_service.dart         # PDF→text extraction
│   │   ├── hashing_service.dart     # MD5 duplicate detection
│   │   ├── chunking_service.dart    # Text chunking + embeddings
│   │   ├── vector_store_service.dart# Local SQLite vector store
│   │   ├── ai_extraction_service.dart# AI metadata extraction
│   │   ├── ris_generator_service.dart# .RIS file generator
│   │   └── local_server_service.dart # HTTP server for Add-in
│   ├── providers/                   # Riverpod providers
│   │   ├── license_provider.dart
│   │   ├── api_keys_provider.dart
│   │   ├── documents_provider.dart
│   │   └── server_provider.dart
│   ├── pages/
│   │   ├── license_gate_page.dart   # License validation screen
│   │   ├── dashboard_page.dart      # Main shell with nav dock
│   │   ├── api_keys_page.dart       # Multi-LLM API key manager
│   │   ├── research_page.dart       # PDF upload & auto-archive
│   │   ├── logs_page.dart           # System terminal logs
│   │   └── settings_page.dart       # App settings & update
│   └── widgets/
│       ├── glass_card.dart          # Reusable frosted glass card
│       ├── glass_nav_dock.dart      # macOS-style floating dock
│       ├── status_indicator.dart
│       └── log_terminal.dart
└── pubspec.yaml
```

#### [NEW] React Word Add-in Project
Create `d:\SUPER SKRIPSI GANDI\super_skripsi_addin\` via Yeoman Office Add-in generator or manual Webpack setup.

**Directory structure:**
```
super_skripsi_addin/
├── manifest.xml                     # Office Add-in manifest
├── src/
│   ├── taskpane/
│   │   ├── index.html
│   │   ├── index.jsx                # React entry
│   │   ├── App.jsx                  # Root with Zustand
│   │   ├── components/
│   │   │   ├── ChatPanel.jsx        # Unified bento chat
│   │   │   ├── MessageBubble.jsx    # Chat message display
│   │   │   ├── ResponseCard.jsx     # 3-way format card
│   │   │   ├── LlmSelector.jsx      # Dynamic LLM dropdown
│   │   │   └── DocumentSelector.jsx # Author/Year filter
│   │   ├── services/
│   │   │   ├── llmRouter.js         # Dynamic LLM API routing
│   │   │   ├── promptBase.js        # Prompt engineering + JSON strip
│   │   │   ├── managerBridge.js     # Fetch from Flutter HTTP server
│   │   │   ├── wordInjector.js      # Word.run() document injection
│   │   │   └── ragService.js        # RAG context builder
│   │   ├── stores/
│   │   │   └── appStore.js          # Zustand global state
│   │   └── styles/
│   │       ├── glassmorphism.css    # iOS glass design system
│   │       └── index.css            # Global resets
│   └── commands/
│       └── commands.js
├── webpack.config.js
└── package.json
```

---

### Phase 2: Flutter Manager — Core Infrastructure

#### [NEW] [license_service.dart](file:///d:/SUPER%20SKRIPSI%20GANDI/super_skripsi_manager/lib/services/license_service.dart)
- HTTP POST to Google Apps Script endpoint with `{name, deviceId, key}`
- Parse JSON response for `status: "Aktif"` / `"Nonaktif"`
- Encrypt license session in local storage (`flutter_secure_storage`)
- Device ID via `device_info_plus` package

#### [NEW] [updater_service.dart](file:///d:/SUPER%20SKRIPSI%20GANDI/super_skripsi_manager/lib/services/updater_service.dart)
- Fetch GitHub Releases API (`/repos/{owner}/{repo}/releases/latest`)
- Compare semantic version against local `pubspec.yaml` version
- Background download of installer asset
- Execute installer with appropriate OS privileges
- Handle GitHub API rate limits (429 status)

#### [NEW] [local_server_service.dart](file:///d:/SUPER%20SKRIPSI%20GANDI/super_skripsi_manager/lib/services/local_server_service.dart)
- `dart:io HttpServer` on port `28145`
- CORS headers for Office Add-in origin
- Endpoints:
  - `GET /api/keys` → returns all active API keys
  - `GET /api/documents` → returns document metadata list
  - `GET /api/documents/{id}/chunks` → returns text chunks for RAG
  - `GET /api/health` → server health check
  - `GET /api/documents/{id}/context` → returns full context for a doc

#### [NEW] [api_keys_page.dart](file:///d:/SUPER%20SKRIPSI%20GANDI/super_skripsi_manager/lib/pages/api_keys_page.dart)
- Grid of input fields for: Gemini, OpenAI, Claude, Groq, DeepSeek, xAI Grok
- Encrypted local storage via `flutter_secure_storage`
- Real-time sync to local HTTP server

---

### Phase 3: Flutter Manager — Zero-Input Auto-Archiving

#### [NEW] [pdf_service.dart](file:///d:/SUPER%20SKRIPSI%20GANDI/super_skripsi_manager/lib/services/pdf_service.dart)
- `syncfusion_flutter_pdf` for text extraction
- Error handling for scanned (image-only) PDFs
- Returns raw text string

#### [NEW] [hashing_service.dart](file:///d:/SUPER%20SKRIPSI%20GANDI/super_skripsi_manager/lib/services/hashing_service.dart)
- MD5 hash of extracted text content
- Check against existing hashes in SQLite
- Reject duplicates with user notification

#### [NEW] [chunking_service.dart](file:///d:/SUPER%20SKRIPSI%20GANDI/super_skripsi_manager/lib/services/chunking_service.dart)
- Split text into ~500 token overlapping chunks
- Store chunks with metadata (page ranges, position index)

#### [NEW] [vector_store_service.dart](file:///d:/SUPER%20SKRIPSI%20GANDI/super_skripsi_manager/lib/services/vector_store_service.dart)
- SQLite table for embeddings (via AI embedding API or simple TF-IDF fallback)
- Cosine similarity search for RAG retrieval
- Return top-K relevant chunks for a query

#### [NEW] [ai_extraction_service.dart](file:///d:/SUPER%20SKRIPSI%20GANDI/super_skripsi_manager/lib/services/ai_extraction_service.dart)
- Send first ~2000 chars to configured LLM
- Extract structured JSON: `{title, authors[], year, category}`
- Fallback with regex patterns if AI fails

#### [NEW] [research_page.dart](file:///d:/SUPER%20SKRIPSI%20GANDI/super_skripsi_manager/lib/pages/research_page.dart)
- Drag-and-drop or file picker for PDF upload
- Real-time processing pipeline display
- Document list with search/filter
- Auto-rename display + download RIS button

---

### Phase 4: React Word Add-in

#### [NEW] [manifest.xml](file:///d:/SUPER%20SKRIPSI%20GANDI/super_skripsi_addin/manifest.xml)
- Valid Office Add-in manifest for Word
- Configured for localhost sideloading + production URLs
- Taskpane dimensions and permissions

#### [NEW] [ChatPanel.jsx](file:///d:/SUPER%20SKRIPSI%20GANDI/super_skripsi_addin/src/taskpane/components/ChatPanel.jsx)
- Bento-style minimalist chat interface
- Message history with scrollable area
- Input field with send button
- Document context selector (Author, Year)

#### [NEW] [llmRouter.js](file:///d:/SUPER%20SKRIPSI%20GANDI/super_skripsi_addin/src/taskpane/services/llmRouter.js)
- Dynamic routing to: Gemini, GPT-4o, Claude, Groq, DeepSeek, xAI Grok
- Offline-first: detect & route to Ollama/LM Studio on localhost
- Unified response interface regardless of provider

#### [NEW] [promptBase.js](file:///d:/SUPER%20SKRIPSI%20GANDI/super_skripsi_addin/src/taskpane/services/promptBase.js)
- Strict JSON output prompt engineering
- **Regex/string cleaner** to strip markdown code fences from LLM responses before `JSON.parse()`
- Force 3-way output: `{verbatim, paraphrase, citation}`

#### [NEW] [wordInjector.js](file:///d:/SUPER%20SKRIPSI%20GANDI/super_skripsi_addin/src/taskpane/services/wordInjector.js)
- `Word.run()` API for native cursor injection
- Insert formatted HTML (bold citations, proper paragraphing)

---

### Phase 5: iOS Glassmorphism Design System

#### Flutter Theme
- `BackdropFilter` + `ImageFilter.blur` on all cards/panels
- Cupertino-style rounded corners (20px radius)
- Red accent palette (`#E53935` primary)
- Frosted white glass backgrounds (`Colors.white.withOpacity(0.15)`)
- Soft drop shadows + thin white translucent borders
- `google_fonts: Inter` for modern typography

#### React CSS System
- `backdrop-filter: blur(20px) saturate(180%)`
- Frosted glass variables in CSS custom properties
- Red accent theming
- Inter font from Google Fonts CDN
- Smooth micro-animations (hover/focus transitions)

---

## Verification Plan

### Automated Tests
1. **Flutter analyze**: `cd d:\SUPER SKRIPSI GANDI\super_skripsi_manager && flutter analyze`
2. **Flutter build**: `cd d:\SUPER SKRIPSI GANDI\super_skripsi_manager && flutter build windows`
3. **React build**: `cd d:\SUPER SKRIPSI GANDI\super_skripsi_addin && npm run build`
4. **React lint**: `cd d:\SUPER SKRIPSI GANDI\super_skripsi_addin && npx eslint src/`

### Manual Verification
1. **License Gate**: Launch Flutter app → should show license validation screen → enter test credentials → verify API call and response handling
2. **API Keys Page**: Navigate to API Keys tab → enter test keys → verify they persist after restart → verify they appear on `GET http://localhost:28145/api/keys`
3. **PDF Pipeline**: Upload a PDF in Research tab → verify: text extracted → MD5 checked → chunks created → AI metadata extracted → file auto-renamed → RIS downloadable
4. **Word Add-in Sideload**: Open Word → sideload manifest.xml → verify taskpane opens → verify LLM dropdown populates → verify document selector shows uploaded docs → send query → verify 3-way response → click "Use" → verify text injected at cursor
5. **Cross-App Sync**: With Flutter Manager running → open Word Add-in → verify API keys and document list are fetched from localhost server

> [!TIP]
> I will build **Phase 1 + Phase 2** first so you can test the Flutter Manager independently before we wire up the Add-in.
