@echo off
REM  Doble clic aqui para levantar el lector de documentos en tu maquina.
REM  Para parar: cierra esta ventana.
REM
REM  Sin parentesis en ningun sitio, y con etiquetas en vez de bloques
REM  if(...): un ")" dentro de un bloque -aunque este en un echo o en el
REM  texto de un set /p- lo cierra antes de tiempo y la ventana se cierra
REM  sola sin decir nada. Paso una vez; que no vuelva a pasar.
setlocal
title Lector de documentos - CIIP

where node >nul 2>nul
if errorlevel 1 goto sinnode
if not "%LECTOR_CLAVE%"=="" goto arranca

echo.
echo   EL LECTOR DE DOCUMENTOS
echo   -----------------------
echo   Pega aqui tu clave de console.anthropic.com y pulsa Intro.
echo   Clic derecho pega. El texto no se ve mientras escribes: es normal.
echo.
echo   Si la dejas en blanco arranca SIN LEER NADA, con datos inventados,
echo   para probar la tuberia mientras llega la clave.
echo.
set /p LECTOR_CLAVE=Clave: 
if "%LECTOR_CLAVE%"=="" set LECTOR_DE_MENTIRA=1

:arranca
node "%~dp0pruebas\lector-local.js"
echo.
echo   El lector se ha parado.
pause
exit /b

:sinnode
echo.
echo   NO ENCUENTRO NODE
echo   -----------------
echo   Este lector necesita Node.js, que se instala desde nodejs.org
echo   Despues hay que cerrar esta ventana y volver a abrirla.
echo.
pause
exit /b
