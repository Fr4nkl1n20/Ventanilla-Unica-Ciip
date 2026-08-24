# ══════════════════════════════════════════════════════════════════════
#  UNA COPIA DEL PANEL PARA MIRAR
#  Se lanza con:  powershell -File pruebas\vista.ps1
# ══════════════════════════════════════════════════════════════════════
#  Deja un archivo 'vista-cola.html' en la raíz del proyecto: el panel de
#  verdad, con la biblioteca de Supabase sustituida por la de mentira. No
#  toca la base ni el panel: solo escribe ese archivo, que está ignorado
#  por Git.
#
#  Para qué: ver cómo queda una pantalla con TRABAJO ENCIMA. La cola del
#  equipo con dos solicitudes no dice nada —cualquier orden vale, los
#  montones dicen lo mismo y el reloj no tiene con qué compararse—. El
#  pase '?caso=cola' trae doce, de siete inversionistas, con los tres
#  estados, esperas de dos horas a mes y medio y el reparto repartido.
#
#  Se abre en:
#    http://localhost:8080/vista-cola.html?caso=cola   (el equipo, con cola)
#    http://localhost:8080/vista-cola.html?caso=lleno  (un inversionista)
#
#  El servidor tiene que estar corriendo (ABRIR-LOCAL.bat). Con doble clic
#  sobre el archivo también abre, pero sin servidor algunas cosas del
#  navegador se comportan distinto: mejor por localhost.
# ══════════════════════════════════════════════════════════════════════

$ErrorActionPreference = 'Stop'
$raiz    = Split-Path -Parent $PSScriptRoot
$pagina  = Join-Path $raiz 'ciip-ventanilla-unica-local.html'
$mentira = Join-Path $PSScriptRoot 'supabase-mentira.js'
$salida  = Join-Path $raiz 'vista-cola.html'

foreach ($f in @($pagina, $mentira)) {
  if (-not (Test-Path $f)) { Write-Host "  Falta el archivo: $f" -ForegroundColor Red; exit 1 }
}

$utf8 = New-Object Text.UTF8Encoding($false)
$html = [IO.File]::ReadAllText($pagina, $utf8)

$cdn = '<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.js"></script>'
if ($html.IndexOf($cdn) -lt 0) {
  Write-Host '  No se encontro la etiqueta de Supabase en el panel.' -ForegroundColor Red
  Write-Host '  Si cambio la direccion de la CDN, hay que actualizarla aqui.' -ForegroundColor DarkGray
  exit 1
}
# La ruta lleva 'pruebas/' porque esto se guarda en la raiz: asi el resto
# -config.js, pasos.js, banderas, logos- sigue resolviendo como siempre.
$html = $html.Replace($cdn, '<script src="pruebas/supabase-mentira.js"></script>')

[IO.File]::WriteAllText($salida, $html, $utf8)

Write-Host ''
Write-Host '  COPIA PARA MIRAR' -ForegroundColor Cyan
Write-Host '  ----------------' -ForegroundColor Cyan
Write-Host "  Escrita: $salida"
Write-Host ''
Write-Host '  La cola del equipo, con doce solicitudes:' -ForegroundColor DarkGray
Write-Host '    http://localhost:8080/vista-cola.html?caso=cola' -ForegroundColor Green
Write-Host '  Un inversionista con su expediente:' -ForegroundColor DarkGray
Write-Host '    http://localhost:8080/vista-cola.html?caso=lleno' -ForegroundColor Green
Write-Host ''
Write-Host '  No toca la base de datos: todo lo que se ve es de mentira.' -ForegroundColor DarkGray
Write-Host ''
