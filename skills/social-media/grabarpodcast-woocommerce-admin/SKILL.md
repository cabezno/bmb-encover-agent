---
name: grabarpodcast-woocommerce-admin
description: "Gestión técnica de WordPress y WooCommerce de GrabarPodcast — editar páginas, productos, categorías, settings, imágenes, banners, checkout, CSS, pedidos. Automatización vía REST API + WP REST + sesión con nonce."
version: 1.1.0
tags:
  - wordpress
  - woocommerce
  - grabarpodcast
  - productos
  - api
  - css
  - divi
---

# GrabarPodcast WooCommerce Admin

Skill especializado para gestionar **grabarpodcast.com** — WooCommerce, páginas, productos, settings y contenido.

## Credenciales

| Sistema | Credencial |
|---------|-----------|
| WordPress (login) | `paradedasantiago@gmail.com` / `*W6yAs@ReD)qg2#FQnbPT*ck` |
| WooCommerce API | Consumer Key: `ck_4b7195def11a9afb295604ddd96eff14f93d86b7` |
| | Consumer Secret: `cs_7f947abc3c46a930a5cd3f8dc597d5db9775f3c5` |
| Site | `https://grabarpodcast.com` |

## Conexión

### Para WP REST API (editar páginas, settings, options)
Siempre usar sesión con cookie + nonce:

```bash
# 1. Login
curl -s -c /tmp/wp_cookies.txt "https://grabarpodcast.com/wp-login.php" > /dev/null
curl -s -L -b /tmp/wp_cookies.txt -c /tmp/wp_cookies.txt \
  -X POST "https://grabarpodcast.com/wp-login.php" \
  -d "log=paradedasantiago@gmail.com&pwd=*W6yAs@ReD)qg2#FQnbPT*ck&wp-submit=Iniciar+sesi%C3%B3n&redirect_to=%2Fwp-admin%2F&testcookie=1" \
  -o /dev/null -w "%{http_code}"

# 2. Get nonce
NONCE=$(curl -s -b /tmp/wp_cookies.txt "https://grabarpodcast.com/wp-admin/admin-ajax.php?action=rest-nonce")
```

Luego usar `-b /tmp/wp_cookies.txt -H "X-WP-Nonce: $NONCE"` en los requests REST.

### Para WooCommerce CRUD (productos, categorías, pedidos)
Usar WooCommerce REST API v3 con Basic Auth (Consumer Key + Secret):

```bash
curl -s -u "ck_4b7195def11a9afb295604ddd96eff14f93d86b7:cs_7f947abc3c46a930a5cd3f8dc597d5db9775f3c5" \
  "https://grabarpodcast.com/wp-json/wc/v3/products?per_page=5"
```

## Historial de Interacciones Realizadas

### ⚙️ Configuración Inicial de la Tienda (Mayo 11)
- **Problema:** Tienda mostraba "Coming Soon" de WordPress 6.9 y página rota por Divi Builder
- **Soluciones:**
  1. Creó `disable-coming-soon.php` (mu-plugin) que aplica `add_filter('woocommerce_coming_soon', '__return_false')` y `add_filter('wp_coming_soon', '__return_false')`
  2. Desactivó Divi Builder en la página Tienda (ID 394) seteando `_et_pb_use_builder=off` vía XML-RPC
  3. Restauró contenido con shortcode `[products]` para que WooCommerce use su template
- **Producto duplicado:** Eliminó producto "PODCAST 1 Camara" (ID 399, incompleto, sin precio/categoría/imagen)

### 🖼️ Imágenes y Estilo (Mayo 11-14)
- **Imágenes asignadas:**
  - Podcast → ID 196 (composition_1769614682525.jpg)
  - Streaming → ID 175 (composition_1769567385320.jpg)
  - Packs → ID 200 (composition_1769613671030.jpg)
- **CSS de tienda:** Generó `grabarpodcast-tienda.css` (fondo oscuro, tarjetas glass, overlay de nombre en imágenes). NO se pudo inyectar automáticamente — requiere pegarlo en Apariencia → Personalizar → CSS Adicional
- **Overlay de texto:** Los nombres de productos aparecen en blanco con fuente Montserrat sobre la imagen

### 📦 Productos (Mayo 11-14)
- **Categorías creadas:** Packs Podcast (ID 29) y Packs Streaming (ID 30), hijos de Packs (ID 20)
- **6 packs creados** (4hs/6hs/12hs para Podcast y Streaming 1 Cámara Full) con descuentos del 10%, 15% y 30%
- **Script de 144 productos:** Se generó script Python para crear productos base (24) + packs (120) con precios, categorías, imágenes

### 📋 Banner de Reserva (Mayo 14)
- **Implementado en:** Tienda (ID 394) y Finalizar Compra (ID 396)
- **Diseño:** Fondo negro, texto blanco, botón naranja #e67e22 "📲 Consultar por WhatsApp"
- **Mensaje:** "📅 IMPORTANTE: Las reservas requieren coordinación previa. Luego de tu compra te contactaremos por WhatsApp para acordar fecha y horario."
- **⚠️ Problema conocido:** Cada escritura por API duplica el banner porque WordPress escapa HTML. **Solución:** Siempre eliminar TODAS las ocurrencias de "IMPORTANTE" (en HTML directo y escapado) antes de agregar uno nuevo
- **Método correcto:** Usar sesión con nonce + `requests.Session()`, NO XML-RPC

### 🛒 Configuración WooCommerce (Mayo 11-15)
- **Moneda:** UYU (Peso Uruguayo)
- **País:** Uruguay
- **Guest checkout:** Habilitado
- **Cupones:** Habilitados (cupón GRABAR2026 = 20% OFF)
- **Envío:** Deshabilitado (servicios locales)
- **Orden por defecto:** Precio (de menor a mayor) — seteado el 15/5/2026 vía WP REST API con nonce
  - **Caveat:** `woocommerce_default_catalog_orderby` NO tiene endpoint en WC API v3. Sólo se puede cambiar via WP REST `/wp/v2/settings` con nonce.
  - **Valor correcto:** `"price"` (no `"price_asc"`). WP REST rechaza cualquier valor que no esté en su enum: `menu_order`, `popularity`, `rating`, `date`, `price`, `price-desc`.
  - **WC API keys dan `rest_forbidden`** en este endpoint. Usar cookie+nonce (ver `references/wp-rest-auth-cookie-nonce.md`).
- **Payment gateways habilitados:**
  - Mercado Pago (`woo-mercado-pago-basic`) ✅
  - Tarjeta crédito/débito (`woo-mercado-pago-custom`) ✅
  - Efectivo (`woo-mercado-pago-ticket`) ✅

### 🔔 Webhooks (Mayo 12)
- **woo-orders:** `http://localhost:8644/webhooks/woo-orders`
- Evento: `woocommerce_order_status_completed`
- Delivery: WhatsApp al dueño

### 📱 WhatsApp Auto-Responder (Mayo 12)
- **Parche al SKILL.md** de `grabarpodcast-asistente` (v1.8.0) para reforzar que incluya links de la tienda al cotizar precios
- Flujo de venta: Efectivo (paso 1) → Link Mercado Pago (paso 2) → Cupón GRABAR2026 (paso 3)

## Páginas Clave

| Página | ID | URL |
|--------|----|-----|
| INICIO | 10 | / |
| Tienda | 394 | /tienda/ |
| Carrito | 395 | /carrito/ |
| Finalizar compra | 396 | /finalizar-compra/ |
| Mi cuenta | 397 | /mi-cuenta/ |
| Contacto | 485 | /contacto/ |
| Términos y Condiciones | 483 | /terminos-y-condiciones/ |

## Categorías de Productos

| Categoría | ID | Padre |
|-----------|----|-------|
| Podcast | 18 | - |
| Streaming | 19 | - |
| Packs | 20 | - |
| Packs Podcast | 29 | 20 |
| Packs Streaming | 30 | 20 |
| 1 Cámara (Podcast) | 21 | 18 |
| 2 Cámaras (Podcast) | 22 | 18 |
| 3 Cámaras (Podcast) | 23 | 18 |
| 4 Cámaras (Podcast) | 24 | 18 |
| 1 Cámara (Streaming) | 25 | 19 |
| 2 Cámaras (Streaming) | 26 | 19 |
| 3 Cámaras (Streaming) | 27 | 19 |
| 4 Cámaras (Streaming) | 28 | 19 |

## Imágenes de Productos

| ID | URL | Usada para |
|----|-----|-----------|
| 196 | composition_1769614682525.jpg | Podcast |
| 175 | composition_1769567385320.jpg | Streaming |
| 200 | composition_1769613671030.jpg | Packs |

## Productos — IDs por Categoría

### Podcast (12, imagen ID 196)
| ID | Nombre | Precio |
|----|--------|-------|
| 448 | Podcast 1 Cámara - Básico | $3.240 |
| 449 | Podcast 1 Cámara - Plus | $5.400 |
| 450 | Podcast 1 Cámara - Full | $7.560 |
| 451 | Podcast 2 Cámaras - Básico | $4.860 |
| 452 | Podcast 2 Cámaras - Plus | $7.020 |
| 453 | Podcast 2 Cámaras - Full | $9.180 |
| 454 | Podcast 3 Cámaras - Básico | $5.940 |
| 455 | Podcast 3 Cámaras - Plus | $8.100 |
| 456 | Podcast 3 Cámaras - Full | $10.260 |
| 457 | Podcast 4 Cámaras - Básico | $7.020 |
| 458 | Podcast 4 Cámaras - Plus | $9.180 |
| 459 | Podcast 4 Cámaras - Full | $11.340 |

### Streaming (12, imagen ID 175)
| ID | Nombre | Precio |
|----|--------|-------|
| 460 | Streaming 1 Cámara - Básico | $5.400 |
| 461 | Streaming 1 Cámara - Plus | $7.560 |
| 462 | Streaming 1 Cámara - Full | $9.720 |
| 463 | Streaming 2 Cámaras - Básico | $7.020 |
| 464 | Streaming 2 Cámaras - Plus | $9.180 |
| 465 | Streaming 2 Cámaras - Full | $11.340 |
| 466 | Streaming 3 Cámaras - Básico | $8.100 |
| 467 | Streaming 3 Cámaras - Plus | $10.260 |
| 468 | Streaming 3 Cámaras - Full | $12.420 |
| 469 | Streaming 4 Cámaras - Básico | $9.180 |
| 470 | Streaming 4 Cámaras - Plus | $11.340 |
| 471 | Streaming 4 Cámaras - Full | $13.500 |

### Packs (6, imagen ID 200)
| ID | Nombre | Precio | Categoría |
|----|--------|-------|----------|
| 472 | Pack 4hs Podcast 1 Cámara Full (10% OFF) | $27.216 | Packs Podcast |
| 473 | Pack 6hs Podcast 1 Cámara Full (15% OFF) | $38.556 | Packs Podcast |
| 474 | Pack 12hs Podcast 1 Cámara Full (30% OFF) | $63.504 | Packs Podcast |
| 475 | Pack 4hs Streaming 1 Cámara Full (10% OFF) | $34.992 | Packs Streaming |
| 476 | Pack 6hs Streaming 1 Cámara Full (15% OFF) | $49.572 | Packs Streaming |
| 477 | Pack 12hs Streaming 1 Cámara Full (30% OFF) | $81.648 | Packs Streaming |

## Operaciones Comunes

### 1. Leer/Editar página (contenido Gutenberg)
```bash
NONCE="<nonce>"
PAGE_ID=394

# GET page content (raw)
curl -s -b /tmp/wp_cookies.txt -H "X-WP-Nonce: $NONCE" \
  "https://grabarpodcast.com/wp-json/wp/v2/pages/$PAGE_ID"

# UPDATE page content — usar POST, NO PUT (PUT no funciona bien con nonce)
curl -s -X POST -b /tmp/wp_cookies.txt -H "X-WP-Nonce: $NONCE" \
  -H "Content-Type: application/json" \
  -d '{"content": "<!-- wp:paragraph --><p>Nuevo contenido</p><!-- /wp:paragraph -->"}' \
  "https://grabarpodcast.com/wp-json/wp/v2/pages/$PAGE_ID"
```

### 2. Banner de reserva (Tienda ID 394 / Finalizar Compra ID 396)
El banner debe estar AL INICIO del contenido, único.

**⚠️ CRITICAL: Siempre limpiar banners duplicados primero**
```python
import re, requests

s = requests.Session()
s.post("https://grabarpodcast.com/wp-login.php", data={
    "log": "paradedasantiago@gmail.com",
    "pwd": "*W6yAs@ReD)qg2#FQnbPT*ck",
    "wp-submit": "Iniciar sesión",
    "redirect_to": "/wp-admin/",
    "testcookie": "1"
})
nonce = s.get("https://grabarpodcast.com/wp-admin/admin-ajax.php?action=rest-nonce").text.strip()

# Obtener página
r = s.get(f"https://grabarpodcast.com/wp-json/wp/v2/pages/{page_id}",
          headers={"X-WP-Nonce": nonce})
content = r.json()['content']['rendered']

# ELIMINAR todos los banners existentes (HTML directo y escapado)
while 'IMPORTANTE' in content:
    content = re.sub(r'<!-- wp:group.*?IMPORTANTE.*?<!-- /wp:group -->', '', content, count=1, flags=re.DOTALL)
    content = re.sub(r'<div[^>]*>[\s\S]*?IMPORTANTE[\s\S]*?</div>', '', content, count=1, flags=re.DOTALL)
content = content.replace('&lt;', '<').replace('&gt;', '>')
content = re.sub(r'<div[^>]*>[\s\S]*?IMPORTANTE[\s\S]*?</div>', '', content, count=1, flags=re.DOTALL)

# Recién ahí agregar uno nuevo
banner_html = '<!-- wp:group --><div class="wp-block-group" style="background-color:#000;color:#fff;padding:20px;text-align:center;border-radius:8px;margin-bottom:20px"><p style="font-size:16px;margin:0 0 10px 0"><strong>📅 IMPORTANTE:</strong> Las reservas requieren coordinación previa. Luego de tu compra te contactaremos por WhatsApp para acordar fecha y horario.</p><a href="https://wa.me/59899244029?text=Hola%21+Quiero+coordinar+mi+reserva" style="display:inline-block;background-color:#e67e22;color:#fff;padding:10px 24px;border-radius:5px;text-decoration:none;font-weight:bold">📲 Consultar por WhatsApp</a></div><!-- /wp:group -->'

r = s.post(f"https://grabarpodcast.com/wp-json/wp/v2/pages/{page_id}",
           json={"content": banner_html + '\n\n' + content},
           headers={"X-WP-Nonce": nonce, "Content-Type": "application/json"})
```

### 3. Cambiar orden por defecto de productos
```bash
curl -s -X PUT -b /tmp/wp_cookies.txt -H "X-WP-Nonce: $NONCE" \
  -H "Content-Type: application/json" \
  -d '{"woocommerce_default_catalog_orderby": "price"}' \
  "https://grabarpodcast.com/wp-json/wp/v2/settings"
```
Valores: `menu_order`, `popularity`, `rating`, `date`, `price` (menor a mayor), `price-desc`

### 4. Modificar precio de producto
```bash
curl -s -u "CK:CS" -X PUT -H "Content-Type: application/json" \
  -d '{"regular_price": "3240"}' \
  "https://grabarpodcast.com/wp-json/wc/v3/products/448"
```

### 5. Listar productos por categoría
```bash
curl -s -u "CK:CS" \
  "https://grabarpodcast.com/wp-json/wc/v3/products?category=21&per_page=50" \
  | python3 -c "import sys,json;[print(f'ID {p[\"id\"]}: {p[\"name\"]} — \${p[\"price\"]}') for p in json.load(sys.stdin)]"
```

### 6. Buscar imágenes en media library
```bash
curl -s -u "CK:CS" \
  "https://grabarpodcast.com/wp-json/wp/v2/media?search=composition&per_page=100&_fields=id,source_url" \
  | python3 -c "import sys,json;[print(f'ID {m[\"id\"]}: {m[\"source_url\"][-60:]}') for m in json.load(sys.stdin)]"
```

### 7. Subir imagen (via XML-RPC — WC API no puede)
```python
import xmlrpc.client
server = xmlrpc.client.ServerProxy("https://grabarpodcast.com/xmlrpc.php")
with open("imagen.jpg", "rb") as f:
    img = f.read()
result = server.wp.uploadFile(1, "paradedasantiago@gmail.com", "*W6yAs@ReD)qg2#FQnbPT*ck", {
    "name": "imagen.jpg",
    "type": "image/jpeg",
    "bits": xmlrpc.client.Binary(img),
})
print(result)  # {"id": 123, "url": "https://..."}
```

### 8. Habilitar/deshabilitar gateway de pago
```bash
curl -s -u "CK:CS" -X PUT -H "Content-Type: application/json" \
  -d '{"enabled": true}' \
  "https://grabarpodcast.com/wp-json/wc/v3/payment_gateways/woo-mercado-pago-basic"
```

### 9. Verificar/enable webhooks de pedidos
```bash
curl -s -u "CK:CS" "https://grabarpodcast.com/wp-json/wc/v3/webhooks"
```

### 10. Aplicar CSS personalizado (NO se puede por API)
El CSS de la tienda debe pegarse manualmente en:
**Apariencia → Personalizar → CSS Adicional**

CSS generado anteriormente incluye: fondo oscuro, tarjetas glass, overlay de nombre de producto en imagen, fuente Montserrat.

## Payment Gateways
| Gateway | ID | Estado |
|---------|----|--------|
| Mercado Pago | woo-mercado-pago-basic | ✅ |
| Tarjeta crédito/débito | woo-mercado-pago-custom | ✅ |
| Efectivo | woo-mercado-pago-ticket | ✅ |

## Mercado Pago
- Token: `APP_USR-d1f5b7d7-5a34-4a5e-a443-4d09b7eea4a7`
- Integrado vía plugin nativo de WooCommerce

## WooCommerce Settings (vía WP REST API con nonce)
- Currency: UYU
- Country: Uruguay
- Guest checkout: yes
- Coupons: yes (cupón activo: GRABAR2026 = 20% OFF, válido hasta 20 julio 2026)
- Shipping: no
- Default order: price (menor a mayor) — seteado 15/5/2026

## Webhooks
| Nombre | URL | Evento | Delivery |
|--------|-----|--------|----------|
| woo-orders | http://localhost:8644/webhooks/woo-orders | order_completed | WhatsApp dueño |

## Related Skills

This skill handles **technical administration** of the WooCommerce store. For **customer-facing WhatsApp assistance** (pricing, sales flow, client questions), see the `grabarpodcast-asistente` skill.

### 11. Ver orden de productos por defecto y cambiarlo
```bash
# Ver valor actual
curl -s -u "CK:CS" -X GET "https://grabarpodcast.com/wp-json/wp/v2/settings" \
  | python3 -c "import sys,json;print(json.load(sys.stdin).get('woocommerce_default_catalog_orderby','no encontrado'))"

# Cambiarlo (requiere nonce, NO WC API keys)
NONCE=$(curl -s -b /tmp/wp_cookies.txt "https://grabarpodcast.com/wp-admin/admin-ajax.php?action=rest-nonce")
curl -s -X PUT -b /tmp/wp_cookies.txt -H "X-WP-Nonce: $NONCE" \
  -H "Content-Type: application/json" \
  -d '{"woocommerce_default_catalog_orderby": "price"}' \
  "https://grabarpodcast.com/wp-json/wp/v2/settings"
```

## ⚠️ Pitfalls Conocidos

1. **WC API keys NO pueden subir media.** Para imágenes usar XML-RPC con user/pass.
2. **No usar XML-RPC para páginas Gutenberg.** El contenido con bloques se rompe. Usar WP REST API con nonce + POST.
3. **No poner shortcodes WooCommerce dentro de módulos Divi Text.** Se renderizan como texto literal.
4. **El banner de reserva debe ser ÚNICO.** Cada POST duplica el banner. Siempre limpiar TODAS las ocurrencias de "IMPORTANTE" primero.
5. **WordPress 6.9 tiene "coming soon" que bloquea la tienda.** Si aparece "Tenemos grandes proyectos por anunciar" en la tienda, crear/verificar mu-plugin `disable-coming-soon.php`.
6. **Las contraseñas de aplicación no están disponibles** en este hosting. Usar login con cookie + nonce.
7. **Product descriptions con HTML** pueden tener caracteres de control. Usar `json.loads(strict=False)`.
8. **CSS no se inyecta por API.** Requiere pegarlo manualmente en Customizer (Apariencia → Personalizar → CSS Adicional).
9. **WP REST Auth dance no obvio.** Para opciones de WooCommerce que no tienen endpoint en WC API (ej: `woocommerce_default_catalog_orderby`), necesitás login por cookie → nonce → WP REST API con PUT. Ver `references/wp-rest-auth-cookie-nonce.md` para el dance exacto.
10. **Cloudflare bloquea browsers automatizados.** Usar curl, no browser tools, para interactuar con el sitio.
