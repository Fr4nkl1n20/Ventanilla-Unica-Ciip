# ══════════════════════════════════════════════════════════════════════
#  Rellena config.js con las claves de Supabase, sin editarlo a mano.
#  Se lanza con CONFIGURAR.bat (doble clic).
# ══════════════════════════════════════════════════════════════════════

$ErrorActionPreference = 'Stop'
$raiz   = Split-Path -Parent $PSScriptRoot
$config = Join-Path $raiz 'config.js'
$utf8   = New-Object Text.UTF8Encoding($false)

Write-Host ''
Write-Host '  CONFIGURAR LA CONEXION CON SUPABASE' -ForegroundColor Cyan
Write-Host '  -----------------------------------' -ForegroundColor Cyan
Write-Host ''
Write-Host '  Los dos valores estan en:' -ForegroundColor DarkGray
Write-Host '     Supabase -> Project Settings -> API' -ForegroundColor DarkGray
Write-Host ''

if (-not (Test-Path $config)) {
  Write-Host "  No encuentro config.js en $raiz" -ForegroundColor Red
  Read-Host '  Enter para cerrar'; exit 1
}

$txt = [IO.File]::ReadAllText($config, $utf8)

# --- valores actuales ---
$mU = [regex]::Match($txt, "SUPABASE_URL:\s*'([^']*)'")
$mK = [regex]::Match($txt, "SUPABASE_ANON_KEY:\s*'([^']*)'")
$urlAct = $mU.Groups[1].Value
$keyAct = $mK.Groups[1].Value
$puesto = ($urlAct -notmatch 'TU-PROYECTO') -and ($keyAct -notmatch 'TU_CLAVE')

if ($puesto) {
  Write-Host '  Ya hay algo configurado:' -ForegroundColor Yellow
  Write-Host "     URL   : $urlAct"
  Write-Host ("     Clave : {0}..." -f $keyAct.Substring(0, [Math]::Min(24, $keyAct.Length)))
  Write-Host ''
  $r = Read-Host '  Quieres reemplazarlo? (s/n)'
  if ($r -ne 's') { Write-Host '  Sin cambios.'; Read-Host '  Enter para cerrar'; exit 0 }
  Write-Host ''
}

# --- pedir la URL ---
do {
  $url = (Read-Host '  Project URL (https://xxxxx.supabase.co)').Trim().TrimEnd('/')
  $okU = $url -match '^https://[a-z0-9-]+\.supabase\.co$'
  if (-not $okU) { Write-Host '     Formato raro. Debe ser https://algo.supabase.co' -ForegroundColor Yellow }
} until ($okU)

# --- pedir la clave ---
do {
  $key = (Read-Host '  anon / public key').Trim()
  $okK = $true
  if ($key.Length -lt 40) { Write-Host '     Demasiado corta, revisa que la copiaste entera.' -ForegroundColor Yellow; $okK = $false }
  elseif ($key -like '*service_role*') { Write-Host '     ESA ES LA service_role. NO la uses: abre la base de datos entera.' -ForegroundColor Red; $okK = $false }
  elseif ($key -notlike 'eyJ*' -and $key -notlike 'sb_*') { Write-Host '     No parece una clave de Supabase. Sigo igualmente si insistes.' -ForegroundColor Yellow }
} until ($okK)

# aviso extra: las claves de servicio suelen llevar el rol dentro del JWT
if ($key -like 'eyJ*') {
  try {
    $p = $key.Split('.')[1].Replace('-', '+').Replace('_', '/')
    while ($p.Length % 4) { $p += '=' }
    $carga = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($p))
    if ($carga -match 'service_role') {
      Write-Host ''
      Write-Host '  PARA. Esa clave es service_role: da acceso total saltandose el RLS.' -ForegroundColor Red
      Write-Host '  Copia la que pone "anon" / "public".' -ForegroundColor Red
      Write-Host ''
      Read-Host '  Enter para cerrar'; exit 1
    }
  } catch { }
}

# --- escribir ---
$txt = [regex]::Replace($txt, "SUPABASE_URL:(\s*)'[^']*'",      { param($m) "SUPABASE_URL:" + $m.Groups[1].Value + "'" + $url + "'" })
$txt = [regex]::Replace($txt, "SUPABASE_ANON_KEY:(\s*)'[^']*'", { param($m) "SUPABASE_ANON_KEY:" + $m.Groups[1].Value + "'" + $key + "'" })
[IO.File]::WriteAllText($config, $txt, $utf8)

Write-Host ''
Write-Host '  Guardado en config.js' -ForegroundColor Green
Write-Host ''
Write-Host '  Siguiente paso: en Supabase, Authentication -> URL Configuration,' -ForegroundColor DarkGray
Write-Host '  anade la direccion desde la que abras el proyecto. Con ABRIR-LOCAL.bat es:' -ForegroundColor DarkGray
Write-Host '     Site URL      : http://localhost:8080/acceso.html' -ForegroundColor Green
Write-Host '     Redirect URLs : http://localhost:8080/**' -ForegroundColor Green
Write-Host ''
Write-Host '  Luego abre ABRIR-LOCAL.bat y crea una cuenta de prueba.' -ForegroundColor DarkGray
Write-Host '  El recorrido completo esta en PRUEBAS.md, parte 4.' -ForegroundColor DarkGray
Write-Host ''
Read-Host '  Enter para cerrar'
