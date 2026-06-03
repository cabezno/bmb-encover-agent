# Scripts de Automatización - GrabarPodcast

## Monitoreo
- `grabarpodcast_watchdog.py` — Verifica cada 5min que los servicios estén activos (web, gateway, bridge). Envía alerta a WhatsApp si algo está caído. Cron: GrabarPodcast Watchdog (cada 5m).

## Agenda y Calendario
- `agenda_semanal.py` — Lista eventos de la semana siguiente. Se ejecuta Domingos 9:00.
- `recordatorio_diario.py` — Lista eventos de mañana. Se ejecuta Lun-Dom 20:00.
- Targets de cron para delivery vía WhatsApp (NO usar números de teléfono, usar el nombre del contacto exacto del bridge):
  - Santiago Paradeda → `whatsapp:Santiago Paradeda (dm)` o chat ID `13430463447048@lid`
  - Adriana Gutierrez → `whatsapp:Adriana Gutierrez (dm)` o chat ID `263557077811238@lid`
- ⚠️ Los cron jobs NO se configuran con números de teléfono (`59898397283`) porque el bridge no resuelve números a contactos en delivery proactivo. Usar el nombre exacto listado por `hermes message list`.

## Gateway Modifications
- `/usr/local/lib/hermes-agent/gateway/run.py` — Modificado para: reenvío automático al dueño tras cada interacción, ocultar "Interrupting current task" a clientes
- `/usr/local/lib/hermes-agent/gateway/platforms/whatsapp.py` — Modificado para: _classify_contact(), auto-skill loading para clientes
