@echo off
REM  Abre las maquetas del panel.
REM  Son paginas sueltas: no piden base de datos ni sesion, se ven con
REM  doble clic. No son la aplicacion; llevan su cartel arriba diciendolo.
REM  Las dos primeras son de la portada; las otras dos, de la solicitud.
start "" "%~dp0maquetas\portada-que-toca-ahora.html"
start "" "%~dp0maquetas\portada-sin-repetir.html"
start "" "%~dp0maquetas\adelantar-con-el-pdf.html"
start "" "%~dp0maquetas\ia-en-el-formulario.html"
