# ================================================================= #
#          FileTools.ps1 — Funciones para trabajar con archivos     #
#          github.com/HEO-80/powershell-cyberpunk                   #
#                                                                   #
#  Cargar manualmente:                                              #
#    irm https://raw.githubusercontent.com/HEO-80/powershell-cyberpunk/main/extras/FileTools.ps1 | iex
#                                                                   #
#  O añadir a tu $PROFILE:                                          #
#    . "C:\ruta\powershell-cyberpunk\extras\FileTools.ps1"          #
# ================================================================= #
# Funciones que reciben rutas de archivos y carpetas.
# Arrastra un archivo a la terminal para pegar su ruta automaticamente.

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
    $global:CY = @{ Yellow="#FCEE0A"; Green="#39FF14"; Cyan="#00F0FF"; Magenta="#C678DD"; Dim="#888888" }
}

# ================================================================= #
#  info — Informacion completa de un archivo o carpeta              #
# ================================================================= #
# Uso: info C:\ruta\archivo.pdf
# Uso: info .                     (carpeta actual)
# Uso: info  + arrastrar archivo encima de la terminal
function info {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Ruta
    )
    $c = $global:CY

    if (-not (Test-Path $Ruta)) {
        Write-Cyber "No existe: $Ruta" $c.Magenta
        return
    }

    $item = Get-Item $Ruta -Force

    Write-Host ""
    Write-Cyber "=== INFO ===" $c.Green

    if ($item.PSIsContainer) {
        $archivos = @(Get-ChildItem $Ruta -Recurse -File -Force -ErrorAction SilentlyContinue)
        $carpetas = @(Get-ChildItem $Ruta -Recurse -Directory -Force -ErrorAction SilentlyContinue)
        $tamano = ($archivos | Measure-Object Length -Sum).Sum

        Write-Cyber "  Tipo:       Carpeta" $c.Cyan
        Write-Cyber "  Nombre:     $($item.Name)" $c.Cyan
        Write-Cyber "  Ruta:       $($item.FullName)" $c.Cyan
        Write-Cyber "  Archivos:   $($archivos.Count)" $c.Yellow
        Write-Cyber "  Carpetas:   $($carpetas.Count)" $c.Yellow
        Write-Cyber "  Tamano:     $([math]::Round($tamano / 1MB, 2)) MB" $c.Yellow
        Write-Cyber "  Creada:     $($item.CreationTime)" $c.Dim
        Write-Cyber "  Modificada: $($item.LastWriteTime)" $c.Dim

        # Top 5 archivos mas pesados
        $top = $archivos | Sort-Object Length -Descending | Select-Object -First 5
        if ($top) {
            Write-Host ""
            Write-Cyber "  Top 5 mas pesados:" $c.Green
            foreach ($f in $top) {
                $rel = $f.FullName.Substring($item.FullName.Length).TrimStart('\', '/')
                Write-Cyber "    $([math]::Round($f.Length / 1KB, 1).ToString().PadLeft(10)) KB  $rel" $c.Dim
            }
        }

        # Extensiones
        $exts = $archivos | Group-Object Extension | Sort-Object Count -Descending | Select-Object -First 8
        if ($exts) {
            Write-Host ""
            Write-Cyber "  Extensiones:" $c.Green
            foreach ($e in $exts) {
                $ext = if ($e.Name) { $e.Name } else { "(sin ext)" }
                Write-Cyber "    $($e.Count.ToString().PadLeft(5))  $ext" $c.Dim
            }
        }
    }
    else {
        Write-Cyber "  Tipo:       Archivo" $c.Cyan
        Write-Cyber "  Nombre:     $($item.Name)" $c.Cyan
        Write-Cyber "  Ruta:       $($item.FullName)" $c.Cyan
        Write-Cyber "  Extension:  $($item.Extension)" $c.Yellow
        Write-Cyber "  Tamano:     $([math]::Round($item.Length / 1KB, 2)) KB ($([math]::Round($item.Length / 1MB, 2)) MB)" $c.Yellow
        Write-Cyber "  Creado:     $($item.CreationTime)" $c.Dim
        Write-Cyber "  Modificado: $($item.LastWriteTime)" $c.Dim
        Write-Cyber "  Atributos:  $($item.Attributes)" $c.Dim

        # Solo lectura?
        if ($item.IsReadOnly) {
            Write-Cyber "  SOLO LECTURA" $c.Magenta
        }
    }
    Write-Host ""
}

# ================================================================= #
#  hash — Calcular el hash SHA-256 de un archivo                    #
# ================================================================= #
# Uso: hash .\descarga.iso
# Uso: hash C:\Users\Usuario\Downloads\programa.exe
function hash {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Ruta,

        [ValidateSet('SHA256', 'SHA1', 'MD5', 'SHA384', 'SHA512')]
        [string]$Algoritmo = 'SHA256'
    )
    $c = $global:CY

    if (-not (Test-Path $Ruta -PathType Leaf)) {
        Write-Cyber "No existe o no es un archivo: $Ruta" $c.Magenta
        return
    }

    Write-Cyber "Calculando $Algoritmo..." $c.Dim
    $h = Get-FileHash $Ruta -Algorithm $Algoritmo
    Write-Host ""
    Write-Cyber "  Archivo:    $(Split-Path $h.Path -Leaf)" $c.Cyan
    Write-Cyber "  $($Algoritmo):  $($h.Hash)" $c.Yellow
    Write-Cyber "  Tamano:     $([math]::Round((Get-Item $Ruta).Length / 1MB, 2)) MB" $c.Dim
    Write-Host ""
}

# ================================================================= #
#  peso — Que carpetas ocupan mas espacio                           #
# ================================================================= #
# Uso: peso                   (carpeta actual)
# Uso: peso C:\Users\Usuario  (otra carpeta)
function peso {
    param(
        [Parameter(Position = 0)]
        [string]$Ruta = "."
    )
    $c = $global:CY

    if (-not (Test-Path $Ruta -PathType Container)) {
        Write-Cyber "No existe o no es una carpeta: $Ruta" $c.Magenta
        return
    }

    Write-Cyber "Calculando tamanos..." $c.Dim
    $resultados = Get-ChildItem $Ruta -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $tamano = (Get-ChildItem $_.FullName -Recurse -File -Force -ErrorAction SilentlyContinue |
                   Measure-Object Length -Sum).Sum
        [pscustomobject]@{
            Carpeta = $_.Name
            MB      = [math]::Round($tamano / 1MB, 1)
            Archivos = @(Get-ChildItem $_.FullName -Recurse -File -Force -ErrorAction SilentlyContinue).Count
        }
    } | Sort-Object MB -Descending

    if (-not $resultados) {
        Write-Cyber "No hay subcarpetas en $Ruta" $c.Dim
        return
    }

    Write-Host ""
    Write-Cyber "  $("CARPETA".PadRight(35)) $("MB".PadLeft(10))  ARCHIVOS" $c.Green
    Write-Cyber "  $("-" * 60)" $c.Dim
    foreach ($r in $resultados) {
        $col = if ($r.MB -gt 100) { $c.Magenta } elseif ($r.MB -gt 10) { $c.Yellow } else { $c.Cyan }
        Write-Cyber "  $($r.Carpeta.PadRight(35)) $($r.MB.ToString().PadLeft(10))  $($r.Archivos)" $col
    }

    $totalMB = ($resultados | Measure-Object MB -Sum).Sum
    Write-Host ""
    Write-Cyber "  Total: $([math]::Round($totalMB, 1)) MB en $($resultados.Count) carpetas" $c.Green
    Write-Host ""
}

# ================================================================= #
#  buscar — Encontrar archivos por nombre                           #
# ================================================================= #
# Uso: buscar informe                (en carpeta actual)
# Uso: buscar .pdf C:\Users\Usuario  (en otra carpeta)
# Uso: buscar config -Ext ini,conf   (solo ciertas extensiones)
function buscar {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Nombre,

        [Parameter(Position = 1)]
        [string]$Ruta = ".",

        [string[]]$Ext
    )
    $c = $global:CY

    Write-Cyber "Buscando '*$Nombre*'..." $c.Dim

    $resultados = Get-ChildItem $Ruta -Recurse -Filter "*$Nombre*" -ErrorAction SilentlyContinue

    if ($Ext) {
        $resultados = $resultados | Where-Object {
            $extension = $_.Extension.TrimStart('.')
            $Ext -contains $extension
        }
    }

    $resultados = @($resultados | Select-Object -First 50)

    if ($resultados.Count -eq 0) {
        Write-Cyber "No se encontro nada con '*$Nombre*'" $c.Dim
        return
    }

    Write-Host ""
    foreach ($r in $resultados) {
        $tamano = if ($r.PSIsContainer) { "[DIR]" } else { "$([math]::Round($r.Length / 1KB, 1)) KB" }
        Write-Cyber "  $($tamano.PadLeft(12))  " $c.Yellow -NoNewline
        Write-Cyber "$($r.FullName)" $c.Cyan
    }
    Write-Host ""
    if ($resultados.Count -eq 50) {
        Write-Cyber "  (mostrando los primeros 50 resultados)" $c.Dim
    }
    Write-Cyber "  $($resultados.Count) resultado(s)" $c.Green
    Write-Host ""
}

# ================================================================= #
#  duplicados — Encontrar archivos duplicados por hash              #
# ================================================================= #
# Uso: duplicados                     (carpeta actual)
# Uso: duplicados C:\Users\Descargas  (otra carpeta)
# Uso: duplicados . -MinKB 100       (solo archivos > 100 KB)
function duplicados {
    param(
        [Parameter(Position = 0)]
        [string]$Ruta = ".",

        [int]$MinKB = 1
    )
    $c = $global:CY

    Write-Cyber "Buscando duplicados (archivos > $MinKB KB)..." $c.Dim

    $archivos = @(Get-ChildItem $Ruta -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Length -gt ($MinKB * 1KB) })

    if ($archivos.Count -eq 0) {
        Write-Cyber "No hay archivos que analizar." $c.Dim
        return
    }

    Write-Cyber "Calculando hashes de $($archivos.Count) archivos..." $c.Dim

    # Primero agrupar por tamano (solo pueden ser duplicados si pesan lo mismo)
    $porTamano = $archivos | Group-Object Length | Where-Object { $_.Count -gt 1 }

    $candidatos = @($porTamano | ForEach-Object { $_.Group } )

    if ($candidatos.Count -eq 0) {
        Write-Cyber "No hay duplicados (ningun archivo tiene el mismo tamano que otro)." $c.Green
        return
    }

    Write-Cyber "Comparando $($candidatos.Count) candidatos..." $c.Dim

    $conHash = $candidatos | ForEach-Object {
        [pscustomobject]@{
            Hash = (Get-FileHash $_.FullName -Algorithm MD5).Hash
            Nombre = $_.Name
            Ruta = $_.FullName
            KB = [math]::Round($_.Length / 1KB, 1)
        }
    }

    $dupes = $conHash | Group-Object Hash | Where-Object { $_.Count -gt 1 }

    if ($dupes.Count -eq 0) {
        Write-Cyber "No hay duplicados." $c.Green
        return
    }

    Write-Host ""
    $totalDupes = 0
    $totalBytes = 0
    foreach ($grupo in $dupes) {
        Write-Cyber "  Duplicados ($($grupo.Count) copias, $($grupo.Group[0].KB) KB cada una):" $c.Magenta
        foreach ($f in $grupo.Group) {
            Write-Cyber "    $($f.Ruta)" $c.Cyan
            $totalDupes++
        }
        # El espacio desperdiciado es (copias - 1) * tamano
        $totalBytes += ($grupo.Count - 1) * $grupo.Group[0].KB * 1KB
        Write-Host ""
    }

    Write-Cyber "  $totalDupes archivos duplicados en $($dupes.Count) grupos" $c.Yellow
    Write-Cyber "  Espacio desperdiciado: $([math]::Round($totalBytes / 1MB, 2)) MB" $c.Yellow
    Write-Host ""
}

# ================================================================= #
#  renombrar — Renombrar archivos en lote                           #
# ================================================================= #
# Uso: renombrar -Prefijo "2024_"              (anadir prefijo)
# Uso: renombrar -Reemplazar "foto","img"      (cambiar texto)
# Uso: renombrar -Extension txt,bak            (cambiar extension)
# Uso: renombrar -Prefijo "BKP_" -WhatIf       (simular sin hacer nada)
function renombrar {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Ruta = ".",
        [string]$Filtro = "*",
        [string]$Prefijo,
        [string[]]$Reemplazar,   # @("viejo", "nuevo")
        [string[]]$Extension,    # @("txt", "bak") — de txt a bak
        [switch]$Numerar         # foto.jpg -> 001_foto.jpg, 002_foto.jpg...
    )
    $c = $global:CY

    $archivos = @(Get-ChildItem $Ruta -File -Filter $Filtro -ErrorAction SilentlyContinue)
    if ($archivos.Count -eq 0) {
        Write-Cyber "No hay archivos que coincidan con '$Filtro' en $Ruta" $c.Dim
        return
    }

    $contador = 1
    foreach ($f in $archivos) {
        $nuevo = $f.Name

        if ($Prefijo) {
            $nuevo = "$Prefijo$nuevo"
        }

        if ($Reemplazar -and $Reemplazar.Count -ge 2) {
            $nuevo = $nuevo -replace [regex]::Escape($Reemplazar[0]), $Reemplazar[1]
        }

        if ($Extension -and $Extension.Count -ge 2) {
            $nuevo = $nuevo -replace "\.$($Extension[0])$", ".$($Extension[1])"
        }

        if ($Numerar) {
            $num = $contador.ToString().PadLeft(3, '0')
            $nuevo = "${num}_$nuevo"
            $contador++
        }

        if ($nuevo -ne $f.Name) {
            if ($PSCmdlet.ShouldProcess($f.Name, "Renombrar a '$nuevo'")) {
                Rename-Item $f.FullName -NewName $nuevo
                Write-Cyber "  $($f.Name)  ->  $nuevo" $c.Cyan
            }
        }
    }
}

# ================================================================= #
#  comparar — Comparar dos carpetas (que tiene una que no la otra)  #
# ================================================================= #
# Uso: comparar C:\CarpetaA C:\CarpetaB
function comparar {
    param(
        [Parameter(Mandatory, Position = 0)][string]$CarpetaA,
        [Parameter(Mandatory, Position = 1)][string]$CarpetaB
    )
    $c = $global:CY

    if (-not (Test-Path $CarpetaA)) { Write-Cyber "No existe: $CarpetaA" $c.Magenta; return }
    if (-not (Test-Path $CarpetaB)) { Write-Cyber "No existe: $CarpetaB" $c.Magenta; return }

    $nombresA = @(Get-ChildItem $CarpetaA -File | ForEach-Object { $_.Name })
    $nombresB = @(Get-ChildItem $CarpetaB -File | ForEach-Object { $_.Name })

    $soloEnA = @($nombresA | Where-Object { $nombresB -notcontains $_ })
    $soloEnB = @($nombresB | Where-Object { $nombresA -notcontains $_ })
    $enAmbos = @($nombresA | Where-Object { $nombresB -contains $_ })

    Write-Host ""
    Write-Cyber "  A: $(Split-Path $CarpetaA -Leaf) ($($nombresA.Count) archivos)" $c.Cyan
    Write-Cyber "  B: $(Split-Path $CarpetaB -Leaf) ($($nombresB.Count) archivos)" $c.Cyan
    Write-Host ""

    if ($soloEnA.Count -gt 0) {
        Write-Cyber "  Solo en A ($($soloEnA.Count)):" $c.Yellow
        foreach ($n in $soloEnA) { Write-Cyber "    $n" $c.Dim }
    }

    if ($soloEnB.Count -gt 0) {
        Write-Cyber "  Solo en B ($($soloEnB.Count)):" $c.Yellow
        foreach ($n in $soloEnB) { Write-Cyber "    $n" $c.Dim }
    }

    Write-Cyber "  En ambos: $($enAmbos.Count)" $c.Green
    Write-Host ""
}

# ================================================================= #
#                           AYUDA                                   #
# ================================================================= #
function Show-FileToolsHelp {
    $c = $global:CY
    Write-Host ""
    Write-Cyber "  ============================================" $c.Magenta
    Write-Cyber "  FILE TOOLS — Funciones para archivos" $c.Green
    Write-Cyber "  ============================================" $c.Magenta
    Write-Host ""
    $cmds = @(
        @{ K = "info <ruta>";              D = "Informacion completa de un archivo o carpeta" }
        @{ K = "hash <ruta> [-Algo MD5]";  D = "Hash SHA-256 (o MD5/SHA1/SHA512) de un archivo" }
        @{ K = "peso [ruta]";              D = "Que subcarpetas ocupan mas espacio" }
        @{ K = "buscar <texto> [ruta]";    D = "Encontrar archivos por nombre (-Ext para filtrar)" }
        @{ K = "duplicados [ruta]";        D = "Encontrar archivos duplicados por hash (-MinKB)" }
        @{ K = "renombrar [-Prefijo]";     D = "Renombrar en lote: -Prefijo, -Reemplazar, -Extension, -Numerar (-WhatIf)" }
        @{ K = "comparar <A> <B>";         D = "Comparar dos carpetas: que tiene una que no la otra" }
        @{ K = "file-tools";               D = "Mostrar esta ayuda" }
    )
    foreach ($item in $cmds) {
        Write-Cyber "  $($item.K.PadRight(30))" $c.Yellow -NoNewline
        Write-Cyber "$($item.D)" $c.Cyan
    }
    Write-Host ""
    Write-Cyber "  Tip: arrastra un archivo a la terminal para pegar su ruta" $c.Dim
    Write-Host ""
}

Set-Alias file-tools Show-FileToolsHelp
