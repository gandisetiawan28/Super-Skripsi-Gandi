# 🚀 Super Skripsi Gandi (SSG) - AI Research Assistant

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?logo=python&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-009688?logo=fastapi&logoColor=white)
![ChromeExtension](https://img.shields.io/badge/Chrome_Extension-4285F4?logo=google-chrome&logoColor=white)

**Super Skripsi Gandi (SSG)** adalah platform riset masa depan yang menggabungkan kekuatan *Large Language Models* (LLM) dengan data riset lokal Anda. SSG membantu mengubah tumpukan PDF jurnal yang membingungkan menjadi database teori terstruktur yang siap pakai.

---

## 🌟 Fitur Mendalam

### 🧠 Semantic RAG Engine (Local-First)
Bukan sekadar pencarian kata kunci biasa. SSG menggunakan **Vector Embeddings** untuk memahami konteks riset Anda.
- **Hybrid Search**: Menggabungkan pencarian semantik (makna) dengan filter metadata (Bab, Sub-bab, Variabel).
- **Persistent Vector DB**: Menggunakan **ChromaDB** yang disimpan di lokal, memastikan data tidak hilang meski aplikasi ditutup.
- **Smart Chunking**: Teknik pemotongan dokumen yang cerdas agar konteks antar paragraf tetap terjaga.

### 📑 Automated Theory Extraction
Proses bedah dokumen yang manual dan melelahkan kini diotomatisasi sepenuhnya.
- **Structure Recognition**: AI secara cerdas mengenali mana yang merupakan Kutipan Verbatim, Sitasi (APA 7th), dan Penjelasan Teori.
- **JSON Mapping**: Data dikonversi menjadi format JSON terstruktur yang memudahkan integrasi ke database atau ekspor dokumen.
- **Noise Cleaning**: Menghilangkan header, footer, dan nomor halaman yang mengganggu dari kutipan teks asli.

### 🧩 Browser Bridge & Multi-Layer Abort
Inovasi unik untuk menggunakan AI Web tanpa biaya API tambahan yang mahal.
- **Emergency Stop System**: Sistem jalur ganda (Dual-Polling) yang menjamin AI berhenti dalam <1 detik jika user menekan tombol Batal, mencegah penggunaan token berlebih.
- **Provider Heartbeat**: Monitor status koneksi antara Flutter Manager dan Ekstensi Browser secara real-time.
- **Automasi DOM**: Simulasi interaksi manusia pada web DeepSeek/Gemini untuk pengetikan prompt yang stabil.

### 📝 Integration Bridge (MS Word & RIS)
Sinkronisasi langsung ke meja kerja Anda.
- **Word Add-in**: Masukkan teori yang sudah ditemukan langsung ke dokumen Word tanpa perlu copy-paste manual.
- **RIS Export**: Dukungan ekspor format RIS untuk diimpor ke aplikasi manajemen referensi seperti Mendeley atau Zotero.

---

## 🛡️ Keamanan & Privasi Data

SSG dirancang dengan prinsip **Private-by-Design**:

1.  **Local-Only Storage**: Seluruh dokumen PDF, index database (Vector DB), dan metadata riset Anda disimpan **100% di komputer lokal**. Tidak ada data riset yang diunggah ke server pihak ketiga (kecuali ke provider AI yang Anda pilih).
2.  **API Key Encryption**: API Key yang Anda masukkan disimpan menggunakan **Secure Storage** bawaan OS (Windows Credential Manager), terenkripsi dan tidak dapat diakses oleh aplikasi lain.
3.  **Sandboxed Automation**: Browser Extension berjalan di dalam *sandbox* Chrome yang ketat, memastikan ia hanya berinteraksi dengan tab AI yang ditentukan.
4.  **No Tracking Policy**: Aplikasi ini tidak mengumpulkan data penggunaan, analitik, atau informasi pribadi pengguna.

---

## 🛠️ Arsitektur Teknologi

Sistem ini terbagi menjadi 3 komponen utama yang saling terhubung:

1.  **Manager (Frontend)**: Dibangun dengan **Flutter (Desktop)** untuk dashboard manajemen data dan monitoring logs.
2.  **API Bridge (Middleware)**: Server **Node.js** yang bertugas sebagai jembatan komunikasi antara Manager dan Browser Extension.
3.  **RAG Core (Backend)**: Engine berbasis **Python (FastAPI)** untuk pemrosesan PDF, OCR, Embeddings, dan Vector Storage (ChromaDB).

---

## 🚀 Cara Menjalankan

### Prasyarat
- Flutter SDK (Channel Stable)
- Node.js (v16+)
- Python 3.10+
- Google Chrome (untuk Extension)

*(Lihat panduan instalasi mendalam di [Wiki](#) - segera hadir)*

---
**Developed by Gandi Setiawan.**
"Empowering Academic Excellence through Intelligent Automation."
