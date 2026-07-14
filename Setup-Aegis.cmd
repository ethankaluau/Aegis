@echo off
setlocal
REM Run this ONCE on a new computer to put the "Aegis" shortcut on your Desktop.
set "APPDIR=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ws=New-Object -ComObject WScript.Shell; $d=[Environment]::GetFolderPath('Desktop'); $l=$ws.CreateShortcut((Join-Path $d 'Aegis.lnk')); $l.TargetPath=(Join-Path $env:APPDIR 'Open-Aegis.cmd'); $l.WorkingDirectory=$env:APPDIR; $c='C:\Program Files\Google\Chrome\Application\chrome.exe'; if(Test-Path $c){ $l.IconLocation=$c+',0' }; $l.WindowStyle=7; $l.Description='Open the Aegis investing app'; $l.Save(); Write-Host 'Aegis shortcut created on your Desktop.'"
echo.
echo Done! Look for the "Aegis" icon on your Desktop and double-click it.
pause
endlocal
