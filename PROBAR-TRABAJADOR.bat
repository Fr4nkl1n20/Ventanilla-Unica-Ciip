@echo off
REM Doble clic aqui para probar el trabajador: quien vacia la cola y
REM ejecuta lo que el conector decide.
REM
REM No toca ninguna red ni ningun organismo: levanta el SENIAT de mentira
REM en esta maquina y usa un deposito de mentira en vez de la base.
REM Hace falta Node instalado.
node "%~dp0interoperabilidad\prueba-trabajador.js"
REM El codigo de salida se guarda AQUI, antes del echo: `echo.` pisa el
REM ERRORLEVEL y sin esto el .bat contesta 0 aunque la tanda se caiga.
set ERR=%ERRORLEVEL%
echo.
REM Callado cuando lo llama PROBAR-TODO: si no, cada puerta se para
REM a esperar una tecla y la cadena no avanza sola.
if not "%CIIP_SIN_PAUSA%"=="1" pause
exit /b %ERR%
