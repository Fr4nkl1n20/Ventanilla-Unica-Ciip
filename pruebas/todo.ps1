# ══════════════════════════════════════════════════════════════════════
#  TODAS LAS PUERTAS, DE UNA VEZ
# ══════════════════════════════════════════════════════════════════════
#  Lo lanza PROBAR-TODO.bat. Corre las diez tandas y termina con un cuadro.
#
#  POR QUE EXISTE
#  ─────────────────────────────────────────────────────────────────────
#  Habia diez puertas y ninguna que las abriera todas. "Esta todo en
#  verde" era acordarse de diez dobles clic, saber cual necesita que
#  clave, y leerse diez pantallas hasta el final. Eso no se sostiene
#  antes de subir a main, y no se sostuvo: el arnes de acceso.html llevaba
#  dias sin ejecutarse y nadie lo vio.
#
#  LAS TRES COLUMNAS, Y LA TERCERA ES LA QUE FALTABA
#  ─────────────────────────────────────────────────────────────────────
#  Paso / Fallo / NO SE PUDO PROBAR. Sin la tercera, una tanda que no
#  corre por falta de una clave local se cuenta como que fue bien, que es
#  justo la mentira que se viene a quitar. Aqui se dice cuantas se
#  quedaron sin probar y por que, y sale en el resumen final, no perdido
#  en el medio.
#
#  EL CODIGO DE SALIDA
#  ─────────────────────────────────────────────────────────────────────
#  0 solo si TODAS las que se pudieron correr fueron bien. Lo que no se
#  pudo probar no pone esto en rojo -no es un fallo- pero se cuenta y se
#  dice. Quien encadene esto desde fuera necesita las dos cosas.
# ══════════════════════════════════════════════════════════════════════

$ErrorActionPreference = 'Continue'
$RAIZ = Split-Path -Parent $PSScriptRoot

# Lo que necesita cada puerta ademas de Node. Si falta, no se corre y se
# dice por que, en vez de correrla para que se caiga sola con un error que
# no distingue "falta una clave" de "hay un agujero".
# El de las cerraduras pide un archivo; el del SQL pide un PROGRAMA, que es
# otra cosa y por eso van por separado. Estuvo mal puesto: pedia
# pruebas\postgres.local.json, un archivo que postgres.ps1 ya no usa -levanta
# su propio Postgres de usar y tirar-, asi que la puerta salia como "sin
# probar" en una maquina donde funcionaba perfectamente. Un requisito
# inventado esconde una tanda igual de bien que un fallo.
$REQUISITOS = @{
  'PROBAR-CERRADURAS' = @{ archivo = 'pruebas\cuentas.local.json'; por = 'faltan las cuentas de prueba (pruebas\cuentas.local.json)' }
  'PROBAR-SQL'        = @{ programa = 'C:\Program Files\PostgreSQL\*\bin\initdb.exe'; por = 'no hay PostgreSQL instalado en esta maquina' }
  # El intermediario del asistente es lo unico del proyecto con una
  # dependencia. Recien clonado no esta instalada, y sin este requisito la
  # tanda saldria en rojo con un "Cannot find module" que parece un fallo
  # del codigo y es solo un `npm install` que nadie corrio.
  'PROBAR-ASISTENTE'  = @{ archivo = 'node_modules\@anthropic-ai\sdk\package.json'; por = 'falta correr `npm install` una vez (api\asistente.js usa el SDK de Anthropic)' }
}

# El orden es de mas barato a mas caro: lo que no toca la red primero, para
# que un fallo tonto salte en los primeros segundos y no en el minuto ocho.
$ORDEN = @(
  'PROBAR-CONECTOR', 'PROBAR-SAREN', 'PROBAR-TRABAJADOR', 'PROBAR-PAGOS',
  'PROBAR-AVISOS', 'PROBAR-BARRENDERO', 'PROBAR-ASISTENTE',
  'PROBAR', 'PROBAR-PANEL',
  'PROBAR-SQL', 'PROBAR-CERRADURAS'
)

Write-Host ''
Write-Host '  TODAS LAS PRUEBAS' -ForegroundColor Cyan
Write-Host '  -----------------'
Write-Host ''

# Que no se quede ninguna puerta fuera del orden de arriba. Una lista
# escrita a mano envejece en cuanto alguien añade un .bat y se olvida de
# esto, y entonces la puerta nueva no la corre nadie y aqui sale que todo
# fue bien. Se comprueba contra lo que hay en el disco.
$enDisco = Get-ChildItem -Path $RAIZ -Filter 'PROBAR*.bat' -File |
           Where-Object { $_.BaseName -ne 'PROBAR-TODO' } |
           ForEach-Object { $_.BaseName }
$sueltas = $enDisco | Where-Object { $ORDEN -notcontains $_ }
if ($sueltas) {
  Write-Host ('  OJO: hay puertas que este archivo no conoce: ' + ($sueltas -join ', ')) -ForegroundColor Yellow
  Write-Host '  Se corren igual, al final. Añadelas a $ORDEN en pruebas\todo.ps1.'
  Write-Host ''
  $ORDEN = $ORDEN + $sueltas
}

$env:CIIP_SIN_PAUSA = '1'
$filas = @()

foreach ($nombre in $ORDEN) {
  $bat = Join-Path $RAIZ ($nombre + '.bat')
  if (-not (Test-Path $bat)) {
    $filas += [pscustomobject]@{ puerta = $nombre; estado = 'sin probar'; detalle = 'no existe ese .bat' }
    continue
  }

  $req = $REQUISITOS[$nombre]
  $falta = $false
  if ($req -and $req.archivo)  { $falta = -not (Test-Path (Join-Path $RAIZ $req.archivo)) }
  if ($req -and $req.programa) { $falta = -not (Get-ChildItem $req.programa -ErrorAction SilentlyContinue) }
  if ($falta) {
    Write-Host ('  {0,-20} sin probar' -f $nombre) -ForegroundColor Yellow
    $filas += [pscustomobject]@{ puerta = $nombre; estado = 'sin probar'; detalle = $req.por }
    continue
  }

  Write-Host ('  {0,-20} corriendo...' -f $nombre) -NoNewline
  $salida = & $bat 2>&1 | Out-String
  $codigo = $LASTEXITCODE

  # Los renglones de la cuenta, para enseñarlos sin volcar la pantalla
  # entera. Se cogen TODOS y no el ultimo: el panel escribe dos -4569
  # pruebas y 10 comprobaciones de traduccion- y quedarse con el ultimo
  # enseñaba "10 de 10" y se comia las cuatro mil quinientas, que es
  # exactamente la cifra que uno viene a mirar aqui.
  # Si la tanda no escribe ninguno se queda vacio y no pasa nada: lo que
  # manda es el codigo de salida.
  $cuenta = (($salida -split "`n" |
              Select-String -Pattern 'de \d+ (pruebas|comprobaciones|cerraduras)' |
              ForEach-Object { ($_.ToString() -replace '\s+', ' ').Trim() }) -join '  ·  ')

  if ($codigo -eq 0) {
    Write-Host ("`r  {0,-20} BIEN    {1}" -f $nombre, $cuenta) -ForegroundColor Green
    $filas += [pscustomobject]@{ puerta = $nombre; estado = 'bien'; detalle = $cuenta }
  } else {
    Write-Host ("`r  {0,-20} FALLA   {1}" -f $nombre, $cuenta) -ForegroundColor Red
    # Las lineas en rojo de esa tanda, para no tener que volver a correrla
    # a mano solo para ver cual fue.
    $rojas = ($salida -split "`n" | Select-String -Pattern 'FALLA' |
              Select-Object -First 6 | ForEach-Object { $_.ToString().Trim() })
    foreach ($r in $rojas) { Write-Host ('      ' + $r) -ForegroundColor Red }
    $filas += [pscustomobject]@{ puerta = $nombre; estado = 'falla'; detalle = $cuenta }
  }
}

Remove-Item Env:\CIIP_SIN_PAUSA -ErrorAction SilentlyContinue

$bien      = @($filas | Where-Object { $_.estado -eq 'bien' })
$fallan    = @($filas | Where-Object { $_.estado -eq 'falla' })
$sinProbar = @($filas | Where-Object { $_.estado -eq 'sin probar' })

Write-Host ''
Write-Host ('  {0} de {1} puertas en verde' -f $bien.Count, ($bien.Count + $fallan.Count)) -ForegroundColor Cyan

if ($fallan.Count) {
  Write-Host ''
  foreach ($f in $fallan) { Write-Host ('  FALLA  ' + $f.puerta) -ForegroundColor Red }
}

# Esto va SIEMPRE y al final, no solo cuando falta algo: una tanda que no
# se pudo correr es lo que mas facilmente se da por buena.
if ($sinProbar.Count) {
  Write-Host ''
  Write-Host ('  Y ' + $sinProbar.Count + ' sin probar. No es un fallo, pero tampoco es un verde:') -ForegroundColor Yellow
  foreach ($s in $sinProbar) {
    Write-Host ('    ' + $s.puerta + ': ' + $s.detalle) -ForegroundColor Yellow
  }
  Write-Host ''
  Write-Host '  Las cerraduras hay que correrlas donde esten las cuentas, que no'
  Write-Host '  viajan en el repositorio: .gitignore no las deja subir y por eso'
  Write-Host '  ninguna descarga las trae.'
}

Write-Host ''
if ($fallan.Count) { exit 1 } else { exit 0 }
