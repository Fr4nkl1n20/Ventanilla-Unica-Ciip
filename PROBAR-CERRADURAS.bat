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
echo.
pause
