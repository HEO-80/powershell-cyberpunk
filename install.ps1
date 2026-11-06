# ================================================================= #
#           powershell-cyberpunk · install.ps1                      #
#         github.com/HEO-80/powershell-cyberpunk                    #
#                                                                   #
#  ONE-LINER (paste this in PowerShell):                           #
#    irm https://raw.githubusercontent.com/HEO-80/powershell-cyberpunk/main/install.ps1 | iex
#                                                                   #
#  OR clone and run locally:                                        #
#    git clone https://github.com/HEO-80/powershell-cyberpunk      #
#    .\powershell-cyberpunk\install.ps1                             #
# ================================================================= #

$ErrorActionPreference = "Stop"
$esc = [char]27

function Write-Step  { param($t) Write-Host "${esc}[38;2;252;238;10m  > $t${esc}[0m" }
function Write-OK    { param($t) Write-Host "${esc}[38;2;57;255;20m  OK $t${esc}[0m" }
function Write-Warn  { param($t) Write-Host "${esc}[38;2;198;120;221m  ! $t${esc}[0m" }
function Write-Fail  { param($t) Write-Host "${esc}[38;2;255;48;48m  X $t${esc}[0m" }

Write-Host ""
Write-Host "${esc}[38;2;252;238;10m  ========================================${esc}[0m"
Write-Host "${esc}[38;2;252;238;10m   powershell-cyberpunk  ·  installer     ${esc}[0m"
Write-Host "${esc}[38;2;252;238;10m  ========================================${esc}[0m"
Write-Host ""

# ── 0. Determine install directory ────────────────────────────────
# If run via irm|iex, $PSScriptRoot is empty — clone the repo
$_root = $PSScriptRoot
$_cloned = $false

if (-not $_root -or -not (Test-Path (Join-Path $_root "themes"))) {
    # Running from irm|iex — need to clone
    $_installDir = Join-Path $HOME ".powershell-cyberpunk"

    if (Test-Path $_installDir) {
        Write-Step "Updating existing installation..."
        git -C $_installDir pull --ff-only 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "Could not update. Removing and re-cloning..."
            Remove-Item $_installDir -Recurse -Force
        }
    }

    if (-not (Test-Path $_installDir)) {
        # Install Git automatically if missing
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            Write-Warn "Git no esta instalado. Instalando..."
            winget install Git.Git -s winget --accept-package-agreements --accept-source-agreements 2>$null
            # Refresh PATH so git is available now
            $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
            if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
                Write-Fail "No se pudo instalar Git automaticamente."
                Write-Fail "Instala Git manualmente: https://git-scm.com/download/win"
                return
            }
            Write-OK "Git instalado"
        }

        Write-Step "Cloning powershell-cyberpunk..."
        git clone --depth 1 https://github.com/HEO-80/powershell-cyberpunk.git $_installDir
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "git clone failed."
            return
        }
    }

    $_root = $_installDir
    $_cloned = $true
    Write-OK "Repository ready at $_root"
}

# ── 1. Check & install Oh My Posh ────────────────────────────────
Write-Step "Checking Oh My Posh..."
if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
    Write-Warn "Installing Oh My Posh via winget..."
    winget install JanDeDobbeleer.OhMyPosh -s winget --accept-package-agreements --accept-source-agreements 2>$null
    # Refresh PATH
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
    Write-OK "Oh My Posh installed"
} else { Write-OK "Oh My Posh already installed" }

# ── 2. Install Nerd Font (CaskaydiaCove) ─────────────────────────
Write-Step "Checking Nerd Font..."
$_fontInstalled = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Windows\Fonts\*CaskaydiaCove*" -ErrorAction SilentlyContinue
if (-not $_fontInstalled) {
    $_fontInstalled = Get-ChildItem "C:\Windows\Fonts\*CaskaydiaCove*" -ErrorAction SilentlyContinue
}
if (-not $_fontInstalled) {
    Write-Warn "Installing CaskaydiaCove Nerd Font via oh-my-posh..."
    try {
        oh-my-posh font install CascadiaCode 2>$null
        Write-OK "CaskaydiaCove Nerd Font installed"
    } catch {
        Write-Warn "Could not auto-install font. Download manually from: https://www.nerdfonts.com/font-downloads"
    }
} else { Write-OK "Nerd Font already installed" }

# ── 3. Install PowerShell modules ────────────────────────────────
$_modules = @("Terminal-Icons", "PSFzf")
foreach ($_mod in $_modules) {
    Write-Step "Checking module: $_mod..."
    if (-not (Get-Module -ListAvailable -Name $_mod -ErrorAction SilentlyContinue)) {
        Write-Warn "Installing $_mod..."
        Install-Module $_mod -Scope CurrentUser -Force -SkipPublisherCheck
        Write-OK "$_mod installed"
    } else { Write-OK "$_mod already installed" }
}

# ── 4. Install CLI tools ─────────────────────────────────────────
Write-Step "Checking fzf..."
if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
    Write-Warn "Installing fzf via winget..."
    winget install junegunn.fzf -s winget --accept-package-agreements --accept-source-agreements 2>$null
    Write-OK "fzf installed"
} else { Write-OK "fzf already installed" }

Write-Step "Checking zoxide..."
if (-not (Get-Command zoxide -ErrorAction SilentlyContinue)) {
    Write-Warn "Installing zoxide via winget..."
    winget install ajeetdsouza.zoxide -s winget --accept-package-agreements --accept-source-agreements 2>$null
    Write-OK "zoxide installed"
} else { Write-OK "zoxide already installed" }

# ── 5. Hook into $PROFILE ────────────────────────────────────────
Write-Step "Setting up PowerShell profile..."
$_profileLine = ". `"$_root\Profile.ps1`""

if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    Write-Warn "Created new profile at: $PROFILE"
}

$_profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
if ($_profileContent -notmatch [regex]::Escape("powershell-cyberpunk")) {
    Add-Content -Path $PROFILE -Value "`n# powershell-cyberpunk`n$_profileLine"
    Write-OK "Profile hooked: $PROFILE"
} else {
    Write-OK "Profile already configured"
}

# ── Done ─────────────────────────────────────────────────────────
Write-Host ""
Write-Host "${esc}[38;2;57;255;20m  ========================================${esc}[0m"
Write-Host "${esc}[38;2;57;255;20m   Installation complete!                 ${esc}[0m"
Write-Host "${esc}[38;2;57;255;20m  ========================================${esc}[0m"
Write-Host ""
Write-Host "  Restart PowerShell or run: ${esc}[38;2;252;238;10m. `$PROFILE${esc}[0m"
Write-Host ""
Write-Host "  ${esc}[38;2;136;136;136mIMPORTANT: Set your terminal font to 'CaskaydiaCove Nerd Font'${esc}[0m"
Write-Host "  ${esc}[38;2;136;136;136mWindows Terminal: Settings > Profiles > Defaults > Font Face${esc}[0m"
Write-Host ""
