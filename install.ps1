# ================================================================= #
#           powershell-cyberpunk · install.ps1                      #
#         github.com/HEO-80/powershell-cyberpunk                    #
#                                                                   #
#  Run this script once to set up everything:                       #
#    .\install.ps1                                                   #
# ================================================================= #

$ErrorActionPreference = "Stop"
$esc = [char]27

function Write-Step  { param($t) Write-Host "${esc}[38;2;252;238;10m  ❯ $t${esc}[0m" }
function Write-OK    { param($t) Write-Host "${esc}[38;2;57;255;20m  ✔ $t${esc}[0m" }
function Write-Warn  { param($t) Write-Host "${esc}[38;2;198;120;221m  ! $t${esc}[0m" }
function Write-Fail  { param($t) Write-Host "${esc}[38;2;255;48;48m  ✘ $t${esc}[0m" }

Write-Host ""
Write-Host "${esc}[38;2;252;238;10m  ╔══════════════════════════════════════╗${esc}[0m"
Write-Host "${esc}[38;2;252;238;10m  ║   powershell-cyberpunk · installer   ║${esc}[0m"
Write-Host "${esc}[38;2;252;238;10m  ╚══════════════════════════════════════╝${esc}[0m"
Write-Host ""

$_root = $PSScriptRoot

# ── 1. Check Scoop ────────────────────────────────────────────────
Write-Step "Checking Scoop..."
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Warn "Scoop not found. Installing..."
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
    Write-OK "Scoop installed"
} else { Write-OK "Scoop already installed" }

# ── 2. Install Oh My Posh ─────────────────────────────────────────
Write-Step "Checking Oh My Posh..."
if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
    Write-Warn "Installing Oh My Posh via winget..."
    winget install JanDeDobbeleer.OhMyPosh -s winget --accept-package-agreements --accept-source-agreements
    Write-OK "Oh My Posh installed"
} else { Write-OK "Oh My Posh already installed" }

# ── 3. Install PowerShell modules ────────────────────────────────
$modules = @("Terminal-Icons", "PSReadLine", "z", "PSFzf")
foreach ($mod in $modules) {
    Write-Step "Checking module: $mod..."
    if (-not (Get-Module -ListAvailable -Name $mod -ErrorAction SilentlyContinue)) {
        Write-Warn "Installing $mod..."
        Install-Module $mod -Scope CurrentUser -Force -SkipPublisherCheck
        Write-OK "$mod installed"
    } else { Write-OK "$mod already installed" }
}

# ── 4. Install fzf ───────────────────────────────────────────────
Write-Step "Checking fzf..."
if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
    Write-Warn "Installing fzf via scoop..."
    scoop install fzf
    Write-OK "fzf installed"
} else { Write-OK "fzf already installed" }

# ── 5. Hook into $PROFILE ────────────────────────────────────────
Write-Step "Setting up PowerShell profile..."
# $profileDir  = Split-Path $PROFILE
$profileLine = ". `"$_root\profile.ps1`""

if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    Write-Warn "Created new profile at: $PROFILE"
}

$profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
if ($profileContent -notmatch [regex]::Escape("powershell-cyberpunk")) {
    Add-Content -Path $PROFILE -Value "`n# powershell-cyberpunk`n$profileLine"
    Write-OK "Profile hooked: $PROFILE"
} else {
    Write-OK "Profile already configured"
}

# ── 6. Optional: SSH server config ──────────────────────────────
Write-Host ""
Write-Warn "Optional: configure SSH shortcut (bee command)"
Write-Host "  Set these env vars in your Windows Terminal profile or system env:" -ForegroundColor DarkGray
Write-Host "    CYBER_SSH_HOST = your-server-ip" -ForegroundColor DarkGray
Write-Host "    CYBER_SSH_USER = your-username" -ForegroundColor DarkGray
Write-Host "    CYBER_SSH_PORT = 22  (optional, default 22)" -ForegroundColor DarkGray

# ── Done ─────────────────────────────────────────────────────────
Write-Host ""
Write-Host "${esc}[38;2;57;255;20m  ══════════════════════════════════════${esc}[0m"
Write-Host "${esc}[38;2;57;255;20m  ✔ Installation complete!${esc}[0m"
Write-Host "${esc}[38;2;57;255;20m  ══════════════════════════════════════${esc}[0m"
Write-Host ""
Write-Host "  Restart PowerShell or run: ${esc}[38;2;252;238;10m. `$PROFILE${esc}[0m"
Write-Host ""