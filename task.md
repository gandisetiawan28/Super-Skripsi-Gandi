# Super Skripsi Gandi Ecosystem — Master Task List

## Phase 1: Project Scaffolding
- [ ] Create Flutter Desktop project (`super_skripsi_manager`)
- [ ] Create React Word Add-in project (`super_skripsi_addin`)
- [ ] Create shared architecture docs

## Phase 2: Flutter Manager — Core Infrastructure
- [ ] Cloud Licensing & Auth (Google Apps Script validation)
- [ ] GitHub-Based OTA Auto-Updater
- [ ] Centralized API Key Management (multi-LLM)
- [ ] Local HTTP Server (CORS-enabled cross-app bridge)
- [ ] System Logs Dashboard

## Phase 3: Flutter Manager — Zero-Input Auto-Archiving
- [ ] PDF Upload + Text Extraction (syncfusion_flutter_pdf)
- [ ] Anti-Duplicate MD5 Hashing
- [ ] Smart Text Chunking & Local Vector Store
- [ ] AI-Driven Metadata Extraction (Title, Author, Year, Category)
- [ ] Smart Auto-Renaming (APA format)
- [ ] .RIS Generator (Mendeley Integration)

## Phase 4: React Word Add-in
- [ ] Manifest.xml + Office Add-in Sideloading config
- [ ] Unified Chat Interface (Bento panel)
- [ ] Dynamic LLM Routing (dropdown selector)
- [ ] Cross-App API Key Streaming (from Flutter HTTP server)
- [ ] Context-Aware Memory (RAG via document selection)
- [ ] 3-Way Strict Format Generation (Verbatim / Parafrase / APA Citation)
- [ ] Seamless Word Injection (Word.run API)

## Phase 5: UI/UX — iOS Glassmorphism Design System
- [ ] Flutter: Cupertino-style Glassmorphism theme
- [ ] React: Frosted glass CSS system with backdrop-filter

## Phase 6: Verification & Polish
- [ ] End-to-end local server connectivity test
- [ ] PDF processing pipeline test
- [ ] Word Add-in sideloading test
- [ ] Cross-app sync verification
