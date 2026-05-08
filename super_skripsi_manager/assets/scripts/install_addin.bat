@echo off
title Super Skripsi Gandi - Add-in Installer
color 0A

echo =======================================================
echo    SUPER SKRIPSI GANDI - WORD ADD-IN INSTALLER
echo =======================================================
echo.

:: Get current directory and point to manifest
set MANIFEST_DIR=%~dp0..\..\..\super_skripsi_addin
pushd %MANIFEST_DIR%
set ABS_PATH=%CD%
popd

:: Convert to UNC path for Trust Center compatibility (e.g., \\localhost\D$\...)
set DRIVE_LETTER=%ABS_PATH:~0,1%
set FOLDER_PATH=%ABS_PATH:~3%
set UNC_PATH=\\localhost\%DRIVE_LETTER%$\%FOLDER_PATH%

echo Local Path: %ABS_PATH%
echo UNC Path  : %UNC_PATH%
echo.

:: Registry keys
set WEF_KEY="HKEY_CURRENT_USER\Software\Microsoft\Office\16.0\WEF\Developer"
set TRUST_LOC="HKEY_CURRENT_USER\Software\Microsoft\Office\16.0\Registration\Trusted Locations\SuperSkripsi"
set TRUST_CAT="HKEY_CURRENT_USER\Software\Microsoft\Office\16.0\WEF\TrustedCatalogs\SuperSkripsiGandi"

:: Check if Word is running
tasklist /FI "IMAGENAME eq winword.exe" 2>NUL | find /I /N "winword.exe">NUL
if "%ERRORLEVEL%"=="0" (
    color 0E
    echo [WARNING] Microsoft Word is currently running.
    echo Please save your work and CLOSE Word before continuing.
    echo.
    pause
)

echo [1/4] Clearing Office WEF Cache...
if exist "%LocalAppData%\Microsoft\Office\16.0\Wef" (
    echo Menghapus cache lama di %LocalAppData%\Microsoft\Office\16.0\Wef...
    rmdir /s /q "%LocalAppData%\Microsoft\Office\16.0\Wef" >nul 2>&1
    mkdir "%LocalAppData%\Microsoft\Office\16.0\Wef" >nul 2>&1
    echo Cache berhasil dibersihkan.
) else (
    echo Cache tidak ditemukan, lanjut...
)
echo.

echo [2/4] Registering Sideload Path (Developer)...
reg add %WEF_KEY% /v "SuperSkripsiGandi" /t REG_SZ /d "%ABS_PATH%" /f >nul 2>&1

echo [3/4] Registering Trusted Catalog (Shared Folder)...
:: This makes it appear in 'Shared Folder' tab with complete metadata
reg add %TRUST_CAT% /v "Id" /t REG_SZ /d "{88888888-4444-4444-4444-121212121212}" /f >nul 2>&1
reg add %TRUST_CAT% /v "Url" /t REG_SZ /d "%UNC_PATH%" /f >nul 2>&1
reg add %TRUST_CAT% /v "Flags" /t REG_DWORD /d 1 /f >nul 2>&1
reg add %TRUST_CAT% /v "ShowInMenu" /t REG_DWORD /d 1 /f >nul 2>&1

echo [4/4] Adding to Trusted Locations (Security Security)...
reg add %TRUST_LOC% /v "Path" /t REG_SZ /d "%ABS_PATH%" /f >nul 2>&1
reg add %TRUST_LOC% /v "AllowSubfolders" /t REG_DWORD /d 1 /f >nul 2>&1
reg add %TRUST_LOC% /v "Description" /t REG_SZ /d "Super Skripsi Gandi Workspace" /f >nul 2>&1

if %errorlevel% neq 0 (
    color 0C
    echo Error: Gagal menambahkan registry keys. Coba jalankan aplikasi sebagai Administrator.
    pause
    exit /b %errorlevel%
)

echo.
echo [DONE] Registry updated. Launching Microsoft Word...
echo.

pushd "%ABS_PATH%"
:: This command opens Word, creates a blank doc, and sideloads the manifest
call npm run sideload
popd

echo.
echo =======================================================
echo    INSTALLATION & LAUNCH SUCCESSFUL!
echo =======================================================
echo.
echo Jika Word tidak terbuka secara otomatis:
echo 1. Jalankan perintah 'npm run sideload' di folder Add-in.
echo 2. Atau buka Word secara manual dan cek 'My Add-ins'.
echo.

pause
exit
