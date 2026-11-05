# ================================================================= #
#              powershell-cyberpunk · Profile.ps1                   #
#         github.com/HEO-80/powershell-cyberpunk                    #
#                                                                   #
#  HOW TO USE:                                                      #
#    1. Run install.ps1 (recommended)                               #
#    OR                                                             #
#    2. Add this line to your $PROFILE:                             #
#       . "C:\path\to\powershell-cyberpunk\Profile.ps1"            #
# ================================================================= #

# GUARD: prevent double load
if ($global:CyberProfileLoaded) { return }
$global:CyberProfileLoaded = $true

# Console UTF-8 (icons, accents, ASCII art blocks)
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding  = [System.Text.Encoding]::UTF8
    $OutputEncoding           = [System.Text.Encoding]::UTF8
} catch {}

$_root = $PSScriptRoot

# ── Available themes ──────────────────────────────────────────────
$global:CyberThemes = @{
    "cyberpunk" = Join-Path $_root "themes\Cyberpunk2077.ps1"
}

# ── Switch theme at runtime ───────────────────────────────────────
function Set-Theme {
    param(
        [Parameter(Mandatory)]
        [ArgumentCompleter({ $global:CyberThemes.Keys | Sort-Object })]
        [ValidateScript({ $global:CyberThemes.ContainsKey($_) })]
        [string]$Name
    )
    $file = $global:CyberThemes[$Name]
    if (-not (Test-Path $file)) {
        Write-Host "Error: theme '$Name' not found at: $file" -ForegroundColor Red
        return
    }
    Write-Host "Switching to theme: $Name" -ForegroundColor Green
    . $file
}

# ── Load default theme ────────────────────────────────────────────
$_theme = if ($env:CYBER_THEME) { $env:CYBER_THEME } else { "cyberpunk" }

$_themeFile = $global:CyberThemes[$_theme]
if (Test-Path $_themeFile) {
    . $_themeFile
} else {
    Write-Host "[powershell-cyberpunk] Theme '$_theme' not found. Run install.ps1" -ForegroundColor Red
}
