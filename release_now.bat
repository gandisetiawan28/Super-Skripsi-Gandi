@echo off
setlocal enabledelayedexpansion

echo ========================================================
echo   SUPER SKRIPSI GANDI - ULTIMATE RELEASE AUTOMATION
echo ========================================================
echo.

echo [1/5] Membaca Versi dari pubspec.yaml...
cd super_skripsi_manager
for /f "tokens=2 delims=: " %%a in ('findstr /C:"version:" pubspec.yaml') do (
    set VERSION=%%a
)
echo [OK] Versi terdeteksi: !VERSION!

echo.
echo [2/5] Sinkronisasi Versi ke Seluruh Platform...
cd ..
if exist .venv\Scripts\python.exe (
    .venv\Scripts\python.exe sync_versions.py
) else (
    python sync_versions.py
)

echo.
echo [3/5] Menjalankan Audit Kode (Flutter Analyze)...
cd super_skripsi_manager
call flutter analyze > linter_output.txt 2>&1
findstr /C:"error -" linter_output.txt > nul
if %errorlevel% equ 0 (
    echo.
    echo [!] ERROR KRITIS DITEMUKAN:
    findstr /C:"error -" linter_output.txt
    echo.
    echo Silakan perbaiki error di atas sebelum rilis!
    del linter_output.txt
    pause
    exit /b 1
)
echo [OK] Tidak ada error kritis ditemukan.
del linter_output.txt
echo [OK] Kode bersih.

echo.
echo [4/5] Simulasi Build Windows (Mencegah Error GitHub)...
echo Harap tunggu, ini memastikan rilis Anda 100%% aman...
call flutter build windows --no-pub --release > build_log.txt 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [!] ERROR: Kompilasi gagal! Jangan push ke GitHub.
    echo Periksa file 'super_skripsi_manager/build_log.txt' untuk detailnya.
    pause
    exit /b 1
)
echo [OK] Kompilasi berhasil.
del build_log.txt

echo.
echo [5/5] Mengirim Perubahan ke GitHub...
cd ..
git add .
git commit -m "release: v!VERSION! (automated stable build)"
git push origin main

echo.
echo ========================================================
echo   BERHASIL! Versi !VERSION! telah dirilis ke GitHub.
echo   Silakan cek GitHub Actions untuk melihat proses rilis.
echo ========================================================
pause
