# ══════════════════════════════════════════════════════════════════════
#  Servidor local del proyecto CIIP
#  Lánzalo con ABRIR-LOCAL.bat (doble clic). Para pararlo: cierra la
#  ventana negra, o pulsa Ctrl+C dentro de ella.
# ══════════════════════════════════════════════════════════════════════
#  Sirve esta carpeta en http://localhost:8080
#
#  ¿Por qué hace falta, si los archivos se abren con doble clic?
#  Con doble clic el navegador usa file://, y ahí:
#    · el origen de la pagina es "null", asi que los enlaces de los
#      correos de Supabase no pueden volver a ella;
#    · localStorage se comparte con CUALQUIER otro archivo local;
#    · history.replaceState falla (por eso hay un try/catch en acceso.html).
#  Con http://localhost desaparecen los tres problemas y se comporta
#  igual que en un servidor real.
#
#  Usa TcpListener y no HttpListener a proposito: HttpListener exige
#  permisos de administrador en Windows para reservar la URL. Asi
#  funciona sin pedir nada.
# ══════════════════════════════════════════════════════════════════════

param([int]$Puerto = 8080)

$raiz = $PSScriptRoot
$ErrorActionPreference = 'Stop'

$MIME = @{
  '.html'='text/html; charset=utf-8'; '.htm'='text/html; charset=utf-8'
  '.js'='text/javascript; charset=utf-8'; '.css'='text/css; charset=utf-8'
  '.png'='image/png'; '.jpg'='image/jpeg'; '.jpeg'='image/jpeg'; '.webp'='image/webp'
  '.svg'='image/svg+xml'; '.gif'='image/gif'; '.ico'='image/x-icon'
  '.json'='application/json; charset=utf-8'; '.md'='text/plain; charset=utf-8'
  '.sql'='text/plain; charset=utf-8'; '.txt'='text/plain; charset=utf-8'
  '.woff2'='font/woff2'; '.woff'='font/woff'; '.ttf'='font/ttf'
}

# --- abrir el puerto ---------------------------------------------------
# El motivo mas comun de que falle es que el servidor YA este abierto en
# otra ventana. En ese caso no es un error: basta con abrir el navegador.
# Si el puerto lo ocupa otra cosa, se prueban los diez siguientes.
function Abrir($p) {
  try {
    $l = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, $p)
    $l.Start()
    return $l
  } catch { return $null }
}

$oyente = Abrir $Puerto

if (-not $oyente) {
  # ¿es nuestro propio servidor, ya abierto?
  $yaEsta = $false
  try {
    $r = Invoke-WebRequest "http://localhost:$Puerto/acceso.html" -UseBasicParsing -TimeoutSec 3
    if ($r.StatusCode -eq 200 -and $r.Content -match 'brand-lockup') { $yaEsta = $true }
  } catch { }

  if ($yaEsta) {
    Write-Host ''
    Write-Host '  El servidor ya estaba abierto en otra ventana.' -ForegroundColor Cyan
    Write-Host "  Te abro el navegador en http://localhost:$Puerto/acceso.html" -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  Si quieres pararlo, cierra la OTRA ventana negra.' -ForegroundColor DarkGray
    Write-Host ''
    Start-Process "http://localhost:$Puerto/acceso.html"
    Start-Sleep -Seconds 3
    exit 0
  }

  # lo ocupa otra cosa: buscar hueco
  $original = $Puerto
  foreach ($p in ($original + 1)..($original + 10)) {
    $oyente = Abrir $p
    if ($oyente) { $Puerto = $p; break }
  }
  if ($oyente) {
    Write-Host ''
    Write-Host "  El puerto $original estaba ocupado por otro programa." -ForegroundColor Yellow
    Write-Host "  Uso el $Puerto en su lugar." -ForegroundColor Yellow
  } else {
    Write-Host ''
    Write-Host "  No se pudo abrir ningun puerto entre $original y $($original+10)." -ForegroundColor Red
    Write-Host '  Prueba con uno distinto:' -ForegroundColor Red
    Write-Host '     powershell -File servidor.ps1 -Puerto 9100' -ForegroundColor DarkGray
    Write-Host ''
    Read-Host '  Pulsa Enter para cerrar'
    exit 1
  }
}

Write-Host ''
Write-Host '  SERVIDOR LOCAL CIIP' -ForegroundColor Cyan
Write-Host '  -------------------' -ForegroundColor Cyan
Write-Host ''
Write-Host "  Carpeta : $raiz"
Write-Host "  Acceso  : " -NoNewline; Write-Host "http://localhost:$Puerto/acceso.html" -ForegroundColor Green
Write-Host "  Panel   : " -NoNewline; Write-Host "http://localhost:$Puerto/ciip-ventanilla-unica-local.html" -ForegroundColor Green
Write-Host "  Vistas  : " -NoNewline; Write-Host "http://localhost:$Puerto/capturas/ver.html" -ForegroundColor Green
Write-Host ''
Write-Host '  Para parar: cierra esta ventana o pulsa Ctrl+C.' -ForegroundColor DarkGray
Write-Host ''

Start-Sleep -Milliseconds 400
Start-Process "http://localhost:$Puerto/acceso.html"

try {
  while ($true) {
    $cliente = $oyente.AcceptTcpClient()
    try {
      $flujo = $cliente.GetStream()
      $flujo.ReadTimeout = 5000

      # --- leer la peticion hasta la linea en blanco ---
      $buf = New-Object byte[] 8192
      $txt = ''
      do {
        $n = $flujo.Read($buf, 0, $buf.Length)
        if ($n -le 0) { break }
        $txt += [Text.Encoding]::ASCII.GetString($buf, 0, $n)
      } while ($flujo.DataAvailable -and $txt -notmatch "`r`n`r`n")

      if ($txt -notmatch '^(GET|HEAD)\s+(\S+)') {
        $cliente.Close(); continue
      }
      $ruta = $Matches[2]

      # quitar la parte de consulta y el ancla, y descodificar %20 y demas
      $ruta = ($ruta -split '[?#]')[0]
      $ruta = [Uri]::UnescapeDataString($ruta)
      if ($ruta -eq '/' ) { $ruta = '/acceso.html' }

      # --- resolver el archivo, sin salir de la carpeta ---
      $rel = $ruta.TrimStart('/').Replace('/', [IO.Path]::DirectorySeparatorChar)
      $destino = Join-Path $raiz $rel
      $completa = $null
      try { $completa = [IO.Path]::GetFullPath($destino) } catch { }

      $cuerpo = $null; $estado = '200 OK'; $tipo = 'text/plain; charset=utf-8'

      if ($completa -and $completa.StartsWith([IO.Path]::GetFullPath($raiz)) -and (Test-Path $completa -PathType Leaf)) {
        $ext = [IO.Path]::GetExtension($completa).ToLower()
        if ($MIME.ContainsKey($ext)) { $tipo = $MIME[$ext] } else { $tipo = 'application/octet-stream' }
        $cuerpo = [IO.File]::ReadAllBytes($completa)
        Write-Host ("  200  {0}" -f $ruta) -ForegroundColor DarkGray
      } else {
        $estado = '404 Not Found'
        $tipo = 'text/html; charset=utf-8'
        $cuerpo = [Text.Encoding]::UTF8.GetBytes("<meta charset='utf-8'><h1>404</h1><p>No existe <code>$ruta</code> en la carpeta del proyecto.</p>")
        Write-Host ("  404  {0}" -f $ruta) -ForegroundColor Yellow
      }

      $cab = "HTTP/1.1 $estado`r`n" +
             "Content-Type: $tipo`r`n" +
             "Content-Length: $($cuerpo.Length)`r`n" +
             "Cache-Control: no-store`r`n" +
             "Connection: close`r`n`r`n"
      $bcab = [Text.Encoding]::ASCII.GetBytes($cab)
      $flujo.Write($bcab, 0, $bcab.Length)
      if ($txt -notmatch '^HEAD') { $flujo.Write($cuerpo, 0, $cuerpo.Length) }
      $flujo.Flush()
    } catch {
      # una conexion cortada por el navegador no debe tumbar el servidor
    } finally {
      $cliente.Close()
    }
  }
} finally {
  $oyente.Stop()
  Write-Host ''
  Write-Host '  Servidor detenido.' -ForegroundColor Cyan
}
