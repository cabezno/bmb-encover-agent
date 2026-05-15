# ==========================================
# BMB Encover Agent — Instalador para Windows
# ==========================================
# Ejecutar en PowerShell como Administrador:
#   powershell -ExecutionPolicy Bypass -File install_windows.ps1
#

$ErrorActionPreference = "Stop"
$BMB_DIR = "$env:USERPROFILE\bmb-encover"
$BMB_EXE = "$BMB_DIR\bmb.exe"

Write-Host "=== BMB Encover Agent — Instalador Windows ===" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar si ya existe
if (Test-Path $BMB_EXE) {
    Write-Host "[INFO] BMB ya instalado en $BMB_EXE" -ForegroundColor Yellow
    $ver = & $BMB_EXE --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "       Versión: $ver" -ForegroundColor Green
    }
} else {
    Write-Host "[INFO] BMB no encontrado en $BMB_DIR" -ForegroundColor Yellow
}

# 2. Opciones de instalación
Write-Host ""
Write-Host "Opciones:" -ForegroundColor Cyan
Write-Host "  1. Usar Python (pip install -e .)"
Write-Host "  2. Usar ejecutable portable (bmb.exe)"
Write-Host "  3. Salir"
Write-Host ""

$choice = Read-Host "Seleccione una opción (1-3)"

switch ($choice) {
    "1" {
        # Instalación con Python
        Write-Host "[INFO] Instalando con Python..." -ForegroundColor Yellow

        # Verificar Python
        $pyVer = python --version 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[ERROR] Python no encontrado. Descargue Python 3.11+ de python.org" -ForegroundColor Red
            pause
            exit 1
        }
        Write-Host "[OK] $pyVer" -ForegroundColor Green

        # Crear directorio
        if (!(Test-Path $BMB_DIR)) {
            New-Item -ItemType Directory -Path $BMB_DIR -Force | Out-Null
        }

        # Copiar archivos (desde donde se ejecuta el script o desde GitHub)
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
        if (Test-Path "$scriptDir\run_agent.py") {
            Write-Host "[INFO] Copiando archivos locales..." -ForegroundColor Yellow
            Copy-Item "$scriptDir\*" "$BMB_DIR\" -Recurse -Force
        } else {
            Write-Host "[INFO] Descargando desde GitHub..." -ForegroundColor Yellow
            # TODO: cuando tengamos el repo público
            Write-Host "[ERROR] Todavía no hay release pública." -ForegroundColor Red
            pause
            exit 1
        }

        # Instalar
        Push-Location $BMB_DIR
        python -m venv venv
        .\venv\Scripts\Activate.ps1
        pip install -e .[pty,cli,mcp,cron,acp]
        Pop-Location

        # Crear alias en perfil de PowerShell
        $profilePath = $PROFILE.CurrentUserAllHosts
        $aliasLine = "`nSet-Alias -Name bmb -Value `"$BMB_DIR\venv\Scripts\bmb.exe`""
        if (!(Test-Path $profilePath)) {
            New-Item -ItemType File -Path $profilePath -Force | Out-Null
        }
        Add-Content -Path $profilePath -Value $aliasLine -NoNewline

        Write-Host "[OK] Instalación completada." -ForegroundColor Green
        Write-Host "     Reinicie PowerShell o ejecute: . `$PROFILE"
        Write-Host "     Luego pruebe: bmb --version"
    }
    "2" {
        # Instalación con ejecutable portable
        if (Test-Path $BMB_EXE) {
            Write-Host "[INFO] bmb.exe encontrado localmente." -ForegroundColor Green
        } else {
            Write-Host "[ERROR] No hay bmb.exe en $BMB_DIR" -ForegroundColor Red
            Write-Host "       Genere uno primero con build_windows.bat"
            pause
            exit 1
        }

        # Agregar al PATH del usuario
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($userPath -notlike "*$BMB_DIR*") {
            [Environment]::SetEnvironmentVariable("Path", "$userPath;$BMB_DIR", "User")
            Write-Host "[INFO] $BMB_DIR agregado al PATH de usuario." -ForegroundColor Green
            Write-Host "      Reinicie la terminal para aplicar."
        } else {
            Write-Host "[INFO] $BMB_DIR ya está en el PATH." -ForegroundColor Green
        }
        Write-Host ""
        Write-Host "[OK] Instalación completada." -ForegroundColor Green
        Write-Host "     Pruebe en una nueva terminal: bmb --version"
    }
    "3" {
        Write-Host "Saliendo..."
        exit 0
    }
    default {
        Write-Host "[ERROR] Opción inválida" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== Fin del instalador ===" -ForegroundColor Cyan
pause
