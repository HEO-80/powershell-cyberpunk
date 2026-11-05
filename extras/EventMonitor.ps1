# ================================================================= #
#     EventMonitor.ps1 — Monitor de eventos de Windows              #
#     github.com/HEO-80/powershell-cyberpunk                        #
#                                                                    #
#  Cargar directamente:                                              #
#    irm https://raw.githubusercontent.com/HEO-80/powershell-cyberpunk/main/extras/EventMonitor.ps1 | iex
#                                                                    #
#  O anadir a tu $PROFILE:                                           #
#    . "C:\ruta\powershell-cyberpunk\extras\EventMonitor.ps1"        #
# ================================================================= #
# Funciones para monitorizar los Event Logs de Windows:
# errores criticos, logins fallidos, servicios caidos, reinicios
# inesperados y mas. Compatible con PSRemoting para vigilar
# varias maquinas a la vez.

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
    $global:CY = @{ Yellow="#FCEE0A"; Green="#39FF14"; Cyan="#00F0FF"; Magenta="#C678DD"; Dim="#888888"; Red="#FF3030"; Orange="#FF8C00" }
}

# ================================================================= #
#  IDs de eventos importantes — referencia rapida                   #
# ================================================================= #
$global:EventosConocidos = @{
    # Security
    4624 = "Login exitoso"
    4625 = "Login FALLIDO"
    4634 = "Logoff"
    4648 = "Login con credenciales explicitas"
    4720 = "Cuenta de usuario CREADA"
    4722 = "Cuenta de usuario habilitada"
    4725 = "Cuenta de usuario deshabilitada"
    4726 = "Cuenta de usuario ELIMINADA"
    4732 = "Usuario anadido a grupo"
    4733 = "Usuario eliminado de grupo"
    4740 = "Cuenta BLOQUEADA"
    4767 = "Cuenta desbloqueada"
    # System
    7036 = "Servicio cambio de estado"
    7040 = "Tipo de inicio de servicio cambiado"
    7045 = "Nuevo servicio instalado"
    6005 = "Sistema arranco"
    6006 = "Sistema apagado limpio"
    6008 = "Apagado INESPERADO"
    6009 = "Info de version del SO al arrancar"
    1074 = "Reinicio/apagado iniciado por usuario/proceso"
    41   = "Kernel-Power: reinicio sin apagado limpio"
    # Application
    1001 = "Windows Error Reporting (crash)"
    1000 = "Fallo de aplicacion"
    1002 = "Aplicacion colgada"
}

# ================================================================= #
#  vigilar — Resumen rapido de que ha pasado en las ultimas horas   #
# ================================================================= #
# Uso: vigilar              (ultimas 24h)
# Uso: vigilar -Horas 4     (ultimas 4 horas)
# Uso: vigilar -Horas 168   (ultima semana)
function vigilar {
    param(
        [int]$Horas = 24
    )
    $c = $global:CY
    $desde = (Get-Date).AddHours(-$Horas)

    Write-Host ""
    Write-Cyber "  ============================================" $c.Magenta
    Write-Cyber "  MONITOR DE EVENTOS — ultimas $Horas horas" $c.Green
    Write-Cyber "  Desde: $($desde.ToString('dd/MM/yyyy HH:mm'))" $c.Dim
    Write-Cyber "  ============================================" $c.Magenta

    # ── Errores criticos y errores en System ─────────────────────
    Write-Host ""
    Write-Cyber "  >> SYSTEM — Errores criticos y errores" $c.Yellow
    try {
        $sysErrors = @(Get-WinEvent -FilterHashtable @{
            LogName   = 'System'
            Level     = 1,2   # Critical, Error
            StartTime = $desde
        } -ErrorAction SilentlyContinue)

        if ($sysErrors.Count -eq 0) {
            Write-Cyber "     Sin errores criticos" $c.Green
        } else {
            Write-Cyber "     $($sysErrors.Count) evento(s)" $c.Red
            $grupos = $sysErrors | Group-Object Id | Sort-Object Count -Descending | Select-Object -First 8
            foreach ($g in $grupos) {
                $desc = if ($global:EventosConocidos[$g.Name]) { $global:EventosConocidos[$g.Name] } else { $g.Group[0].Message -split "`n" | Select-Object -First 1 }
                $descCorta = if ($desc.Length -gt 60) { $desc.Substring(0, 57) + "..." } else { $desc }
                Write-Cyber "     $($g.Count.ToString().PadLeft(4))x  ID $($g.Name.ToString().PadRight(6)) $descCorta" $c.Orange
            }
        }
    } catch {
        Write-Cyber "     No se pudo leer (necesitas permisos de admin)" $c.Dim
    }

    # ── Warnings en System ───────────────────────────────────────
    Write-Host ""
    Write-Cyber "  >> SYSTEM — Warnings" $c.Yellow
    try {
        $sysWarns = @(Get-WinEvent -FilterHashtable @{
            LogName   = 'System'
            Level     = 3   # Warning
            StartTime = $desde
        } -ErrorAction SilentlyContinue)

        if ($sysWarns.Count -eq 0) {
            Write-Cyber "     Sin warnings" $c.Green
        } else {
            Write-Cyber "     $($sysWarns.Count) warning(s)" $c.Yellow
            $grupos = $sysWarns | Group-Object Id | Sort-Object Count -Descending | Select-Object -First 5
            foreach ($g in $grupos) {
                $desc = if ($global:EventosConocidos[$g.Name]) { $global:EventosConocidos[$g.Name] } else { $g.Group[0].Message -split "`n" | Select-Object -First 1 }
                $descCorta = if ($desc.Length -gt 60) { $desc.Substring(0, 57) + "..." } else { $desc }
                Write-Cyber "     $($g.Count.ToString().PadLeft(4))x  ID $($g.Name.ToString().PadRight(6)) $descCorta" $c.Dim
            }
        }
    } catch {
        Write-Cyber "     No se pudo leer" $c.Dim
    }

    # ── Logins fallidos en Security ──────────────────────────────
    Write-Host ""
    Write-Cyber "  >> SECURITY — Logins fallidos" $c.Yellow
    try {
        $loginFail = @(Get-WinEvent -FilterHashtable @{
            LogName   = 'Security'
            Id        = 4625
            StartTime = $desde
        } -ErrorAction SilentlyContinue)

        if ($loginFail.Count -eq 0) {
            Write-Cyber "     Sin intentos fallidos" $c.Green
        } else {
            $color = if ($loginFail.Count -gt 50) { $c.Red } elseif ($loginFail.Count -gt 10) { $c.Orange } else { $c.Yellow }
            Write-Cyber "     $($loginFail.Count) intento(s) fallido(s)" $color

            # Extraer usuarios que fallaron
            $usuarios = @{}
            foreach ($evt in $loginFail) {
                try {
                    $xml = [xml]$evt.ToXml()
                    $user = ($xml.Event.EventData.Data | Where-Object { $_.Name -eq 'TargetUserName' }).'#text'
                    $ip   = ($xml.Event.EventData.Data | Where-Object { $_.Name -eq 'IpAddress' }).'#text'
                    $key = "$user (desde $ip)"
                    if ($usuarios.ContainsKey($key)) { $usuarios[$key]++ }
                    else { $usuarios[$key] = 1 }
                } catch {}
            }

            $topUsuarios = $usuarios.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 5
            foreach ($u in $topUsuarios) {
                Write-Cyber "     $($u.Value.ToString().PadLeft(4))x  $($u.Key)" $c.Cyan
            }
        }
    } catch {
        Write-Cyber "     No se pudo leer (requiere admin)" $c.Dim
    }

    # ── Cuentas creadas/eliminadas ───────────────────────────────
    Write-Host ""
    Write-Cyber "  >> SECURITY — Cambios de cuentas" $c.Yellow
    try {
        $cuentas = @(Get-WinEvent -FilterHashtable @{
            LogName   = 'Security'
            Id        = 4720,4726,4725,4722,4732,4733,4740
            StartTime = $desde
        } -ErrorAction SilentlyContinue)

        if ($cuentas.Count -eq 0) {
            Write-Cyber "     Sin cambios de cuentas" $c.Green
        } else {
            foreach ($evt in $cuentas) {
                $desc = if ($global:EventosConocidos[$evt.Id]) { $global:EventosConocidos[$evt.Id] } else { "ID $($evt.Id)" }
                $hora = $evt.TimeCreated.ToString("dd/MM HH:mm")
                try {
                    $xml = [xml]$evt.ToXml()
                    $target = ($xml.Event.EventData.Data | Where-Object { $_.Name -eq 'TargetUserName' }).'#text'
                    Write-Cyber "     $hora  $desc — $target" $c.Orange
                } catch {
                    Write-Cyber "     $hora  $desc" $c.Orange
                }
            }
        }
    } catch {
        Write-Cyber "     No se pudo leer (requiere admin)" $c.Dim
    }

    # ── Servicios caidos ─────────────────────────────────────────
    Write-Host ""
    Write-Cyber "  >> SYSTEM — Servicios que se pararon" $c.Yellow
    try {
        $svcEvents = @(Get-WinEvent -FilterHashtable @{
            LogName      = 'System'
            Id           = 7036
            StartTime    = $desde
        } -ErrorAction SilentlyContinue | Where-Object {
            $_.Message -match "stopped|detenido"
        })

        if ($svcEvents.Count -eq 0) {
            Write-Cyber "     Ningun servicio se ha parado" $c.Green
        } else {
            $grupos = $svcEvents | Group-Object { ($_.Message -split "'|«|»")[1] } |
                Sort-Object Count -Descending | Select-Object -First 8
            foreach ($g in $grupos) {
                Write-Cyber "     $($g.Count.ToString().PadLeft(4))x  $($g.Name)" $c.Orange
            }
        }
    } catch {
        Write-Cyber "     No se pudo leer" $c.Dim
    }

    # ── Reinicios y apagados ─────────────────────────────────────
    Write-Host ""
    Write-Cyber "  >> SYSTEM — Reinicios y apagados" $c.Yellow
    try {
        $reinicios = @(Get-WinEvent -FilterHashtable @{
            LogName   = 'System'
            Id        = 6005,6006,6008,1074,41
            StartTime = $desde
        } -ErrorAction SilentlyContinue)

        if ($reinicios.Count -eq 0) {
            Write-Cyber "     Sin reinicios ni apagados" $c.Green
        } else {
            foreach ($evt in ($reinicios | Sort-Object TimeCreated -Descending | Select-Object -First 10)) {
                $desc = if ($global:EventosConocidos[$evt.Id]) { $global:EventosConocidos[$evt.Id] } else { "ID $($evt.Id)" }
                $hora = $evt.TimeCreated.ToString("dd/MM HH:mm")
                $color = if ($evt.Id -in @(6008, 41)) { $c.Red } else { $c.Cyan }
                Write-Cyber "     $hora  $desc" $color
            }
        }
    } catch {
        Write-Cyber "     No se pudo leer" $c.Dim
    }

    # ── Application errors ───────────────────────────────────────
    Write-Host ""
    Write-Cyber "  >> APPLICATION — Crashes de aplicaciones" $c.Yellow
    try {
        $appErrors = @(Get-WinEvent -FilterHashtable @{
            LogName   = 'Application'
            Level     = 1,2
            StartTime = $desde
        } -ErrorAction SilentlyContinue)

        if ($appErrors.Count -eq 0) {
            Write-Cyber "     Sin crashes" $c.Green
        } else {
            Write-Cyber "     $($appErrors.Count) error(es) de aplicacion" $c.Orange
            $grupos = $appErrors | Group-Object ProviderName | Sort-Object Count -Descending | Select-Object -First 5
            foreach ($g in $grupos) {
                Write-Cyber "     $($g.Count.ToString().PadLeft(4))x  $($g.Name)" $c.Dim
            }
        }
    } catch {
        Write-Cyber "     No se pudo leer" $c.Dim
    }

    # ── Nuevos servicios instalados (posible malware) ────────────
    Write-Host ""
    Write-Cyber "  >> SYSTEM — Nuevos servicios instalados" $c.Yellow
    try {
        $nuevos = @(Get-WinEvent -FilterHashtable @{
            LogName   = 'System'
            Id        = 7045
            StartTime = $desde
        } -ErrorAction SilentlyContinue)

        if ($nuevos.Count -eq 0) {
            Write-Cyber "     Ningun servicio nuevo" $c.Green
        } else {
            Write-Cyber "     $($nuevos.Count) servicio(s) nuevo(s)" $c.Orange
            foreach ($evt in $nuevos) {
                $hora = $evt.TimeCreated.ToString("dd/MM HH:mm")
                try {
                    $xml = [xml]$evt.ToXml()
                    $nombre = ($xml.Event.EventData.Data | Where-Object { $_.Name -eq 'ServiceName' }).'#text'
                    $ruta   = ($xml.Event.EventData.Data | Where-Object { $_.Name -eq 'ImagePath' }).'#text'
                    $rutaCorta = if ($ruta.Length -gt 50) { $ruta.Substring(0, 47) + "..." } else { $ruta }
                    Write-Cyber "     $hora  $nombre" $c.Cyan
                    Write-Cyber "              $rutaCorta" $c.Dim
                } catch {
                    Write-Cyber "     $hora  (no se pudo extraer el nombre)" $c.Dim
                }
            }
        }
    } catch {
        Write-Cyber "     No se pudo leer" $c.Dim
    }

    Write-Host ""
    Write-Cyber "  ============================================" $c.Green
    Write-Cyber "  Resumen completado" $c.Green
    Write-Cyber "  ============================================" $c.Green
    Write-Host ""
}

# ================================================================= #
#  logins — Ver logins exitosos y fallidos                          #
# ================================================================= #
# Uso: logins                     (ultimas 24h)
# Uso: logins -Horas 4            (ultimas 4h)
# Uso: logins -Solo Fallidos      (solo los fallidos)
# Uso: logins -Solo Exitosos
# Uso: logins -Usuario admin
function logins {
    param(
        [int]$Horas = 24,
        [ValidateSet('Todos', 'Exitosos', 'Fallidos')]
        [string]$Solo = 'Todos',
        [string]$Usuario
    )
    $c = $global:CY
    $desde = (Get-Date).AddHours(-$Horas)

    $ids = switch ($Solo) {
        'Exitosos' { @(4624) }
        'Fallidos' { @(4625) }
        default    { @(4624, 4625) }
    }

    Write-Host ""
    Write-Cyber "  LOGINS — ultimas $Horas horas ($Solo)" $c.Green
    Write-Host ""

    try {
        $eventos = @(Get-WinEvent -FilterHashtable @{
            LogName   = 'Security'
            Id        = $ids
            StartTime = $desde
        } -ErrorAction SilentlyContinue)

        if ($eventos.Count -eq 0) {
            Write-Cyber "  Sin eventos de login." $c.Dim
            return
        }

        $resultados = @()
        foreach ($evt in $eventos) {
            try {
                $xml = [xml]$evt.ToXml()
                $user = ($xml.Event.EventData.Data | Where-Object { $_.Name -eq 'TargetUserName' }).'#text'
                $domain = ($xml.Event.EventData.Data | Where-Object { $_.Name -eq 'TargetDomainName' }).'#text'
                $ip = ($xml.Event.EventData.Data | Where-Object { $_.Name -eq 'IpAddress' }).'#text'
                $logonType = ($xml.Event.EventData.Data | Where-Object { $_.Name -eq 'LogonType' }).'#text'

                # Filtrar cuentas de sistema
                if ($user -in @('SYSTEM', '-', 'ANONYMOUS LOGON', '$', 'DWM-1', 'DWM-2', 'UMFD-0', 'UMFD-1') -or
                    $user -match '\$$') { continue }

                # Filtrar por usuario si se especifica
                if ($Usuario -and $user -ne $Usuario) { continue }

                $tipoLogin = switch ($logonType) {
                    "2"  { "Interactivo" }
                    "3"  { "Red" }
                    "4"  { "Batch" }
                    "5"  { "Servicio" }
                    "7"  { "Desbloqueo" }
                    "8"  { "Red (cleartext)" }
                    "10" { "Escritorio remoto" }
                    "11" { "Cached" }
                    default { "Tipo $logonType" }
                }

                $resultados += [pscustomobject]@{
                    Hora     = $evt.TimeCreated.ToString("dd/MM HH:mm:ss")
                    Tipo     = if ($evt.Id -eq 4624) { "OK" } else { "FALLO" }
                    Usuario  = "$domain\$user"
                    Metodo   = $tipoLogin
                    IP       = if ($ip -and $ip -ne '-') { $ip } else { "local" }
                }
            } catch { continue }
        }

        if ($resultados.Count -eq 0) {
            Write-Cyber "  Sin eventos (filtrados cuentas de sistema)." $c.Dim
            return
        }

        # Mostrar los mas recientes
        $mostrar = $resultados | Select-Object -First 30
        foreach ($r in $mostrar) {
            $color = if ($r.Tipo -eq "OK") { $c.Green } else { $c.Red }
            $tipo = if ($r.Tipo -eq "OK") { " OK  " } else { "FALLO" }
            Write-Cyber "  $($r.Hora)  " $c.Dim -NoNewline
            Write-Cyber "[$tipo] " $color -NoNewline
            Write-Cyber "$($r.Usuario.PadRight(25)) $($r.Metodo.PadRight(18)) $($r.IP)" $c.Cyan
        }

        if ($resultados.Count -gt 30) {
            Write-Host ""
            Write-Cyber "  (mostrando 30 de $($resultados.Count) — usa -Horas para acotar)" $c.Dim
        }

        # Resumen
        $exitosos = @($resultados | Where-Object { $_.Tipo -eq "OK" }).Count
        $fallidos = @($resultados | Where-Object { $_.Tipo -eq "FALLO" }).Count
        Write-Host ""
        Write-Cyber "  Total: $exitosos exitosos, $fallidos fallidos" $(if ($fallidos -gt 10) { $c.Red } else { $c.Green })

    } catch {
        Write-Cyber "  Error: $($_.Exception.Message)" $c.Red
        Write-Cyber "  (requiere ejecutar como Administrador)" $c.Dim
    }
    Write-Host ""
}

# ================================================================= #
#  errores — Ver errores criticos de un log especifico              #
# ================================================================= #
# Uso: errores                       (System, 24h)
# Uso: errores -Log Application      (otro log)
# Uso: errores -Horas 48 -Top 20    (mas tiempo, mas resultados)
function errores {
    param(
        [ValidateSet('System', 'Application', 'Security')]
        [string]$Log = 'System',
        [int]$Horas = 24,
        [int]$Top = 10
    )
    $c = $global:CY
    $desde = (Get-Date).AddHours(-$Horas)

    Write-Host ""
    Write-Cyber "  ERRORES en $Log — ultimas $Horas horas" $c.Green
    Write-Host ""

    try {
        $eventos = @(Get-WinEvent -FilterHashtable @{
            LogName   = $Log
            Level     = 1,2   # Critical, Error
            StartTime = $desde
        } -ErrorAction SilentlyContinue)

        if ($eventos.Count -eq 0) {
            Write-Cyber "  Sin errores. Todo limpio." $c.Green
            return
        }

        Write-Cyber "  $($eventos.Count) error(es) encontrado(s)" $c.Orange
        Write-Host ""

        $mostrar = $eventos | Select-Object -First $Top
        foreach ($evt in $mostrar) {
            $hora = $evt.TimeCreated.ToString("dd/MM HH:mm:ss")
            $nivel = if ($evt.Level -eq 1) { "CRITICO" } else { "ERROR  " }
            $color = if ($evt.Level -eq 1) { $c.Red } else { $c.Orange }
            $msg = ($evt.Message -split "`n")[0]
            if ($msg.Length -gt 80) { $msg = $msg.Substring(0, 77) + "..." }

            Write-Cyber "  $hora  [$nivel]  ID:$($evt.Id)" $color
            Write-Cyber "    $msg" $c.Dim
            Write-Host ""
        }

        if ($eventos.Count -gt $Top) {
            Write-Cyber "  (mostrando $Top de $($eventos.Count) — usa -Top para ver mas)" $c.Dim
        }
    } catch {
        Write-Cyber "  Error: $($_.Exception.Message)" $c.Red
    }
    Write-Host ""
}

# ================================================================= #
#  buscar-evento — Buscar eventos por ID o texto                    #
# ================================================================= #
# Uso: buscar-evento 4625                    (por ID)
# Uso: buscar-evento -Texto "disco"          (por texto en el mensaje)
# Uso: buscar-evento 7045 -Log System -Horas 168
function buscar-evento {
    param(
        [Parameter(Position = 0)]
        [int]$Id,

        [string]$Texto,

        [ValidateSet('System', 'Application', 'Security')]
        [string]$Log = 'System',

        [int]$Horas = 24,
        [int]$Top = 20
    )
    $c = $global:CY
    $desde = (Get-Date).AddHours(-$Horas)

    Write-Host ""

    try {
        if ($Id) {
            Write-Cyber "  Buscando Event ID $Id en $Log (ultimas $Horas h)..." $c.Green
            $filter = @{
                LogName   = $Log
                Id        = $Id
                StartTime = $desde
            }
            $eventos = @(Get-WinEvent -FilterHashtable $filter -ErrorAction SilentlyContinue)
        }
        elseif ($Texto) {
            Write-Cyber "  Buscando '$Texto' en $Log (ultimas $Horas h)..." $c.Green
            $filter = @{
                LogName   = $Log
                StartTime = $desde
            }
            $eventos = @(Get-WinEvent -FilterHashtable $filter -ErrorAction SilentlyContinue |
                Where-Object { $_.Message -match $Texto })
        }
        else {
            Write-Cyber "  Usa: buscar-evento <ID> o buscar-evento -Texto 'algo'" $c.Dim
            return
        }

        if ($eventos.Count -eq 0) {
            Write-Cyber "  No se encontro nada." $c.Dim
            return
        }

        Write-Cyber "  $($eventos.Count) resultado(s)" $c.Yellow
        Write-Host ""

        $mostrar = $eventos | Select-Object -First $Top
        foreach ($evt in $mostrar) {
            $hora = $evt.TimeCreated.ToString("dd/MM HH:mm:ss")
            $nivel = switch ($evt.Level) {
                1 { "CRITICO" }
                2 { "ERROR  " }
                3 { "WARNING" }
                4 { "INFO   " }
                default { "LVL $($evt.Level)  " }
            }
            $msg = ($evt.Message -split "`n")[0]
            if ($msg.Length -gt 80) { $msg = $msg.Substring(0, 77) + "..." }

            Write-Cyber "  $hora  [$nivel]  ID:$($evt.Id)  $($evt.ProviderName)" $c.Cyan
            Write-Cyber "    $msg" $c.Dim
        }

        if ($eventos.Count -gt $Top) {
            Write-Host ""
            Write-Cyber "  (mostrando $Top de $($eventos.Count))" $c.Dim
        }
    } catch {
        Write-Cyber "  Error: $($_.Exception.Message)" $c.Red
    }
    Write-Host ""
}

# ================================================================= #
#  exportar-eventos — Exportar eventos a CSV                        #
# ================================================================= #
# Uso: exportar-eventos                              (System errors 24h)
# Uso: exportar-eventos -Log Security -Horas 48      (Security 48h)
# Uso: exportar-eventos -Archivo C:\informes\eventos.csv
function exportar-eventos {
    param(
        [ValidateSet('System', 'Application', 'Security')]
        [string]$Log = 'System',
        [int]$Horas = 24,
        [string]$Archivo
    )
    $c = $global:CY
    $desde = (Get-Date).AddHours(-$Horas)

    if (-not $Archivo) {
        $fecha = (Get-Date).ToString("yyyyMMdd_HHmm")
        $Archivo = Join-Path ([Environment]::GetFolderPath("Desktop")) "eventos_${Log}_${fecha}.csv"
    }

    Write-Cyber "  Exportando eventos de $Log (ultimas $Horas h)..." $c.Yellow

    try {
        $eventos = @(Get-WinEvent -FilterHashtable @{
            LogName   = $Log
            Level     = 1,2,3
            StartTime = $desde
        } -ErrorAction SilentlyContinue)

        if ($eventos.Count -eq 0) {
            Write-Cyber "  Sin eventos que exportar." $c.Dim
            return
        }

        $datos = $eventos | ForEach-Object {
            $nivel = switch ($_.Level) { 1 { "Critical" } 2 { "Error" } 3 { "Warning" } default { $_.Level } }
            [pscustomobject]@{
                Fecha      = $_.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
                Nivel      = $nivel
                EventID    = $_.Id
                Origen     = $_.ProviderName
                Mensaje    = ($_.Message -split "`n")[0]
            }
        }

        $datos | Export-Csv -Path $Archivo -NoTypeInformation -Encoding UTF8
        Write-Cyber "  Exportados $($datos.Count) eventos a:" $c.Green
        Write-Cyber "  $Archivo" $c.Cyan
    } catch {
        Write-Cyber "  Error: $($_.Exception.Message)" $c.Red
    }
    Write-Host ""
}

# ================================================================= #
#  ids — Referencia rapida de Event IDs importantes                 #
# ================================================================= #
function ids {
    $c = $global:CY
    Write-Host ""
    Write-Cyber "  Event IDs importantes para sysadmin" $c.Green
    Write-Host ""
    Write-Cyber "  SECURITY:" $c.Yellow
    Write-Cyber "    4624  Login exitoso" $c.Cyan
    Write-Cyber "    4625  Login FALLIDO" $c.Red
    Write-Cyber "    4720  Cuenta creada" $c.Orange
    Write-Cyber "    4726  Cuenta eliminada" $c.Orange
    Write-Cyber "    4732  Usuario anadido a grupo" $c.Orange
    Write-Cyber "    4740  Cuenta BLOQUEADA" $c.Red
    Write-Host ""
    Write-Cyber "  SYSTEM:" $c.Yellow
    Write-Cyber "    7036  Servicio cambio de estado" $c.Cyan
    Write-Cyber "    7045  Nuevo servicio instalado" $c.Orange
    Write-Cyber "    6005  Sistema arranco" $c.Cyan
    Write-Cyber "    6006  Apagado limpio" $c.Cyan
    Write-Cyber "    6008  Apagado INESPERADO" $c.Red
    Write-Cyber "    41    Kernel-Power (crash)" $c.Red
    Write-Host ""
    Write-Cyber "  APPLICATION:" $c.Yellow
    Write-Cyber "    1000  Fallo de aplicacion" $c.Orange
    Write-Cyber "    1001  Windows Error Reporting" $c.Orange
    Write-Cyber "    1002  Aplicacion colgada" $c.Orange
    Write-Host ""
    Write-Cyber "  Buscar: buscar-evento <ID> -Log <System|Security|Application>" $c.Dim
    Write-Host ""
}

# ================================================================= #
#                           AYUDA                                   #
# ================================================================= #
function Show-EventMonitorHelp {
    $c = $global:CY
    Write-Host ""
    Write-Cyber "  ============================================" $c.Magenta
    Write-Cyber "  EVENT MONITOR — Monitor de eventos Windows" $c.Green
    Write-Cyber "  ============================================" $c.Magenta
    Write-Host ""
    $cmds = @(
        @{ K = "vigilar [-Horas 24]";              D = "Resumen completo de que ha pasado (errores, logins, servicios, reinicios)" }
        @{ K = "logins [-Horas] [-Solo Fallidos]";  D = "Ver logins exitosos y fallidos (-Usuario para filtrar)" }
        @{ K = "errores [-Log System] [-Horas]";    D = "Ver errores criticos de un log" }
        @{ K = "buscar-evento <ID>";                D = "Buscar por Event ID o -Texto en el mensaje" }
        @{ K = "exportar-eventos [-Log] [-Horas]";  D = "Exportar errores y warnings a CSV (escritorio)" }
        @{ K = "ids";                               D = "Referencia rapida de Event IDs importantes" }
        @{ K = "eventos";                           D = "Mostrar esta ayuda" }
    )
    foreach ($item in $cmds) {
        Write-Cyber "  $($item.K.PadRight(38))" $c.Yellow -NoNewline
        Write-Cyber "$($item.D)" $c.Cyan
    }
    Write-Host ""
    Write-Cyber "  Tip: ejecuta como Administrador para ver Security." $c.Dim
    Write-Cyber "  Tip: combina con PSRemoting para vigilar maquinas remotas:" $c.Dim
    Write-Cyber "    remoto Servidor01 { vigilar -Horas 4 }" $c.Yellow
    Write-Host ""
}

Set-Alias eventos Show-EventMonitorHelp
