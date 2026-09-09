@echo off
REM Doble clic aqui para probar acceso.html.
REM No modifica nada: trabaja sobre una copia temporal.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0pruebas\ejecutar.ps1"
REM El codigo de salida se guarda AQUI, antes del echo: `echo.` pisa el
REM ERRORLEVEL y sin esto el .bat contesta 0 aunque la tanda se caiga.
set ERR=%ERRORLEVEL%
echo.
REM Callado cuando lo llama PROBAR-TODO: si no, cada puerta se para
REM a esperar una tecla y la cadena no avanza sola.
if not "%CIIP_SIN_PAUSA%"=="1" pause
exit /b %ERR%
