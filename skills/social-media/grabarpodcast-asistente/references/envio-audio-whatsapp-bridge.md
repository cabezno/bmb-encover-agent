# Envío de Audio por WhatsApp (bridge directo)

El `send_message` de Hermes NO soporta MEDIA attachments para WhatsApp. Para enviar archivos de audio (ej: pruebas de TTS, audios de prueba), hay que llamar directo al bridge Baileys.

## Método: curl directo al bridge

```bash
# El bridge corre en http://127.0.0.1:3000 (verificar puerto con ps aux | grep bridge)
curl -s -X POST "http://127.0.0.1:3000/send-media" \
  -H "Content-Type: application/json" \
  -d '{
    "chatId":"13430463447048@lid",
    "filePath":"/ruta/al/archivo.mp3",
    "mediaType":"audio",
    "caption":"Descripción opcional"
  }'
```

## Parámetros

| Campo | Valor | Descripción |
|-------|-------|-------------|
| chatId | LID de WhatsApp (ej: `13430463447048@lid`) | El del chat de destino |
| filePath | Ruta absoluta al archivo | El archivo debe existir y ser accesible |
| mediaType | `"audio"`, `"document"`, `"image"`, `"video"` | `"audio"` para que se reproduzca inline. `"document"` si no se abre |
| fileName | Solo para `mediaType: "document"` | Nombre visible del archivo |
| caption | Texto opcional | Aparece debajo del audio |

## Pitfalls

- **Usar `mediaType: "audio"`** para que WhatsApp lo muestre como audio reproducible. Si usás `"document"` con .mp3, el receptor ve un archivo que quizás no puede abrir.
- **El chat ID del dueño** (Santiago) es `13430463447048@lid`. No usar número de teléfono.
- **Para enviar a Adriana** usar `263557077811238@lid` (su LID).
- **El puerto del bridge** puede variar. Verificar con `ps aux | grep bridge.js`.
- **Errores comunes:** `Cannot destructure property 'user'` = el chat ID no es válido. Usar `send_message` con target `whatsapp:Nombre Contacto (dm)` primero para descubrir el LID.
- **MP3 funciona como audio**, pero WhatsApp no lo reproduce como mensaje de voz (ptt). Para voice messages usar OGG Opus con `ptt=true` (ver skill `whatsapp-voice-reply-config`).
