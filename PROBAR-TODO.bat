@echo off
REM Doble clic aqui para correr TODAS las tandas de una vez y ver un cuadro
REM al final: cuantas fueron bien, cuales fallaron y cuales NO SE PUDIERON
REM probar y por que.
REM
REM Esa tercera columna es la razon de existir de este archivo. Sin ella,
REM una tanda que no corre por falta de una clave local se cuenta como que
REM fue bien, y eso ya paso: el arnes de acceso.html llevaba dias sin
REM ejecutarse y su .bat contestaba que si.
REM
REM Sale con 0 solo si todas las que se pudieron correr fueron bien.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0pruebas\todo.ps1"
REM El codigo de salida se guarda AQUI, antes del echo: `echo.` pisa el
REM ERRORLEVEL y sin esto el .bat contesta 0 aunque la tanda se caiga.
set ERR=%ERRORLEVEL%
echo.
if not "%CIIP_SIN_PAUSA%"=="1" pause
exit /b %ERR%
