@echo off
setlocal enabledelayedexpansion

echo ========================================================
echo   SUPER SKRIPSI GANDI - PRE-PUSH SANITY CHECK
echo ========================================================
echo.

echo [1/4] Menjalankan Static Analysis (Linter)...
cd super_skripsi_manager
call flutter analyze > linter_output.txt 2>&1
set LINTER_STATUS=%errorlevel%

if %LINTER_STATUS% neq 0 (
    echo [!] ERROR: Analisis kode menemukan masalah.
    echo Silakan periksa linter_output.txt atau tab "Problems" di IDE Anda.
    echo.
    findstr /C:"error" linter_output.txt
    pause
    exit /b 1
) else (
    echo [OK] Kode bersih dari error kritis.
    del linter_output.txt
)

echo.
echo [2/4] Mencoba Build Windows (Cek Kompilasi)...
echo (Ini mungkin memakan waktu beberapa menit, tapi lebih baik daripada error di GitHub)
call flutter build windows --no-pub > build_output.txt 2>&1
set BUILD_STATUS=%errorlevel%

if %BUILD_STATUS% neq 0 (
    echo [!] ERROR: Build lokal gagal!
    echo Build di GitHub pasti akan gagal juga. Periksa build_output.txt.
    echo.
    findstr /C:"error" build_output.txt
    pause
    exit /b 1
) else (
    echo [OK] Kompilasi berhasil.
    del build_output.txt
)

echo.
echo [3/4] Sinkronisasi Versi...
cd ..
if exist .venv\Scripts\python.exe (
    .venv\Scripts\python.exe sync_versions.py
) else (
    python sync_versions.py
)

echo.
echo [4/4] Final Check Selesai!
echo ========================================================
echo   KODE ANDA SIAP UNTUK DIRILIS KE GITHUB
echo ========================================================
echo.

set /p confirm="Ingin melakukan COMMIT dan PUSH sekarang? (y/n): "
if /i "%confirm%"=="y" (
    set /p msg="Masukkan pesan commit (contoh: feat: fix theme errors): "
    git add .
    git commit -m "!msg!"
    git push origin main
    echo.
    echo [BERHASIL] Perubahan telah didorong ke GitHub.
) else (
    echo Push dibatalkan.
)

pause
