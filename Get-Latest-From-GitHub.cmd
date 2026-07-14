@echo off
setlocal
cd /d "%~dp0"
echo ============================================
echo   Getting the latest Aegis from GitHub...
echo ============================================
echo.
git pull origin main
echo.
echo Done. You now have the newest version. Safe to start working.
echo (If it mentions a conflict, stop and ask for help before continuing.)
echo.
pause
endlocal
