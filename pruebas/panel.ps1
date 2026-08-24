# ══════════════════════════════════════════════════════════════════════
#  Pruebas automáticas del panel
#  Se lanza con PROBAR-PANEL.bat (doble clic) o con:
#      powershell -File pruebas\panel.ps1
# ══════════════════════════════════════════════════════════════════════
#  Qué hace, en cuatro pasos:
#    1. Busca Chrome o Edge en el equipo.
#    2. Hace una copia temporal del panel con DOS cosas cambiadas: la
#       biblioteca de Supabase de la CDN se sustituye por una de mentira,
#       y al final se pega el arnés. El panel de verdad NUNCA se toca.
#    3. Abre esa copia SIN VENTANA, cuatro veces: una con un expediente con
#       solicitudes, otra sin nada, otra con una cuenta cuyo perfil no trae
#       nombre, y otra con una cuenta del equipo del CIIP. Buena parte de lo
#       que hay que comprobar es que el panel se calla cuando no hay nada que
#       decir, y que no le ofrece al inversionista lo que no es suyo.
#    4. El navegador devuelve el HTML final; de ahí se lee el resultado.
#
#  Esto NO prueba el trato con el Supabase de verdad: eso sigue siendo a
#  mano, y está en PRUEBAS.md. Lo que prueba es qué hace el panel con lo
#  que la base le conteste, que es donde vive la lógica.
# ══════════════════════════════════════════════════════════════════════

$ErrorActionPreference = 'Stop'
$raiz    = Split-Path -Parent $PSScriptRoot
$pagina  = Join-Path $raiz 'ciip-ventanilla-unica-local.html'
$arnes   = Join-Path $PSScriptRoot 'arnes-panel.js'
$mentira = Join-Path $PSScriptRoot 'supabase-mentira.js'
$trabajo = Join-Path $env:TEMP 'ciip-pruebas-panel'

Write-Host ''
Write-Host '  PRUEBAS DEL PANEL' -ForegroundColor Cyan
Write-Host '  -----------------' -ForegroundColor Cyan
Write-Host ''

# ---- 1. navegador ----
$candidatos = @(
  "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
  "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
  "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
  "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
)
$navegador = $candidatos | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $navegador) {
  Write-Host '  No se encontro Chrome ni Edge. Sin navegador no se puede probar.' -ForegroundColor Red
  exit 1
}
Write-Host "  Navegador : $(Split-Path $navegador -Leaf)"

foreach ($f in @($pagina, $arnes, $mentira)) {
  if (-not (Test-Path $f)) { Write-Host "  Falta el archivo: $f" -ForegroundColor Red; exit 1 }
}

# ---- 2. copia temporal ----
if (-not (Test-Path $trabajo)) { New-Item -ItemType Directory -Path $trabajo -Force | Out-Null }
$utf8 = New-Object Text.UTF8Encoding($false)

# pasos.js va tal cual: de ahi salen los textos de los avisos y la franja
Copy-Item (Join-Path $raiz 'pasos.js') $trabajo -Force

# Las banderas del buscador de paises. Sin copiarlas, el panel comprobaria
# que no hay carpeta y caeria al codigo del pais: la prueba de que se
# dibujan pasaria a rojo por un falso negativo.
$banderas = Join-Path $raiz 'banderas'
if (Test-Path $banderas) {
  $dest = Join-Path $trabajo 'banderas'
  if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
  Copy-Item (Join-Path $banderas '*.svg') $dest -Force
}
# Y los logos de los organismos, por lo mismo: sin la carpeta, el onerror
# de cada <img> retira su placa y la prueba de que cargan daria rojo sin que
# hubiera nada roto.
$logos = Join-Path $raiz 'logos'
if (Test-Path $logos) {
  $destl = Join-Path $trabajo 'logos'
  if (-not (Test-Path $destl)) { New-Item -ItemType Directory -Path $destl -Force | Out-Null }
  Copy-Item (Join-Path $logos '*.png') $destl -Force
  Copy-Item (Join-Path $logos '*.svg') $destl -Force
}
Copy-Item $arnes   $trabajo -Force
Copy-Item $mentira $trabajo -Force

# Un config.js con valores de mentira. Hace falta que PAREZCA configurado:
# si no, el panel se planta en "sin guardia" y no llega a pedir nada.
$configPrueba = @"
window.CIIP_CONFIG = {
  SUPABASE_URL:      'https://ejemplo.supabase.co',
  SUPABASE_ANON_KEY: 'clave-de-mentira',
  RUTA_ACCESO: './acceso.html'
};
"@
[IO.File]::WriteAllText((Join-Path $trabajo 'config.js'), $configPrueba, $utf8)

$html = [IO.File]::ReadAllText($pagina, $utf8)

$cdn = '<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.js"></script>'
if ($html.IndexOf($cdn) -lt 0) {
  Write-Host '  No se encontro la etiqueta de Supabase en el panel.' -ForegroundColor Red
  Write-Host '  Si cambio la direccion de la CDN, hay que actualizarla aqui.' -ForegroundColor DarkGray
  exit 1
}
$html = $html.Replace($cdn, '<script src="supabase-mentira.js"></script>')
$html = $html.Replace('</body>', "<script src=`"arnes-panel.js`"></script>`n</body>")

$copia = Join-Path $trabajo 'panel.html'
[IO.File]::WriteAllText($copia, $html, $utf8)

# ---- 3. ejecutar sin ventana, un expediente por pasada ----
$todos   = @()
$fallos  = 0
$graves  = @()

# Cuatro expedientes en pantalla ancha, y uno mas ESTRECHO. Sin esa quinta
# pasada, todo lo que ocurre por debajo de 840px -donde la barra lateral se
# aparta- no lo miraba nadie: el boton del menu deslizaba una barra de cero
# pixeles y las pruebas daban verde, porque a 1400 el fallo no existe.
$casos = @(
  @{ caso='lleno';     ancho='1400,1000' },
  @{ caso='vacio';     ancho='1400,1000' },
  @{ caso='sinnombre'; ancho='1400,1000' },
  @{ caso='gestor';    ancho='1400,1000' },
  @{ caso='estrecho';  ancho='760,900'   },
  @{ caso='sinsql';    ancho='1400,1000' },
  @{ caso='admin';     ancho='1400,1000' },
  @{ caso='sinsector';   ancho='1400,1000' },
  @{ caso='sincatalogo'; ancho='1400,1000' },
  @{ caso='sinsectorsql'; ancho='1400,1000' }
)
foreach ($c in $casos) {
  $caso  = $c.caso
  $ancho = $c.ancho
  $salida  = Join-Path $trabajo "dom-$caso.html"
  $errores = Join-Path $trabajo "consola-$caso.txt"
  $url     = 'file:///' + ($copia.Replace([char]92, '/')) + "?caso=$caso"
  # El ancho se fija a proposito. Sin el, la ventana sin cabeza mide 800px,
  # el camino se pliega a dos columnas y las pruebas de maquetacion medirian
  # una portada que casi nadie ve. 1400 es una pantalla de escritorio normal,
  # que es donde las cuatro etapas van en fila.
  $args = @('--headless=new','--disable-gpu','--no-sandbox','--dump-dom',
            # El presupuesto de tiempo crece con la cadena de pasos del arnes: cada uno
  # espera medio segundo a que la base conteste. Si se queda corto, el arnes
  # no llega a volcar y el fallo parece un error de JavaScript que no existe.
  '--enable-logging=stderr','--virtual-time-budget=70000',
            "--window-size=$ancho",
            "--user-data-dir=$trabajo\perfil-$caso", $url)
  $p = Start-Process $navegador -ArgumentList $args -RedirectStandardOutput $salida `
                     -RedirectStandardError $errores -NoNewWindow -Wait -PassThru
  Write-Host "  Expediente '$caso' : ejecutado (codigo $($p.ExitCode))"

  $dom = [IO.File]::ReadAllText($salida, $utf8)
  $m = [regex]::Match($dom, '###(\[.*?\])###', [Text.RegularExpressions.RegexOptions]::Singleline)
  if (-not $m.Success) {
    Write-Host ''
    Write-Host "  El arnes no llego a ejecutarse en el expediente '$caso'. Suele" -ForegroundColor Red
    Write-Host '  significar que hay un error de JavaScript que corta la pagina.' -ForegroundColor Red
    Get-Content $errores -ErrorAction SilentlyContinue |
      Where-Object { $_ -match 'ERROR|Uncaught|TypeError|SyntaxError' } |
      Select-Object -First 10 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    exit 1
  }
  $todos += ,@($caso, ($m.Groups[1].Value | ConvertFrom-Json))
  $graves += @(Get-Content $errores -ErrorAction SilentlyContinue |
               Where-Object { $_ -match 'Uncaught|TypeError|SyntaxError|is not defined|is not a function' })
}

# ---- 4. leer resultados ----
Write-Host ''
$total = 0; $pasan = 0
foreach ($par in $todos) {
  $caso = $par[0]; $r = $par[1]
  Write-Host "  EXPEDIENTE '$caso'" -ForegroundColor DarkCyan
  foreach ($c in $r) {
    $total++
    if ($c.ok) {
      $pasan++
      Write-Host '  PASA  ' -ForegroundColor Green -NoNewline; Write-Host $c.n
    } else {
      Write-Host '  FALLA ' -ForegroundColor Red -NoNewline; Write-Host $c.n
      Write-Host "          esperaba : $($c.exp)" -ForegroundColor DarkGray
      Write-Host "          obtuvo   : $($c.got)" -ForegroundColor DarkGray
    }
  }
  Write-Host ''
}

if ($graves.Count -gt 0) {
  Write-Host "  Errores de JavaScript en consola ($($graves.Count)):" -ForegroundColor Yellow
  $graves | Select-Object -First 6 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
  Write-Host ''
}

if ($pasan -eq $total -and $graves.Count -eq 0) {
  Write-Host "  $pasan de $total pruebas superadas" -ForegroundColor Green
} else {
  Write-Host "  $pasan de $total pruebas superadas" -ForegroundColor Red
}
# Las claves de traduccion. No corre en el navegador -lee los archivos-:
# una clave que se pide desde el codigo no se ve en el DOM.
Write-Host ''
Write-Host '  LAS CLAVES DE TRADUCCION' -ForegroundColor DarkCyan
# Se pasa por Write-Host: node escribe directo a la salida y sin esto sus
# lineas salen desordenadas entre las de arriba.
& node (Join-Path $PSScriptRoot 'claves.js') 2>&1 | ForEach-Object { Write-Host $_ }
$clavesMal = ($LASTEXITCODE -ne 0)

Write-Host '  Esto prueba que hace el panel con lo que la base le conteste.'
Write-Host '  Hablar con el Supabase de verdad -entrar, crear una solicitud,'
Write-Host '  subir recaudos- sigue siendo a mano: ver PRUEBAS.md.'
Write-Host ''

if ($pasan -ne $total -or $graves.Count -gt 0 -or $clavesMal) { exit 1 }
