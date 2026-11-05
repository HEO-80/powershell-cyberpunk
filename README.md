<div align="center">

<img src="img/netwatch-header.svg" alt="NETWATCH OS v2.077"/>

<pre>
 ██╗  ██╗███████╗ ██████╗    ██████╗ ███████╗██╗   ██╗
 ██║  ██║██╔════╝██╔═══██╗   ██╔══██╗██╔════╝██║   ██║
 ███████║█████╗  ██║   ██║   ██║  ██║█████╗  ██║   ██║
 ██╔══██║██╔══╝  ██║   ██║   ██║  ██║██╔══╝  ╚██╗ ██╔╝
 ██║  ██║███████╗╚██████╔╝   ██████╔╝███████╗ ╚████╔╝
 ╚═╝  ╚═╝╚══════╝ ╚═════╝    ╚═════╝ ╚══════╝  ╚═══╝
</pre>

**Cyberpunk 2077–themed PowerShell with a built-in terminal training system**

</div>

---

## ⚡ Quick Install (one command)

```powershell
irm https://raw.githubusercontent.com/HEO-80/powershell-cyberpunk/main/install.ps1 | iex
```

This installs everything automatically: Oh My Posh, Nerd Font, Terminal-Icons, fzf, zoxide, PSFzf, and hooks into your `$PROFILE`.

> **After installing**, set your terminal font to **CaskaydiaCove Nerd Font** in Windows Terminal: `Settings > Profiles > Defaults > Font Face`.

---

## Screenshots

### Dashboard on startup

<img src="img/dashboard.png" alt="Dashboard" width="100%"/>

### Full dashboard with Docker and training reminders

<img src="img/dashboard-full.png" alt="Full Dashboard" width="100%"/>

### Terminal-Icons — icons for files and folders

<img src="img/terminal-icons.png" alt="Terminal Icons" width="100%"/>

### help-ps — all commands, shortcuts and tools

<img src="img/help-ps-1.png" alt="Help 1" width="100%"/>
<img src="img/help-ps-2.png" alt="Help 2" width="100%"/>

---

## What's Inside

### 🎨 Cyberpunk 2077 Theme
- **NETWATCH-style prompt** with git branch, path, and execution time (via Oh My Posh)
- **Dashboard** on startup: system info, shortcuts, Docker status, and training reminders
- **ANSI true-color palette**: yellow, neon green, cyan, magenta — fully customizable via `$global:CY`

### 🛠 Ergonomic Functions

| Command | What it does |
|---|---|
| `top-size [n]` | Top N biggest files in the current folder |
| `top-cpu [n]` | Top N processes by CPU usage |
| `matar <name>` | Kill process by name (min 3 chars, asks confirmation) |
| `puertos` | Listening ports with process names |
| `clean-logs [-WhatIf]` | Delete `.log` and `.tmp` recursively (`-WhatIf` = dry run) |
| `help-ps` | Show all commands, shortcuts, and installed tools |
| `Show-Dashboard` | Redisplay the startup dashboard |
| `Measure-Profile` | Measure how long your profile takes to load |

### ⌨️ Keyboard Shortcuts (PSReadLine)

| Key | Action |
|---|---|
| `Tab` | Navigable autocomplete menu |
| `Ctrl+T` | fzf: find files interactively |
| `Ctrl+R` | fzf: search command history |
| `Up/Down` | History filtered by what you've typed |
| `Ctrl+A` / `Ctrl+E` | Start / end of line |
| `Ctrl+W` | Delete word backward |
| `Alt+D` | Delete word forward |
| `Ctrl+L` | Clear screen |

### 🥋 Training System (Spaced Repetition)

A built-in practice system using **Leitner spaced repetition** — items you fail come back sooner, items you master appear less often. Track your progress with `progreso`.

| Module | Command | What you practice |
|---|---|---|
| **Dojo 1** | `dojo` / `quiz` | Command names: Linux vs PowerShell vs CMD |
| **Dojo 2** | `dojo2` | Full commands with arguments (intermediate) |
| **Rosetta** | `rosetta` | Side-by-side Linux / PowerShell / CMD equivalences |
| **Tatami 1** | `tatami` | Practical missions in a temporary sandbox (basic) |
| **Tatami 2** | `tatami2` | Intermediate missions: text, CSV, rename, try/catch |
| **Forja** | `forja` | Write PowerShell scripts — tested against cases |
| **Santuario** | `santuario` | Write bash scripts — runs in WSL |
| **Progress** | `progreso` | See your stats: mastered, due, most-failed |

**Options:** `-Preguntas N` · `-Modo Linux|PowerShell|Cmd` · `-Repaso` (review due items) · `-Lista` (list all) · `-Id <id>` (specific challenge)

---

## Installed Tools

| Tool | Purpose |
|---|---|
| [Oh My Posh](https://ohmyposh.dev/) | Custom prompt with git info |
| [Terminal-Icons](https://github.com/devblackops/Terminal-Icons) | File/folder icons in `ls` |
| [fzf](https://github.com/junegunn/fzf) + [PSFzf](https://github.com/kelleyma49/PSFzf) | Fuzzy finder for files and history |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | Smart `cd` — jump to frequent folders |
| [PSReadLine](https://github.com/PowerShell/PSReadLine) | Inline predictions from history |

---

## Manual Install

```powershell
git clone https://github.com/HEO-80/powershell-cyberpunk.git
cd powershell-cyberpunk
.\install.ps1
```

Or add this line to your `$PROFILE` manually:

```powershell
. "C:\path\to\powershell-cyberpunk\Profile.ps1"
```

## Structure

```
powershell-cyberpunk/
├── install.ps1              # Installer (works with irm|iex and locally)
├── Profile.ps1              # Entry point — sources the theme
├── themes/
│   ├── Cyberpunk2077.ps1    # Theme: colors, dashboard, functions, training loader
│   └── omp_cyberpunk.json   # Oh My Posh prompt theme
└── training/
    ├── Motor.ps1            # Leitner spaced repetition engine
    ├── Dojo.ps1             # Rosetta quiz: Linux / PowerShell / CMD
    ├── Dojo2.ps1            # Intermediate: full commands with arguments
    ├── Tatami1.ps1          # Sandbox missions (basic)
    ├── Tatami2.ps1          # Sandbox missions (intermediate)
    ├── Forja.ps1            # Write & test PowerShell scripts
    └── Santuario.ps1        # Write & test bash scripts (WSL)
```

## Requirements

- **PowerShell 5.1+** (Windows PowerShell) or **PowerShell 7+**
- **Windows Terminal** (recommended for full color support)
- **Git** (for installation)
- **WSL** (only needed for Santuario — bash training)

## License

MIT

---

<div align="center">

Made by [HEO-80](https://github.com/HEO-80) · Cyberpunk 2077 aesthetic, real sysadmin tools

</div>
