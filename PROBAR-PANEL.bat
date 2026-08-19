@echo off
REM Doble clic aqui para probar el panel.
REM No modifica nada: trabaja sobre una copia temporal.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0pruebas\panel.ps1"
echo.
pause
