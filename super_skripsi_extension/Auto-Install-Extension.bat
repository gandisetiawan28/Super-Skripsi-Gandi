@echo off
title Super Skripsi Gandi - Auto-Installer
color 0b

echo ==========================================
echo    AI EXTENSION AUTO-INSTALL HELPER
echo ==========================================
echo.
echo Lokasi Ekstensi: %~dp0
echo.

set EXT_PATH=%~dp0
:: Remove trailing backslash
set EXT_PATH=%EXT_PATH:~0,-1%

echo [1] Membuka Chrome Extension Manager...
start chrome --load-extension="%EXT_PATH%" "chrome://extensions"

echo [2] Membuka Edge Extension Manager...
start msedge --load-extension="%EXT_PATH%" "edge://extensions"

echo.
echo ------------------------------------------
echo PETUNJUK MANUAL (Wajib Sekali Saja):
echo ------------------------------------------
echo 1. Di browser yang terbuka, pastikan "Developer Mode" (Mode Pengembang) AKTIF.
echo 2. Jika ekstensi belum muncul, klik "Load unpacked" (Muat yang belum dikemas).
echo 3. Tempel path berikut jika diminta:
echo    %EXT_PATH%
echo.
echo [OK] Selesai! Ekstensi sekarang terhubung ke API Bridge.
pause
