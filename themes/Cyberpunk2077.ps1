# ================================================================= #
#                    TEMA: CyberPunk 2077                           #
#          Cyberpunk-themed PowerShell environment                  #
#          github.com/HEO-80/powershell-cyberpunk                   #
# ================================================================= #
# IMPORTANTE: guardar como UTF-8 con BOM (o usar PowerShell 7).

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
function Import-ModuleSafe {
    param([string]$Name)
    try {
        Import-Module $Name -ErrorAction Stop
        return $true
    } catch {
        Write-Cyber "  [!] Missing module '$Name'  ->  Install-Module $Name -Scope CurrentUser" $global:CY.Dim
        return $false
    }
}

$null = Import-ModuleSafe "Terminal-Icons"

# zoxide
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
} else {
    Write-Cyber "  [!] zoxide not installed  ->  winget install ajeetdsouza.zoxide" $global:CY.Dim
}

# fzf + PSFzf
if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
    $fzfPath = Get-ChildItem "$env:LocalAppData\Microsoft\WinGet\Packages\junegunn.fzf*\fzf.exe" -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty DirectoryName
    if ($fzfPath) { $env:PATH += ";$fzfPath" }
}

# ── PSReadLine ────────────────────────────────────────────────────
try { Set-PSReadLineOption -PredictionSource History } catch {}
try { Set-PSReadLineOption -PredictionViewStyle InlineView } catch {}
Set-PSReadLineOption -HistoryNoDuplicates
Set-PSReadLineOption -BellStyle None

Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key Tab       -Function MenuComplete
Set-PSReadLineKeyHandler -Key Ctrl+a    -Function BeginningOfLine
Set-PSReadLineKeyHandler -Key Ctrl+e    -Function EndOfLine
Set-PSReadLineKeyHandler -Key Alt+d     -Function KillWord
Set-PSReadLineKeyHandler -Key Ctrl+w    -Function BackwardKillWord
Set-PSReadLineKeyHandler -Key Ctrl+l    -Function ClearScreen

if ((Get-Command fzf -ErrorAction SilentlyContinue) -and (Import-ModuleSafe "PSFzf")) {
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
}

# ================================================================= #
#                        OH MY POSH                                 #
# ================================================================= #
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh init pwsh --config (Join-Path $PSScriptRoot "omp_cyberpunk.json") | Invoke-Expression
} else {
    Write-Cyber "  [!] oh-my-posh not installed  ->  winget install JanDeDobbeleer.OhMyPosh" $global:CY.Dim
}

# ================================================================= #
#                 ERGONOMIC FUNCTIONS                               #
# ================================================================= #

# Top files by size in the current folder
function top-size ($count = 10) {
    Get-ChildItem -File -ErrorAction SilentlyContinue |
        Sort-Object Length -Descending |
        Select-Object -First $count Name, @{N="Size (MB)"; E={[math]::Round($_.Length / 1MB, 2)}}
}

# Top processes by CPU
function top-cpu ($count = 5) {
    Get-Process |
        Sort-Object CPU -Descending |
        Select-Object -First $count ProcessName, @{N="CPU (s)"; E={[math]::Round($_.CPU, 1)}}, @{N="RAM (MB)"; E={[math]::Round($_.WorkingSet64 / 1MB, 1)}}
}

# Kill a process by name (min 3 chars, asks confirmation)
function matar {
    param(
        [Parameter(Mandatory)]
        [ValidateLength(3,50)]
        [string]$Name
    )
    $procs = @(Get-Process -Name "*$Name*" -ErrorAction SilentlyContinue)
    if ($procs.Count -eq 0) {
        Write-Cyber "No matches for '*$Name*'." $global:CY.Dim
        return
    }
    $procs |
        Stop-Process -Confirm -PassThru |
        ForEach-Object { Write-Cyber "Stopped: $($_.ProcessName) (PID: $($_.Id))" $global:CY.Green }
}

# Listening ports with process names
function puertos {
    Get-NetTCPConnection -State Listen |
        Select-Object LocalAddress, LocalPort, OwningProcess,
            @{N="Process"; E={ (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName }} |
        Sort-Object LocalPort
}

# Clean .log/.tmp files — test with: clean-logs -WhatIf
function clean-logs {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param()
    Get-ChildItem -Include *.log, *.tmp -Recurse -File -ErrorAction SilentlyContinue |
        Remove-Item -Force -Verbose
}

# ================================================================= #
#                     LOAD TRAINING MODULES                        #
# ================================================================= #
# Only Motor.ps1 loads at startup (the Leitner engine, ~50ms).
# All other modules load ON DEMAND the first time you run their command.
# This saves ~3 seconds of startup time.

$_trainingDir = Join-Path (Split-Path $PSScriptRoot) "training"
if (Test-Path $_trainingDir) {
    # Motor.ps1 — always loaded (provides progress tracking for all modules)
    $ruta = Join-Path $_trainingDir "Motor.ps1"
    if (Test-Path $ruta) { try { . $ruta } catch {} }

    # Lazy-load wrapper: creates a stub function for each module.
    # The first time you call dojo/tatami/etc, it loads the real file and re-runs.
    function New-LazyTrainingCommand {
        param([string]$CommandName, [string]$FileName)
        $filePath = Join-Path $_trainingDir $FileName
        if (Test-Path $filePath) {
            $sb = [scriptblock]::Create(@"
                # Remove this stub and load the real module
                Remove-Item "Function:\$CommandName" -ErrorAction SilentlyContinue
                try { . "$filePath" } catch { Write-Host "Error loading $FileName : `$(`$_.Exception.Message)" -ForegroundColor Red; return }
                # Now call the real function with the original arguments
                if (Get-Command "$CommandName" -ErrorAction SilentlyContinue) { & "$CommandName" @args }
"@)
            Set-Item "Function:global:$CommandName" $sb
        }
    }

    # Register lazy stubs for each training module's entry-point commands
    # Dojo.ps1 -> dojo, quiz, rosetta
    New-LazyTrainingCommand "dojo"      "Dojo.ps1"
    New-LazyTrainingCommand "quiz"      "Dojo.ps1"
    New-LazyTrainingCommand "rosetta"   "Dojo.ps1"
    # Dojo2.ps1 -> dojo2
    New-LazyTrainingCommand "dojo2"     "Dojo2.ps1"
    # Tatami1.ps1 -> tatami
    New-LazyTrainingCommand "tatami"    "Tatami1.ps1"
    # Tatami2.ps1 -> tatami2
    New-LazyTrainingCommand "tatami2"   "Tatami2.ps1"
    # Forja.ps1 -> forja
    New-LazyTrainingCommand "forja"     "Forja.ps1"
    # Santuario.ps1 -> santuario
    New-LazyTrainingCommand "santuario" "Santuario.ps1"
}

# ================================================================= #
#                  DATA (dashboard + help)                         #
# ================================================================= #

$global:Shortcuts = @(
    @{ Label = "top-size [n]";      Value = "Biggest files in current folder" }
    @{ Label = "top-cpu [n]";       Value = "Top CPU-consuming processes" }
    @{ Label = "matar <name>";      Value = "Kill process by name (with confirm)" }
    @{ Label = "puertos";           Value = "Listening ports with process names" }
    @{ Label = "clean-logs";        Value = "Remove .log/.tmp recursively" }
    @{ Label = "help-ps";           Value = "Show all commands and keys" }
)

$global:HelpData = [ordered]@{
    "NAVIGATION (NO MOUSE)" = @(
        @{ K = "Shift + PgUp / PgDn";       D = "Scroll up/down in Windows Terminal" }
        @{ K = "Ctrl + Shift + Up/Down";     D = "Scroll line by line" }
        @{ K = "ls | more";                  D = "Paginate long output (Space advances, Q quits)" }
        @{ K = "cd -";                       D = "Go back to previous directory (PowerShell 7 only)" }
        @{ K = "z <name>";                   D = "zoxide: jump to frequently visited folders (zi = interactive)" }
    )
    "INSTALLED TOOLS" = @(
        @{ K = "Terminal-Icons"; D = "ls / dir  ->  icons next to files and folders" }
        @{ K = "fzf (PSFzf)";   D = "Fuzzy file/history search (see Ctrl+T / Ctrl+R)" }
        @{ K = "PSReadLine";    D = "Grey inline predictions from history (right arrow accepts)" }
        @{ K = "zoxide";        D = "z folder_name  ->  jump to visited folders" }
        @{ K = "Oh My Posh";    D = "Prompt with git branch, path and colors (automatic)" }
    )
    "KEYBOARD SHORTCUTS" = @(
        @{ K = "Tab";                    D = "Navigable autocomplete menu" }
        @{ K = "Ctrl + Space";           D = "Force autocomplete menu" }
        @{ K = "Up/Down arrows";         D = "History filtered by what you've typed" }
        @{ K = "Ctrl + T";              D = "fzf: find files in current folder" }
        @{ K = "Ctrl + R";              D = "fzf: search command history" }
        @{ K = "Ctrl + A / Ctrl + E";   D = "Start / end of line" }
        @{ K = "Alt + D";               D = "Delete word forward" }
        @{ K = "Ctrl + W";              D = "Delete word backward" }
        @{ K = "Ctrl + L";              D = "Clear screen" }
        @{ K = "Ctrl + C";              D = "Cancel running command" }
    )
    "FUNCTIONS" = @(
        @{ K = "top-size [n]";         D = "Top N biggest files in current folder" }
        @{ K = "top-cpu [n]";          D = "Top N processes by CPU usage" }
        @{ K = "matar <name>";         D = "Kill processes by name (min 3 chars, asks confirmation)" }
        @{ K = "puertos";              D = "Listening local ports with process names" }
        @{ K = "clean-logs [-WhatIf]"; D = "Delete .log and .tmp recursively (-WhatIf = dry run)" }
        @{ K = "dojo / quiz";          D = "Dojo 1 (command names): -Modo Linux|PowerShell|Cmd, -Preguntas N, -Repaso" }
        @{ K = "dojo2";                D = "Dojo 2 (full commands, intermediate): same options" }
        @{ K = "rosetta";              D = "Rosetta table: Linux / PowerShell / CMD equivalences" }
        @{ K = "tatami [-Repaso]";     D = "Tatami 1: basic practical missions in a temp sandbox" }
        @{ K = "tatami2 [-Repaso]";    D = "Tatami 2: intermediate missions (text, CSV, rename, try/catch)" }
        @{ K = "forja [-Repaso]";      D = "Forja: write PowerShell scripts with tests. -Nivel 1|2, -Id, -Lista, -Continuar" }
        @{ K = "santuario [-Repaso]";  D = "Santuario: write bash scripts (runs in WSL). -Nivel, -Id, -Lista, -Diagnostico" }
        @{ K = "progreso";             D = "Your stats: mastered, due for review, most-failed items (-Reset to clear)" }
        @{ K = "Show-Dashboard";       D = "Show dashboard (-Refresh updates cache, -SinDocker skips Docker)" }
        @{ K = "Measure-Profile";      D = "Measure profile load time" }
        @{ K = "help-ps";              D = "Show this help" }
    )
}

# ================================================================= #
#                            DASHBOARD                              #
# ================================================================= #
function Get-SysInfoCached {
    param([switch]$Refresh)
    $dir = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA "CyberProfile" } else { Join-Path $HOME ".cache/cyberprofile" }
    $file = Join-Path $dir "sysinfo.json"
    if ($Refresh -and (Test-Path $file)) { Remove-Item $file -Force -ErrorAction SilentlyContinue }
    if (Test-Path $file) {
        $edad = (Get-Date) - (Get-Item $file).LastWriteTime
        if ($edad.TotalHours -lt 24) {
            try { return (Get-Content $file -Raw | ConvertFrom-Json) } catch {}
        }
    }
    try {
        $cpu = ((Get-CimInstance Win32_Processor | Select-Object -First 1).Name -replace 'AMD |Intel\(R\) | \d+-Core| Processor| @.*$', '').Trim()
        $ram = "{0:N2} GB" -f ((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
        $os  = (Get-CimInstance Win32_OperatingSystem).Caption
    } catch {
        $cpu = "N/A"; $ram = "N/A"; $os = "N/A"
    }
    $info = [pscustomobject]@{ CPU = $cpu; RAM = $ram; OS = $os }
    try {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $info | ConvertTo-Json | Set-Content -Path $file -Encoding UTF8
    } catch {}
    return $info
}

function Show-Dashboard {
    param(
        [switch]$Refresh,
        [switch]$SinDocker
    )

    $c   = $global:CY
    $sys = Get-SysInfoCached -Refresh:$Refresh

    $sessionInfo = [ordered]@{
        "Started" = (Get-Date -Format "yyyy-MM-dd HH:mm")
        "Shell"   = "$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor) $($PSVersionTable.PSEdition)"
        "CPU"     = $sys.CPU
        "RAM"     = $sys.RAM
        "User"    = [Environment]::UserName
        "OS"      = $sys.OS
    }

    $shortcuts = $global:Shortcuts
    $features  = $global:HelpData["INSTALLED TOOLS"]

    $sep  = "=" * 80
    $sep2 = "-" * 80
    $colIzq = 38

    Write-Cyber $sep $c.Magenta
    Write-Host ""
    Write-Cyber "$("System Info".PadRight($colIzq))| Quick Reference" $c.Green
    Write-Host ""

    $maxLines = [System.Math]::Max($sessionInfo.Count, $shortcuts.Count)
    $sysKeys  = @($sessionInfo.Keys)

    for ($i = 0; $i -lt $maxLines; $i++) {
        if ($i -lt $sysKeys.Count) {
            $k = $sysKeys[$i]
            $v = "$($sessionInfo[$k])"
            if ($v.Length -gt 26) { $v = $v.Substring(0, 25) + "..." }
            Write-Cyber "$($k.PadRight(10))" $c.Yellow -NoNewline
            Write-Cyber ": " $c.Magenta -NoNewline
            Write-Cyber $v.PadRight(26) $c.Cyan -NoNewline
        } else {
            Write-Host "".PadRight($colIzq) -NoNewline
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
    Write-Cyber "  Installed Tools   (help-ps for all commands)" $c.Green
    Write-Host ""
    foreach ($f in $features) {
        Write-Cyber "  $($f.K.PadRight(16))" $c.Yellow -NoNewline
        Write-Cyber "  $($f.D)" $c.Cyan
    }

    if (Get-Command Get-CyberDueCount -ErrorAction SilentlyContinue) {
        $pend = Get-CyberDueCount
        if ($pend -gt 0) {
            Write-Host ""
            Write-Cyber "  Review due: $pend  ->  dojo/dojo2/tatami/tatami2/forja/santuario with -Repaso" $c.Magenta
        }
    }

    # Docker: only show section if docker is installed AND running (fast check)
    if (-not $SinDocker -and (Get-Command docker -ErrorAction SilentlyContinue)) {
        $dockerRunning = Get-Process -Name "com.docker.backend", "dockerd" -ErrorAction SilentlyContinue
        Write-Host ""
        Write-Cyber $sep2 $c.Magenta
        Write-Host ""
        Write-Cyber "  Docker" $c.Green
        Write-Host ""
        if (-not $dockerRunning) {
            Write-Cyber "  Docker stopped (start Docker Desktop)." $c.Dim
        }
        else {
            try {
                $containers = docker ps --format "{{.Names}}|{{.Image}}|{{.Status}}|{{.Ports}}" 2>$null
                if ($containers) {
                    Write-Cyber "  $("NAME".PadRight(22)) $("IMAGE".PadRight(25)) $("STATUS".PadRight(20)) PORTS" $c.Cyan
                    Write-Cyber "  $("-" * 76)" $c.Dark
                    foreach ($line in $containers) {
                        $parts  = $line -split "\|"
                        $name   = $parts[0].PadRight(22)
                        $image  = $parts[1].PadRight(25)
                        $status = $parts[2].PadRight(20)
                        $ports  = if ($parts[3]) { $parts[3] } else { "-" }
                        Write-Cyber "  $name " $c.Yellow -NoNewline
                        Write-Cyber "$image " $c.Cyan -NoNewline
                        Write-Cyber "$status " $c.Green -NoNewline
                        Write-Cyber "$ports" $c.Dim
                    }
                } else {
                    Write-Cyber "  No active containers." $c.Dim
                }
            } catch {
                Write-Cyber "  Could not connect to Docker daemon." $c.Dim
            }
        }
    }

    Write-Host ""
    Write-Cyber $sep $c.Magenta
    Write-Host ""
}

Show-Dashboard

# ================================================================= #
#                          HELP                                     #
# ================================================================= #
function Show-Help {
    $c   = $global:CY
    $bar = "=" * 70

    foreach ($seccion in $global:HelpData.Keys) {
        Write-Host ""
        Write-Cyber $bar $c.Magenta
        Write-Cyber "  $seccion" $c.Green
        Write-Cyber $bar $c.Magenta
        foreach ($item in $global:HelpData[$seccion]) {
            Write-Cyber "  $($item.K.PadRight(28))" $c.Yellow -NoNewline
            Write-Cyber "$($item.D)" $c.Cyan
        }
    }
    Write-Host ""
    Write-Cyber "  Tip: check any shortcut with  Get-PSReadLineKeyHandler" $c.Dim
    Write-Host ""
}

Set-Alias help-ps Show-Help

# ================================================================= #
#                      MEASURE PROFILE                             #
# ================================================================= #
function Measure-Profile {
    $exe = (Get-Process -Id $PID).Path
    Write-Host "Measuring (a few seconds)..." -ForegroundColor DarkGray
    $con = [math]::Round((Measure-Command { & $exe -NoLogo -Command exit }).TotalMilliseconds, 0)
    $sin = [math]::Round((Measure-Command { & $exe -NoLogo -NoProfile -Command exit }).TotalMilliseconds, 0)
    Write-Host "With profile : $con ms"
    Write-Host "Without      : $sin ms"
    Write-Host "Profile cost : $($con - $sin) ms"
    if (($con - $sin) -gt 1000) {
        Write-Host "Over 1s: check Docker/CIM/modules (Show-Dashboard -SinDocker, -Refresh)." -ForegroundColor Yellow
    }
}
