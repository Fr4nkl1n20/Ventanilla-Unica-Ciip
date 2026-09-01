# ══════════════════════════════════════════════════════════════════════
#  El SQL del proyecto, ejecutado en un Postgres de verdad
#  Se lanza con PROBAR-SQL.bat (doble clic) o con:
#      powershell -File pruebas\postgres.ps1
# ══════════════════════════════════════════════════════════════════════
#  POR QUE HACE FALTA
#  Las otras tres tandas no tocan Postgres. El panel corre contra
#  supabase-mentira.js, que concede o niega segun lo que se escribio que
#  deberia pasar; que salga en verde no dice si un trigger existe o si una
#  politica cierra. Esto ejecuta los once archivos y luego intenta hacer
#  lo que no se debe.
#
#  NO HACE FALTA NINGUNA CLAVE, Y NO SE TOCA NINGUN SERVIDOR
#  Levanta un Postgres suyo, vacio, en una carpeta temporal y en un puerto
#  libre, con autenticacion "trust" porque solo escucha en 127.0.0.1 y
#  vive lo que dura la prueba. Al acabar lo para y borra la carpeta. Si en
#  esta maquina hay un PostgreSQL con datos de verdad, ni se entera: no se
#  abre, no se conecta y no se le pide la clave a nadie.
#
#  QUE NO ES
#  No sustituye a PROBAR-CERRADURAS.bat. Aquel entra por HTTP en un
#  Supabase de verdad, como entraria un cliente hostil, y prueba tambien
#  lo que Postgres no sabe: el tope del cubo, que lo aplica storage-api,
#  un servicio aparte. Este comprueba lo que vive DENTRO de la base.
# ══════════════════════════════════════════════════════════════════════

$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$env:PGCLIENTENCODING = 'UTF8'

Write-Output ''
Write-Output '  EL SQL, EJECUTADO'
Write-Output '  -----------------'
Write-Output ''

# ── los programas ─────────────────────────────────────────────────────
# El mas nuevo que haya. La carpeta padre de bin ES el numero de version.
$bin = Get-ChildItem 'C:\Program Files\PostgreSQL\*\bin\initdb.exe' -ErrorAction SilentlyContinue |
       Sort-Object { [int]($_.Directory.Parent.Name) } | Select-Object -Last 1
if (-not $bin) {
  Write-Output '  No encuentro PostgreSQL en esta maquina.'
  Write-Output '  Hace falta initdb.exe, que viene con cualquier instalacion.'
  Write-Output ''
  exit 2
}
$carpetaBin = $bin.Directory.FullName
$initdb = Join-Path $carpetaBin 'initdb.exe'
$pgctl  = Join-Path $carpetaBin 'pg_ctl.exe'
$psql   = Join-Path $carpetaBin 'psql.exe'
$exePg   = Join-Path $carpetaBin 'postgres.exe'
$isready = Join-Path $carpetaBin 'pg_isready.exe'
Write-Output ('  PostgreSQL : ' + (& $initdb --version))

# ── un puerto que no moleste a nadie ──────────────────────────────────
$puerto = 0
foreach ($p in 5460..5480) {
  $usado = Get-NetTCPConnection -State Listen -LocalPort $p -ErrorAction SilentlyContinue
  if (-not $usado) { $puerto = $p; break }
}
if ($puerto -eq 0) { Write-Output '  No hay puertos libres entre 5460 y 5480.'; exit 2 }

$datos = Join-Path $env:TEMP ('ciip-sql-' + (Get-Date -Format 'yyyyMMddHHmmss'))
$log    = $datos + '.log'
$logErr = $datos + '.err'
$salida = 0
$levantado = $false

try {
  Write-Output '  Levantando un Postgres vacio, solo para esto...'
  & $initdb -D $datos -U ciip -A trust --encoding=UTF8 --locale=C -N | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'No pude crear el cluster' }

  # NO con "pg_ctl start": ahi el servidor queda colgando de los mismos
  # descriptores que esta consola, y PowerShell no vuelve hasta que se
  # cierren, o sea nunca. Se arranca postgres.exe suelto, con la salida a
  # un archivo, y se espera preguntandole si ya atiende.
  $argsPg = @('-D', $datos, '-p', $puerto, '-h', '127.0.0.1')
  $proc = Start-Process -FilePath $exePg -ArgumentList $argsPg -PassThru -WindowStyle Hidden -RedirectStandardOutput $log -RedirectStandardError $logErr
  $levantado = $true

  $listo = $false
  foreach ($i in 1..60) {
    & $isready -h 127.0.0.1 -p $puerto -q
    if ($LASTEXITCODE -eq 0) { $listo = $true; break }
    Start-Sleep -Milliseconds 500
  }
  if (-not $listo) { throw 'El servidor no llego a atender en 30 segundos' }
  Write-Output ('  Puerto     : ' + $puerto + '  (temporal, se apaga al acabar)')
  Write-Output ''

  function Correr($archivo) {
    & $psql -h 127.0.0.1 -p $puerto -U ciip -d postgres -v 'ON_ERROR_STOP=1' -q --no-psqlrc -c 'set client_min_messages = warning' -f $archivo
  }

  Correr (Join-Path $PSScriptRoot 'postgres-doble.sql')
  if ($LASTEXITCODE -ne 0) { throw 'El andamio no entro' }

  # El orden es EL DEL README, y que corran en el es la primera prueba: si
  # uno usa algo que otro define despues, aqui se cae y se ve cual.
  # El orden sale de las dependencias, no de la fecha: cada archivo lo
  # declara en su cabecera y aqui se comprueba EJECUTANDOLO. Si uno usa
  # algo que otro define despues, esta tanda se cae y dice cual.
  $once = @(
    'supabase-setup.sql',            #  1  define tocar_actualizado_en()
    'supabase-tramites.sql',         #  2  define es_gestor()
    'supabase-admin.sql',            #  3  define es_admin()
    'supabase-citas.sql',            #  4  del 4 al 8, usan es_gestor()
    'supabase-empresa.sql',          #  5  y entre ellos el orden da igual
    'supabase-activos.sql',          #  6
    'supabase-identidad.sql',        #  7
    'supabase-emision.sql',          #  8
    'supabase-presencia.sql',        #  9  no depende de nadie
    'supabase-sectores.sql',         # 10  usa es_admin(), del 3
    'supabase-catalogos.sql',        # 11  despues del 2, del 3 y del 10
    'supabase-bitacora.sql',         # 12  despues del 11; se engancha a citas
    'supabase-bloqueo.sql',          # 13  se engancha a tramites, documentos y citas
    'supabase-acompanamiento.sql',   # 14  usa es_admin()
    'supabase-gestor.sql',           # 15  las politicas del equipo
    'supabase-cola.sql',             # 16  necesita tramites y es_gestor()
    'supabase-avisos.sql',           # 17  cuelga del historial de tramites
    'supabase-aranceles.sql',        # 18  envuelve el encolado del 16
    'supabase-huellas.sql',          # 19  solo necesita documentos
    'supabase-encadenado.sql',       # 20  solo necesita el catalogo
    'supabase-plazos.sql',           # 21  idem
    'supabase-una-viva.sql',         # 22  solo necesita tramites
    'supabase-hilo.sql'              # 23  necesita tramites y documentos
  )
  $n = 0
  foreach ($f in $once) {
    $n++
    $ruta = Join-Path $raiz $f
    if (-not (Test-Path $ruta)) { throw ('Falta ' + $f) }
    Correr $ruta
    if ($LASTEXITCODE -ne 0) { throw ('Se cayo en el ' + $n + ': ' + $f) }
    Write-Output ('  ' + $n.ToString().PadLeft(2) + ' - ' + $f)
  }
  Write-Output ''
  Write-Output '  Los veintitres entraron, en el orden del README.'
  Write-Output ''

  Correr (Join-Path $PSScriptRoot 'postgres-pruebas.sql')
  $salida = $LASTEXITCODE
}
catch {
  Write-Output ''
  Write-Output ('  ' + $_.Exception.Message)
  foreach ($x in @($log, $logErr)) {
    if ((Test-Path $x) -and (Get-Item $x).Length -gt 0) {
      Write-Output ('  Ultimas lineas de ' + (Split-Path $x -Leaf) + ':')
      Get-Content $x -Tail 8 | ForEach-Object { Write-Output ('    ' + $_) }
    }
  }
  Write-Output ''
  $salida = 1
}
finally {
  # Se recoge SIEMPRE, tambien si algo revento a medias: un servidor
  # colgado y una carpeta de datos por pasada acaban siendo un monton.
  if ($levantado) {
    & $pgctl -D $datos -m immediate -w stop | Out-Null
    # Y por si pg_ctl no lo alcanzo: un servidor vivo se queda con el
    # puerto y con la carpeta, y la proxima pasada no puede borrarla.
    if ($proc -and -not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Milliseconds 500
  }
  foreach ($x in @($datos, $log, $logErr)) {
    if (Test-Path $x) { Remove-Item $x -Recurse -Force -ErrorAction SilentlyContinue }
  }
}

Write-Output ''
if ($salida -eq 0) {
  Write-Output '  Esto prueba lo que hay DENTRO de la base: que los once entran en'
  Write-Output '  ese orden, que los triggers saltan y que las politicas cierran.'
  Write-Output '  El tope del cubo lo aplica storage-api, que es otro servicio: eso'
  Write-Output '  solo lo dice PROBAR-CERRADURAS.bat contra un Supabase de verdad.'
} else {
  Write-Output '  Hay algo en rojo. El mismo SQL esta puesto en el proyecto real.'
}
Write-Output ''
exit $salida
