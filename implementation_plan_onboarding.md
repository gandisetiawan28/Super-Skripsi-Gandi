# Implementation Plan: Professional Onboarding & Google Drive Sync

Rencana ini bertujuan untuk meningkatkan alur masuk aplikasi menjadi lebih profesional dengan fitur sinkronisasi data otomatis dan perlindungan privasi pengguna.

## User Review Required

> [!IMPORTANT]
> **Privacy Architecture:** Data riset pengguna akan dikirim langsung dari aplikasi ke Google Drive milik pengguna. Developer tidak memiliki akses ke data tersebut.
> **Survey Data:** Data survey akan disimpan secara lokal atau bisa dikirim ke server developer jika Anda ingin mengumpulkan statistik pemasaran.

## Technical Considerations

1. **SQLite Snapshot Backup:** Melakukan copy file `.db` ke folder temporary sebelum upload untuk menghindari file lock/corruption saat database sedang aktif.
2. **Conflict Resolution:** Menggunakan sistem *Last-Write-Wins* berbasis timestamp untuk menangani perbedaan data antara lokal dan cloud.
3. **Resumable PDF Upload:** Menggunakan protokol resumable dari Google Drive API untuk mengunggah file PDF besar agar lebih stabil pada koneksi buruk.
4. **OAuth Windows Loopback:** Menggunakan local server (ApiBridge) atau package pendukung untuk menangani redirect Google Auth di platform Windows.

## Fitur Utama

1. **Unified Onboarding Flow:** Alur masuk satu arah (Google Login -> Survey -> Validasi Lisensi).
2. **Google Drive Auto-Sync:** Sinkronisasi database (`.db`) dan file library (`.pdf`) secara otomatis ke folder aplikasi tersembunyi di Drive pengguna.
3. **One-time Marketing Survey:** Mengetahui asal pengguna (Instagram, TikTok, Teman, dll) untuk keperluan statistik.

---

## Proyeksi Perubahan

### 1. UI Components (Onboarding)

#### [NEW] `onboarding_page.dart`
Halaman baru yang menggantikan `license_gate_page.dart` dengan sistem *multi-step*:
- **Step 1: Welcome & Google Login:** Tombol login Google yang elegan.
- **Step 2: User Profile & License:** Input Nama Pengguna dan Kode Lisensi (mengambil data nama dari Google secara otomatis).
- **Step 3: Quick Survey:** Dropdown/Pilihan "Dari mana Anda tahu aplikasi ini?".

### 2. Services & Providers

#### [NEW] `google_drive_service.dart`
Mengelola interaksi dengan Google API:
- Autentikasi OAuth2.
- Upload/Download file database dan library.
- Cek keberadaan backup lama saat instalasi baru.

#### [NEW] `onboarding_provider.dart`
State management untuk melacak apakah pengguna sudah menyelesaikan survey dan login.

#### [MODIFY] `license_provider.dart`
Ditingkatkan agar bisa menyimpan data profil pengguna yang diambil dari Google Auth.

### 3. Background Sync Engine

#### [NEW] `sync_service.dart`
Service yang berjalan di latar belakang:
- Mendeteksi perubahan file lokal.
- Melakukan upload berkala (misal: setiap ada dokumen baru atau setiap 15 menit).
- Menampilkan indikator "Last Synced" di UI.

---

## Tahapan Implementasi

### Fase 1: Google Cloud Setup
- Mendaftarkan aplikasi di Google Cloud Console.
- Mengaktifkan Google Drive API & Google Auth.
- Mengonfigurasi *OAuth Consent Screen*.

### Fase 2: Alur Onboarding (UI)
- Membuat `OnboardingPage` dengan animasi transisi antar step.
- Integrasi Google Sign-In menggunakan package `google_sign_in`.
- Implementasi form survey sederhana.

### Fase 3: Integrasi Sinkronisasi (Logic)
- Implementasi `GoogleDriveService` dengan dukungan *App Data Folder* (folder tersembunyi).
- Logika **Snapshot Backup**: Menyalin SQLite ke temp sebelum upload.
- Implementasi `SyncService` yang berjalan secara asinkron di latar belakang.
- Logika untuk mengunduh data (Restore) saat pengguna pertama kali login di perangkat baru.

### Fase 4: Finalisasi & UI Polish
- Menambahkan **Sync Status Indicator** (ikon awan) di sidebar atau navbar.
- Optimasi performa: Upload dilakukan dalam chunk untuk file besar (PDF).
- Penanganan error: Auto-retry saat koneksi internet kembali aktif.

---

## Rencana Verifikasi

### Manual Verification
1. Melakukan login Google pada instalasi bersih.
2. Mengisi survey dan lisensi.
3. Menambahkan beberapa dokumen di tab Research.
4. Mengecek di Google Drive (bagian App Data) apakah file sudah terunggah.
5. Menghapus aplikasi dan menginstal ulang untuk mencoba fitur **Auto-Restore**.
