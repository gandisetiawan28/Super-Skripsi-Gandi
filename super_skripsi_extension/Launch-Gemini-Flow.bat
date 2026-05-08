@echo off
:: Gemini Flow All-in-One Launcher
:: This script starts the backend and the console app.

title Gemini Flow Launcher
color 0b

echo ==========================================
echo       GEMINI FLOW SYSTEM LAUNCHER
echo ==========================================
echo.

:: 1. Start Backend
echo [1/2] Starting API Bridge (Backend)...
cd /d "%~dp0api-bridge"
start /b node server.js
echo API Bridge is running in background.
echo.

:: 2. Launch Console
echo [2/2] Launching Gemini Flow Console...
cd /d "%~dp0console\build\windows\x64\runner\Release"
start console.exe
echo Console launched.
echo.

echo ==========================================
echo ALL SYSTEMS GO!
echo Keep this window open if you want to see
echo backend logs, or minimize it.
echo ==========================================
echo.
echo IMPORTANT: If you get a "Connection Error", 
echo run "Apply-Loopback-Fix.bat" as Administrator.
echo.

:: Stay open for logs
pause
