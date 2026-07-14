@echo off
setlocal
REM Aegis - refresh today's numbers, then open as a standalone desktop app window.
cd /d "%~dp0"

echo Getting today's market numbers...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0refresh-stocks.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0refresh-signals.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0refresh-data.ps1"
echo.
echo Opening Aegis...

set "CHROME=C:\Program Files\Google\Chrome\Application\chrome.exe"
set "APPDIR=%LocalAppData%\AegisApp"
if exist "%CHROME%" (
  start "" "%CHROME%" --app="file:///%~dp0index.html" --user-data-dir="%APPDIR%" --window-size=1000,900
) else (
  start "" "%~dp0index.html"
)

endlocal
