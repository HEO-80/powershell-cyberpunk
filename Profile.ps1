# ================================================================= #
#              powershell-cyberpunk · profile.ps1                   #
#         github.com/HEO-80/powershell-cyberpunk                    #
#                                                                   #
#  HOW TO USE:                                                      #
#    1. Run install.ps1 (recommended)                               #
#    OR                                                             #
#    2. Add this line to your $PROFILE:                             #
#       . "C:\path\to\powershell-cyberpunk\profile.ps1"            #
# ================================================================= #

# GUARD: prevent double load
if ($global:CyberProfileLoaded) { return }
$global:CyberProfileLoaded = $true

$_root = $PSScriptRoot

# ── Available themes ──────────────────────────────────────────────
$global:CyberThemes = @{
    "cyberpunk" = Join-Path $_root "themes\Cyberpunk2077.ps1"
    "default"   = Join-Path $_root "themes\Default.ps1"
}

# ── Switch theme at runtime ───────────────────────────────────────
#    Usage: Set-Theme cyberpunk
#           Set-Theme default
function Set-Theme {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("cyberpunk","default")]
        [string]$Name
    )
    $file = $global:CyberThemes[$Name]
    if (Test-Path $file) {
        Write-Host "Switching to theme: $Name" -ForegroundColor Green
        . $file
    } else {
        Write-Host "Theme '$Name' not found at: $file" -ForegroundColor Red
    }
}

# ── Load default theme ────────────────────────────────────────────
#    Override by setting $env:CYBER_THEME before loading this file
#    e.g. in Windows Terminal settings: "CYBER_THEME": "default"
$_theme = if ($env:CYBER_THEME) { $env:CYBER_THEME } else { "cyberpunk" }

$_themeFile = $global:CyberThemes[$_theme]
if (Test-Path $_themeFile) {
    . $_themeFile
} else {
    Write-Host "[powershell-cyberpunk] Theme '$_theme' not found. Run install.ps1" -ForegroundColor Red
}