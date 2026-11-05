# ================================================================= #
#   Install-DragDrop.ps1 — Integrar FileTools con Explorer          #
#   github.com/HEO-80/powershell-cyberpunk                          #
#                                                                    #
#  Ejecutar:                                                         #
#    irm https://raw.githubusercontent.com/HEO-80/powershell-cyberpunk/main/extras/Install-DragDrop.ps1 | iex
#                                                                    #
#  Que hace:                                                         #
#    1. Crea un .bat en el Escritorio para arrastrar archivos        #
#    2. Anade "Analizar con CyberTools" al clic derecho de Explorer  #
#    3. Carga funciones para recibir rutas en la terminal            #
#                                                                    #
#  NOTA: El menu de clic derecho necesita ejecutar como Admin        #
# ================================================================= #

$ErrorActionPreference = "Stop"
$esc = [char]27

# ================================================================= #
#  DEFINICIONES DE FUNCIONES (antes de usarlas)                     #
# ================================================================= #

function Write-Step  { param($t) Write-Host "${esc}[38;2;252;238;10m  > $t${esc}[0m" }
function Write-OK    { param($t) Write-Host "${esc}[38;2;57;255;20m  OK $t${esc}[0m" }
function Write-Warn  { param($t) Write-Host "${esc}[38;2;198;120;221m  ! $t${esc}[0m" }
function Write-Info  { param($t) Write-Host "${esc}[38;2;0;240;255m  i $t${esc}[0m" }

function Get-MenuRegistryScript {
    $fileToolsUrl = "https://raw.githubusercontent.com/HEO-80/powershell-cyberpunk/main/extras/FileTools.ps1"

    return @"
# Instalar menu de clic derecho 'Analizar con CyberTools'
# Ejecutar como Administrador

`$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "  Instalando menu de clic derecho..." -ForegroundColor Yellow

# --- Clic derecho en ARCHIVOS ---
`$keyFile = "Registry::HKEY_CLASSES_ROOT\*\shell\CyberToolsAnalizar"
`$keyFileCmd = "`$keyFile\command"

if (-not (Test-Path `$keyFile)) {
    New-Item -Path `$keyFile -Force | Out-Null
}
Set-ItemProperty -Path `$keyFile -Name "(Default)" -Value "Analizar con CyberTools"
Set-ItemProperty -Path `$keyFile -Name "Icon" -Value "powershell.exe"

if (-not (Test-Path `$keyFileCmd)) {
    New-Item -Path `$keyFileCmd -Force | Out-Null
}
`$cmdFile = 'powershell.exe -NoExit -ExecutionPolicy Bypass -Command "irm $fileToolsUrl | iex; info \"%1\"; hash \"%1\""'
Set-ItemProperty -Path `$keyFileCmd -Name "(Default)" -Value `$cmdFile

Write-Host "  OK  Clic derecho en archivos instalado" -ForegroundColor Green

# --- Clic derecho en CARPETAS ---
`$keyDir = "Registry::HKEY_CLASSES_ROOT\Directory\shell\CyberToolsAnalizar"
`$keyDirCmd = "`$keyDir\command"

if (-not (Test-Path `$keyDir)) {
    New-Item -Path `$keyDir -Force | Out-Null
}
Set-ItemProperty -Path `$keyDir -Name "(Default)" -Value "Analizar con CyberTools"
Set-ItemProperty -Path `$keyDir -Name "Icon" -Value "powershell.exe"

if (-not (Test-Path `$keyDirCmd)) {
    New-Item -Path `$keyDirCmd -Force | Out-Null
}
`$cmdDir = 'powershell.exe -NoExit -ExecutionPolicy Bypass -Command "irm $fileToolsUrl | iex; info \"%V\""'
Set-ItemProperty -Path `$keyDirCmd -Name "(Default)" -Value `$cmdDir

Write-Host "  OK  Clic derecho en carpetas instalado" -ForegroundColor Green

# --- Clic derecho en FONDO de carpeta (background) ---
`$keyBg = "Registry::HKEY_CLASSES_ROOT\Directory\Background\shell\CyberToolsAnalizar"
`$keyBgCmd = "`$keyBg\command"

if (-not (Test-Path `$keyBg)) {
    New-Item -Path `$keyBg -Force | Out-Null
}
Set-ItemProperty -Path `$keyBg -Name "(Default)" -Value "Abrir CyberTools aqui"
Set-ItemProperty -Path `$keyBg -Name "Icon" -Value "powershell.exe"

if (-not (Test-Path `$keyBgCmd)) {
    New-Item -Path `$keyBgCmd -Force | Out-Null
}
`$cmdBg = 'powershell.exe -NoExit -ExecutionPolicy Bypass -Command "irm $fileToolsUrl | iex; cd \"%V\"; Write-Host \"  CyberTools cargado en `$(Get-Location)\" -ForegroundColor Green; Write-Host \"  Comandos: info, hash, peso, buscar, duplicados, comparar\" -ForegroundColor DarkGray"'
Set-ItemProperty -Path `$keyBgCmd -Name "(Default)" -Value `$cmdBg

Write-Host "  OK  Clic derecho en fondo de carpeta instalado" -ForegroundColor Green

Write-Host ""
Write-Host "  Instalacion completada. Cierra y abre Explorer para verlo." -ForegroundColor Green
Write-Host ""
pause
"@
}

function Install-ContextMenu {
    $tempScript = Join-Path $env:TEMP "install-cybertools-menu.ps1"
    $menuScript = Get-MenuRegistryScript
    $menuScript | Set-Content $tempScript -Encoding UTF8
    & powershell -ExecutionPolicy Bypass -File $tempScript
    Remove-Item $tempScript -ErrorAction SilentlyContinue
}

function global:Uninstall-CyberToolsMenu {
    <#
    .SYNOPSIS
    Quita el menu de clic derecho de CyberTools. Necesita Admin.
    #>
    $esAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $esAdmin) {
        Write-Host "  Necesitas ejecutar como Administrador." -ForegroundColor Red
        return
    }

    $claves = @(
        "Registry::HKEY_CLASSES_ROOT\*\shell\CyberToolsAnalizar",
        "Registry::HKEY_CLASSES_ROOT\Directory\shell\CyberToolsAnalizar",
        "Registry::HKEY_CLASSES_ROOT\Directory\Background\shell\CyberToolsAnalizar"
    )

    foreach ($clave in $claves) {
        if (Test-Path $clave) {
            Remove-Item $clave -Recurse -Force
            Write-Host "  Eliminado: $clave" -ForegroundColor Green
        }
    }

    $batPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "CyberAnalizar.bat"
    if (Test-Path $batPath) {
        Remove-Item $batPath -Force
        Write-Host "  Eliminado: $batPath" -ForegroundColor Green
    }

    Write-Host "  CyberTools desinstalado del menu de clic derecho." -ForegroundColor Green
}

function global:recibir {
    <#
    .SYNOPSIS
    Recibe una o varias rutas y muestra info + hash de cada una.
    Arrastra archivos a la terminal y pega las rutas como argumentos.
    .EXAMPLE
    recibir C:\archivo1.pdf C:\archivo2.docx
    recibir "C:\ruta con espacios\informe.xlsx"
    #>
    param(
        [Parameter(Position = 0, ValueFromRemainingArguments)]
        [string[]]$Rutas
    )

    if (-not $Rutas -or $Rutas.Count -eq 0) {
        Write-Host ""
        Write-Host "  Uso: recibir <ruta1> [ruta2] [ruta3] ..." -ForegroundColor Yellow
        Write-Host "  Tip: arrastra archivos a la terminal y pega las rutas" -ForegroundColor DarkGray
        Write-Host ""
        return
    }

    $rutasLimpias = @()
    foreach ($r in $Rutas) {
        $limpia = $r.Trim().Trim('"').Trim("'")
        if ($limpia) { $rutasLimpias += $limpia }
    }

    foreach ($ruta in $rutasLimpias) {
        if (-not (Test-Path $ruta)) {
            Write-Host "  No existe: $ruta" -ForegroundColor Red
            continue
        }

        if (Get-Command info -ErrorAction SilentlyContinue) {
            info $ruta
        } else {
            $item = Get-Item $ruta -Force
            Write-Host ""
            Write-Host "  Nombre:  $($item.Name)" -ForegroundColor Cyan
            Write-Host "  Ruta:    $($item.FullName)" -ForegroundColor Cyan
            if ($item.PSIsContainer) {
                $size = (Get-ChildItem $ruta -Recurse -File -Force -EA SilentlyContinue | Measure-Object Length -Sum).Sum
                Write-Host "  Tipo:    Carpeta" -ForegroundColor Yellow
                Write-Host "  Tamano:  $([math]::Round($size / 1MB, 2)) MB" -ForegroundColor Yellow
            } else {
                Write-Host "  Tipo:    Archivo ($($item.Extension))" -ForegroundColor Yellow
                Write-Host "  Tamano:  $([math]::Round($item.Length / 1KB, 2)) KB" -ForegroundColor Yellow
            }
        }

        if (-not (Get-Item $ruta).PSIsContainer) {
            if (Get-Command hash -ErrorAction SilentlyContinue) {
                hash $ruta
            } else {
                $h = Get-FileHash $ruta -Algorithm SHA256
                Write-Host "  SHA256:  $($h.Hash)" -ForegroundColor DarkGray
            }
        }
    }
}

# ================================================================= #
#  EJECUCION PRINCIPAL                                              #
# ================================================================= #

Write-Host ""
Write-Host "${esc}[38;2;252;238;10m  ========================================${esc}[0m"
Write-Host "${esc}[38;2;252;238;10m   Install-DragDrop · Integracion Explorer${esc}[0m"
Write-Host "${esc}[38;2;252;238;10m  ========================================${esc}[0m"
Write-Host ""

# ── 1. WRAPPER .BAT ──────────────────────────────────────────────
Write-Step "Creando wrapper .bat en el Escritorio..."

$desktop = [Environment]::GetFolderPath("Desktop")
$batPath = Join-Path $desktop "CyberAnalizar.bat"

$fileToolsPath = $null
$posibles = @(
    (Join-Path $HOME ".powershell-cyberpunk\extras\FileTools.ps1"),
    (Join-Path $HOME ".my-Heo-Terminal\extras\FileTools.ps1")
)
if ($PSScriptRoot) {
    $posibles += (Join-Path $PSScriptRoot "FileTools.ps1")
}
foreach ($p in $posibles) {
    if (Test-Path $p) { $fileToolsPath = $p; break }
}

if (-not $fileToolsPath) {
    $fileToolsPath = "DOWNLOAD"
}

if ($fileToolsPath -eq "DOWNLOAD") {
    $batContent = @"
@echo off
chcp 65001 >nul
title CyberTools — Analizando archivo(s)
echo.
echo   Cargando CyberTools...
echo.

if "%~1"=="" (
    echo   Arrastra uno o mas archivos encima de este .bat
    echo   para analizarlos con CyberTools.
    echo.
    pause
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "irm https://raw.githubusercontent.com/HEO-80/powershell-cyberpunk/main/extras/FileTools.ps1 | iex; " ^
    "foreach (`$ruta in @('%*' -split '\"\" \"\"')) { " ^
    "  `$r = `$ruta.Trim('\"'); " ^
    "  if (Test-Path `$r) { info `$r; hash `$r } " ^
    "}"

echo.
echo   Pulsa una tecla para cerrar...
pause >nul
"@
} else {
    $batContent = @"
@echo off
chcp 65001 >nul
title CyberTools — Analizando archivo(s)
echo.
echo   Cargando CyberTools...
echo.

if "%~1"=="" (
    echo   Arrastra uno o mas archivos encima de este .bat
    echo   para analizarlos con CyberTools.
    echo.
    pause
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    ". '$fileToolsPath'; " ^
    "`$args = @(); " ^
    "foreach (`$a in '%*'.Split('\"\"')) { " ^
    "  `$r = `$a.Trim().Trim('\"'); " ^
    "  if (`$r -and (Test-Path `$r)) { info `$r; hash `$r } " ^
    "}"

echo.
echo   Pulsa una tecla para cerrar...
pause >nul
"@
}

$batContent | Set-Content $batPath -Encoding ASCII
Write-OK "Creado: $batPath"
Write-Info "Arrastra archivos encima del icono 'CyberAnalizar' en tu Escritorio"

# ── 2. MENU DE CLIC DERECHO ──────────────────────────────────────
Write-Host ""
Write-Step "Menu de clic derecho en Explorer..."

$esAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $esAdmin) {
    Write-Warn "Para el clic derecho necesitas ejecutar como Administrador."
    $instalarMenu = Read-Host "  Quieres abrir una ventana elevada para instalarlo? (S/n)"
    if ($instalarMenu -in @("", "s", "S", "si", "Si")) {
        $tempScript = Join-Path $env:TEMP "install-cybertools-menu.ps1"
        $menuScript = Get-MenuRegistryScript
        $menuScript | Set-Content $tempScript -Encoding UTF8
        Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$tempScript`"" -Verb RunAs -Wait
        Remove-Item $tempScript -ErrorAction SilentlyContinue
    } else {
        Write-Info "Puedes instalarlo luego ejecutando este script como Admin."
    }
} else {
    Install-ContextMenu
}

# ── 3. FUNCION 'recibir' ─────────────────────────────────────────
Write-Host ""
Write-OK "Funcion 'recibir' disponible en esta sesion"
Write-Info "Uso: recibir C:\archivo.pdf 'C:\otro archivo.docx'"

# ── 4. OFRECER ANADIR AL $PROFILE ────────────────────────────────
Write-Host ""
$agregarProfile = Read-Host "  Quieres que 'recibir' se cargue siempre al abrir PowerShell? (S/n)"
if ($agregarProfile -in @("", "s", "S", "si", "Si")) {
    if (-not (Test-Path $PROFILE)) {
        New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    }
    $profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
    if ($profileContent -notmatch "function.*recibir") {
        $recibirFunc = @'

# CyberTools: funcion recibir (arrastra archivos a la terminal)
function recibir {
    param([Parameter(Position=0, ValueFromRemainingArguments)][string[]]$Rutas)
    if (-not $Rutas) { Write-Host "  Uso: recibir <ruta1> [ruta2]..." -ForegroundColor Yellow; return }
    foreach ($r in $Rutas) {
        $ruta = $r.Trim().Trim('"').Trim("'")
        if (-not (Test-Path $ruta)) { Write-Host "  No existe: $ruta" -ForegroundColor Red; continue }
        if (Get-Command info -EA SilentlyContinue) { info $ruta } else {
            $i = Get-Item $ruta -Force
            Write-Host "  $($i.Name) — $([math]::Round($i.Length/1KB,1)) KB" -ForegroundColor Cyan
        }
        if (-not (Get-Item $ruta).PSIsContainer) {
            if (Get-Command hash -EA SilentlyContinue) { hash $ruta }
            else { Write-Host "  SHA256: $((Get-FileHash $ruta).Hash)" -ForegroundColor DarkGray }
        }
    }
}
'@
        Add-Content -Path $PROFILE -Value $recibirFunc
        Write-OK "Funcion 'recibir' anadida a tu `$PROFILE"
    } else {
        Write-OK "Ya existe 'recibir' en tu `$PROFILE"
    }
}

# ── Resumen ──────────────────────────────────────────────────────
Write-Host ""
Write-Host "${esc}[38;2;57;255;20m  ========================================${esc}[0m"
Write-Host "${esc}[38;2;57;255;20m   Instalacion completada                 ${esc}[0m"
Write-Host "${esc}[38;2;57;255;20m  ========================================${esc}[0m"
Write-Host ""
Write-Info "3 formas de analizar archivos:"
Write-Host ""
Write-Host "${esc}[38;2;252;238;10m  1. Arrastrar${esc}[0m archivos encima de 'CyberAnalizar.bat' en el Escritorio"
Write-Host "${esc}[38;2;252;238;10m  2. Clic derecho${esc}[0m en Explorer > 'Analizar con CyberTools'"
Write-Host "${esc}[38;2;252;238;10m  3. En la terminal:${esc}[0m recibir C:\ruta\archivo.pdf"
Write-Host ""
Write-Info "Para desinstalar el menu: Uninstall-CyberToolsMenu (como Admin)"
Write-Host ""
