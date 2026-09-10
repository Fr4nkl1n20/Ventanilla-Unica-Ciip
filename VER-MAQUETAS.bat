@echo off
REM  Abre las maquetas de la portada del panel.
REM  Son paginas sueltas: no piden base de datos ni sesion, se ven con
REM  doble clic. No son la aplicacion; llevan su cartel arriba diciendolo.
start "" "%~dp0maquetas\portada-que-toca-ahora.html"
start "" "%~dp0maquetas\portada-sin-repetir.html"
