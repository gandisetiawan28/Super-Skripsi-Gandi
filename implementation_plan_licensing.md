# Implementation Plan: Smart Licensing System (Google Sheets Backend)

Sistem lisensi zero-cost menggunakan Google Sheets sebagai database dan Google Apps Script sebagai API Gateway untuk memvalidasi penggunaan lisensi pada maksimal 2 perangkat.

## Arsitektur Sistem

1. **Database (Google Sheets)**: Tabel private untuk menyimpan data `Key`, `DeviceID_1`, `DeviceID_2`, `DeviceName`, dan `Status`.
2. **Backend API (Google Apps Script)**: Bertindak sebagai "satpam" yang memproses request dari Flutter menggunakan **Secret Token** untuk keamanan.
3. **Offline support**: Menggunakan Hive untuk menyimpan cache status lisensi lokal dengan masa tenggang (Grace Period) 7 hari.

## Rencana Perubahan

### 1. Database Schema (Google Sheets)
Kolom pada Spreadsheet:
- `license_key`: Kunci unik (Primary Key).
- `device_id_1`: ID unik perangkat pertama (Hashed SHA-256).
- `device_name_1`: Nama perangkat pertama (misal: "Windows PC").
- `device_id_2`: ID unik perangkat kedua.
- `device_name_2`: Nama perangkat kedua (misal: "Android Phone").
- `status`: "Active" atau "Blocked".
- `last_validated`: Tanggal validasi terakhir.

### 2. Keamanan (Secret Token)
- Menambahkan variabel `SECRET_API_TOKEN` di Apps Script dan kode Flutter.
- Request hanya akan diproses jika header atau parameter `token` sesuai.

### 3. Service & Logic Baru
#### [NEW] `lib/services/device_info_service.dart`
- Mengambil ID unik perangkat + Nama perangkat.
- Melakukan hashing SHA-256 pada ID sebelum dikirim.

#### [NEW] `lib/services/license_validation_service.dart`
- `activate(String key)`: Mengirim request `POST` ke Apps Script.
- `verifyStatus()`: Mengecek status ke server secara berkala.
- **Logic Offline**: Jika internet mati, cek `last_online_validation`. Jika < 7 hari, tetap izinkan akses.

### 4. UI Updates
#### [MODIFY] `lib/pages/onboarding_page.dart`
- Menghubungkan form lisensi ke `LicenseValidationService`.
- Menambahkan indikator loading yang jelas saat validasi (estimasi 2-3 detik).

## User Review Required

> [!IMPORTANT]
> **Secret Token**: Anda perlu menentukan satu string rahasia (misal: `SUPER_GANDI_SECURE_2024`) yang akan kita tanam di skrip dan aplikasi.

> [!TIP]
> **Manajemen Manual**: Anda bisa me-reset perangkat pelanggan hanya dengan menghapus isi sel `device_id` di Google Sheets secara langsung dari HP atau Laptop Anda.

## Langkah Selanjutnya
1. Membuat Google Sheets & Menulis kode Apps Script.
2. Implementasi `DeviceInfoService` dengan hashing SHA-256.
3. Integrasi alur validasi ke Onboarding & Main App.
