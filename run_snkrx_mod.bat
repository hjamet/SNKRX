@echo off
cd /d "%~dp0"
echo 1607580 > steam_appid.txt
if exist "bin\love\love.exe" (
    start "" "bin\love\love.exe" .
) else (
    start "" love .
)
