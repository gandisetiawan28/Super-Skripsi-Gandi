@echo off
title Super Skripsi Gandi - Word Add-in Installer
color 0b

echo ==========================================
echo   REGISTERING WORD ADD-IN
echo ==========================================
echo.

:: Get current folder path
set "ADDIN_PATH=%~dp0"
if "%ADDIN_PATH:~-1%"=="\" set "ADDIN_PATH=%ADDIN_PATH:~0,-1%"
set "MANIFEST_PATH=%ADDIN_PATH%\manifest.xml"

echo Target Path: %ADDIN_PATH%
echo Manifest   : %MANIFEST_PATH%
echo.

:: 1. Clear Office WEF Cache (Sangat penting agar Add-in tidak stuck di versi lama)
echo [1/4] Clearing Office Cache...
if exist "%LocalAppData%\Microsoft\Office\16.0\Wef" (
    rmdir /s /q "%LocalAppData%\Microsoft\Office\16.0\Wef" >nul 2>&1
)
mkdir "%LocalAppData%\Microsoft\Office\16.0\Wef" >nul 2>&1

:: 2. Registry for Trusted Catalogs
echo [2/4] Registering Trusted Catalog...
set "REG_KEY=HKCU\Software\Microsoft\Office\16.0\Word\Trusted Catalogs\{a8b2c3d4-e5f6-7890-abcd-ef1234567890}"
:: Gunakan path lokal langsung (lebih stabil di PC pelanggan)
reg add "%REG_KEY%" /v URL /t REG_SZ /d "%ADDIN_PATH%" /f >nul 2>&1
reg add "%REG_KEY%" /v Flags /t REG_DWORD /d 1 /f >nul 2>&1
reg add "%REG_KEY%" /v Id /t REG_DWORD /d 1 /f >nul 2>&1

:: 3. Registry for Trusted Locations (Keamanan Word)
echo [3/4] Adding to Trusted Locations...
set "TRUST_LOC=HKCU\Software\Microsoft\Office\16.0\Registration\Trusted Locations\SuperSkripsi"
reg add "%TRUST_LOC%" /v "Path" /t REG_SZ /d "%ADDIN_PATH%" /f >nul 2>&1
reg add "%TRUST_LOC%" /v "AllowSubfolders" /t REG_DWORD /d 1 /f >nul 2>&1

:: 4. Loopback Exemption (Sangat penting agar icon muncul di Windows 10/11)
echo [4/5] Enabling Localhost access (Loopback Exemption)...
:: Izin untuk Word
CheckNetIsolation.exe LoopbackExempt -a -n="microsoft.winword_8wekyb3d8bbwe" >nul 2>&1
:: Izin untuk Desktop App Web Viewer (Edge/IE)
CheckNetIsolation.exe LoopbackExempt -a -n="microsoft.microsoftedge_8wekyb3d8bbwe" >nul 2>&1
CheckNetIsolation.exe LoopbackExempt -a -n="Microsoft.Win32WebViewHost_cw5n1h2txyewy" >nul 2>&1

:: 5. Launching Word with Recent Document
echo [5/5] Membuka Dokumen Terakhir (Recent)...
set "RECENT_DOC="
for /f "delims=" %%i in ('dir "%USERPROFILE%\Documents\*.docx" /b /s /o-d /a-h 2^>nul') do (
    set "RECENT_DOC=%%i"
    goto :found_doc
)

:found_doc
if defined RECENT_DOC (
    echo Membuka: %RECENT_DOC%
    start "" winword "%RECENT_DOC%"
) else (
    echo Tidak ada dokumen recent di folder Documents, membuka Word kosong...
    start winword
)

echo.
echo ------------------------------------------
echo BERHASIL! Word sedang dibuka...
echo ------------------------------------------
echo LANGKAH TERAKHIR (Hanya sekali):
echo 1. Di Word, Klik menu "Insert" -> "My Add-ins"
echo 2. Pilih tab "Shared Folder" (Folder Bersama)
echo 3. Pilih "Super Skripsi Gandi" dan klik OK/Add.
echo.
echo Add-in akan muncul secara permanen di Tab "Home" bagian kanan.
echo.
timeout /t 10
exit
