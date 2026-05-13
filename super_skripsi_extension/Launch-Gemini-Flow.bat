@echo off
title Gemini Flow Launcher
color 0b

echo ==========================================
echo    GEMINI FLOW SYSTEM LAUNCHER
echo ==========================================
echo.

:: 1. Start Backend (API Bridge)
echo [1/2] Starting API Bridge (Backend)...
cd /d "%~dp0api-bridge"
start /b node server.js
echo API Bridge is running in background.
echo.

:: 2. Launch Manager (Console)
echo [2/2] Launching Manager...

:: CARA 1: Cek folder instalasi (Production)
if exist "%~dp0..\super_skripsi_manager.exe" (
    cd /d "%~dp0.."
    start "" "super_skripsi_manager.exe"
    echo Manager launched (Production Mode).
) else if exist "%~dp0..\super_skripsi_manager\build\windows\x64\runner\Release\super_skripsi_manager.exe" (
    :: CARA 2: Jika dijalankan di folder project (Mode Developer)
    cd /d "%~dp0..\super_skripsi_manager\build\windows\x64\runner\Release"
    start "" "super_skripsi_manager.exe"
    echo Manager launched (Developer Mode).
) else (
    echo [ERROR] super_skripsi_manager.exe tidak ditemukan!
    echo Path saat ini: %cd%
    echo Pastikan Anda tidak memindahkan file .bat ini dari folder aslinya.
)

echo.
echo ==========================================
echo ALL SYSTEMS GO!
echo ==========================================
echo.
echo PENTING: Jika aplikasi mengalami "Connection Error" atau tidak bisa
echo memuat data, jalankan "Apply-Loopback-Fix.bat" sebagai Administrator.
echo.
pause