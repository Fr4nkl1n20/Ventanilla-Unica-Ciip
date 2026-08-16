# ══════════════════════════════════════════════════════════════════════
#  Pruebas automáticas de acceso.html
#  Se lanza con PROBAR.bat (doble clic) o con:  powershell -File ejecutar.ps1
# ══════════════════════════════════════════════════════════════════════
#  Qué hace, en cuatro pasos:
#    1. Busca Chrome o Edge en el equipo.
#    2. Hace una copia temporal de acceso.html con arnes.js pegado al final.
#       El acceso.html de verdad NUNCA se toca.
#    3. Abre esa copia en el navegador SIN VENTANA. El navegador ejecuta la
#       página entera y el arnés rellena formularios y pulsa botones solo.
#    4. El navegador devuelve el HTML final; de ahí se lee el resultado.
# ══════════════════════════════════════════════════════════════════════

$ErrorActionPreference = 'Stop'
$raiz    = Split-Path -Parent $PSScriptRoot
$pagina  = Join-Path $raiz 'acceso.html'
$arnes   = Join-Path $PSScriptRoot 'arnes.js'
$trabajo = Join-Path $env:TEMP 'ciip-pruebas'

Write-Host ''
Write-Host '  PRUEBAS DE acceso.html' -ForegroundColor Cyan
Write-Host '  ----------------------' -ForegroundColor Cyan
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

foreach ($f in @($pagina, $arnes)) {
  if (-not (Test-Path $f)) { Write-Host "  Falta el archivo: $f" -ForegroundColor Red; exit 1 }
}

# ---- 2. copia temporal con el arnes dentro ----
if (-not (Test-Path $trabajo)) { New-Item -ItemType Directory -Path $trabajo -Force | Out-Null }
$utf8   = New-Object Text.UTF8Encoding($false)
$html   = [IO.File]::ReadAllText($pagina, $utf8)
$js     = [IO.File]::ReadAllText($arnes,  $utf8)
$copia  = Join-Path $trabajo 'prueba.html'
[IO.File]::WriteAllText($copia, ($html -replace '</body>', "<script>`n$js`n</script>`n</body>"), $utf8)

# Junto a la copia va un config.js NEUTRALIZADO, con los valores de ejemplo.
# Asi se comprueba que el cableado con config.js funciona, pero las pruebas
# no dependen de tus claves reales: si usaramos el config.js de verdad, en
# cuanto lo rellenaras la pagina intentaria hablar con Supabase y los casos
# que esperan "no esta conectado a la base de datos" empezarian a fallar.
$configPrueba = @"
window.CIIP_CONFIG = {
  SUPABASE_URL:      'https://TU-PROYECTO.supabase.co',
  SUPABASE_ANON_KEY: 'TU_CLAVE_ANON_PUBLICA',
  RUTA_PANEL:  './ciip-ventanilla-unica-local.html',
  RUTA_ACCESO: './acceso.html'
};
"@
[IO.File]::WriteAllText((Join-Path $trabajo 'config.js'), $configPrueba, $utf8)

# ---- 3. ejecutar sin ventana ----
$salida = Join-Path $trabajo 'dom.html'
$errores = Join-Path $trabajo 'consola.txt'
$url = 'file:///' + ($copia -replace '\\','/')
$args = @('--headless=new','--disable-gpu','--no-sandbox','--dump-dom',
          '--enable-logging=stderr','--virtual-time-budget=8000',
          "--user-data-dir=$trabajo\perfil", $url)
$p = Start-Process $navegador -ArgumentList $args -RedirectStandardOutput $salida `
                   -RedirectStandardError $errores -NoNewWindow -Wait -PassThru
Write-Host "  Pagina    : ejecutada (codigo $($p.ExitCode))"
Write-Host ''

# ---- 4. leer resultados ----
$dom = [IO.File]::ReadAllText($salida, $utf8)
$m = [regex]::Match($dom, '###(\[.*?\])###', [Text.RegularExpressions.RegexOptions]::Singleline)
if (-not $m.Success) {
  Write-Host '  El arnes no llego a ejecutarse. Suele significar que hay un error' -ForegroundColor Red
  Write-Host '  de JavaScript que corta la pagina antes de tiempo. Consola:' -ForegroundColor Red
  Get-Content $errores -ErrorAction SilentlyContinue |
    Where-Object { $_ -match 'ERROR|Uncaught|TypeError|SyntaxError' } |
    Select-Object -First 10 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
  exit 1
}

$r     = $m.Groups[1].Value | ConvertFrom-Json
$pasan = @($r | Where-Object { $_.ok }).Count
$total = @($r).Count

foreach ($c in $r) {
  if ($c.ok) {
    Write-Host '  PASA  ' -ForegroundColor Green -NoNewline; Write-Host $c.n
  } else {
    Write-Host '  FALLA ' -ForegroundColor Red -NoNewline; Write-Host $c.n
    Write-Host "          esperaba : $($c.exp)" -ForegroundColor DarkGray
    Write-Host "          obtuvo   : $($c.got)" -ForegroundColor DarkGray
  }
}

# errores de JavaScript, aunque las pruebas pasen
$graves = @(Get-Content $errores -ErrorAction SilentlyContinue |
            Where-Object { $_ -match 'Uncaught|TypeError|SyntaxError|is not defined|is not a function' })
Write-Host ''
if ($graves.Count -gt 0) {
  Write-Host "  Errores de JavaScript en consola ($($graves.Count)):" -ForegroundColor Yellow
  $graves | Select-Object -First 6 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
  Write-Host ''
}

$color = if ($pasan -eq $total -and $graves.Count -eq 0) { 'Green' } else { 'Red' }
Write-Host "  $pasan de $total pruebas superadas" -ForegroundColor $color
Write-Host ''
Write-Host '  Esto prueba solo la parte que corre en el navegador.' -ForegroundColor DarkGray
Write-Host '  Crear cuenta de verdad, entrar y los correos necesitan Supabase:' -ForegroundColor DarkGray
Write-Host '  ver PRUEBAS.md, parte 4.' -ForegroundColor DarkGray
Write-Host ''

if ($pasan -ne $total) { exit 1 }
