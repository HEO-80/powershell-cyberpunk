# ================================================================= #
#                    TEMA: CyberPunk 2077                           #
#          Cyberpunk-themed PowerShell environment                  #
#          github.com/HEO-80/powershell-cyberpunk                   #
# ================================================================= #

Clear-Host

# ── ANSI color helper ─────────────────────────────────────────────
function Write-Cyber {
    param(
        [string]$Text,
        [string]$Color = "#FCEE0A",
        [switch]$NoNewline
    )
    $esc   = [char]27
    $r     = [Convert]::ToInt32($Color.Substring(1,2), 16)
    $g     = [Convert]::ToInt32($Color.Substring(3,2), 16)
    $b     = [Convert]::ToInt32($Color.Substring(5,2), 16)
    $ansi  = "${esc}[38;2;${r};${g};${b}m"
    $reset = "${esc}[0m"
    if ($NoNewline) { Write-Host "$ansi$Text$reset" -NoNewline }
    else            { Write-Host "$ansi$Text$reset" }
}

# ── Global color palette — edit these to change the whole theme ───
$global:CY = @{
    Yellow  = "#FCEE0A"   # Main accent — NETWATCH yellow
    Green   = "#39FF14"   # Success / git clean
    Cyan    = "#00F0FF"   # Info / values
    Magenta = "#C678DD"   # Separators / secondary
    Dark    = "#555555"   # Borders
    Dim     = "#888888"   # Muted text
}

# ================================================================= #
#                        MODULES                                    #
# ================================================================= #
$_mods = @("Terminal-Icons", "PSReadLine", "z")
foreach ($_m in $_mods) {
    if (Get-Module -ListAvailable -Name $_m -ErrorAction SilentlyContinue) {
        Import-Module $_m -ErrorAction SilentlyContinue
    }
}

# PSFzf — load only if fzf binary is present
$_fzf = (Get-Command fzf -ErrorAction SilentlyContinue)
if (-not $_fzf) {
    # fallback: try WinGet packages folder
    $_fzf = (Get-ChildItem "$env:LocalAppData\Microsoft\WinGet\Packages\junegunn.fzf*\fzf.exe" -ErrorAction SilentlyContinue)
    if ($_fzf) { $env:PATH += ";$($_fzf.DirectoryName)" }
}
if (Get-Command fzf -ErrorAction SilentlyContinue) {
    if (Get-Module -ListAvailable -Name PSFzf -ErrorAction SilentlyContinue) {
        Import-Module PSFzf
        Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
    }
}

Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle InlineView

# ================================================================= #
#                        OH MY POSH                                 #
# ================================================================= #
$_ompExe = (Get-Command oh-my-posh -ErrorAction SilentlyContinue)?.Source
if (-not $_ompExe) {
    $_ompExe = "$env:LOCALAPPDATA\Microsoft\WindowsApps\oh-my-posh.exe"
}
$_ompTheme = Join-Path $PSScriptRoot "omp_cyberpunk.json"

if ((Test-Path $_ompExe) -and (Test-Path $_ompTheme)) {
    & $_ompExe init pwsh --config $_ompTheme | Invoke-Expression
} else {
    Write-Cyber "  [WARN] Oh My Posh or theme not found. Run install.ps1 first." $global:CY.Magenta
}

# ================================================================= #
#                    PERSONAL SHORTCUTS                             #
#     Edit this section to add your own aliases and functions       #
# ================================================================= #

# --- Quick launchers (customize these) ---
# function n    { start https://www.notion.so/ }
# function o    { start obsidian:// }
# function g    { start https://mail.google.com }
# function vsc  { code . }

# --- SSH server shortcut ---
# Usage: bee   →  connects to your home server via SSH
# Edit $ServerIP and $User below to match your setup
function Invoke-ServerSSH {
    $ServerIP = $env:CYBER_SSH_HOST   # set via $env or edit directly
    $User     = $env:CYBER_SSH_USER
    $Port     = if ($env:CYBER_SSH_PORT) { $env:CYBER_SSH_PORT } else { "22" }

    if (-not $ServerIP -or -not $User) {
        Write-Cyber "  Set CYBER_SSH_HOST and CYBER_SSH_USER env vars, or edit profile.ps1" $global:CY.Magenta
        return
    }

    Write-Cyber "  Scanning for $ServerIP ..." $global:CY.Yellow -NoNewline
    if (Test-Connection -ComputerName $ServerIP -Count 1 -Quiet) {
        Write-Cyber " [ONLINE]" $global:CY.Green
        ssh "$User@$ServerIP" -p $Port
    } else {
        Write-Cyber " [OFFLINE]" "#FF3030"
    }
}
Set-Alias bee Invoke-ServerSSH

# ================================================================= #
#                          DASHBOARD                                #
# ================================================================= #
function Show-Dashboard {
    $c = $global:CY

    $cpuName = (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue)?.Name `
        -replace 'AMD |Intel\(R\) | \d+-Core| Processor| @.*$', ''

    $sysInfo = [ordered]@{
        "Started" = (Get-Date -Format "yyyy-MM-dd HH:mm")
        "Shell"   = "$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor) $($PSVersionTable.PSEdition)"
        "CPU"     = if ($cpuName) { $cpuName.Trim() } else { "N/A" }
        "RAM"     = "{0:N2} GB" -f ((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
        "User"    = "$env:USERNAME"
        "OS"      = (Get-CimInstance Win32_OperatingSystem).Caption
    }

    # ── Shortcuts — edit to match your tools ──────────────────────
    $shortcuts = @(
        @{ Label = "VS Code   (vsc)";  Value = "code ." }
        @{ Label = "Projects  (proj)"; Value = "code <your-repos-path>" }
        @{ Label = "Server    (bee)";  Value = "ssh via CYBER_SSH_HOST" }
        @{ Label = "Help      (help-ps)"; Value = "show all commands" }
    )

    $features = @(
        @{ Key = "ls / dir";    Desc = "Terminal-Icons   ->  icons next to files and folders" }
        @{ Key = "Ctrl+T";      Desc = "Fzf Search       ->  interactive file finder" }
        @{ Key = "Ctrl+R";      Desc = "Fzf History      ->  search command history" }
        @{ Key = "Arrow  ->";   Desc = "Autocomplete     ->  accept grey suggestion" }
        @{ Key = "help-ps";     Desc = "Help             ->  list all available commands" }
    )

    $sep  = "=" * 80
    $sep2 = "-" * 80

    Write-Cyber $sep $c.Magenta
    Write-Host ""
    Write-Cyber "$("System Info".PadRight(38))| Shortcuts" $c.Green
    Write-Host ""

    $maxLines = [Math]::Max($sysInfo.Count, $shortcuts.Count)
    $sysKeys  = @($sysInfo.Keys)

    for ($i = 0; $i -lt $maxLines; $i++) {
        if ($i -lt $sysKeys.Count) {
            $k = $sysKeys[$i]
            Write-Cyber "$($k.PadRight(10))" $c.Yellow -NoNewline
            Write-Cyber ": " $c.Magenta -NoNewline
            Write-Cyber "$("$($sysInfo[$k])".PadRight(24))" $c.Cyan -NoNewline
        } else {
            Write-Host "".PadRight(38) -NoNewline
        }
        if ($i -lt $shortcuts.Count) {
            Write-Cyber "| " $c.Magenta -NoNewline
            Write-Cyber "$($shortcuts[$i].Label.PadRight(18))" $c.Yellow -NoNewline
            Write-Cyber " $($shortcuts[$i].Value)" $c.Cyan
        } else { Write-Host "" }
    }

    Write-Host ""
    Write-Cyber $sep2 $c.Magenta
    Write-Host ""
    Write-Cyber "  Features" $c.Green
    Write-Host ""
    foreach ($f in $features) {
        Write-Cyber "  $($f.Key.PadRight(14))" $c.Yellow -NoNewline
        Write-Cyber "  $($f.Desc)" $c.Cyan
    }

    # ── Docker status ─────────────────────────────────────────────
    Write-Host ""
    Write-Cyber $sep2 $c.Magenta
    Write-Host ""
    Write-Cyber "  Docker" $c.Green
    Write-Host ""

    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Cyber "  Docker not installed or not in PATH." $c.Dim
    } else {
        try {
            $containers = docker ps --format "{{.Names}}|{{.Image}}|{{.Status}}|{{.Ports}}" 2>$null
            if ($containers) {
                Write-Cyber "  $("NAME".PadRight(22)) $("IMAGE".PadRight(25)) $("STATUS".PadRight(20)) PORTS" $c.Cyan
                Write-Cyber "  $("-" * 76)" $c.Dark
                foreach ($line in $containers) {
                    $p = $line -split "\|"
                    Write-Cyber "  $($p[0].PadRight(22)) " $c.Yellow -NoNewline
                    Write-Cyber "$($p[1].PadRight(25)) " $c.Cyan -NoNewline
                    Write-Cyber "$($p[2].PadRight(20)) " $c.Green -NoNewline
                    Write-Cyber "$(if ($p[3]) { $p[3] } else { '-' })" $c.Dim
                }
            } else {
                Write-Cyber "  No active containers." $c.Dim
            }
        } catch {
            Write-Cyber "  Could not connect to Docker daemon." $c.Dim
        }
    }

    Write-Host ""
    Write-Cyber $sep $c.Magenta
    Write-Host ""
}

# ================================================================= #
#                            HELP                                   #
# ================================================================= #
function Show-Help {
    $c   = $global:CY
    $bar = "=" * 65

    $tools = @(
        @{ Name = "Terminal-Icons"; Use = "ls / dir";      Desc = "Icons next to files and folders" }
        @{ Name = "fzf (PSFzf)";   Use = "Ctrl+T";         Desc = "Interactive fuzzy file finder" }
        @{ Name = "fzf history";   Use = "Ctrl+R";         Desc = "Search command history" }
        @{ Name = "PSReadLine";    Use = "Arrow right";    Desc = "Accept autocomplete suggestion (grey)" }
        @{ Name = "z (zoxide)";    Use = "z folder";       Desc = "Jump to frecent directories" }
        @{ Name = "Oh My Posh";    Use = "(automatic)";    Desc = "Git branch, path, execution time prompt" }
    )

    $keys = @(
        @{ Key = "Tab";             Desc = "Autocomplete commands and paths" }
        @{ Key = "Ctrl+Space";      Desc = "Force suggestion list" }
        @{ Key = "Ctrl+T";          Desc = "Open fzf file finder" }
        @{ Key = "Ctrl+R";          Desc = "Search history with fzf" }
        @{ Key = "Ctrl+L";          Desc = "Clear screen" }
        @{ Key = "Ctrl+A / Ctrl+E"; Desc = "Go to start / end of line" }
        @{ Key = "Alt+D";           Desc = "Delete word forward" }
        @{ Key = "Ctrl+W";          Desc = "Delete word backward" }
    )

    $cmds = @(
        @{ Cmd = "Show-Dashboard";  Desc = "Show system dashboard" }
        @{ Cmd = "Set-Theme <name>";Desc = "Switch theme: cyberpunk | default" }
        @{ Cmd = "bee";             Desc = "SSH connect to CYBER_SSH_HOST server" }
        @{ Cmd = "help-ps";         Desc = "Show this help screen" }
    )

    Write-Host ""
    Write-Cyber $bar $c.Magenta
    Write-Cyber "  INSTALLED TOOLS" $c.Green
    Write-Cyber $bar $c.Magenta
    foreach ($t in $tools) {
        Write-Cyber "  $($t.Name.PadRight(18))" $c.Yellow -NoNewline
        Write-Cyber "$($t.Use.PadRight(18))" $c.Cyan -NoNewline
        Write-Cyber "$($t.Desc)" $c.Dim
    }
    Write-Host ""
    Write-Cyber $bar $c.Magenta
    Write-Cyber "  KEYBOARD SHORTCUTS" $c.Green
    Write-Cyber $bar $c.Magenta
    foreach ($k in $keys) {
        Write-Cyber "  $($k.Key.PadRight(22))" $c.Yellow -NoNewline
        Write-Cyber "$($k.Desc)" $c.Cyan
    }
    Write-Host ""
    Write-Cyber $bar $c.Magenta
    Write-Cyber "  COMMANDS" $c.Green
    Write-Cyber $bar $c.Magenta
    foreach ($cmd in $cmds) {
        Write-Cyber "  $($cmd.Cmd.PadRight(22))" $c.Yellow -NoNewline
        Write-Cyber "$($cmd.Desc)" $c.Cyan
    }
    Write-Host ""
}

Set-Alias help-ps Show-Help

# ── Show dashboard on startup ─────────────────────────────────────
Show-Dashboard