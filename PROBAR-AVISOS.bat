@echo off
REM Doble clic aqui para probar los avisos: que cada quien los reciba en
REM su idioma y que ninguno se pierda cuando el correo no sale.
REM
REM No levanta ningun servidor de correo ni manda nada a nadie: el
REM transporte es de mentira y guarda lo que se le dio.
REM Hace falta Node instalado.
node "%~dp0avisos\prueba-avisos.js"
REM El codigo de salida se guarda AQUI, antes del echo: `echo.` pisa el
REM ERRORLEVEL y sin esto el .bat contesta 0 aunque la tanda se caiga.
set ERR=%ERRORLEVEL%
echo.
REM Callado cuando lo llama PROBAR-TODO: si no, cada puerta se para
REM a esperar una tecla y la cadena no avanza sola.
if not "%CIIP_SIN_PAUSA%"=="1" pause
exit /b %ERR%
