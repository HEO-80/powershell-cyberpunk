# ================================================================= #
#     PSRemoting.ps1 — Administracion remota simplificada           #
#     github.com/HEO-80/powershell-cyberpunk                        #
#                                                                    #
#  Cargar directamente:                                              #
#    irm https://raw.githubusercontent.com/HEO-80/powershell-cyberpunk/main/extras/PSRemoting.ps1 | iex
#                                                                    #
#  O anadir a tu $PROFILE:                                           #
#    . "C:\ruta\powershell-cyberpunk\extras\PSRemoting.ps1"          #
# ================================================================= #
# Funciones para administrar maquinas remotas con PowerShell Remoting.
# Ejecutar comandos en uno o varios equipos a la vez, comprobar
# estado, recoger informacion y gestionar sesiones.
#
# REQUISITO: WinRM debe estar activado en las maquinas remotas.
#   En la maquina remota (como admin): Enable-PSRemoting -Force

# Por si se carga suelto (sin el tema Cyberpunk)
if (-not (Get-Command Write-Cyber -ErrorAction SilentlyContinue)) {
    function Write-Cyber {
        param([string]$Text, [string]$Color, [switch]$NoNewline)
        $esc = [char]27
        if ($Color -and $Color.StartsWith('#')) {
            $r = [Convert]::ToInt32($Color.Substring(1,2), 16)
            $g = [Convert]::ToInt32($Color.Substring(3,2), 16)
            $b = [Convert]::ToInt32($Color.Substring(5,2), 16)
            $ansi = "${esc}[38;2;${r};${g};${b}m"
            $reset = "${esc}[0m"
            if ($NoNewline) { Write-Host "$ansi$Text$reset" -NoNewline }
            else { Write-Host "$ansi$Text$reset" }
        } else {
            Write-Host $Text -NoNewline:$NoNewline
        }
    }
    $global:CY = @{ Yellow="#FCEE0A"; Green="#39FF14"; Cyan="#00F0FF"; Magenta="#C678DD"; Dim="#888888"; Red="#FF3030" }
}

# ================================================================= #
#  CONFIGURACION — Maquinas guardadas                               #
# ================================================================= #
# Archivo donde se guardan las maquinas conocidas
$global:RemotingConfigFile = Join-Path $env:LOCALAPPDATA "CyberProfile\remoting.json"

function Get-MaquinasGuardadas {
    if (Test-Path $global:RemotingConfigFile) {
        return (Get-Content $global:RemotingConfigFile -Raw | ConvertFrom-Json)
    }
    return @()
}

function Save-MaquinasGuardadas {
    param($Maquinas)
    $dir = Split-Path $global:RemotingConfigFile
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $Maquinas | ConvertTo-Json -Depth 3 | Set-Content $global:RemotingConfigFile -Encoding UTF8
}

# ================================================================= #
#  maquinas — Listar / anadir / quitar maquinas guardadas           #
# ================================================================= #
# Uso: maquinas                       (listar)
# Uso: maquinas -Agregar Servidor01   (anadir)
# Uso: maquinas -Agregar 192.168.1.50 -Alias "fileserver"
# Uso: maquinas -Quitar Servidor01    (eliminar)
function maquinas {
    param(
        [string]$Agregar,
        [string]$Alias,
        [string]$Quitar
    )
    $c = $global:CY

    if ($Agregar) {
        $lista = @(Get-MaquinasGuardadas)
        $existe = $lista | Where-Object { $_.Nombre -eq $Agregar -or $_.Alias -eq $Agregar }
        if ($existe) {
            Write-Cyber "  Ya existe: $Agregar" $c.Magenta
            return
        }
        $nueva = [pscustomobject]@{
            Nombre = $Agregar
            Alias  = if ($Alias) { $Alias } else { $Agregar }
        }
        $lista += $nueva
        Save-MaquinasGuardadas $lista
        Write-Cyber "  Agregada: $Agregar $(if ($Alias) { "($Alias)" })" $c.Green
        return
    }

    if ($Quitar) {
        $lista = @(Get-MaquinasGuardadas)
        $nueva = @($lista | Where-Object { $_.Nombre -ne $Quitar -and $_.Alias -ne $Quitar })
        if ($nueva.Count -eq $lista.Count) {
            Write-Cyber "  No encontrada: $Quitar" $c.Magenta
            return
        }
        Save-MaquinasGuardadas $nueva
        Write-Cyber "  Eliminada: $Quitar" $c.Green
        return
    }

    # Listar
    $lista = @(Get-MaquinasGuardadas)
    if ($lista.Count -eq 0) {
        Write-Cyber "  No hay maquinas guardadas." $c.Dim
        Write-Cyber "  Usa: maquinas -Agregar Servidor01" $c.Dim
        return
    }

    Write-Host ""
    Write-Cyber "  Maquinas guardadas:" $c.Green
    Write-Host ""
    foreach ($m in $lista) {
        $aliasText = if ($m.Alias -ne $m.Nombre) { " ($($m.Alias))" } else { "" }
        Write-Cyber "    $($m.Nombre)$aliasText" $c.Cyan
    }
    Write-Host ""
}

# ================================================================= #
#  Resolver nombres — convierte alias a nombres reales              #
# ================================================================= #
function Resolve-Maquinas {
    param([string[]]$Nombres)
    $lista = @(Get-MaquinasGuardadas)
    $resultado = @()
    foreach ($n in $Nombres) {
        if ($n -eq "todas" -or $n -eq "all") {
            $resultado += $lista.Nombre
        } else {
            $match = $lista | Where-Object { $_.Alias -eq $n -or $_.Nombre -eq $n }
            if ($match) {
                $resultado += $match.Nombre
            } else {
                # No esta guardada: usar el nombre tal cual (IP o hostname directo)
                $resultado += $n
            }
        }
    }
    return @($resultado | Select-Object -Unique)
}

# ================================================================= #
#  ping-remoto — Comprobar que maquinas estan vivas                 #
# ================================================================= #
# Uso: ping-remoto Servidor01,Servidor02
# Uso: ping-remoto todas                    (todas las guardadas)
# Uso: ping-remoto 192.168.1.50,192.168.1.51
function ping-remoto {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string[]]$Equipos
    )
    $c = $global:CY
    $maquinas = Resolve-Maquinas $Equipos

    if ($maquinas.Count -eq 0) {
        Write-Cyber "  No hay maquinas que comprobar." $c.Dim
        return
    }

    Write-Host ""
    Write-Cyber "  Comprobando $($maquinas.Count) equipo(s)..." $c.Dim
    Write-Host ""

    foreach ($m in $maquinas) {
        Write-Cyber "  $($m.PadRight(25))" $c.Cyan -NoNewline
        $ping = Test-Connection -ComputerName $m -Count 1 -Quiet -ErrorAction SilentlyContinue
        if ($ping) {
            # Comprobar si WinRM responde
            $winrm = $false
            try {
                $test = Test-WSMan -ComputerName $m -ErrorAction Stop
                $winrm = $true
            } catch { }

            if ($winrm) {
                Write-Cyber "[ONLINE + WinRM]" $c.Green
            } else {
                Write-Cyber "[ONLINE] " $c.Yellow -NoNewline
                Write-Cyber "(WinRM no responde)" $c.Dim
            }
        } else {
            Write-Cyber "[OFFLINE]" $c.Red
        }
    }
    Write-Host ""
}

# ================================================================= #
#  remoto — Ejecutar un comando en maquinas remotas                 #
# ================================================================= #
# Uso: remoto Servidor01 { Get-Service WinRM }
# Uso: remoto Servidor01,Servidor02 { Get-Process | Select -First 5 }
# Uso: remoto todas { hostname }
# Uso: remoto Servidor01 { Get-Service WinRM } -Credencial
function remoto {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string[]]$Equipos,

        [Parameter(Mandatory, Position = 1)]
        [scriptblock]$Comando,

        [switch]$Credencial
    )
    $c = $global:CY
    $maquinas = Resolve-Maquinas $Equipos

    if ($maquinas.Count -eq 0) {
        Write-Cyber "  No hay maquinas." $c.Dim
        return
    }

    $params = @{
        ComputerName = $maquinas
        ScriptBlock  = $Comando
        ErrorAction  = "SilentlyContinue"
        ErrorVariable = "errores"
    }

    if ($Credencial) {
        $params.Credential = Get-Credential -Message "Credenciales para acceso remoto"
    }

    Write-Host ""
    Write-Cyber "  Ejecutando en $($maquinas.Count) equipo(s)..." $c.Dim
    Write-Cyber "  Comando: $Comando" $c.Yellow
    Write-Host ""

    $inicio = Get-Date
    $resultados = Invoke-Command @params
    $duracion = ((Get-Date) - $inicio).TotalSeconds

    if ($resultados) {
        # Agrupar por maquina
        $porMaquina = $resultados | Group-Object PSComputerName

        foreach ($grupo in $porMaquina) {
            Write-Cyber "  === $($grupo.Name) ===" $c.Green
            $grupo.Group | Select-Object * -ExcludeProperty PSComputerName, RunspaceId, PSShowComputerName |
                Format-Table -AutoSize | Out-String | ForEach-Object {
                    $_.Trim() -split "`n" | ForEach-Object {
                        Write-Host "    $_"
                    }
                }
        }
    }

    # Errores
    if ($errores) {
        Write-Host ""
        foreach ($err in $errores) {
            $target = if ($err.TargetObject) { $err.TargetObject } else { "desconocido" }
            Write-Cyber "  ERROR en $target : $($err.Exception.Message)" $c.Red
        }
    }

    Write-Host ""
    Write-Cyber "  Completado en $([math]::Round($duracion, 2))s" $c.Dim
    Write-Host ""
}

# ================================================================= #
#  ir — Sesion interactiva en una maquina remota (como SSH)         #
# ================================================================= #
# Uso: ir Servidor01
# Uso: ir 192.168.1.50 -Credencial
function ir {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Equipo,

        [switch]$Credencial
    )
    $c = $global:CY
    $maquina = (Resolve-Maquinas @($Equipo))[0]

    Write-Cyber "  Conectando a $maquina..." $c.Yellow

    $params = @{ ComputerName = $maquina }
    if ($Credencial) {
        $params.Credential = Get-Credential -Message "Credenciales para $maquina"
    }

    try {
        Enter-PSSession @params
        Write-Cyber "  Conectado a $maquina. Escribe 'Exit-PSSession' para volver." $c.Green
    } catch {
        Write-Cyber "  No se pudo conectar: $($_.Exception.Message)" $c.Red
        Write-Host ""
        Write-Cyber "  Posibles causas:" $c.Dim
        Write-Cyber "    - WinRM no esta activado (Enable-PSRemoting -Force)" $c.Dim
        Write-Cyber "    - El equipo no es accesible o esta apagado" $c.Dim
        Write-Cyber "    - No estas en el mismo dominio (usa -Credencial)" $c.Dim
        Write-Cyber "    - Necesitas agregar a TrustedHosts:" $c.Dim
        Write-Cyber "      Set-Item WSMan:\localhost\Client\TrustedHosts -Value '$maquina' -Force" $c.Cyan
    }
}

# ================================================================= #
#  disco-remoto — Espacio en disco de maquinas remotas              #
# ================================================================= #
# Uso: disco-remoto Servidor01
# Uso: disco-remoto todas
function disco-remoto {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string[]]$Equipos,
        [switch]$Credencial
    )
    $c = $global:CY

    $comando = {
        Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
            [pscustomobject]@{
                Unidad    = $_.DeviceID
                TotalGB   = [math]::Round($_.Size / 1GB, 1)
                LibreGB   = [math]::Round($_.FreeSpace / 1GB, 1)
                UsadoPct  = [math]::Round((($_.Size - $_.FreeSpace) / $_.Size) * 100, 0)
            }
        }
    }

    $params = @($Equipos)
    if ($Credencial) {
        remoto @params $comando -Credencial
    } else {
        remoto @params $comando
    }
}

# ================================================================= #
#  servicios-remoto — Estado de servicios en maquinas remotas       #
# ================================================================= #
# Uso: servicios-remoto Servidor01 WinRM,Spooler
# Uso: servicios-remoto todas WinRM,DNS,DHCP
function servicios-remoto {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string[]]$Equipos,

        [Parameter(Mandatory, Position = 1)]
        [string[]]$Servicios,

        [switch]$Credencial
    )
    $c = $global:CY
    $maquinas = Resolve-Maquinas $Equipos

    $comando = [scriptblock]::Create("
        `$servicios = @('$($Servicios -join "','")')
        foreach (`$s in `$servicios) {
            `$svc = Get-Service -Name `$s -ErrorAction SilentlyContinue
            if (`$svc) {
                [pscustomobject]@{
                    Servicio = `$svc.Name
                    Estado   = `$svc.Status.ToString()
                    Inicio   = `$svc.StartType.ToString()
                }
            } else {
                [pscustomobject]@{
                    Servicio = `$s
                    Estado   = 'NO ENCONTRADO'
                    Inicio   = '-'
                }
            }
        }
    ")

    $params = @{
        ComputerName = $maquinas
        ScriptBlock  = $comando
        ErrorAction  = "SilentlyContinue"
    }
    if ($Credencial) {
        $params.Credential = Get-Credential
    }

    Write-Host ""
    $resultados = Invoke-Command @params

    if ($resultados) {
        $porMaquina = $resultados | Group-Object PSComputerName
        foreach ($grupo in $porMaquina) {
            Write-Cyber "  === $($grupo.Name) ===" $c.Green
            foreach ($svc in $grupo.Group) {
                $color = switch ($svc.Estado) {
                    "Running"       { $c.Green }
                    "Stopped"       { $c.Red }
                    "NO ENCONTRADO" { $c.Magenta }
                    default         { $c.Yellow }
                }
                Write-Cyber "    $($svc.Servicio.PadRight(20)) $($svc.Estado.PadRight(15)) ($($svc.Inicio))" $color
            }
            Write-Host ""
        }
    }
}

# ================================================================= #
#  reiniciar-servicio — Reiniciar un servicio en remoto             #
# ================================================================= #
# Uso: reiniciar-servicio Servidor01 Spooler
# Uso: reiniciar-servicio todas WinRM
function reiniciar-servicio {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string[]]$Equipos,

        [Parameter(Mandatory, Position = 1)]
        [string]$Servicio,

        [switch]$Credencial,
        [switch]$Force
    )
    $c = $global:CY
    $maquinas = Resolve-Maquinas $Equipos

    if (-not $Force) {
        Write-Cyber "  Vas a reiniciar '$Servicio' en: $($maquinas -join ', ')" $c.Yellow
        $confirmar = Read-Host "  Continuar? (s/N)"
        if ($confirmar -notin @("s", "S", "si", "Si")) {
            Write-Cyber "  Cancelado." $c.Dim
            return
        }
    }

    $comando = [scriptblock]::Create("
        Restart-Service -Name '$Servicio' -Force -ErrorAction Stop
        `$svc = Get-Service -Name '$Servicio'
        [pscustomobject]@{
            Servicio = `$svc.Name
            Estado   = `$svc.Status.ToString()
        }
    ")

    $params = @{
        ComputerName = $maquinas
        ScriptBlock  = $comando
        ErrorAction  = "SilentlyContinue"
        ErrorVariable = "errores"
    }
    if ($Credencial) { $params.Credential = Get-Credential }

    $resultados = Invoke-Command @params

    Write-Host ""
    if ($resultados) {
        foreach ($r in $resultados) {
            $color = if ($r.Estado -eq "Running") { $c.Green } else { $c.Red }
            Write-Cyber "  $($r.PSComputerName): $($r.Servicio) -> $($r.Estado)" $color
        }
    }
    if ($errores) {
        foreach ($err in $errores) {
            Write-Cyber "  ERROR: $($err.Exception.Message)" $c.Red
        }
    }
    Write-Host ""
}

# ================================================================= #
#  info-remoto — Informacion del sistema de maquinas remotas        #
# ================================================================= #
# Uso: info-remoto Servidor01
# Uso: info-remoto todas
function info-remoto {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string[]]$Equipos,
        [switch]$Credencial
    )
    $c = $global:CY

    $comando = {
        $os   = Get-CimInstance Win32_OperatingSystem
        $cpu  = Get-CimInstance Win32_Processor | Select-Object -First 1
        $ram  = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
        $libre = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
        $uptime = (Get-Date) - $os.LastBootUpTime

        [pscustomobject]@{
            Hostname  = $env:COMPUTERNAME
            SO        = "$($os.Caption) $($os.Version)"
            CPU       = $cpu.Name.Trim()
            RAM_GB    = "$libre / $ram GB libres"
            Uptime    = "$($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"
            IP        = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Ethernet*","Wi-Fi*" -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress
        }
    }

    $params = @($Equipos)
    if ($Credencial) {
        remoto @params $comando -Credencial
    } else {
        remoto @params $comando
    }
}

# ================================================================= #
#  copiar-remoto — Copiar archivos a/desde maquinas remotas         #
# ================================================================= #
# Uso: copiar-remoto -A Servidor01 -Origen .\script.ps1 -Destino C:\temp\
# Uso: copiar-remoto -De Servidor01 -Origen C:\logs\app.log -Destino .\
function copiar-remoto {
    param(
        [Parameter(Mandatory, ParameterSetName = "Enviar")]
        [string]$A,

        [Parameter(Mandatory, ParameterSetName = "Recibir")]
        [string]$De,

        [Parameter(Mandatory)]
        [string]$Origen,

        [Parameter(Mandatory)]
        [string]$Destino,

        [switch]$Credencial
    )
    $c = $global:CY

    $sessionParams = @{}
    if ($Credencial) {
        $sessionParams.Credential = Get-Credential
    }

    try {
        if ($A) {
            $maquina = (Resolve-Maquinas @($A))[0]
            Write-Cyber "  Enviando a $maquina..." $c.Yellow
            $session = New-PSSession -ComputerName $maquina @sessionParams
            Copy-Item -Path $Origen -Destination $Destino -ToSession $session -Force
            Remove-PSSession $session
            Write-Cyber "  Enviado: $Origen -> ${maquina}:$Destino" $c.Green
        }
        elseif ($De) {
            $maquina = (Resolve-Maquinas @($De))[0]
            Write-Cyber "  Descargando de $maquina..." $c.Yellow
            $session = New-PSSession -ComputerName $maquina @sessionParams
            Copy-Item -Path $Origen -Destination $Destino -FromSession $session -Force
            Remove-PSSession $session
            Write-Cyber "  Recibido: ${maquina}:$Origen -> $Destino" $c.Green
        }
    } catch {
        Write-Cyber "  Error: $($_.Exception.Message)" $c.Red
    }
    Write-Host ""
}

# ================================================================= #
#  activar-winrm — Preparar WinRM en la maquina LOCAL              #
# ================================================================= #
# Uso: activar-winrm
# Uso: activar-winrm -Confiar 192.168.1.50
# Uso: activar-winrm -Confiar "*"       (todas, solo para labs)
function activar-winrm {
    param(
        [string]$Confiar
    )
    $c = $global:CY

    # Comprobar si somos admin
    $esAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $esAdmin) {
        Write-Cyber "  Necesitas ejecutar como Administrador." $c.Red
        return
    }

    Write-Step "Activando PSRemoting..."
    try {
        Enable-PSRemoting -Force -SkipNetworkProfileCheck 2>$null
        Write-OK "PSRemoting activado"
    } catch {
        Write-Cyber "  Error: $($_.Exception.Message)" $c.Red
    }

    if ($Confiar) {
        Write-Step "Configurando TrustedHosts: $Confiar"
        $actual = (Get-Item WSMan:\localhost\Client\TrustedHosts).Value
        if ($actual -and $Confiar -ne "*") {
            $nuevo = "$actual,$Confiar"
        } else {
            $nuevo = $Confiar
        }
        Set-Item WSMan:\localhost\Client\TrustedHosts -Value $nuevo -Force
        Write-OK "TrustedHosts actualizado: $nuevo"
    }

    # Mostrar estado
    Write-Host ""
    Write-Cyber "  Estado de WinRM:" $c.Green
    $service = Get-Service WinRM
    Write-Cyber "    Servicio: $($service.Status)" $(if ($service.Status -eq "Running") { $c.Green } else { $c.Red })
    $trusted = (Get-Item WSMan:\localhost\Client\TrustedHosts).Value
    Write-Cyber "    TrustedHosts: $(if ($trusted) { $trusted } else { '(ninguno)' })" $c.Cyan
    Write-Host ""
}

# ================================================================= #
#                           AYUDA                                   #
# ================================================================= #
function Show-RemotingHelp {
    $c = $global:CY
    Write-Host ""
    Write-Cyber "  ============================================" $c.Magenta
    Write-Cyber "  PSREMOTING — Administracion remota" $c.Green
    Write-Cyber "  ============================================" $c.Magenta
    Write-Host ""
    $cmds = @(
        @{ K = "maquinas";                       D = "Listar maquinas guardadas (-Agregar / -Quitar)" }
        @{ K = "ping-remoto <equipos>";          D = "Comprobar estado (ping + WinRM)" }
        @{ K = "remoto <equipos> { cmd }";       D = "Ejecutar comando en remoto (en paralelo)" }
        @{ K = "ir <equipo>";                    D = "Sesion interactiva (como SSH)" }
        @{ K = "disco-remoto <equipos>";         D = "Espacio en disco de maquinas remotas" }
        @{ K = "servicios-remoto <eq> svc1,svc2"; D = "Estado de servicios en remoto" }
        @{ K = "reiniciar-servicio <eq> svc";    D = "Reiniciar un servicio en remoto" }
        @{ K = "info-remoto <equipos>";          D = "Info del sistema: SO, CPU, RAM, uptime, IP" }
        @{ K = "copiar-remoto -A <eq> ...";      D = "Copiar archivos a/desde remoto (-A / -De)" }
        @{ K = "activar-winrm [-Confiar IP]";    D = "Activar WinRM local y configurar TrustedHosts" }
        @{ K = "psremoting";                     D = "Mostrar esta ayuda" }
    )
    foreach ($item in $cmds) {
        Write-Cyber "  $($item.K.PadRight(38))" $c.Yellow -NoNewline
        Write-Cyber "$($item.D)" $c.Cyan
    }
    Write-Host ""
    Write-Cyber "  Usa 'todas' como equipo para lanzar a todas las guardadas." $c.Dim
    Write-Cyber "  Usa -Credencial en cualquier comando para pedir usuario/pass." $c.Dim
    Write-Host ""
}

Set-Alias psremoting Show-RemotingHelp
