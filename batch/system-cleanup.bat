@echo off
setlocal enabledelayedexpansion

echo ================================
echo    SYSTEM CLEANUP UTILITY
echo ================================
echo.
echo WARNING: This will delete temporary files and clear caches.
echo.

set /p confirm="Are you sure you want to continue? (y/N): "
if /i not "!confirm!"=="y" (
    echo Cleanup cancelled.
    pause
    exit /b 0
)

echo.
echo Starting cleanup process...
echo.

set /a freed=0

rem Clean Windows Temp files
echo [1/6] Cleaning Windows Temp files...
for /d %%d in ("%temp%\*") do (
    rd /s /q "%%d" 2>nul
)
del /q /f /s "%temp%\*.*" 2>nul
echo ✓ Windows Temp files cleaned

rem Clean Prefetch
echo [2/6] Cleaning Prefetch files...
del /q /f /s "C:\Windows\Prefetch\*.*" 2>nul
echo ✓ Prefetch cleaned

rem Clean Recent files
echo [3/6] Cleaning Recent files...
del /q /f /s "%appdata%\Microsoft\Windows\Recent\*.*" 2>nul
echo ✓ Recent files cleaned

rem Clean Recycle Bin
echo [4/6] Emptying Recycle Bin...
@powershell -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue" 2>nul
echo ✓ Recycle Bin emptied

rem Clean DNS cache
echo [5/6] Clearing DNS cache...
ipconfig /flushdns >nul 2>&1
echo ✓ DNS cache cleared

rem Clean browser caches (Chrome, Firefox, Edge)
echo [6/6] Cleaning browser caches...
@powershell -Command "Remove-Item -Path '$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache\*' -Recurse -Force -ErrorAction SilentlyContinue" 2>nul
@powershell -Command "Remove-Item -Path '$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\*' -Recurse -Force -ErrorAction SilentlyContinue" 2>nul
@powershell -Command "Remove-Item -Path '$env:APPDATA\Mozilla\Firefox\Profiles\*\cache2\*' -Recurse -Force -ErrorAction SilentlyContinue" 2>nul
echo ✓ Browser caches cleaned

echo.
echo ================================
echo Cleanup completed successfully!
echo ================================
echo.
echo Restart your computer for best results.
pause
