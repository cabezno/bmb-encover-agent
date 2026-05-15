# ==========================================
# BMB Encover Agent — Configuración Windows
# ==========================================
# Ejecutar en PowerShell:
#   powershell -ExecutionPolicy Bypass -File setup_windows.ps1

$ErrorActionPreference = "Stop"
$BMB_DIR = "$env:USERPROFILE\.bmb"
$BMB_EXE = Join-Path $PSScriptRoot "bmb.exe"

Write-Host "=== BMB Encover Agent — Configuración Windows ===" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar que bmb.exe existe
if (!(Test-Path $BMB_EXE)) {
    Write-Host "[ERROR] No se encuentra bmb.exe en $PSScriptRoot" -ForegroundColor Red
    Write-Host "        Asegurate de estar en la misma carpeta que bmb.exe"
    pause
    exit 1
}

Write-Host "[OK] bmb.exe encontrado" -ForegroundColor Green

# 2. Crear carpeta de configuración
if (!(Test-Path $BMB_DIR)) {
    New-Item -ItemType Directory -Path $BMB_DIR -Force | Out-Null
    Write-Host "[OK] Carpeta $BMB_DIR creada" -ForegroundColor Green
} else {
    Write-Host "[OK] Carpeta $BMB_DIR ya existe" -ForegroundColor Green
}

# 3. Configurar .env
Write-Host ""
Write-Host "Configuración de API Key" -ForegroundColor Yellow
Write-Host "Dejá vacío y presioná Enter para usar la key por defecto (DeepSeek)."
$apiKey = Read-Host "API Key de DeepSeek (Enter = usar default)"

if ([string]::IsNullOrWhiteSpace($apiKey)) {
    $apiKey = "sk-bce51366b7ea42d296ef633f1fbea2f5"
    Write-Host "[INFO] Usando API Key por defecto" -ForegroundColor Gray
}

# Guardar .env
@"
DEEPSEEK_API_KEY=$apiKey
BMB_APP_PORT=8643
"@ | Out-File -FilePath "$BMB_DIR\.env" -Encoding UTF8
Write-Host "[OK] .env configurado" -ForegroundColor Green

# 4. Configurar config.yaml
@"
provider:
  model: deepseek-chat
  base_url: https://api.deepseek.com/v1
  api_key: $apiKey
"@ | Out-File -FilePath "$BMB_DIR\config.yaml" -Encoding UTF8
Write-Host "[OK] config.yaml configurado" -ForegroundColor Green

# 5. Agregar al PATH
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$PSScriptRoot*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$PSScriptRoot", "User")
    Write-Host "[OK] $PSScriptRoot agregado al PATH de usuario" -ForegroundColor Green
    Write-Host "     Reiniciá la terminal para usar 'bmb' desde cualquier lado." -ForegroundColor Yellow
} else {
    Write-Host "[OK] $PSScriptRoot ya está en el PATH" -ForegroundColor Green
}

# 6. Probar
Write-Host ""
Write-Host "=== Probando BMB ===" -ForegroundColor Cyan
try {
    $result = & $BMB_EXE --help 2>&1 | Select-Object -First 3
    Write-Host "[OK] BMB responde correctamente" -ForegroundColor Green
} catch {
    Write-Host "[WARN] No se pudo probar BMB: $_" -ForegroundColor Yellow
}

# 7. Iniciar server (opcional)
Write-Host ""
Write-Host "¿Querés iniciar el servidor ahora?" -ForegroundColor Cyan
$startServer = Read-Host "Iniciar servidor? (s/N)"

if ($startServer -eq "s" -or $startServer -eq "S") {
    Write-Host "[INFO] Iniciando App Server en puerto 8643..." -ForegroundColor Yellow
    Write-Host "      Abrí http://localhost:8643/health en tu navegador"
    Write-Host "      Presioná Ctrl+C para detener"
    Write-Host ""
    & $BMB_EXE app_server --port 8643
}

Write-Host ""
Write-Host "=== Configuración completada ===" -ForegroundColor Green
Write-Host ""
Write-Host "Comandos útiles:" -ForegroundColor Cyan
Write-Host "  bmb.exe app_server --port 8643        Iniciar servidor"
Write-Host "  bmb.exe pair                           Vincular dispositivo"
Write-Host "  curl http://localhost:8643/health       Ver estado"
pause
