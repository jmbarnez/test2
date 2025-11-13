@echo off
setlocal

set "ROOT=%~dp0"
set "GAME_NAME=Novus"
set "DIST_DIR=%ROOT%dist"
set "LOVE_RUNTIME_DIR=%ROOT%tools\love-windows"
pushd "%ROOT%" >nul

if exist "%DIST_DIR%" rmdir /S /Q "%DIST_DIR%"
mkdir "%DIST_DIR%"

set "LOVE_ARCHIVE=%DIST_DIR%\%GAME_NAME%.love"
set "LOVE_ARCHIVE_ZIP=%DIST_DIR%\%GAME_NAME%.zip"

powershell -NoLogo -NoProfile -Command ^
    "Set-StrictMode -Version Latest; $ErrorActionPreference='Stop'; Compress-Archive -LiteralPath @('assets','libs','src','main.lua','conf.lua') -DestinationPath '%LOVE_ARCHIVE_ZIP%' -Force" || goto FailArchive

if exist "%LOVE_ARCHIVE%" del "%LOVE_ARCHIVE%"
move /Y "%LOVE_ARCHIVE_ZIP%" "%LOVE_ARCHIVE%" >nul || goto FailArchiveRename

call :BuildWindows
if errorlevel 1 goto FailWindows

popd >nul

echo.
echo [SUCCESS] Created game archive at "%DIST_DIR%\%GAME_NAME%.love".
echo          Windows executable build attempted; see messages above.
echo.
exit /b 0

:FailArchive
echo [ERROR] Failed to create game archive (.love).
popd >nul
pause
exit /b 1

:FailArchiveRename
echo [ERROR] Failed to finalize game archive (.love).
popd >nul
pause
exit /b 1

:FailWindows
echo [ERROR] Failed to build Windows executable.
popd >nul
pause
exit /b 1

:BuildWindows
rem Build fused Windows .exe if a LÖve runtime is available locally.
set "LOVE_RUNTIME_EXE=%LOVE_RUNTIME_DIR%\love.exe"

if not exist "%LOVE_RUNTIME_EXE%" (
    echo [WARN] Windows LÖve runtime not found at "%LOVE_RUNTIME_EXE%".
    echo        To build a Windows EXE, download the Windows .zip from https://love2d.org/,
    echo        extract it to: %LOVE_RUNTIME_DIR%
    exit /b 0
)

set "WINDOWS_DIST_DIR=%DIST_DIR%\windows"
if exist "%WINDOWS_DIST_DIR%" rmdir /S /Q "%WINDOWS_DIST_DIR%"
mkdir "%WINDOWS_DIST_DIR%" || (
    echo [ERROR] Failed to create Windows dist directory.
    exit /b 1
)

xcopy /E /I /Y "%LOVE_RUNTIME_DIR%\*" "%WINDOWS_DIST_DIR%\" >nul || (
    echo [ERROR] Failed to copy LÖve runtime files.
    exit /b 1
)

copy /b "%WINDOWS_DIST_DIR%\love.exe"+"%LOVE_ARCHIVE%" "%WINDOWS_DIST_DIR%\%GAME_NAME%.exe" >nul || (
    echo [ERROR] Failed to fuse LÖve runtime with game archive.
    exit /b 1
)

set "RCEDIT_EXE=%ROOT%tools\rcedit-x64.exe"
set "GAME_ICON=%ROOT%assets\icons\novus.ico"

if exist "%RCEDIT_EXE%" if exist "%GAME_ICON%" (
    "%RCEDIT_EXE%" "%WINDOWS_DIST_DIR%\%GAME_NAME%.exe" --set-icon "%GAME_ICON%" || (
        echo [WARN] rcedit failed to set custom icon; using default icon.
    )
) else (
    echo [INFO] Custom icon not applied. Ensure both "%RCEDIT_EXE%" and "%GAME_ICON%" exist to set a custom EXE icon.
)

del "%WINDOWS_DIST_DIR%\love.exe"

echo [INFO] Windows executable built at "%WINDOWS_DIST_DIR%\%GAME_NAME%.exe".
exit /b 0
