@echo off
setlocal enabledelayedexpansion

echo ================================
echo      FILE ORGANIZER SCRIPT
echo ================================
echo.

if "%~1"=="" (
    set "target_dir=%cd%"
    echo No directory specified. Using current directory.
) else (
    set "target_dir=%~1"
)

echo Target directory: %target_dir%
echo.

if not exist "%target_dir%" (
    echo Error: Directory does not exist!
    pause
    exit /b 1
)

set /a moved=0
set /a skipped=0

for %%f in ("%target_dir%\*.*") do (
    if exist "%%f" (
        if not "%%~xf"=="" (
            set "ext=%%~xf"
            set "ext=!ext:~1!"
            
            rem Skip batch files and directories
            if /i not "!ext!"=="bat" (
                if not "%%~f"=="%~f0" (
                    
                    rem Create category folders for common file types
                    if /i "!ext!"=="jpg" set "category=images"
                    if /i "!ext!"=="jpeg" set "category=images"
                    if /i "!ext!"=="png" set "category=images"
                    if /i "!ext!"=="gif" set "category=images"
                    if /i "!ext!"=="bmp" set "category=images"
                    
                    if /i "!ext!"=="pdf" set "category=documents"
                    if /i "!ext!"=="doc" set "category=documents"
                    if /i "!ext!"=="docx" set "category=documents"
                    if /i "!ext!"=="txt" set "category=documents"
                    
                    if /i "!ext!"=="mp4" set "category=videos"
                    if /i "!ext!"=="avi" set "category=videos"
                    if /i "!ext!"=="mkv" set "category=videos"
                    if /i "!ext!"=="mov" set "category=videos"
                    
                    if /i "!ext!"=="mp3" set "category=music"
                    if /i "!ext!"=="wav" set "category=music"
                    if /i "!ext!"=="flac" set "category=music"
                    
                    if /i "!ext!"=="zip" set "category=archives"
                    if /i "!ext!"=="rar" set "category=archives"
                    if /i "!ext!"=="7z" set "category=archives"
                    
                    if not defined category set "category=!ext!"
                    
                    if not exist "%target_dir%\!category!" (
                        mkdir "%target_dir%\!category!"
                        echo Created folder: !category!
                    )
                    
                    move "%%f" "%target_dir%\!category!\" >nul 2>&1
                    if !errorlevel! equ 0 (
                        set /a moved+=1
                        echo Moved: %%~nxf to !category!\
                    ) else (
                        set /a skipped+=1
                        echo Skipped: %%~nxf (may be in use)
                    )
                    
                    set "category="
                )
            )
        )
    )
)

echo.
echo ================================
echo Organization Complete!
echo Files moved: !moved!
echo Files skipped: !skipped!
echo ================================
echo.
pause
