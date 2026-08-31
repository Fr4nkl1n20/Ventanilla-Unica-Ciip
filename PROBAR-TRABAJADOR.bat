@echo off
REM Doble clic aqui para probar el trabajador: quien vacia la cola y
REM ejecuta lo que el conector decide.
REM
REM No toca ninguna red ni ningun organismo: levanta el SENIAT de mentira
REM en esta maquina y usa un deposito de mentira en vez de la base.
REM Hace falta Node instalado.
node "%~dp0interoperabilidad\prueba-trabajador.js"
echo.
pause
