@echo off
REM Doble clic aqui para probar el barrendero: quien se lleva del cubo
REM los archivos que se quedaron sin ficha.
REM
REM No toca ningun cubo de verdad ni borra nada: el cubo es de mentira y
REM guarda lo que se le pidio borrar. Lo que se prueba es lo unico que no
REM se ve solo: que no se marque como borrado lo que el cubo no acepto.
REM Hace falta Node instalado.
node "%~dp0avisos\prueba-barrendero.js"
REM El codigo de salida se guarda AQUI, antes del echo: `echo.` pisa el
REM ERRORLEVEL y sin esto el .bat contesta 0 aunque la tanda se caiga.
set ERR=%ERRORLEVEL%
echo.
REM Callado cuando lo llama PROBAR-TODO: si no, cada puerta se para
REM a esperar una tecla y la cadena no avanza sola.
if not "%CIIP_SIN_PAUSA%"=="1" pause
exit /b %ERR%
