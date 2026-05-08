# Pemisahan Database Lokal Berbasis Multi-User (Email)

Mengimplementasikan Pilihan 2 (Pemisahan Database Berdasarkan Email) agar aplikasi aman digunakan oleh beberapa pengguna di PC yang sama tanpa risiko data tertukar atau terhapus.

## User Review Required

> [!IMPORTANT]
> Sistem ini membutuhkan satu sumber kebenaran (*single source of truth*) untuk mengetahui siapa yang sedang *login*. Jika aplikasi dibuka dan belum ada yang *login*, aplikasi akan menggunakan database `default` atau memaksa *login* terlebih dahulu.
> 
> **Pertanyaan:** Apakah kamu setuju jika lisensi aplikasi (`license_store`) tetap bersifat "Global" (menempel di perangkat komputer, bukan di akun email)? Ini adalah standar *desktop app* agar pembeli cukup memasukkan lisensi 1 kali per komputer, lalu siapa pun yang meminjam komputernya bisa *login* Google dengan email masing-masing.

## Proposed Changes

Kita akan membuat penamaan kotak Hive menjadi dinamis dengan format `[nama_kotak]_[safe_email]`. 

### `lib/providers/user_session_provider.dart`

- Memisahkan atau membuat fungsi *helper* kecil yang bertugas mengambil email Google pengguna saat ini dan memformatnya menjadi `safeEmail` (misal: `gandi_gmail_com`).

#### [NEW] `lib/utils/session_utils.dart`
- Membuat *helper* `String getSafeEmail(String? rawEmail)` untuk membersihkan karakter.

### `lib/services/latihan_service.dart`

#### [MODIFY] `lib/services/latihan_service.dart`
- Menambahkan parameter `String userEmail` pada `LatihanService` atau method-methodnya agar `_historyBoxName` dan `_hiveBoxName` menjadi dinamis.

### `lib/services/sync_service.dart`

#### [MODIFY] `lib/services/sync_service.dart`
- Membuat `_syncBoxName` menjadi dinamis berdasarkan email pengguna yang sedang melakukan *sync*.

### `lib/services/api_key_service.dart`

#### [MODIFY] `lib/services/api_key_service.dart`
- Menjadikan penyimpanan *API Key* bersifat spesifik per *user* agar pengguna A tidak menghabiskan kuota pengguna B.

### `lib/providers/onboarding_provider.dart`

#### [MODIFY] `lib/providers/onboarding_provider.dart`
- Menyesuaikan `_boxName` jika *onboarding* perlu dipisah per *user*. Namun jika *onboarding* diikat di perangkat, kotak ini bisa dibiarkan statis. Saya akan membiarkannya statis karena *onboarding* (Langkah 1-3) biasanya dilakukan 1 kali per perangkat setelah instalasi.

## Verification Plan

### Manual Verification
1. Jalankan aplikasi, selesaikan *onboarding* dengan `email_A@gmail.com`.
2. Lakukan aktivitas (buat skripsi/catatan).
3. Logout.
4. Login kembali dengan `email_B@gmail.com`. Pastikan layar kosong (tidak ada data email_A).
5. Buka folder instalasi lokal (PC) untuk memastikan ada 2 set file `.hive` yang berbeda untuk masing-masing email.
