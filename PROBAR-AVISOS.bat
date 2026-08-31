@echo off
REM Doble clic aqui para probar los avisos: que cada quien los reciba en
REM su idioma y que ninguno se pierda cuando el correo no sale.
REM
REM No levanta ningun servidor de correo ni manda nada a nadie: el
REM transporte es de mentira y guarda lo que se le dio.
REM Hace falta Node instalado.
node "%~dp0avisos\prueba-avisos.js"
echo.
pause
