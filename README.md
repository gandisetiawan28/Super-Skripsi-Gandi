# 🚀 Super Skripsi Gandi (SSG) - AI Research Assistant

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?logo=python&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-009688?logo=fastapi&logoColor=white)
![ChromeExtension](https://img.shields.io/badge/Chrome_Extension-4285F4?logo=google-chrome&logoColor=white)

**Super Skripsi Gandi (SSG)** adalah ekosistem asisten riset berbasis AI yang dirancang untuk membantu mahasiswa dan peneliti dalam mengelola referensi, mengekstraksi teori secara otomatis, dan menyinkronkan data riset langsung ke Microsoft Word.

## 🌟 Fitur Utama

- **🧠 RAG (Retrieval-Augmented Generation) Engine**: Pencarian semantik cerdas berbasis ChromaDB untuk menemukan kutipan yang relevan dari puluhan PDF riset Anda.
- **📑 Theory Extractor**: Bedah dokumen PDF secara otomatis menjadi struktur teori (Sitasi, Verbatim, Sub-bab) menggunakan model AI (DeepSeek, Gemini, OpenAI).
- **🧩 Browser Bridge Extension**: Automasi interaksi dengan provider AI web (seperti DeepSeek Web) secara gratis dan efisien tanpa API berbayar yang mahal.
- **📝 Word Bridge Integration**: Kirim kutipan dan teori yang sudah diekstrak langsung ke Microsoft Word sebagai Add-in.
- **🛡️ Emergency Abort System**: Mekanisme penghentian instan untuk mengontrol AI jika terjadi kesalahan generate, menghemat token dan waktu.

## 🛠️ Arsitektur Teknologi

Sistem ini terbagi menjadi 3 komponen utama yang saling terhubung:

1.  **Manager (Frontend)**: Dibangun dengan **Flutter (Desktop)** untuk dashboard manajemen data dan monitoring logs.
2.  **API Bridge (Middleware)**: Server **Node.js** yang bertugas sebagai jembatan komunikasi antara Manager dan Browser Extension.
3.  **RAG Core (Backend)**: Engine berbasis **Python (FastAPI)** untuk pemrosesan PDF, OCR, Embeddings, dan Vector Storage (ChromaDB).

## 🚀 Cara Menjalankan

### Prasyarat
- Flutter SDK (Channel Stable)
- Node.js (v16+)
- Python 3.10+
- Google Chrome (untuk Extension)

### 1. Jalankan RAG Backend (Python)
```bash
cd super_skripsi_rag
pip install -r requirements.txt
python main.py
```

### 2. Jalankan API Bridge (Node.js)
```bash
cd super_skripsi_extension/api-bridge
node server.js
```

### 3. Jalankan Manager App (Flutter)
```bash
cd super_skripsi_manager
flutter run -d windows
```

### 4. Install Extension
1. Buka `chrome://extensions` di Google Chrome.
2. Aktifkan **Developer Mode**.
3. Klik **Load Unpacked** dan pilih folder `super_skripsi_extension`.

---

## 📸 Demo & Tampilan
*(Anda bisa menambahkan screenshot dashboard Anda di sini)*

## 🤝 Kontribusi
Project ini dikembangkan oleh **Gandi Setiawan** sebagai solusi inovatif untuk automasi riset akademik. Kritik dan saran sangat terbuka melalui Pull Request atau Issue.

---
**Made with ❤️ for Academic Excellence.**
