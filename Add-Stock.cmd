@echo off
setlocal
cd /d "%~dp0"
set /p TICKER="Enter a stock ticker to add (e.g. TSLA), then press Enter: "
if "%TICKER%"=="" (echo No ticker entered. & pause & exit /b)
echo %TICKER%>>"%~dp0watchlist.txt"
echo Added %TICKER% to your watchlist. Refreshing...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0refresh-stocks.ps1"
echo.
echo Done. Open Steady to see it.
pause
endlocal
