@echo off
setlocal
cd /d "%~dp0"
echo ============================================
echo   Backing up Aegis to GitHub...
echo ============================================
echo.
git add -A
git commit -m "Update %date% %time%"
git push -u origin main
echo.
echo Done. (The very first time, a browser may pop up asking you
echo to sign in to GitHub - that is normal and only happens once.)
echo.
pause
endlocal
