@echo off
REM Doble clic aqui para probar acceso.html.
REM No modifica nada: trabaja sobre una copia temporal.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0pruebas\ejecutar.ps1"
echo.
pause
