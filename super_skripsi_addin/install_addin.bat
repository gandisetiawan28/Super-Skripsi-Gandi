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

:: 4. Launching Word
echo [4/4] Launching Microsoft Word...
:: Menggunakan start winword tanpa /webextension untuk menghindari error XML di beberapa versi Word
start winword

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
