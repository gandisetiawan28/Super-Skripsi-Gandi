@echo off
setlocal enabledelayedexpansion
:: Simulate running from a subdirectory
cd /d "d:\SUPER SKRIPSI GANDI\super_skripsi_addin"
echo Current Dir: %cd%

:: The fix: Change to script's directory
cd /d "d:\SUPER SKRIPSI GANDI"
echo New Dir: %cd%

echo [1/5] Membaca Versi dari pubspec.yaml...
cd super_skripsi_manager
for /f "tokens=2 delims=: " %%a in ('findstr /C:"version:" pubspec.yaml') do (
    set VERSION=%%a
)
:: Bersihkan build number (misal 1.1.29+1 jadi 1.1.29)
for /f "tokens=1 delims=+" %%v in ("!VERSION!") do set VERSION=%%v

echo [OK] Versi terdeteksi: "!VERSION!"
