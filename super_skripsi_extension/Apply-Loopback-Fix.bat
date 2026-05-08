@echo off
title Gemini Flow Loopback Fixer
color 0c

echo ==========================================
echo    GEMINI FLOW LOOPBACK FIX (ADMIN)
echo ==========================================
echo.
echo This script will allow the installed MSIX app 
echo to access "localhost" (the backend).
echo.

:: Check for admin rights
net session >nul 2>&1
if %errorLevel% == 0 (
    echo [OK] Running as Administrator.
) else (
    echo [ERROR] PLEASE RUN THIS FILE AS ADMINISTRATOR!
    echo Right-click -> Run as Administrator.
    pause
    exit /b
)

echo Applying fix for: com.geminiflow.console
CheckNetIsolation.exe LoopbackExempt -a -n="com.geminiflow.console_4t92yyp97j8vt"

echo.
echo If the command above failed, we will try to find your package name...
echo Listing all loopback exempt apps:
CheckNetIsolation.exe LoopbackExempt -s

echo.
echo Fix applied! You can now close this window and 
echo use "Launch-Gemini-Flow.bat".
pause
