@echo off
REM Doble clic aqui para probar el barrendero: quien se lleva del cubo
REM los archivos que se quedaron sin ficha.
REM
REM No toca ningun cubo de verdad ni borra nada: el cubo es de mentira y
REM guarda lo que se le pidio borrar. Lo que se prueba es lo unico que no
REM se ve solo: que no se marque como borrado lo que el cubo no acepto.
REM Hace falta Node instalado.
node "%~dp0avisos\prueba-barrendero.js"
echo.
pause
