@echo off
setlocal enabledelayedexpansion

echo ========================================================
echo   SUPER SKRIPSI GANDI - ULTIMATE RELEASE AUTOMATION
echo ========================================================
echo.

cd /d "%~dp0"

echo [1/5] Membaca Versi dari pubspec.yaml...
if not exist "super_skripsi_manager\pubspec.yaml" (
    echo [!] ERROR: pubspec.yaml tidak ditemukan di super_skripsi_manager!
    pause
    exit /b 1
)

cd super_skripsi_manager
for /f "tokens=2 delims=: " %%a in ('findstr /C:"version:" pubspec.yaml') do (
    set VERSION=%%a
)
:: Bersihkan build number (misal 1.1.29+1 jadi 1.1.29)
for /f "tokens=1 delims=+" %%v in ("!VERSION!") do set VERSION=%%v

if "!VERSION!"=="" (
    echo [!] ERROR: Versi tidak terdeteksi!
    pause
    exit /b 1
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
echo [4/5] Memulai Proses Kompilasi Lokal (Cepat)...
echo.
echo [4.1] Membangun Word Add-in (npm run build)...
cd ..\super_skripsi_addin
call npm run build > nul 2>&1
if %errorlevel% neq 0 (
    echo [!] ERROR: Gagal membangun Word Add-in. Pastikan Node.js terinstal.
    pause
    exit /b 1
)
echo [OK] Word Add-in siap.

echo.
echo [4.2] Membangun Flutter Windows App...
cd ..\super_skripsi_manager
echo Membersihkan cache lama agar akurat...
call flutter clean > nul 2>&1
echo Harap tunggu, sedang membangun binary Windows...
call flutter build windows --release > build_log.txt 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [!] ERROR: Kompilasi Flutter gagal!
    echo Periksa file 'super_skripsi_manager/build_log.txt' untuk detailnya.
    pause
    exit /b 1
)
echo [OK] Flutter Binary siap.
del build_log.txt

echo.
echo [4.3] Membuat Installer .EXE (Inno Setup)...
set "ISCC_PROG=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
set "ISCC_USER=%LocalAppData%\Programs\Inno Setup 6\ISCC.exe"

if exist "!ISCC_PROG!" (
    set "ISCC=!ISCC_PROG!"
) else if exist "!ISCC_USER!" (
    set "ISCC=!ISCC_USER!"
) else (
    echo [!] ERROR: ISCC.exe tidak ditemukan di folder standar atau folder User.
    echo Silakan instal Inno Setup 6 atau sesuaikan path di script ini.
    pause
    exit /b 1
)
echo [OK] Menggunakan compiler: !ISCC!
"!ISCC!" "windows\installer\super_skripsi_setup.iss"
if %errorlevel% neq 0 (
    echo [!] ERROR: Gagal membuat installer .EXE
    pause
    exit /b 1
)
echo [OK] Installer .EXE berhasil dibuat di folder 'Output'.

echo.
echo [5/5] Sinkronisasi ke GitHub (Skip CI)...
cd ..
git add .
git commit -m "release: v!VERSION! (local stable build) [skip ci]"
git push origin main

:: --- DETEKSI GITHUB CLI ---
set "GH_EXE="
where gh >nul 2>nul
if %errorlevel% equ 0 (
    set "GH_EXE=gh"
) else if exist "C:\Program Files\GitHub CLI\gh.exe" (
    set "GH_EXE=C:\Program Files\GitHub CLI\gh.exe"
) else if exist "%LocalAppData%\Programs\GitHub CLI\gh.exe" (
    set "GH_EXE=%LocalAppData%\Programs\GitHub CLI\gh.exe"
)

echo.
echo [6/6] Mengunggah Installer ke GitHub Release...

if "!GH_EXE!"=="" (
    echo [WARNING] GitHub CLI gh tidak ditemukan.
    echo Silakan upload file .exe secara manual ke GitHub.
) else (
    echo [OK] Menggunakan: !GH_EXE!
    
    :: Push tag versi
    git tag -a v!VERSION! -m "Release v!VERSION!" >nul 2>&1
    git push origin v!VERSION! >nul 2>&1
    
    echo Membuat rilis dan mengunggah file...
    set "EXE_PATH=super_skripsi_manager\windows\installer\Output\SuperSkripsi_Setup_v!VERSION!.exe"
    
    if exist "!EXE_PATH!" (
        "!GH_EXE!" release create v!VERSION! "!EXE_PATH!" --title "Release v!VERSION!" --notes "Automated local stable build v!VERSION!" --repo gandisetiawan28/Super_Skripsi_Gandi
        if %errorlevel% equ 0 (
            echo [OK] BERHASIL DIUNGGAH KE GITHUB RELEASE.
        ) else (
            echo [ERROR] Gagal upload. Pastikan sudah gh auth login.
        )
    ) else (
        echo [ERROR] File installer tidak ditemukan.
    )
)

echo.
echo ========================================================
echo   SELESAI! Versi !VERSION! telah aktif.
echo   Semua proses kompilasi dan rilis berjalan otomatis.
echo ========================================================
pause
