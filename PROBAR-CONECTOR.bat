@echo off
REM Doble clic aqui para probar el conector del RIF contra el SENIAT de mentira.
REM No toca ninguna red ni ningun organismo: todo ocurre en esta maquina.
REM Hace falta Node instalado.
node "%~dp0interoperabilidad\prueba.js"
REM El codigo de salida se guarda AQUI, antes del echo: `echo.` pisa el
REM ERRORLEVEL y sin esto el .bat contesta 0 aunque la tanda se caiga.
set ERR=%ERRORLEVEL%
echo.
REM Callado cuando lo llama PROBAR-TODO: si no, cada puerta se para
REM a esperar una tecla y la cadena no avanza sola.
if not "%CIIP_SIN_PAUSA%"=="1" pause
exit /b %ERR%
