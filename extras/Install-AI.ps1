# ================================================================= #
#       Install-AI.ps1 — Instalador de asistentes IA para terminal  #
#       github.com/HEO-80/powershell-cyberpunk                      #
#                                                                    #
#  Cargar directamente:                                              #
#    irm https://raw.githubusercontent.com/HEO-80/powershell-cyberpunk/main/extras/Install-AI.ps1 | iex
#                                                                    #
#  O ejecutar localmente:                                            #
#    .\extras\Install-AI.ps1                                         #
# ================================================================= #
# Instala y configura asistentes IA de linea de comandos:
#   - Opencode (Gemini, gratis con API key)
#   - Claude Code (Anthropic, requiere API key o suscripcion)
#   - GitHub Copilot CLI (requiere suscripcion GitHub Copilot)

$ErrorActionPreference = "Stop"
$esc = [char]27

# ── Funciones de ayuda para colores ──────────────────────────────
function Write-Step  { param($t) Write-Host "${esc}[38;2;252;238;10m  > $t${esc}[0m" }
function Write-OK    { param($t) Write-Host "${esc}[38;2;57;255;20m  OK $t${esc}[0m" }
function Write-Warn  { param($t) Write-Host "${esc}[38;2;198;120;221m  ! $t${esc}[0m" }
function Write-Fail  { param($t) Write-Host "${esc}[38;2;255;48;48m  X $t${esc}[0m" }
function Write-Info  { param($t) Write-Host "${esc}[38;2;0;240;255m  i $t${esc}[0m" }

# ── Banner ───────────────────────────────────────────────────────
Write-Host ""
Write-Host "${esc}[38;2;252;238;10m  ========================================${esc}[0m"
Write-Host "${esc}[38;2;252;238;10m   Install-AI  ·  Asistentes IA          ${esc}[0m"
Write-Host "${esc}[38;2;252;238;10m  ========================================${esc}[0m"
Write-Host ""
Write-Info "Este script instala asistentes de IA para tu terminal."
Write-Info "Puedes instalar uno, varios o todos."
Write-Host ""

# ================================================================= #
#                      MENU PRINCIPAL                               #
# ================================================================= #
function Show-AIMenu {
    Write-Host ""
    Write-Host "${esc}[38;2;0;240;255m  Asistentes disponibles:${esc}[0m"
    Write-Host ""
    Write-Host "${esc}[38;2;252;238;10m  [1]${esc}[0m Opencode   ${esc}[38;2;136;136;136m— IA en terminal (Gemini, gratis con API key)${esc}[0m"
    Write-Host "${esc}[38;2;252;238;10m  [2]${esc}[0m Claude Code ${esc}[38;2;136;136;136m— IA de Anthropic (API key o Max/Teams/Enterprise)${esc}[0m"
    Write-Host "${esc}[38;2;252;238;10m  [3]${esc}[0m Copilot CLI ${esc}[38;2;136;136;136m— IA de GitHub (requiere suscripcion Copilot)${esc}[0m"
    Write-Host "${esc}[38;2;252;238;10m  [A]${esc}[0m Instalar todos"
    Write-Host "${esc}[38;2;252;238;10m  [Q]${esc}[0m Salir"
    Write-Host ""
}

# ================================================================= #
#              1. OPENCODE (Gemini — Google AI)                     #
# ================================================================= #
function Install-Opencode {
    Write-Host ""
    Write-Step "=== OPENCODE (Gemini) ==="
    Write-Host ""

    # Comprobar si ya esta instalado
    if (Get-Command opencode -ErrorAction SilentlyContinue) {
        Write-OK "Opencode ya esta instalado: $(opencode --version 2>$null)"
        $reinstalar = Read-Host "  Reinstalar? (s/N)"
        if ($reinstalar -notin @("s", "S", "si", "Si")) { return }
    }

    # Instalar con npm (necesita Node.js)
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Warn "Necesitas Node.js. Instalando..."
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget install OpenJS.NodeJS.LTS -s winget --accept-package-agreements --accept-source-agreements 2>$null
            # Refrescar PATH
            $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
        } else {
            Write-Fail "No se pudo instalar Node.js automaticamente."
            Write-Info "Descargalo de: https://nodejs.org"
            return
        }
    }

    Write-Step "Instalando Opencode con npm..."
    npm install -g opencode 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-OK "Opencode instalado"
    } else {
        Write-Fail "Error instalando opencode"
        return
    }

    # Configurar API Key de Gemini
    Write-Host ""
    Write-Info "Opencode usa Gemini de Google (gratis con API key)."
    Write-Info "Necesitas una API key de Google AI Studio."
    Write-Host ""

    $configurar = Read-Host "  Quieres configurar la API key ahora? (S/n)"
    if ($configurar -in @("", "s", "S", "si", "Si")) {

        Write-Step "Abriendo Google AI Studio para obtener tu API key..."
        Start-Process "https://aistudio.google.com/apikey"
        Write-Host ""
        Write-Info "1. Inicia sesion con tu cuenta de Google"
        Write-Info "2. Haz clic en 'Create API key'"
        Write-Info "3. Copia la key y pegala aqui abajo"
        Write-Host ""

        $apiKey = Read-Host "  Pega tu API key de Gemini"

        if ($apiKey -and $apiKey.Length -gt 10) {
            # Guardar como variable de entorno permanente
            [System.Environment]::SetEnvironmentVariable("GEMINI_API_KEY", $apiKey, "User")
            $env:GEMINI_API_KEY = $apiKey
            Write-OK "API key guardada como variable de entorno GEMINI_API_KEY"
            Write-Info "La key estara disponible en todas las terminales nuevas."
        } else {
            Write-Warn "No se guardo la API key. Puedes configurarla luego:"
            Write-Info '  [System.Environment]::SetEnvironmentVariable("GEMINI_API_KEY", "tu-key", "User")'
        }
    } else {
        Write-Info "Puedes configurarla luego:"
        Write-Info '  [System.Environment]::SetEnvironmentVariable("GEMINI_API_KEY", "tu-key", "User")'
    }

    Write-Host ""
    Write-OK "Opencode listo. Ejecuta: opencode"
}

# ================================================================= #
#           2. CLAUDE CODE (Anthropic — Claude)                     #
# ================================================================= #
function Install-ClaudeCode {
    Write-Host ""
    Write-Step "=== CLAUDE CODE (Anthropic) ==="
    Write-Host ""

    # Comprobar si ya esta instalado
    if (Get-Command claude -ErrorAction SilentlyContinue) {
        Write-OK "Claude Code ya esta instalado."
        $reinstalar = Read-Host "  Reinstalar? (s/N)"
        if ($reinstalar -notin @("s", "S", "si", "Si")) { return }
    }

    # Instalar con npm
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Warn "Necesitas Node.js. Instalando..."
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget install OpenJS.NodeJS.LTS -s winget --accept-package-agreements --accept-source-agreements 2>$null
            $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
        } else {
            Write-Fail "No se pudo instalar Node.js automaticamente."
            Write-Info "Descargalo de: https://nodejs.org"
            return
        }
    }

    Write-Step "Instalando Claude Code con npm..."
    npm install -g @anthropic-ai/claude-code 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-OK "Claude Code instalado"
    } else {
        Write-Fail "Error instalando Claude Code"
        return
    }

    # Opciones de autenticacion
    Write-Host ""
    Write-Info "Claude Code tiene dos formas de autenticarse:"
    Write-Host ""
    Write-Host "${esc}[38;2;252;238;10m  [1]${esc}[0m API key de Anthropic ${esc}[38;2;136;136;136m(de pago por uso)${esc}[0m"
    Write-Host "${esc}[38;2;252;238;10m  [2]${esc}[0m Cuenta Max/Teams/Enterprise ${esc}[38;2;136;136;136m(login con navegador)${esc}[0m"
    Write-Host "${esc}[38;2;252;238;10m  [3]${esc}[0m Configurar luego"
    Write-Host ""

    $opcion = Read-Host "  Elige opcion (1/2/3)"

    switch ($opcion) {
        "1" {
            Write-Step "Abriendo la consola de Anthropic para obtener tu API key..."
            Start-Process "https://console.anthropic.com/settings/keys"
            Write-Host ""
            Write-Info "1. Inicia sesion o crea una cuenta"
            Write-Info "2. Ve a Settings > API Keys"
            Write-Info "3. Crea una key y pegala aqui"
            Write-Host ""

            $apiKey = Read-Host "  Pega tu API key de Anthropic"

            if ($apiKey -and $apiKey.StartsWith("sk-")) {
                [System.Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY", $apiKey, "User")
                $env:ANTHROPIC_API_KEY = $apiKey
                Write-OK "API key guardada como ANTHROPIC_API_KEY"
            } else {
                Write-Warn "La key no parece valida (debe empezar por 'sk-')."
                Write-Info "Puedes configurarla luego:"
                Write-Info '  [System.Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY", "sk-...", "User")'
            }
        }
        "2" {
            Write-Step "Iniciando login con navegador..."
            Write-Info "Se abrira una ventana de autenticacion."
            try {
                claude login 2>$null
                Write-OK "Login completado"
            } catch {
                Write-Warn "No se pudo completar el login ahora."
                Write-Info "Ejecuta 'claude login' mas tarde."
            }
        }
        default {
            Write-Info "Puedes configurarlo luego ejecutando: claude"
        }
    }

    Write-Host ""
    Write-OK "Claude Code listo. Ejecuta: claude"
}

# ================================================================= #
#          3. GITHUB COPILOT CLI                                    #
# ================================================================= #
function Install-CopilotCLI {
    Write-Host ""
    Write-Step "=== GITHUB COPILOT CLI ==="
    Write-Host ""

    # Necesita gh (GitHub CLI) instalado
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Warn "GitHub CLI (gh) no esta instalado. Instalando..."
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget install GitHub.cli -s winget --accept-package-agreements --accept-source-agreements 2>$null
            $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
        } else {
            Write-Fail "No se pudo instalar gh automaticamente."
            Write-Info "Descargalo de: https://cli.github.com"
            return
        }
    }

    Write-OK "GitHub CLI encontrado"

    # Comprobar autenticacion
    $authStatus = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "No estas autenticado en GitHub CLI."
        $login = Read-Host "  Quieres hacer login ahora? (S/n)"
        if ($login -in @("", "s", "S", "si", "Si")) {
            Write-Step "Iniciando login de GitHub..."
            gh auth login
            if ($LASTEXITCODE -ne 0) {
                Write-Fail "No se pudo completar el login."
                return
            }
        } else {
            Write-Info "Ejecuta 'gh auth login' antes de usar Copilot."
            return
        }
    }

    # Instalar extension copilot
    Write-Step "Instalando extension GitHub Copilot..."
    gh extension install github/gh-copilot 2>$null
    if ($LASTEXITCODE -ne 0) {
        # Puede que ya este instalada, intentar actualizar
        gh extension upgrade gh-copilot 2>$null
    }
    Write-OK "GitHub Copilot CLI instalado"

    Write-Host ""
    Write-Info "Requiere una suscripcion activa de GitHub Copilot."
    Write-Info "Si no la tienes, activala en: https://github.com/settings/copilot"
    Write-Host ""
    Write-Info "Comandos disponibles:"
    Write-Host "${esc}[38;2;0;240;255m    gh copilot suggest${esc}[0m ${esc}[38;2;136;136;136m— pide un comando en lenguaje natural${esc}[0m"
    Write-Host "${esc}[38;2;0;240;255m    gh copilot explain${esc}[0m ${esc}[38;2;136;136;136m— explica un comando${esc}[0m"
    Write-Host ""

    # Alias opcionales
    $alias = Read-Host "  Quieres crear alias rapidos? 'cop' y 'explain' (S/n)"
    if ($alias -in @("", "s", "S", "si", "Si")) {
        # Anadir alias al $PROFILE
        $aliasLines = @(
            "",
            "# GitHub Copilot CLI aliases",
            "function cop { gh copilot suggest `$args }",
            "function explain { gh copilot explain `$args }"
        )

        $profileContent = ""
        if (Test-Path $PROFILE) {
            $profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
        }

        if ($profileContent -notmatch "copilot suggest") {
            Add-Content -Path $PROFILE -Value ($aliasLines -join "`n")
            Write-OK "Alias creados: 'cop' y 'explain'"
        } else {
            Write-OK "Los alias ya existen en tu perfil"
        }
    }

    Write-Host ""
    Write-OK "Copilot CLI listo. Ejecuta: gh copilot suggest 'listar archivos grandes'"
}

# ================================================================= #
#                   BUCLE PRINCIPAL                                 #
# ================================================================= #
$salir = $false
while (-not $salir) {
    Show-AIMenu
    $opcion = Read-Host "  Elige una opcion"

    switch ($opcion) {
        "1" { Install-Opencode }
        "2" { Install-ClaudeCode }
        "3" { Install-CopilotCLI }
        { $_ -in @("a", "A") } {
            Install-Opencode
            Install-ClaudeCode
            Install-CopilotCLI
        }
        { $_ -in @("q", "Q", "") } {
            $salir = $true
        }
        default {
            Write-Warn "Opcion no valida. Elige 1, 2, 3, A o Q."
        }
    }
}

# ── Resumen final ────────────────────────────────────────────────
Write-Host ""
Write-Host "${esc}[38;2;57;255;20m  ========================================${esc}[0m"
Write-Host "${esc}[38;2;57;255;20m   Instalacion de IA completada           ${esc}[0m"
Write-Host "${esc}[38;2;57;255;20m  ========================================${esc}[0m"
Write-Host ""

# Mostrar que quedo instalado
$instalados = @()
if (Get-Command opencode -ErrorAction SilentlyContinue) { $instalados += "Opencode (Gemini)" }
if (Get-Command claude -ErrorAction SilentlyContinue)   { $instalados += "Claude Code" }
if (Get-Command gh -ErrorAction SilentlyContinue) {
    $copilot = gh extension list 2>$null | Select-String "copilot"
    if ($copilot) { $instalados += "Copilot CLI" }
}

if ($instalados.Count -gt 0) {
    Write-OK "Asistentes IA instalados:"
    foreach ($ia in $instalados) {
        Write-Host "${esc}[38;2;0;240;255m    - $ia${esc}[0m"
    }
} else {
    Write-Info "No se instalo ningun asistente."
}

Write-Host ""
Write-Info "Reinicia PowerShell para que los cambios surtan efecto."
Write-Host ""
