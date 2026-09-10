@echo off
REM Doble clic aqui para probar el intermediario del asistente: api\asistente.js,
REM lo unico del proyecto que corre en un servidor y no en el navegador.
REM
REM No toca la red, no gasta un centimo y no usa ninguna clave de verdad:
REM se le pone delante un Anthropic de mentira y un Supabase de mentira.
REM
REM Hace falta Node y haber corrido `npm install` una vez.
node "%~dp0pruebas\asistente.js"
REM El codigo de salida se guarda AQUI, antes del echo: `echo.` pisa el
REM ERRORLEVEL y sin esto el .bat contesta 0 aunque la tanda se caiga.
set ERR=%ERRORLEVEL%
echo.
REM Callado cuando lo llama PROBAR-TODO: si no, cada puerta se para
REM a esperar una tecla y la cadena no avanza sola.
if not "%CIIP_SIN_PAUSA%"=="1" pause
exit /b %ERR%
