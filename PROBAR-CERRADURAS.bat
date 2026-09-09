@echo off
REM Doble clic aqui para comprobar que las politicas RLS de la base aguantan.
REM
REM OJO: esto ENTRA DE VERDAD en Supabase, en el proyecto de PRUEBAS, con dos
REM cuentas, y trata de hacer lo que no debe. Crea y borra algunas filas. Se
REM niega a correr contra el proyecto real.
REM
REM Hace falta Node y el archivo pruebas\cuentas.local.json con las dos
REM cuentas (copia cuentas.local.ejemplo.json).
node "%~dp0pruebas\rls.js"
REM El codigo de salida se guarda AQUI, antes del echo: `echo.` pisa el
REM ERRORLEVEL y sin esto el .bat contesta 0 aunque la tanda se caiga.
set ERR=%ERRORLEVEL%
echo.
REM Callado cuando lo llama PROBAR-TODO: si no, cada puerta se para
REM a esperar una tecla y la cadena no avanza sola.
if not "%CIIP_SIN_PAUSA%"=="1" pause
exit /b %ERR%
