---
name: wordpress-automation
description: "Automate WordPress and WooCommerce via XML-RPC and REST API — create posts, products, categories, upload media, configure payment gateways."
version: 2.1.0
tags:
  - wordpress
  - woocommerce
  - xmlrpc
  - rest-api
  - products
  - divi
  - automation
related_skills: []
---

# WordPress & WooCommerce Automation

Manage WordPress sites and WooCommerce stores programmatically via XML-RPC (`wp.*` methods) and the WooCommerce REST API (v3).

## Connection Methods

### Method 1: XML-RPC (Lower Overhead)

XML-RPC is usually enabled by default on WordPress. It's accessible at `https://yoursite.com/xmlrpc.php`.

**Authentication:** WordPress username + password.

**Available from:** Python `xmlrpc.client` or direct `curl` with XML payloads.

**Key methods:**

| Method | Purpose |
|--------|---------|
| `wp.getUsersBlogs` | Verify credentials (returns blog ID) |
| `wp.getPosts` | List posts/products |
| `wp.newPost` | Create posts/products |
| `wp.editPost` | Update posts/products |
| `wp.deletePost` | Delete posts/products |
| `wp.getPost` | Get single post/product details |
| `wp.newTerm` | Create categories/tags |
| `wp.getTerms` | List categories/tags |
| `wp.uploadFile` | Upload images to media library |

**XML Payload Template:**

```xml
<?xml version="1.0"?>
<methodCall>
  <methodName>wp.newPost</methodName>
  <params>
    <param><value><int>1</int></value></param>
    <param><value><string>user@email.com</string></value></param>
    <param><value><string>password</string></value></param>
    <param>
      <value>
        <struct>
          <member>
            <name>post_title</name>
            <value><string>Title Here</string></value>
          </member>
          <member>
            <name>post_content</name>
            <value><string>Content here</string></value>
          </member>
          <member>
            <name>post_status</name>
            <value><string>draft</string></value>
          </member>
          <member>
            <name>post_type</name>
            <value><string>post</string></value>
          </member>
        </struct>
      </value>
    </param>
  </params>
</methodCall>
```

**Uploading Images via XML-RPC (Python):**

```python
import xmlrpc.client, base64

server = xmlrpc.client.ServerProxy("https://yoursite.com/xmlrpc.php")
with open("/path/to/image.jpg", "rb") as f:
    img_data = f.read()

params = {
    "name": "image_name.jpg",
    "type": "image/jpeg",
    "bits": xmlrpc.client.Binary(img_data),
}
result = server.wp.uploadFile(1, "user@email.com", "password", params)
# Returns: {"id": 123, "url": "https://..."}
```

### Method 2: WooCommerce REST API (v3)

For WooCommerce-specific operations (products, categories, orders, payment gateways).

**Endpoint:** `https://yoursite.com/wp-json/wc/v3/`

**Authentication:** Consumer Key + Consumer Secret (generate in WooCommerce → Settings → Advanced → REST API → Add Key).

**Generate API Keys:**
1. Go to `https://yoursite.com/wp-admin/admin.php?page=wc-settings&tab=advanced&section=keys`
2. Create a new key with **Read/Write** permissions
3. Save the Consumer Key and Consumer Secret

**Usage with curl:**
```bash
curl -s -u "consumer_key:consumer_secret" \
  "https://yoursite.com/wp-json/wc/v3/products"
```

**Usage with Python:**
```python
import json, urllib.request, base64

CK = "ck_..."
CS = "cs_..."
auth = base64.b64encode(f"{CK}:{CS}".encode()).decode()

req = urllib.request.Request("https://yoursite.com/wp-json/wc/v3/products")
req.add_header("Authorization", f"Basic {auth}")
with urllib.request.urlopen(req) as r:
    products = json.loads(r.read().decode())
```

## WooCommerce Product Operations

### Creating a Product

```bash
curl -s -u "CK:CS" -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Product Name",
    "type": "simple",
    "regular_price": "99.99",
    "description": "Full description",
    "short_description": "Brief desc",
    "categories": [{"id": 18}],
    "images": [{"id": 478}],
    "stock_status": "instock",
    "virtual": true
  }' \
  "https://yoursite.com/wp-json/wc/v3/products"
```

### Assigning Images to Existing Products

```bash
curl -s -u "CK:CS" -X PUT \
  -H "Content-Type: application/json" \
  -d '{"images": [{"id": 478}]}' \
  "https://yoursite.com/wp-json/wc/v3/products/448"
```

### Managing Categories

Create categories with parent/child hierarchy:

```bash
# Create parent category
curl -s -u "CK:CS" -X POST \
  -H "Content-Type: application/json" \
  -d '{"name": "Podcast", "slug": "podcast"}' \
  "https://yoursite.com/wp-json/wc/v3/products/categories"

# Create child category
curl -s -u "CK:CS" -X POST \
  -H "Content-Type: application/json" \
  -d '{"name": "1 Cámara", "slug": "podcast-1-camara", "parent": 18}' \
  "https://yoursite.com/wp-json/wc/v3/products/categories"
```

### Enabling Payment Gateways

```bash
curl -s -u "CK:CS" -X PUT \
  -H "Content-Type: application/json" \
  -d '{"enabled": true}' \
  "https://yoursite.com/wp-json/wc/v3/payment_gateways/woo-mercado-pago-basic"
```

List available gateways:
```bash
curl -s -u "CK:CS" "https://yoursite.com/wp-json/wc/v3/payment_gateways" \
  | python3 -c "import sys,json;[print(f'{g[\"id\"]}: {g[\"title\"]} - {\"✅\" if g[\"enabled\"] else \"❌\"}') for g in json.load(sys.stdin)]"
```

## Divi Builder Content Modification

Divi stores page content as **shortcodes** in the `post_content` field. To modify Divi pages programmatically:

### Workflow
1. Get current content via XML-RPC `wp.getPost` (REST API doesn't expose `.raw` content without authentication)
2. Find the section to replace (e.g., empty trailing section, or a specific button)
3. Build replacement shortcodes with consistent Divi attributes
4. Save via XML-RPC `wp.editPost`

### Adding a CTA Button to a Divi Homepage
```python
import xmlrpc.client
server = xmlrpc.client.ServerProxy("https://yoursite.com/xmlrpc.php")

# Get current content
post = server.wp.getPost(1, "user", "pass", PAGE_ID)
content = post["post_content"]

# Replace empty trailing section with CTA
old_empty = '[et_pb_row _builder_version="4.17.4" _module_preset="default" global_colors_info="{}"][et_pb_column type="4_4" _builder_version="4.17.4" _module_preset="default" global_colors_info="{}"][/et_pb_column][/et_pb_row][/et_pb_section]'

new_section = '''[et_pb_section fb_built="1" admin_label="CTA" _builder_version="4.27.5" _module_preset="default" background_color="#000000" use_background_color_gradient="on" background_color_gradient_stops="rgba(255,255,255,0) 40%|rgba(131,0,233,0.15) 100%" global_colors_info="{}"][et_pb_row _builder_version="4.27.5" _module_preset="default" global_colors_info="{}"][et_pb_column type="4_4" _builder_version="4.27.5" _module_preset="default" global_colors_info="{}"][et_pb_text _builder_version="4.27.5" _module_preset="default" text_text_color="#FFFFFF" header_text_color="#FFFFFF" text_orientation="center" global_colors_info="{}"]

<h2 style="text-align: center;">Title Here</h2>

[/et_pb_text][et_pb_button button_url="URL" button_text="Button Text" button_alignment="center" _builder_version="4.27.5" _module_preset="default" custom_button="on" button_text_size="20px" button_text_color="#FFFFFF" button_bg_color="#8300E9" button_border_radius="50px" button_font="Inter|700||on|||||" global_colors_info="{}"][/et_pb_button][/et_pb_column][/et_pb_row][/et_pb_section]'''

new_content = content.replace(old_empty, new_section)
server.wp.editPost(1, "user", "pass", PAGE_ID, {"post_content": new_content})
```

### Key Divi Shortcode Attributes for Consistent Styling
- `background_color="#000000"` — dark background
- `use_background_color_gradient="on"` with purple tint (`rgba(131,0,233,0.15)`)
- `button_bg_color="#8300E9"` — purple accent button
- `button_border_radius="50px"` — pill-shaped button
- `text_text_color="#FFFFFF"` — white text
- `button_font="Inter|700||on|||||"` — bold Inter font

### Pages That Need WooCommerce Shortcodes
When creating WooCommerce page templates in Divi, use:
- `[woocommerce_shop]` for shop page
- `[woocommerce_cart]` for cart
- `[woocommerce_checkout]` for checkout
- `[woocommerce_my_account]` for account page

## WooCommerce Configuration

### General Settings
```bash
# Set currency to Uruguayan Peso
curl -s -u "CK:CS" -X PUT -H "Content-Type: application/json" \
  -d '{"value":"UYU"}' \
  "https://yoursite.com/wp-json/wc/v3/settings/general/woocommerce_currency"

# Set country
curl -s -u "CK:CS" -X PUT -H "Content-Type: application/json" \
  -d '{"value":"UY"}' \
  "https://yoursite.com/wp-json/wc/v3/settings/general/woocommerce_default_country"

# Enable guest checkout
curl -s -u "CK:CS" -X PUT -H "Content-Type: application/json" \
  -d '{"value":"yes"}' \
  "https://yoursite.com/wp-json/wc/v3/settings/general/woocommerce_enable_guest_checkout"

# Enable coupons
curl -s -u "CK:CS" -X PUT -H "Content-Type: application/json" \
  -d '{"value":"yes"}' \
  "https://yoursite.com/wp-json/wc/v3/settings/general/woocommerce_enable_coupons"

# Disable shipping (for service-based products)
curl -s -u "CK:CS" -X PUT -H "Content-Type: application/json" \
  -d '{"value":"no"}' \
  "https://yoursite.com/wp-json/wc/v3/settings/general/woocommerce_calc_shipping"
```

### Default Catalog Order

The `woocommerce_default_catalog_orderby` option controls how products are sorted on the shop page. **This is a WP option, not a WC API setting** — it lives under `wp/v2/settings`, not `wc/v3/settings/products/`.

**Valid values:** `menu_order` (default), `popularity`, `rating`, `date`, `price` (ascending), `price-desc`

**Read current value via WP REST API:**
```bash
curl -s -u "CK:CS" "https://yoursite.com/wp-json/wp/v2/settings" \
  | python3 -c "import sys,json; s=json.load(sys.stdin); print('Orderby:', s.get('woocommerce_default_catalog_orderby','not set'))"
```

**⚠️ WC API keys cannot set WP options.** The endpoint `wp/v2/settings` returns `401 rest_forbidden` when used with WooCommerce Consumer Key/Secret. To set this value programmatically:

1. **Via admin** (easiest): WooCommerce → Ajustes → Productos → General → Orden por defecto en el catálogo
2. **Via XML-RPC** (requires valid WP user/pass with admin role):
   ```python
   import xmlrpc.client
   server = xmlrpc.client.ServerProxy("https://yoursite.com/xmlrpc.php")
   server.wp.editOption(1, "user@email.com", "password", "woocommerce_default_catalog_orderby", "price")
   ```
3. **Via wp-admin cookie auth** (nonce-based):
   ```bash
   # Login first, get cookies+nonce, then:
   curl -X PUT "https://yoursite.com/wp-json/wp/v2/settings" \
     -H "Content-Type: application/json" \
     -H "X-WP-Nonce: <nonce>" \
     -b "wordpress_logged_in_<hash>=..." \
     -d '{"woocommerce_default_catalog_orderby": "price"}'
   ```
4. **Direct wp_options table** via hosting phpMyAdmin or SQL if available:
   ```sql
   UPDATE wp_options SET option_value='price' WHERE option_name='woocommerce_default_catalog_orderby';
   ```

**Pitfall:** The accepted values from the API are `price` (ascending) and `price-desc` (descending). Using `price_asc` will be rejected with `rest_not_in_enum`.

**Pitfall:** Application Passwords may need to be manually enabled. See ⚠️ section below.

## 🔄 Mass Product Creation Pattern (from woocommerce-automation)

When creating many products (30-150+), batch them in a single Python script. Pattern for generating products with variants (multiple tiers × multiple pack sizes):

```python
# Structure: service → cameras → levels → packs
prices = {
    "podcast": {"1": (3240, 5400, 7560), ...},  # (basic, plus, full)
    "streaming": {"1": (5400, 7560, 9720), ...},
}
level_titles = ["Básico", "Plus", "Full"]
hours_discount = {4: 10, 6: 15, 8: 20, 10: 25, 12: 30}

for service in ["podcast", "streaming"]:
    for cams in ["1", "2", "3", "4"]:
        for level_idx, price in enumerate(prices[service][cams]):
            for hours, disc_pct in hours_discount.items():
                pack_price = int(price * hours * (1 - disc_pct/100))
                # POST product with pack_price
```

**Pitfall:** This produces LOTS of products (e.g., 2 services × 4 cams × 3 levels × (1 base + 5 packs) = 144 products). For services (no shipping), set `"virtual": True`. Each product needs an `images` array with a media library ID.

### Batch Assigning Images

```bash
for pid in 448 449 450 451 452; do
  curl -s -u "CK:CS" \
    -X PUT -H "Content-Type: application/json" \
    -d '{"images": [{"id": 196}]}' \
    "https://site.com/wp-json/wc/v3/products/$pid" > /dev/null
done
```

Better: use Python's `urllib.request` in a loop for per-product error handling.

### Deleting Duplicate/Old Products

```python
old = [p for p in products if "(copia)" in p["name"] or "(10% OFF)" in p["name"]]
for p in old:
    delete(f"products/{p['id']}?force=true")
```

### Custom Product Image Generation (Python + Pillow)

When you need product thumbnails with the product name embedded as text overlay:

```python
from PIL import Image, ImageDraw, ImageFont

font_path = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
font = ImageFont.truetype(font_path, 52)

bg = Image.open("background.jpg").convert("RGBA")
bg = bg.resize((600, 600), Image.LANCZOS)  # WooCommerce thumbnail size

# Dark gradient overlay from bottom
overlay = Image.new('RGBA', (600, 600), (0, 0, 0, 0))
overlay_draw = ImageDraw.Draw(overlay)
for y in range(300, 600):
    alpha = int(220 * ((y - 300) / 300))
    overlay_draw.rectangle([(0, y), (600, y+1)], fill=(0, 0, 0, min(alpha, 200)))

composite = Image.alpha_composite(bg, overlay)
draw = ImageDraw.Draw(composite)

# White text with shadow, centered horizontally, bottom-aligned
lines = text.split('\n')
total_h = sum(draw.textbbox((0, 0), l, font=font)[3] - draw.textbbox((0, 0), l, font=font)[1] for l in lines)
y = 590 - total_h
for l in lines:
    bbox = draw.textbbox((0, 0), l, font=font)
    x = (600 - (bbox[2] - bbox[0])) // 2
    draw.text((x+2, y+2), l, font=font, fill=(0, 0, 0, 200))  # shadow
    draw.text((x, y), l, font=font, fill=(255, 255, 255))      # white text
    y += (bbox[3] - bbox[1]) + 8

composite = composite.convert("RGB")
composite.save("output.jpg", "JPEG", quality=88)
```

Then upload each generated image via XML-RPC and assign to the corresponding product via WC REST API.

---

## ⚠️ Known Limitations & Pitfalls

### 1. WooCommerce REST API Keys vs Application Passwords

WooCommerce API **keys** (Consumer Key + Secret) can read/write products, orders, categories, and payment gateways, but **CANNOT** upload media files. The `wp/v2/media` endpoint returns `401 rest_cannot_create` when using WC API keys.

For **media uploads**, you MUST use either:
- XML-RPC `wp.uploadFile` with username/password
- WordPress REST API (wp/v2/media) with Application Password or Basic Auth from a user login

### 2. Application Passwords May Not Be Available

Some WordPress installations don't have Application Passwords enabled. To enable:
- Install the official "Application Passwords" plugin from WordPress.org
- Or add to wp-config: `add_filter('wp_is_application_passwords_available', '__return_true');`
- Direct link: `https://yoursite.com/wp-admin/authorize-application.php?app_name=Name`

### 3. XML-RPC Can Fail for `product` Post Type

The `wp.newPost` method with `post_type=product` may fail with error `401` when using the main user credentials (only WC API keys can create products reliably). Always prefer the WooCommerce REST API for product CRUD.

### 4. Character Encoding in Descriptions

Product descriptions with HTML/special characters can cause JSON parse errors when piped through `python3 -m json.tool`. The WooCommerce API returns JSON with literal control characters in the `description` field. Use `python3 -c "import sys,json; json.load(sys.stdin)"` instead, or use `urllib.request` which handles encoding properly.

### 5. Env Config Changes Need Gateway Restart

Changes to `WHATSAPP_ALLOWED_USERS` in `.env` require a **gateway restart** with `--replace` flag. The running gateway cached the old value.

### 6. WooCommerce Shortcodes Must NOT Be Inside Divi Text Modules

Divi's `[et_pb_text]` module does **not** process shortcodes. If you place `[products]`, `[product_category]`, or any `[woocommerce_*]` shortcode inside a Divi text module, it renders as **literal text** on the page (visitors see the raw shortcode).

**Correct approaches for showing products with Divi:**

1. **Empty page content** → WooCommerce uses its own template within the Divi theme wrapper (works but no custom sections/headings from page editor)
2. **Use Gutenberg blocks** with `<!-- wp:shortcode -->` wrappers (WordPress 6.x handles this correctly):
   ```
   <!-- wp:heading {"level":2} -->
   <h2>Podcast</h2>
   <!-- /wp:heading -->
   
   <!-- wp:shortcode -->
   [product_category category="podcast" per_page="12" columns="4"]
   <!-- /wp:shortcode -->
   ```
3. **Use Divi's Theme Builder** to create a custom WooCommerce Product Archive template

**Important:** When using Gutenberg blocks for the shop page, ensure `_et_pb_use_builder` meta is set to `off` to prevent Divi from stripping the block markup.

### 7. Product Descriptions with Control Characters

Product descriptions with HTML content may contain control characters causing `json.loads()` to fail with `Invalid control character`.

**Workaround:** Use `json.loads()` with `strict=False`, or `urllib.request` instead of `terminal()` for API calls.

### 8. Checkout Field Configuration Not Available via API

Making phone/email required in WooCommerce checkout **cannot be done through any API**. The setting is stored as serialized PHP in `wp_options` under `woocommerce_billing_fields`.

**Options:**
- Install "Checkout Field Editor for WooCommerce" plugin
- Add a `woocommerce_billing_fields` filter in the theme/functions.php
- User does it manually in WooCommerce settings

### 9. WordPress 6.9 Coming Soon Mode

WordPress 6.9 ships with a built-in "coming soon" feature for WooCommerce stores. It shows *"Tenemos grandes proyectos por anunciar"* on the shop page. This **cannot** be disabled via API.

**Fix:** Create a must-use plugin:
```php
add_filter('woocommerce_coming_soon', '__return_false');
add_filter('wp_coming_soon', '__return_false');
```

Save as `disable-coming-soon.php` in `/wp-content/mu-plugins/` (create the directory if needed). Upload via hosting file manager or FTP — XML-RPC blocks `.php` uploads.

### 10. Finding Media by URL Pattern

When you know the filename but not the media ID:
```bash
curl -s -u "CK:CS" \
  "https://yoursite.com/wp-json/wp/v2/media?search=composition&per_page=100&_fields=id,source_url" \
  | python3 -c "import sys,json;[print(f'ID {m[\"id\"]}: {m[\"source_url\"][-60:]}') for m in json.load(sys.stdin)]"
```

### 11. Deleting Leftover Products from Earlier Attempts

During iterative store setup, `wp.newPost` with `post_type=product` via XML-RPC creates orphan drafts. They show up as:
- Name contains "(copia)" repeated
- No price, no category ("Sin categorizar"), no image
- Published status despite being unfinished

**Detection:**
```bash
curl -s -u "CK:CS" "/wc/v3/products?per_page=100&status=publish" \
  | python3 -c "import sys,json;[\
  print(f'ID {p[\"id\"]}: {p[\"name\"][:50]} - cats: {[c[\"name\"] for c in p.get(\"categories\",[])]}')\
  for p in json.load(sys.stdin) if not p.get(\"categories\") or not p.get(\"price\")]"
```

**Cleanup:**
```bash
curl -s -u "CK:CS" -X DELETE "/wc/v3/products/ID?force=true"
```

### 12. Bulk Assigning Images to Products by Category

After creating products, assign images in batches using product IDs:
```bash
# Assign image ID 196 to podcast products (IDs known)
for pid in 448 449 450 451 452 453 454 455 456 457 458 459; do
  curl -s -u "CK:CS" -X PUT -H "Content-Type: application/json" \
    -d '{"images": [{"id": 196}]}' \
    "https://yoursite.com/wp-json/wc/v3/products/$pid" > /dev/null 2>&1
done
echo "Done"
```

## Workflow: Complete WooCommerce Store Setup

When setting up a WooCommerce store from scratch with product data:

1. **Get API keys** from WooCommerce Settings → Advanced → REST API
2. **Create categories** first (parent → children)
3. **Upload images** via XML-RPC `wp.uploadFile` (note image IDs)
4. **Create products** via WooCommerce REST API with category IDs and image IDs
5. **Assign images** to products (put product update with image array)
6. **Enable payment gateways** via WC REST API
7. **Verify** by listing products: `curl -s -u "CK:CS" /wc/v3/products?per_page=5`
