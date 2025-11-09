@echo off
setlocal enabledelayedexpansion

set "ROOT=%~dp0"
set "GAME_NAME=ProceduralSpace"
set "LOG_DIR=%ROOT%logs"

echo Setting up directories...
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

REM Generate timestamp for log file
for /f "tokens=2 delims==" %%i in ('wmic os get localdatetime /value') do set datetime=%%i
set "LOG_FILE=%LOG_DIR%\debug_output_%datetime:~0,8%_%datetime:~8,6%.txt"

echo ROOT: %ROOT%
echo LOG_FILE: %LOG_FILE%
echo.

REM Check for LÖVE
echo Checking for LÖVE...
where love >nul 2>&1
if !ERRORLEVEL! equ 0 (
    echo Found love in PATH
    set "LOVE_EXE=love"
) else (
    echo love not in PATH, checking common locations...
    if exist "C:\Program Files\LOVE\love.exe" (
        echo Found love.exe in C:\Program Files\LOVE\
        set "LOVE_EXE=C:\Program Files\LOVE\love.exe"
    ) else (
        echo ERROR: Could not find LÖVE installation
        echo Please install LÖVE from https://love2d.org/
        echo.
        pause
        exit /b 1
    )
)

echo Using LÖVE executable: !LOVE_EXE!
echo Starting game in debug mode...
echo Log will be saved to: %LOG_FILE%
echo.

echo [%date% %time%] Starting %GAME_NAME% debug session > "%LOG_FILE%"
echo ======================================== >> "%LOG_FILE%"

echo Running: "!LOVE_EXE!" . --debug
"!LOVE_EXE!" . --debug >> "%LOG_FILE%" 2>&1

set EXIT_CODE=!ERRORLEVEL!
echo Game exited with code: !EXIT_CODE!

if !EXIT_CODE! neq 0 (
    echo.
    echo [ERROR] Game crashed with error code !EXIT_CODE!
    echo [ERROR] Check log file for details: %LOG_FILE%
    echo.
    echo Last few lines of log:
    echo ===============================
    powershell -command "Get-Content '%LOG_FILE%' | Select-Object -Last 20"
    echo ===============================
) else (
    echo.
    echo [INFO] Game exited normally
)

echo.
echo [%date% %time%] %GAME_NAME% session ended >> "%LOG_FILE%"
echo ======================================== >> "%LOG_FILE%"
echo [INFO] Debug session ended. Log saved to: %LOG_FILE%
echo.

pause
