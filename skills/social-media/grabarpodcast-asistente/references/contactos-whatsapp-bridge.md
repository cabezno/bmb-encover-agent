# Contactos WhatsApp Bridge - GrabarPodcast

Los contactos del bridge de WhatsApp NO se identifican por número de teléfono. 
Usar siempre el nombre exacto listado por `send_message list` para targets de cron y envíos proactivos.

## Contactos principales

| Persona | Número real | Nombre en bridge (target) | LID (chat_id) |
|---------|-------------|---------------------------|----------------|
| Santiago Paradeda (dueño) | +59899244029 | `Santiago Paradeda (dm)` | `13430463447048@lid` |
| Adriana Gutierrez | +59898397283 | `Adriana Gutierrez (dm)` | `263557077811238@lid` |

## Reglas para envíos

1. **Cron jobs**: usar `whatsapp:<Nombre exacto (dm)>` como target de delivery.
2. **Envíos proactivos (send_message)**: usar `whatsapp:<Nombre exacto (dm)>` como target.
3. **NO usar números de teléfono directamente** — el bridge los rechaza con error `Cannot destructure property 'user' of 'jidDecode(...)'`.
4. Si un target por nombre falla y redirige al home (`13430463447048@lid`), usar el LID directamente (`whatsapp:<LID>`).
5. **Limitación conocida**: el bridge solo puede enviar mensajes a contactos que ya hayan escrito al bot primero. Si el envío proactivo falla, el mensaje llegará igual por el cron del recordatorio diario (20hs).

## Cómo listar contactos disponibles

```bash
hermes message list
```
