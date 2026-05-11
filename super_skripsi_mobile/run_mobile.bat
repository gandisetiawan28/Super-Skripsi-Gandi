@echo off
setlocal
title Super Skripsi Mobile - Fix & Run

echo ==========================================
echo    SUPER SKRIPSI MOBILE - AUTO REPAIR
echo ==========================================

:: Force using Android Studio's Java 21 (64-bit)
set "JAVA_HOME=C:\Program Files\Android\Android Studio\jbr"
set "PATH=%JAVA_HOME%\bin;%PATH%"

echo [0/4] Using Java from: %JAVA_HOME%
java -version

:: Step 1: Kill all Java processes to release Gradle locks
echo [1/4] Killing Java processes (Gradle locks)...
taskkill /F /IM java.exe /T >nul 2>&1

:: Step 2: Clean project
echo [2/4] Cleaning Flutter project...
call flutter clean

:: Step 3: Get dependencies
echo [3/4] Getting dependencies...
call flutter pub get

:: Step 4: Run Signing Report (To get SHA-1)
echo [4/4] Getting SHA-1 Fingerprint...
echo ------------------------------------------
call .\android\gradlew.bat -p android signingReport

echo.
echo ==========================================
echo SILAKAN CARI 'SHA1' DI ATAS (Variant: debug)
echo ==========================================
echo.

pause
