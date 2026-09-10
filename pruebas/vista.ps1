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
#
#  -Plazos enciende el globo del reloj de la tarjeta, «Los plazos de este
#  trámite», que en el panel está apagado por decisión del CIIP. Se enciende
#  SOLO en esta copia: el panel de verdad no se toca. Es para lo que sirve
#  este archivo —mirar una pantalla— y una pantalla apagada por un
#  interruptor no se puede mirar de ninguna otra manera sin cambiar el panel
#  y acordarse luego de devolverlo.
#
#      powershell -File pruebas\vista.ps1 -Plazos
# ══════════════════════════════════════════════════════════════════════

param([switch]$Plazos)

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

# Se busca la línea EXACTA del interruptor y se avisa si no está, en vez de
# escribir la copia como si nada: una vista que dice que enciende el globo y
# lo deja apagado hace perder la tarde mirando por qué no sale.
if ($Plazos) {
  $apagado = '  var GLOBO_DE_PLAZOS = false;'
  if ($html.IndexOf($apagado) -lt 0) {
    Write-Host '  No se encontro el interruptor GLOBO_DE_PLAZOS en el panel.' -ForegroundColor Red
    Write-Host '  Si se borro -la decision se confirmo- este pase ya no hace falta.' -ForegroundColor DarkGray
    exit 1
  }
  $html = $html.Replace($apagado, '  var GLOBO_DE_PLAZOS = true;   /* encendido SOLO en esta copia */')
}

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
if ($Plazos) {
  Write-Host '  El globo de plazos, ENCENDIDO en esta copia.' -ForegroundColor Yellow
  Write-Host '  Se abre pulsando el reloj de una tarjeta, el que dice "Est.: 10 dias".' -ForegroundColor DarkGray
  Write-Host '  Lo llevan las que tienen norma leida o dias del CIIP en Catalogos.' -ForegroundColor DarkGray
  Write-Host '  En el panel de verdad sigue apagado.' -ForegroundColor DarkGray
  Write-Host ''
}
Write-Host '  No toca la base de datos: todo lo que se ve es de mentira.' -ForegroundColor DarkGray
Write-Host ''
