@echo off
REM Doble clic aqui para probar la ventanilla A MANO.
REM Deja las paginas en la carpeta pruebas-a-mano y abre el indice: el
REM panel de verdad contra una base de mentira, sin clave y sin tocar
REM nada de la base real.
REM PROBAR-PANEL.bat mide; esto se mira y se pulsa.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0pruebas\a-mano.ps1"
set ERR=%ERRORLEVEL%
echo.
if not "%CIIP_SIN_PAUSA%"=="1" pause
exit /b %ERR%
