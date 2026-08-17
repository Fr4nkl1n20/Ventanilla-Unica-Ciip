@echo off
REM Doble clic aqui para que OTROS PC de la oficina puedan ver el proyecto.
REM La ventana negra muestra la direccion que hay que pasarle al companero
REM (algo como http://172.21.20.49:8080/acceso.html).
REM
REM Mientras esta ventana este abierta, cualquiera de la red puede entrar.
REM Para cortar el acceso: cierra la ventana.
REM
REM Si solo quieres verlo tu, usa ABRIR-LOCAL.bat en su lugar.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0servidor.ps1" -Red
