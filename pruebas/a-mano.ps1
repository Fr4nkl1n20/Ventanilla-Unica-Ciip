param([switch]$SinAbrir)
# ══════════════════════════════════════════════════════════════════════
#  PROBAR LA VENTANILLA A MANO
#  --------------------------------------------------------------------
#  El arnes (panel.ps1) abre el panel contra una base de mentira, mide
#  seis mil comprobaciones y cierra el navegador. Nadie llega a TOCARLO.
#  Esto hace lo mismo y para justo antes: deja las paginas en una carpeta
#  y abre el indice, para mirar y pulsar.
#
#  Se genera y no se guarda en git: el panel pesa megabyte y medio, y una
#  copia suya dentro del repositorio estaria vieja al dia siguiente. Se
#  rehace en un segundo cada vez que se ejecuta.
#
#  Lo que se ve es el panel DE VERDAD, con dos piezas cambiadas: la
#  biblioteca de Supabase, que pasa a ser la de mentira de las pruebas, y
#  config.js, que trae valores falsos para que el panel se crea
#  configurado. Nada sale del equipo y nada toca la base real.
#
#  ASCII a proposito: lo que lleva tildes esta en a-mano.json, leido como
#  UTF-8. Un .ps1 sin BOM lo lee PowerShell 5.1 como ANSI y las tildes
#  saldrian rotas en la pagina.
# ══════════════════════════════════════════════════════════════════════
$ErrorActionPreference = 'Stop'
$utf8 = New-Object Text.UTF8Encoding($false)
$raiz = Split-Path $PSScriptRoot -Parent
$destino = Join-Path $raiz 'pruebas-a-mano'

$pagina  = Join-Path $raiz 'ciip-ventanilla-unica-local.html'
$mentira = Join-Path $PSScriptRoot 'supabase-mentira.js'
$textos  = Join-Path $PSScriptRoot 'a-mano.json'
foreach ($f in @($pagina, $mentira, $textos, (Join-Path $raiz 'pasos.js'))) {
  if (-not (Test-Path $f)) { Write-Host "  No encuentro $f" -ForegroundColor Red; exit 1 }
}

Write-Host ''
Write-Host '  PROBAR LA VENTANILLA A MANO' -ForegroundColor Cyan
Write-Host '  ---------------------------'

if (-not (Test-Path $destino)) { New-Item -ItemType Directory -Path $destino -Force | Out-Null }

# --- 1. las piezas que la pagina pide por su nombre ---
Copy-Item (Join-Path $raiz 'pasos.js') $destino -Force
Copy-Item $mentira $destino -Force
foreach ($carpeta in @('logos', 'banderas')) {
  $de = Join-Path $raiz $carpeta
  if (-not (Test-Path $de)) { continue }
  $a = Join-Path $destino $carpeta
  if (-not (Test-Path $a)) { New-Item -ItemType Directory -Path $a -Force | Out-Null }
  Copy-Item (Join-Path $de '*') $a -Force -Recurse
}

# --- 2. un config.js de mentira ---
# Tiene que PARECER configurado: sin esto el panel se planta en "sin
# guardia" y no llega a pedir nada.
$config = @"
window.CIIP_CONFIG = {
  SUPABASE_URL:      'https://ejemplo.supabase.co',
  SUPABASE_ANON_KEY: 'clave-de-mentira',
  RUTA_ACCESO: './index.html'
};
"@
[IO.File]::WriteAllText((Join-Path $destino 'config.js'), $config, $utf8)

# --- 3. el panel, con la biblioteca cambiada ---
$html = [IO.File]::ReadAllText($pagina, $utf8)
$cdn = @'
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.117.2/dist/umd/supabase.js"
        integrity="sha384-Rj26LVGvoeRVR6+mwQmFfcR3QOBEwT+ZmuCWpuiqeTzJpCs0ER4ITAWGb4Hiy3Ok"
        crossorigin="anonymous"></script>
'@
if ($html.IndexOf($cdn) -lt 0) {
  Write-Host '  No encontre la etiqueta de Supabase en el panel.' -ForegroundColor Red
  Write-Host '  Si cambio la direccion de la CDN, hay que actualizarla aqui.' -ForegroundColor DarkGray
  exit 1
}
$html = $html.Replace($cdn, '<script src="supabase-mentira.js"></script>')
[IO.File]::WriteAllText((Join-Path $destino 'panel.html'), $html, $utf8)

# --- 4. el indice ---
function Escapa([string]$s){
  return $s.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;')
}
$j = [IO.File]::ReadAllText($textos, [Text.Encoding]::UTF8) | ConvertFrom-Json
$sb = New-Object Text.StringBuilder
[void]$sb.AppendLine('<!doctype html>')
[void]$sb.AppendLine('<html lang="es"><head><meta charset="utf-8">')
[void]$sb.AppendLine('<meta name="viewport" content="width=device-width, initial-scale=1">')
[void]$sb.AppendLine('<title>' + (Escapa $j.titulo) + '</title>')
[void]$sb.AppendLine(@'
<style>
:root{color-scheme:light; --tinta:#0f172a; --mudo:#64748b; --linea:#e2e8f0;
  --fondo:#f1f5f9; --hoja:#fff; --marca:#0b2f6b;}
*{box-sizing:border-box;}
body{margin:0; padding:34px 20px 60px; background:var(--fondo); color:var(--tinta);
  font:15px/1.55 "Segoe UI", system-ui, sans-serif;}
main{max-width:880px; margin:0 auto;}
h1{font-size:26px; margin:0 0 10px; letter-spacing:-.02em;}
h2{font-size:13px; text-transform:uppercase; letter-spacing:.06em; color:var(--mudo);
  margin:30px 0 10px;}
p{margin:0 0 12px; max-width:66ch;}
.aviso{background:#fff7ed; border:1px solid #fed7aa; border-radius:10px;
  padding:12px 15px; margin:16px 0 4px; color:#7c2d12;}
.pie{margin-top:26px; color:var(--mudo); font-size:13px;}
a.caso{display:block; text-decoration:none; color:inherit; background:var(--hoja);
  border:1px solid var(--linea); border-radius:12px; padding:14px 16px; margin-bottom:10px;}
a.caso:hover{border-color:var(--marca); box-shadow:0 1px 6px rgba(15,23,42,.08);}
a.caso .n{font-weight:700; color:var(--marca);}
a.caso .d{color:var(--mudo); font-size:14px; margin-top:3px;}
a.caso .c{float:right; font-size:12px; color:var(--mudo); font-family:ui-monospace,Consolas,monospace;}
</style></head><body><main>
'@)
[void]$sb.AppendLine('<h1>' + (Escapa $j.titulo) + '</h1>')
[void]$sb.AppendLine('<p>' + (Escapa $j.entrada) + '</p>')
[void]$sb.AppendLine('<div class="aviso">' + (Escapa $j.aviso) + '</div>')
foreach ($g in $j.grupos){
  [void]$sb.AppendLine('<h2>' + (Escapa $g.titulo) + '</h2>')
  foreach ($c in $g.casos){
    [void]$sb.AppendLine('<a class="caso" href="panel.html?caso=' + $c.caso + '">' +
      '<span class="c">?caso=' + $c.caso + '</span>' +
      '<div class="n">' + (Escapa $c.nombre) + '</div>' +
      '<div class="d">' + (Escapa $c.dice) + '</div></a>')
  }
}
[void]$sb.AppendLine('<p class="pie">' + (Escapa $j.rehacer) + '</p>')
[void]$sb.AppendLine('</main></body></html>')
$indice = Join-Path $destino 'index.html'
[IO.File]::WriteAllText($indice, $sb.ToString(), $utf8)

$cuantos = 0
foreach ($g in $j.grupos){ $cuantos += $g.casos.Count }
Write-Host ("  Hechas en: " + $destino)
Write-Host ("  " + $cuantos + " expedientes para entrar, con el indice delante.")
Write-Host ''
if (-not $SinAbrir) { Start-Process $indice }
