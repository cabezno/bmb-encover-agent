# QUICKSTART WINDOWS

Guia rapida para levantar BMB App Server en Windows.

## 1) Clonar repo

```powershell
git clone https://github.com/cabezno/bmb-encover-agent.git
cd bmb-encover-agent
```

## 2) Ejecutar setup

```powershell
.\setup_windows_portable.bat
```

## 3) Configurar API key

Editar:

- %USERPROFILE%\\.bmb\\.env

Agregar al menos:

```env
DEEPSEEK_API_KEY=tu_api_key
```

## 4) Iniciar servidor

```powershell
.\start_windows_portable.bat
```

## 5) Probar

```powershell
curl http://localhost:8643/health
```

Si responde `{"status":"ok"...}` ya esta funcionando.

## Si algo falla

- Leer guia completa: README_WINDOWS_PORTABLE.md
- Verificar Python 3.11+ en PATH
- Reintentar setup: .\setup_windows_portable.bat
