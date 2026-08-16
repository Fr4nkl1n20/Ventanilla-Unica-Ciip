# ══════════════════════════════════════════════════════════════════════
#  Sube el proyecto a GitHub. Se lanza con SUBIR-GITHUB.bat (doble clic).
# ══════════════════════════════════════════════════════════════════════
#  Hace, comprobando en cada paso:
#    1. que Git este instalado
#    2. quien eres (nombre y correo para los commits)
#    3. git init, si hace falta
#    4. avisar si config.js lleva claves de verdad dentro
#    5. add + commit
#    6. enlazar con el repositorio de GitHub y subir
# ══════════════════════════════════════════════════════════════════════

$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
Set-Location $raiz

function Titulo($t) { Write-Host ''; Write-Host "  $t" -ForegroundColor Cyan }
function Bien($t)   { Write-Host "  OK   $t" -ForegroundColor Green }
function Ojo($t)    { Write-Host "  OJO  $t" -ForegroundColor Yellow }
function Mal($t)    { Write-Host "  ERROR $t" -ForegroundColor Red }

Write-Host ''
Write-Host '  SUBIR EL PROYECTO A GITHUB' -ForegroundColor Cyan
Write-Host '  --------------------------' -ForegroundColor Cyan

# ---- 1. Git instalado ----
# Si acabas de instalar Git, las ventanas que ya estaban abiertas conservan
# el PATH viejo y "git" no se encuentra aunque este instalado. Antes de dar
# error, se refresca el PATH y se mira en las rutas habituales.
$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) {
  $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
              [Environment]::GetEnvironmentVariable('Path','User')
  $git = Get-Command git -ErrorAction SilentlyContinue
}
if (-not $git) {
  foreach ($r in @("$env:ProgramFiles\Git\cmd",
                   "${env:ProgramFiles(x86)}\Git\cmd",
                   "$env:LOCALAPPDATA\Programs\Git\cmd")) {
    if (Test-Path (Join-Path $r 'git.exe')) {
      $env:Path = $r + ';' + $env:Path
      $git = Get-Command git -ErrorAction SilentlyContinue
      break
    }
  }
}
if (-not $git) {
  Write-Host ''
  Mal 'Git no esta instalado.'
  Write-Host '  Descargalo de https://git-scm.com/download/win' -ForegroundColor DarkGray
  Write-Host '  Deja las opciones por defecto.' -ForegroundColor DarkGray
  Write-Host ''
  Write-Host '  IMPORTANTE: al terminar, CIERRA esta ventana y vuelve a abrirla.' -ForegroundColor Yellow
  Write-Host '  El PATH no se refresca en las ventanas ya abiertas.' -ForegroundColor Yellow
  Write-Host ''
  Read-Host '  Enter para cerrar'; exit 1
}
Bien "Git encontrado: $(git --version)"

# ---- 2. identidad ----
Titulo 'Quien firma los commits'
$nom = (git config --global user.name)  2>$null
$cor = (git config --global user.email) 2>$null
if (-not $nom) {
  $nom = Read-Host '  Tu nombre'
  git config --global user.name $nom
}
if (-not $cor) {
  $cor = Read-Host '  Tu correo (el mismo de GitHub)'
  git config --global user.email $cor
}
Bien "$nom <$cor>"

# ---- 3. repositorio ----
Titulo 'Repositorio local'
if (Test-Path (Join-Path $raiz '.git')) {
  Bien 'Ya existe, se reutiliza'
} else {
  git init -b main | Out-Null
  Bien 'Creado (rama main)'
}

# ---- 4. aviso sobre config.js ----
Titulo 'Revision de config.js'
$cfg = Join-Path $raiz 'config.js'
$hayClaves = $false
if (Test-Path $cfg) {
  $c = Get-Content $cfg -Raw -Encoding UTF8
  $hayClaves = ($c -notmatch 'TU-PROYECTO') -and ($c -notmatch 'TU_CLAVE')
}
if ($hayClaves) {
  Ojo 'config.js lleva claves de verdad y SE VA A SUBIR.'
  Write-Host '       La clave "anon" es publica por diseno y no pasa nada,' -ForegroundColor DarkGray
  Write-Host '       siempre que el RLS este activo y NO sea la service_role.' -ForegroundColor DarkGray
  Write-Host '       Si no quieres publicarla, haz el repositorio PRIVADO.' -ForegroundColor DarkGray
  Write-Host ''
  if ((Read-Host '       Seguimos? (s/n)') -ne 's') { Write-Host '  Cancelado.'; Read-Host '  Enter'; exit 0 }
} else {
  Bien 'Solo valores de ejemplo, nada sensible'
}

# ---- 5. commit ----
Titulo 'Guardando los cambios'
git add -A
$pendiente = git status --porcelain
if (-not $pendiente) {
  Bien 'No hay nada nuevo que guardar'
} else {
  $n = @($pendiente).Count
  $msg = Read-Host "  Mensaje del commit ($n archivos) [Enter = 'Ventanilla Unica: acceso, panel y pruebas']"
  if (-not $msg) { $msg = 'Ventanilla Unica: acceso, panel y pruebas' }
  git commit -m $msg | Out-Null
  Bien "$n archivos guardados"
}

# ---- 6. subir ----
Titulo 'Subir a GitHub'
$remoto = (git remote get-url origin) 2>$null
if ($remoto) {
  Bien "Ya enlazado con $remoto"
} else {
  Write-Host '  Antes de seguir, crea el repositorio VACIO en GitHub:' -ForegroundColor DarkGray
  Write-Host '     https://github.com/new' -ForegroundColor DarkGray
  Write-Host '     Sin README, sin .gitignore, sin licencia.' -ForegroundColor DarkGray
  Write-Host '     (si lo creas con archivos, el primer push sera rechazado)' -ForegroundColor DarkGray
  Write-Host ''
  $url = (Read-Host '  Pega la URL del repositorio').Trim()
  if (-not $url) { Write-Host '  Cancelado.'; Read-Host '  Enter'; exit 0 }
  if ($url -notmatch '^https://github\.com/.+/.+') {
    Ojo 'Esa URL no parece de GitHub, pero sigo.'
  }
  git remote add origin $url
  Bien "Enlazado con $url"
}

Write-Host ''
Write-Host '  Subiendo... si es la primera vez, se abrira el navegador' -ForegroundColor DarkGray
Write-Host '  para que inicies sesion en GitHub.' -ForegroundColor DarkGray
Write-Host ''
git push -u origin main
if ($LASTEXITCODE -eq 0) {
  Write-Host ''
  Bien 'Subido correctamente'
  Write-Host ''
  Write-Host '  A partir de ahora, para subir cambios nuevos basta con' -ForegroundColor DarkGray
  Write-Host '  volver a ejecutar este mismo archivo.' -ForegroundColor DarkGray
} else {
  Write-Host ''
  Mal 'El push fallo.'
  Write-Host '  Causas mas frecuentes:' -ForegroundColor DarkGray
  Write-Host '   - El repositorio de GitHub no estaba vacio -> git pull --rebase origin main' -ForegroundColor DarkGray
  Write-Host '   - Cancelaste el inicio de sesion del navegador' -ForegroundColor DarkGray
  Write-Host '   - La URL del repositorio esta mal -> git remote set-url origin <url>' -ForegroundColor DarkGray
}
Write-Host ''
Read-Host '  Enter para cerrar'
