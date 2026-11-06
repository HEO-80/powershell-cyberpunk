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
        $null = git -C $_installDir pull --ff-only 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "Could not update. Removing and re-cloning..."
            Remove-Item $_installDir -Recurse -Force
        }
    }

    if (-not (Test-Path $_installDir)) {
        # Install Git automatically if missing
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            Write-Warn "Git no esta instalado. Instalando..."

            # Intento 1: winget
            $_gitInstalled = $false
            if (Get-Command winget -ErrorAction SilentlyContinue) {
                Write-Step "Intentando con winget..."
                winget install Git.Git -s winget --accept-package-agreements --accept-source-agreements 2>$null
                $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
                if (Get-Command git -ErrorAction SilentlyContinue) { $_gitInstalled = $true }
            }

            # Intento 2: descarga directa e instalacion silenciosa
            if (-not $_gitInstalled) {
                Write-Step "Descargando Git directamente..."
                $_gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.1/Git-2.47.1-64-bit.exe"
                $_gitExe = Join-Path $env:TEMP "git-installer.exe"
                try {
                    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                    (New-Object System.Net.WebClient).DownloadFile($_gitUrl, $_gitExe)
                    Write-Step "Instalando Git (silencioso)..."
                    Start-Process $_gitExe -ArgumentList "/VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /COMPONENTS=`"icons,ext\reg\shellhere,assoc,assoc_sh`"" -Wait
                    Remove-Item $_gitExe -ErrorAction SilentlyContinue
                    # Refresh PATH
                    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
                    # Git se instala en Program Files, anadirlo al PATH de la sesion
                    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
                        $gitPath = "C:\Program Files\Git\cmd"
                        if (Test-Path $gitPath) { $env:PATH += ";$gitPath" }
                    }
                    if (Get-Command git -ErrorAction SilentlyContinue) { $_gitInstalled = $true }
                } catch {
                    Write-Warn "No se pudo descargar: $($_.Exception.Message)"
                }
            }

            if (-not $_gitInstalled) {
                Write-Fail "No se pudo instalar Git."
                Write-Fail "Instala manualmente: https://git-scm.com/download/win"
                return
            }
            Write-OK "Git instalado: $(git --version)"
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
    # Intento 1: oh-my-posh font install
    $_fontOK = $false
    if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
        Write-Warn "Installing CaskaydiaCove Nerd Font via oh-my-posh..."
        try {
            oh-my-posh font install CascadiaCode 2>$null
            $_fontOK = $true
        } catch {}
    }
    # Intento 2: descarga directa del ZIP de Nerd Fonts
    if (-not $_fontOK) {
        Write-Step "Descargando fuente directamente..."
        try {
            $_fontZip = Join-Path $env:TEMP "CascadiaCode-NF.zip"
            $_fontDir = Join-Path $env:TEMP "CascadiaCode-NF"
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            (New-Object System.Net.WebClient).DownloadFile("https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaCode.zip", $_fontZip)
            Expand-Archive $_fontZip -DestinationPath $_fontDir -Force
            # Instalar fuentes en la carpeta de usuario
            $fontsFolder = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
            if (-not (Test-Path $fontsFolder)) { New-Item -ItemType Directory -Path $fontsFolder -Force | Out-Null }
            Get-ChildItem $_fontDir -Filter "*.ttf" | ForEach-Object {
                Copy-Item $_.FullName $fontsFolder -Force
            }
            Remove-Item $_fontZip, $_fontDir -Recurse -Force -ErrorAction SilentlyContinue
            $_fontOK = $true
        } catch {
            Write-Warn "No se pudo instalar la fuente: $($_.Exception.Message)"
        }
    }
    if ($_fontOK) { Write-OK "CaskaydiaCove Nerd Font installed" }
    else { Write-Warn "Descarga la fuente manualmente: https://www.nerdfonts.com/font-downloads" }
} else { Write-OK "Nerd Font already installed" }

# ── 3. Install PowerShell modules ────────────────────────────────
# Instalar NuGet silenciosamente para evitar que pregunte
if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue | Where-Object { $_.Version -ge "2.8.5.201" })) {
    Write-Step "Installing NuGet provider..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction SilentlyContinue | Out-Null
}

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
