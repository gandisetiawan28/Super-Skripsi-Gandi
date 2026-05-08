@echo off
title Super Skripsi Gandi - Fixed Installer
color 0e

echo ==========================================
echo    FIXING EXTENSION INSTALLATION
echo ==========================================
echo.

set EXT_PATH=%~dp0
set EXT_PATH=%EXT_PATH:~0,-1%

echo [1] Menghapus data registri lama (jika ada)...
set EXT_ID=jebpgaffkndckfbgfckfkkfclkgfckfk
reg delete "HKCU\Software\Google\Chrome\Extensions\%EXT_ID%" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Edge\Extensions\%EXT_ID%" /f >nul 2>&1

echo [2] Meluncurkan Browser dengan Ekstensi Terpasang...
echo Harap tunggu, browser akan terbuka otomatis...

:: Membuka Chrome dengan load-extension
start chrome --load-extension="%EXT_PATH%" "chrome://extensions"

:: Membuka Edge dengan load-extension
start msedge --load-extension="%EXT_PATH%" "edge://extensions"

echo.
echo ------------------------------------------
echo APAKAH SUDAH MUNCUL?
echo ------------------------------------------
echo 1. Lihat di daftar ekstensi browser yang baru terbuka.
echo 2. Jika ada peringatan "Developer mode extensions", klik "Keep" atau "X".
echo 3. Jika tetap tidak muncul, pastikan "Developer Mode" di pojok kanan atas browser dalam posisi ON (Aktif).
echo.
pause
