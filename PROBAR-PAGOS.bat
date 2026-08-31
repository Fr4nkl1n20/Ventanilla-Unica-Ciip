@echo off
REM Doble clic aqui para probar el cobrador contra una pasarela de pago de
REM mentira. Sobre todo prueba lo que pasa cuando NO se sabe si el cargo
REM entro: con un banco, confundirse cuesta el dinero de una persona.
REM
REM No toca ninguna red ni ningun banco. Hace falta Node instalado.
node "%~dp0pagos\prueba-pagos.js"
echo.
pause
