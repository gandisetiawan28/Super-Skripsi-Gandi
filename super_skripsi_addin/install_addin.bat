@echo off
title Super Skripsi Gandi - Word Add-in Installer
color 0b

echo ==========================================
echo   REGISTERING WORD ADD-IN
echo ==========================================
echo.

set ADDIN_PATH=%~dp0
:: Remove trailing backslash if present
if "%ADDIN_PATH:~-1%"=="\" set ADDIN_PATH=%ADDIN_PATH:~0,-1%

echo Target Path: %ADDIN_PATH%
echo.

:: Registry keys for Office Trusted Catalogs
set REG_KEY="HKCU\Software\Microsoft\Office\16.0\Word\Trusted Catalogs\{a8b2c3d4-e5f6-7890-abcd-ef1234567890}"

echo [1/2] Creating Registry Key...
reg add %REG_KEY% /v URL /t REG_SZ /d "%ADDIN_PATH%" /f >nul 2>&1

echo [2/2] Setting Flags...
reg add %REG_KEY% /v Flags /t REG_DWORD /d 1 /f >nul 2>&1
reg add %REG_KEY% /v Id /t REG_DWORD /d 1 /f >nul 2>&1

echo.
echo ------------------------------------------
echo BERHASIL! Add-in telah didaftarkan.
echo ------------------------------------------
echo 1. Buka/Restart Microsoft Word.
echo 2. Masuk ke menu Insert - My Add-ins.
echo 3. Pilih tab "Shared Folder".
echo 4. Pilih "Super Skripsi Gandi" dan klik Add.
echo.
pause
