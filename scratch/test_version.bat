@echo off
setlocal enabledelayedexpansion
cd super_skripsi_manager
for /f "tokens=2 delims=: " %%a in ('findstr /C:"version:" pubspec.yaml') do (
    set VERSION=%%a
)
echo VERSION is: "!VERSION!"
cd ..
echo VERSION after cd .. is: "!VERSION!"
