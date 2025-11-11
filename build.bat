@echo off
setlocal

set "ROOT=%~dp0"
set "GAME_NAME=Novus"
set "DIST_DIR=%ROOT%dist"
pushd "%ROOT%" >nul

if exist "%DIST_DIR%" rmdir /S /Q "%DIST_DIR%"
mkdir "%DIST_DIR%"

set "LOVE_ARCHIVE=%DIST_DIR%\%GAME_NAME%.love"
set "LOVE_ARCHIVE_ZIP=%DIST_DIR%\%GAME_NAME%.zip"

powershell -NoLogo -NoProfile -Command ^
    "Set-StrictMode -Version Latest; $ErrorActionPreference='Stop'; Compress-Archive -LiteralPath @('assets','libs','src','main.lua','conf.lua') -DestinationPath '%LOVE_ARCHIVE_ZIP%' -Force" || goto FailArchive

if exist "%LOVE_ARCHIVE%" del "%LOVE_ARCHIVE%"
move /Y "%LOVE_ARCHIVE_ZIP%" "%LOVE_ARCHIVE%" >nul || goto FailArchiveRename

popd >nul

echo.
echo [SUCCESS] Created standalone archive at "%DIST_DIR%\%GAME_NAME%.love"
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
