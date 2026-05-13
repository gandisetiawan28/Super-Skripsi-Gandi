@echo off
title Super Skripsi Gandi - Add-in Installer
color 0A

echo =======================================================
echo    SUPER SKRIPSI GANDI - WORD ADD-IN INSTALLER
echo =======================================================
echo.

:: Get current directory (where manifest.xml is located)
set "ABS_PATH=%~dp0"
if "%ABS_PATH:~-1%"=="\" set "ABS_PATH=%ABS_PATH:~0,-1%"

:: Fallback to developer path if manifest.xml is not in the current folder
if not exist "%ABS_PATH%\manifest.xml" (
    if exist "%ABS_PATH%\..\..\..\super_skripsi_addin\manifest.xml" (
        pushd "%ABS_PATH%\..\..\..\super_skripsi_addin"
        set "ABS_PATH=%CD%"
        popd
    )
)

:: Convert to UNC path for Trust Center compatibility (e.g., \\localhost\C$\...)
:: Note: This is a fallback, Developer Registry key is more reliable for local use
set "DRIVE_LETTER=%ABS_PATH:~0,1%"
set "FOLDER_PATH=%ABS_PATH:~3%"
set "UNC_PATH=\\localhost\%DRIVE_LETTER%$\%FOLDER_PATH%"

echo Local Path: %ABS_PATH%
echo UNC Path  : %UNC_PATH%
echo.

:: Registry keys
set "WEF_KEY=HKEY_CURRENT_USER\Software\Microsoft\Office\16.0\WEF\Developer"
set "TRUST_LOC=HKEY_CURRENT_USER\Software\Microsoft\Office\16.0\Registration\Trusted Locations\SuperSkripsi"
set "TRUST_CAT=HKEY_CURRENT_USER\Software\Microsoft\Office\16.0\WEF\TrustedCatalogs\SuperSkripsiGandi"

:: Check if Word is running
tasklist /FI "IMAGENAME eq winword.exe" 2>NUL | find /I /N "winword.exe">NUL
if "%ERRORLEVEL%"=="0" (
    color 0E
    echo [WARNING] Microsoft Word sedang berjalan.
    echo Harap simpan pekerjaan Anda dan TUTUP Word sebelum melanjutkan.
    echo.
    pause
)

echo [1/4] Membersihkan Cache Office WEF...
if exist "%LocalAppData%\Microsoft\Office\16.0\Wef" (
    rmdir /s /q "%LocalAppData%\Microsoft\Office\16.0\Wef" >nul 2>&1
    mkdir "%LocalAppData%\Microsoft\Office\16.0\Wef" >nul 2>&1
    echo Cache berhasil dibersihkan.
) else (
    echo Cache tidak ditemukan, lanjut...
)
echo.

echo [2/4] Mendaftarkan Jalur Sideload (Developer)...
reg add "%WEF_KEY%" /v "SuperSkripsiGandi" /t REG_SZ /d "%ABS_PATH%" /f >nul 2>&1

echo [3/4] Mendaftarkan Katalog Terpercaya (Shared Folder)...
reg add "%TRUST_CAT%" /v "Id" /t REG_SZ /d "{88888888-4444-4444-4444-121212121212}" /f >nul 2>&1
reg add "%TRUST_CAT%" /v "Url" /t REG_SZ /d "%UNC_PATH%" /f >nul 2>&1
reg add "%TRUST_CAT%" /v "Flags" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "%TRUST_CAT%" /v "ShowInMenu" /t REG_DWORD /d 1 /f >nul 2>&1

echo [4/4] Menambahkan ke Lokasi Terpercaya (Security)...
reg add "%TRUST_LOC%" /v "Path" /t REG_SZ /d "%ABS_PATH%" /f >nul 2>&1
reg add "%TRUST_LOC%" /v "AllowSubfolders" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "%TRUST_LOC%" /v "Description" /t REG_SZ /d "Super Skripsi Gandi Workspace" /f >nul 2>&1

if %errorlevel% neq 0 (
    color 0C
    echo Error: Gagal menambahkan registry keys. Coba jalankan aplikasi sebagai Administrator.
    pause
    exit /b %errorlevel%
)

echo.
echo [BERHASIL] Registry telah diperbarui.
echo.

:: Check for npm (developer tools)
where npm >nul 2>&1
if %errorlevel% equ 0 (
    echo [INFO] Mendeteksi Node.js, mencoba menjalankan 'sideload' otomatis...
    pushd "%ABS_PATH%"
    call npm run sideload
    popd
) else (
    echo [INFO] Node.js tidak ditemukan. Membuka Word secara manual...
    start winword
)

echo.
echo =======================================================
echo    INSTALASI BERHASIL!
echo =======================================================
echo.
echo Untuk menggunakan Add-in di Microsoft Word:
echo 1. Buka Microsoft Word.
echo 2. Pergi ke tab 'Insert' (Sisipkan).
echo 3. Klik 'My Add-ins' (Add-in Saya).
echo 4. Pilih tab 'Shared Folder' atau 'Developer'.
echo 5. Klik 'Super Skripsi Gandi Manager' dan klik 'Add'.
echo.
echo Pastikan aplikasi 'Super Skripsi Manager' sedang berjalan!
echo.

pause
exit
