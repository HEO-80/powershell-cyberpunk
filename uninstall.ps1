& {

$esc = [char]27

function Write-Step  { param($t) Write-Host "${esc}[38;2;252;238;10m  > $t${esc}[0m" }
function Write-OK    { param($t) Write-Host "${esc}[38;2;57;255;20m  OK $t${esc}[0m" }
function Write-Warn  { param($t) Write-Host "${esc}[38;2;198;120;221m  ! $t${esc}[0m" }

Write-Host ""
Write-Host "${esc}[38;2;255;48;48m  ========================================${esc}[0m"
Write-Host "${esc}[38;2;255;48;48m   powershell-cyberpunk  ·  uninstaller   ${esc}[0m"
Write-Host "${esc}[38;2;255;48;48m  ========================================${esc}[0m"
Write-Host ""

$confirmar = Read-Host "  Esto va a desinstalar powershell-cyberpunk. Seguro? (s/N)"
if ($confirmar -notin @("s", "S", "si", "Si", "y", "Y")) {
    Write-Host "  Cancelado." -ForegroundColor DarkGray
    return
}

Write-Host ""

# ── 1. Quitar hook del $PROFILE ──────────────────────────────────
Write-Step "Limpiando `$PROFILE..."
if (Test-Path $PROFILE) {
    $lines = Get-Content $PROFILE
    $newLines = $lines | Where-Object { $_ -notmatch "powershell-cyberpunk" }
    if ($newLines.Count -lt $lines.Count) {
        $newLines | Set-Content $PROFILE -Encoding UTF8
        Write-OK "Hook eliminado de `$PROFILE"
    } else {
        Write-OK "No habia hook en `$PROFILE"
    }
    # Si el perfil quedo vacio, borrarlo
    $content = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
    if (-not $content -or $content.Trim().Length -eq 0) {
        Remove-Item $PROFILE -Force -ErrorAction SilentlyContinue
        Write-OK "Archivo `$PROFILE vacio eliminado"
    }
}

# ── 2. Borrar repo clonado ───────────────────────────────────────
Write-Step "Eliminando archivos..."
$repoDir = Join-Path $HOME ".powershell-cyberpunk"
if (Test-Path $repoDir) {
    Remove-Item $repoDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-OK "Eliminado: $repoDir"
} else {
    Write-OK "No existia: $repoDir"
}

# ── 3. Restaurar fuente de Windows Terminal ──────────────────────
Write-Step "Restaurando fuente de Windows Terminal..."
$fontRestored = $false
foreach ($wtPath in @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
)) {
    if (Test-Path $wtPath) {
        try {
            $wt = Get-Content $wtPath -Raw | ConvertFrom-Json
            if ($wt.profiles.defaults.font.face -eq "CaskaydiaCove Nerd Font") {
                $wt.profiles.defaults.font.face = "Cascadia Mono"
                $wt | ConvertTo-Json -Depth 20 | Set-Content $wtPath -Encoding UTF8
                Write-OK "Fuente restaurada a Cascadia Mono"
                $fontRestored = $true
            }
        } catch {}
    }
}
if (-not $fontRestored) { Write-OK "No habia fuente que restaurar" }

# ── 4. Quitar CyberAnalizar.bat del escritorio ───────────────────
$batPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "CyberAnalizar.bat"
if (Test-Path $batPath) {
    Remove-Item $batPath -Force
    Write-OK "Eliminado: CyberAnalizar.bat del escritorio"
}

# ── 5. Quitar menu de clic derecho (si somos admin) ──────────────
$esAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($esAdmin) {
    Write-Step "Eliminando menu de clic derecho..."
    foreach ($clave in @(
        "Registry::HKEY_CLASSES_ROOT\*\shell\CyberToolsAnalizar",
        "Registry::HKEY_CLASSES_ROOT\Directory\shell\CyberToolsAnalizar",
        "Registry::HKEY_CLASSES_ROOT\Directory\Background\shell\CyberToolsAnalizar"
    )) {
        if (Test-Path $clave) {
            Remove-Item $clave -Recurse -Force
            Write-OK "Eliminado: clic derecho"
        }
    }
}

# ── 6. Preguntar si desinstalar programas ────────────────────────
Write-Host ""
$desinstalarProgs = Read-Host "  Desinstalar tambien Git, Oh My Posh, fzf y zoxide? (s/N)"
if ($desinstalarProgs -in @("s", "S", "si", "Si")) {
    foreach ($prog in @(
        @{ Name = "Oh My Posh";  Pkg = "JanDeDobbeleer.OhMyPosh" },
        @{ Name = "fzf";         Pkg = "junegunn.fzf" },
        @{ Name = "zoxide";      Pkg = "ajeetdsouza.zoxide" }
    )) {
        Write-Step "Desinstalando $($prog.Name)..."
        winget uninstall $prog.Pkg --silent 2>$null
    }
    # Git se pregunta aparte porque es mas critico
    $quitarGit = Read-Host "  Desinstalar Git tambien? Otros programas pueden necesitarlo (s/N)"
    if ($quitarGit -in @("s", "S", "si", "Si")) {
        Write-Step "Desinstalando Git..."
        winget uninstall Git.Git --silent 2>$null
    }

    # Eliminar modulos de PowerShell
    Write-Step "Desinstalando modulos PowerShell..."
    Remove-Module Terminal-Icons -Force -ErrorAction SilentlyContinue
    Remove-Module PSFzf -Force -ErrorAction SilentlyContinue
    Uninstall-Module Terminal-Icons -Force -ErrorAction SilentlyContinue
    Uninstall-Module PSFzf -Force -ErrorAction SilentlyContinue
    Write-OK "Modulos eliminados"
}

# ── Done ─────────────────────────────────────────────────────────
Write-Host ""
Write-Host "${esc}[38;2;57;255;20m  ========================================${esc}[0m"
Write-Host "${esc}[38;2;57;255;20m   Desinstalacion completada              ${esc}[0m"
Write-Host "${esc}[38;2;57;255;20m  ========================================${esc}[0m"
Write-Host ""
Write-Host "  Cierra y abre PowerShell para volver a la terminal por defecto."
Write-Host ""

} # fin del bloque & { }
