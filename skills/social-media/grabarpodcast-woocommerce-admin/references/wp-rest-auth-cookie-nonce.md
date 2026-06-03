# WP REST API — Cookie + Nonce Auth Dance

## Cuándo usarlo

Cuando necesitás leer o modificar opciones de WordPress que **no tienen endpoint en la WooCommerce REST API** (v3). Ejemplos:

- `woocommerce_default_catalog_orderby` (orden de productos)
- `woocommerce_currency` (moneda)
- Cualquier `wp/v2/settings` que no tenga mirror en `wc/v3/settings`

## El dance completo

```bash
# 1. Login — obtiene cookie de sesión
curl -s -c /tmp/wp_cookies.txt "https://grabarpodcast.com/wp-login.php" > /dev/null
curl -s -L -b /tmp/wp_cookies.txt -c /tmp/wp_cookies.txt \
  -X POST "https://grabarpodcast.com/wp-login.php" \
  -d "log=USER_EMAIL&pwd=PASSWORD&wp-submit=Iniciar+sesi%C3%B3n&redirect_to=%2Fwp-admin%2F&testcookie=1" \
  -o /dev/null -w "%{http_code}"
# Debería devolver 200 (aunque el HTML sea el dashboard)

# 2. Obtener nonce
NONCE=$(curl -s -b /tmp/wp_cookies.txt \
  "https://grabarpodcast.com/wp-admin/admin-ajax.php?action=rest-nonce")
# Devuelve un hash de 10 caracteres alfanuméricos

# 3. Usar en requests
curl -s -X PUT -b /tmp/wp_cookies.txt -H "X-WP-Nonce: $NONCE" \
  -H "Content-Type: application/json" \
  -d '{"setting_key": "value"}' \
  "https://grabarpodcast.com/wp-json/wp/v2/settings"
```

## Pitfalls

- **WC API keys (ck_ / cs_)** dan `rest_forbidden` en `/wp/v2/settings`. No intentar.
- **PUT vs POST**: WP REST acepta PUT para `/wp/v2/settings`. Usar POST para `/wp/v2/pages/{id}`.
- **Las WC API keys tienen su propio scope limitado** a `/wc/v3/*`. No asumir que tienen acceso a nada fuera de eso.
- **El nonce expira** después de ~24h o al cerrar sesión. Regenerar para cada sesión de trabajo.
