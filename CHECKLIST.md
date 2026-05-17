# BMB Encover Agent — CHECKLIST FINAL

## Estado actual
- ✅ Server Windows (bmb-server.exe build #12) funcionando en puerto 8643
- ✅ Chat REST responde con agente real  
- ✅ Fix NoneType incluido
- ✅ Watchdog Linux→Windows operativo
- ✅ App Flutter creada (29 archivos, ~4.600 líneas)

---

## 📋 PASOS PENDIENTES

### 1. Backend — WebSocket
- [ ] Verificar WS `/ws` funciona desde Windows (probar con cliente)
- [ ] Verificar WS `/ws/voice` funciona
- [ ] Streaming de respuestas (en lugar de esperar la respuesta completa)

### 2. Backend — QR Pairing
- [ ] Verificar `POST /api/pair` con token válido
- [ ] Probar flujo completo: `bmb pair` (genera QR) → app escanea → POST /api/pair → obtiene api_key
- [ ] Persistencia de dispositivos vinculados (`~/.bmb/app_auth.json`)

### 3. App Flutter — Compilar para Windows
- [ ] Instalar Flutter en Windows (flutter.dev)
- [ ] `cd bmb_app && flutter pub get`
- [ ] `flutter build windows`
- [ ] Probar app de escritorio conectada a `localhost:8643`

### 4. App Flutter — Compilar para Android
- [ ] `flutter build apk`
- [ ] Instalar APK en el celular
- [ ] Configurar Tailscale en PC y celular
- [ ] Probar conexión remota

### 5. App Flutter — Funcionalidades
- [ ] Pantalla de onboarding (conectar a server)
- [ ] Sistema de pestañas multi-instancia
- [ ] Chat funcional con WebSocket
- [ ] Live Mode (WebSocket de voz)
- [ ] Consola oculta
- [ ] Settings (modelo, TTS, conexión)

### 6. Live Mode — Voz
- [ ] Integrar Whisper (STT) en el server
- [ ] Integrar Kokoro/Piper (TTS) en el server
- [ ] Flujo completo: micrófono → STT → agente → TTS → parlante
- [ ] VAD (Voice Activity Detection)
- [ ] Modo interrupción

### 7. Skills Hub
- [ ] Index de skills generado (✅ 88 skills indexados)
- [ ] Búsqueda semántica en skills
- [ ] MCP manifest para descubrimiento

### 8. Release
- [ ] Builds automáticos en Actions (✅ build.yml)
- [ ] Tags semánticos para releases
- [ ] .exe para descargar desde GitHub Releases

### 9. Documentación
- [ ] README con instrucciones de instalación
- [ ] Guía de conexión remota (Tailscale)
- [ ] Documentación de la API
