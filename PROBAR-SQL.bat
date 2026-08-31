@echo off
REM Doble clic aqui para ejecutar los once archivos SQL en un Postgres de
REM esta maquina y comprobar que los triggers y las politicas hacen lo que
REM dicen.
REM
REM Crea una base nueva y la borra al acabar. No toca ninguna existente.
REM Hace falta PostgreSQL instalado y pruebas\postgres.local.json con la
REM clave (el propio script te dice como si falta).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0pruebas\postgres.ps1"
echo.
pause
