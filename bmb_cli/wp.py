"""Módulo WordPress/WooCommerce para BMB Undercover Agent.

Comandos genéricos para gestionar contenido y productos en cualquier
WordPress/WooCommerce via REST API.

Configuración (bmb config set):
  wp.url        https://tusitio.com
  wp.key        ck_your_consumer_key
  wp.secret     cs_your_consumer_secret
  wp.username   (para posts - opcional)
  wp.app_password (para posts - opcional)
"""

import json
import logging
import os
from pathlib import Path
from typing import Optional

logger = logging.getLogger("bmb-wp")


# ─── Config ───────────────────────────────────────────────────────

def _get_config() -> dict:
    """Leer configuración de WordPress desde bmb config."""
    config = {}
    try:
        from bmb_cli.config import get_config_value
        config["url"] = get_config_value("wp.url", "")
        config["key"] = get_config_value("wp.key", "")
        config["secret"] = get_config_value("wp.secret", "")
        config["username"] = get_config_value("wp.username", "")
        config["app_password"] = get_config_value("wp.app_password", "")
    except Exception:
        # Fallback a vars de entorno
        config["url"] = os.environ.get("WP_URL", "")
        config["key"] = os.environ.get("WP_KEY", "")
        config["secret"] = os.environ.get("WP_SECRET", "")
        config["username"] = os.environ.get("WP_USERNAME", "")
        config["app_password"] = os.environ.get("WP_APP_PASSWORD", "")

    # Limpiar URL
    config["url"] = config["url"].rstrip("/")
    return config


def _check_config(config: dict) -> bool:
    """Verificar que la configuración mínima existe."""
    if not config.get("url"):
        print("❌ WordPress no configurado.")
        print("   Configure con: bmb config set wp.url https://tusitio.com")
        print("   Y:            bmb config set wp.key ck_...")
        print("   Y:            bmb config set wp.secret cs_...")
        print("   O ejecute:    bmb wp setup")
        return False
    if not config.get("key") or not config.get("secret"):
        print("❌ WooCommerce API credentials no configurados.")
        print("   bmb config set wp.key ck_...")
        print("   bmb config set wp.secret cs_...")
        return False
    return True


# ─── API ──────────────────────────────────────────────────────────

def _wc_api(config: dict, path: str, method: str = "GET", data: dict = None) -> dict:
    """Llamar a la API REST de WooCommerce."""
    import requests
    from requests.auth import HTTPBasicAuth

    url = f"{config['url']}/wp-json/wc/v3/{path.lstrip('/')}"
    auth = HTTPBasicAuth(config["key"], config["secret"])
    headers = {"Content-Type": "application/json"}

    try:
        if method == "GET":
            r = requests.get(url, auth=auth, timeout=30)
        elif method == "POST":
            r = requests.post(url, auth=auth, json=data, headers=headers, timeout=30)
        elif method == "PUT":
            r = requests.put(url, auth=auth, json=data, headers=headers, timeout=30)
        elif method == "DELETE":
            r = requests.delete(url, auth=auth, timeout=30)
        else:
            return {"error": f"Método no soportado: {method}"}

        if r.status_code in (200, 201):
            return r.json()
        else:
            return {"error": f"HTTP {r.status_code}", "detail": r.text[:500]}
    except requests.exceptions.ConnectionError:
        return {"error": f"No se pudo conectar a {config['url']}"}
    except Exception as e:
        return {"error": str(e)}


def _wp_api(config: dict, path: str, method: str = "GET", data: dict = None) -> dict:
    """Llamar a la API REST de WordPress (para posts/páginas)."""
    import requests

    url = f"{config['url']}/wp-json/wp/v2/{path.lstrip('/')}"
    headers = {"Content-Type": "application/json"}

    # Autenticación con Application Password si está configurado
    if config.get("username") and config.get("app_password"):
        from requests.auth import HTTPBasicAuth
        auth = HTTPBasicAuth(config["username"], config["app_password"])
    else:
        auth = None

    try:
        if method == "GET":
            r = requests.get(url, auth=auth, timeout=30)
        elif method == "POST":
            r = requests.post(url, auth=auth, json=data, headers=headers, timeout=30)
        else:
            return {"error": f"Método no soportado: {method}"}

        if r.status_code in (200, 201):
            return r.json()
        else:
            return {"error": f"HTTP {r.status_code}", "detail": r.text[:500]}
    except Exception as e:
        return {"error": str(e)}


# ─── UI ───────────────────────────────────────────────────────────

def _format_product(p: dict) -> str:
    """Formatear un producto para mostrar."""
    name = p.get("name", "Sin nombre")
    price = p.get("price", "0")
    pid = p.get("id", "?")
    stock = p.get("stock_status", "unknown")
    categories = ", ".join(c.get("name", "") for c in p.get("categories", []))
    return f"  #{pid}  ${price}  [{stock}]  {name}  ({categories})"


# ─── Comandos ─────────────────────────────────────────────────────

def cmd_setup(args):
    """Configurar WordPress/WooCommerce por primera vez."""
    print("\n╔══════════════════════════════════════╗")
    print("║  BMB WordPress — Configuración      ║")
    print("╚══════════════════════════════════════╝")
    print()

    url = input("URL del sitio (https://tusitio.com): ").strip()
    print("Consumer Key y Secret se generan en:")
    print(f"  {url}/wp-admin/admin.php?page=wc-settings&tab=advanced&section=keys")
    print()
    key = input("WooCommerce Consumer Key: ").strip()
    secret = input("WooCommerce Consumer Secret: ").strip()

    print()
    print("Para publicar posts se necesita Application Password:")
    print(f"  {url}/wp-admin/profile.php → Application Passwords")
    username = input("Usuario WP (opcional): ").strip()
    app_password = input("Application Password (opcional): ").strip()

    # Guardar configuración
    try:
        from bmb_cli.config import set_config_value
        set_config_value("wp.url", url)
        set_config_value("wp.key", key)
        set_config_value("wp.secret", secret)
        if username:
            set_config_value("wp.username", username)
        if app_password:
            set_config_value("wp.app_password", app_password)
        print("\n✅ Configuración guardada.")
        print("   Pruebe: bmb wp products")
    except Exception as e:
        print(f"\n❌ Error guardando: {e}")
        print("   Configure manualmente con bmb config set")


def cmd_products(args):
    """Listar productos de WooCommerce."""
    config = _get_config()
    if not _check_config(config):
        return

    category = getattr(args, "category", None)
    page = getattr(args, "page", 1)
    per_page = getattr(args, "per_page", 20)

    path = f"products?page={page}&per_page={per_page}"
    if category:
        path += f"&category={category}"

    result = _wc_api(config, path)
    if isinstance(result, list):
        print(f"\n📦 Productos ({len(result)}):\n")
        for p in result:
            print(_format_product(p))
        print(f"\n  Página {page}")
    elif "error" in result:
        print(f"❌ Error: {result.get('error')}")


def cmd_product_get(args):
    """Obtener detalle de un producto."""
    config = _get_config()
    if not _check_config(config):
        return

    pid = args.product_id
    result = _wc_api(config, f"products/{pid}")

    if "error" in result:
        print(f"❌ Error: {result.get('error')}")
        return

    print(f"\n📦 {result.get('name', 'Producto')}")
    print(f"   ID: {result.get('id')}")
    print(f"   Precio: ${result.get('price', '0')}")
    print(f"   Stock: {result.get('stock_status', 'unknown')}")
    print(f"   SKU: {result.get('sku', 'N/A')}")
    print(f"   Categorías: {', '.join(c.get('name','') for c in result.get('categories',[]))}")
    desc = result.get('description', '')
    print(f"   Descripción: {desc[:300]}{'...' if len(desc) > 300 else ''}")


def cmd_orders(args):
    """Listar órdenes de WooCommerce."""
    config = _get_config()
    if not _check_config(config):
        return

    status = getattr(args, "status", "any")
    page = getattr(args, "page", 1)

    path = f"orders?page={page}&per_page=20"
    if status and status != "any":
        path += f"&status={status}"

    result = _wc_api(config, path)
    if isinstance(result, list):
        print(f"\n📋 Órdenes ({len(result)}):\n")
        for o in result:
            print(f"  #{o.get('id')}  ${o.get('total')}  [{o.get('status')}]  "
                  f"{o.get('billing',{}).get('first_name','')} "
                  f"{o.get('billing',{}).get('last_name','')}")
        print(f"\n  Página {page}")
    elif "error" in result:
        print(f"❌ Error: {result.get('error')}")


def cmd_order_get(args):
    """Obtener detalle de una orden."""
    config = _get_config()
    if not _check_config(config):
        return

    oid = args.order_id
    result = _wc_api(config, f"orders/{oid}")

    if "error" in result:
        print(f"❌ Error: {result.get('error')}")
        return

    billing = result.get("billing", {})
    print(f"\n📋 Orden #{result.get('id')}")
    print(f"   Estado: {result.get('status')}")
    print(f"   Total: ${result.get('total')}")
    print(f"   Fecha: {result.get('date_created')}")
    print(f"   Cliente: {billing.get('first_name')} {billing.get('last_name')}")
    print(f"   Email: {billing.get('email')}")
    print(f"   Tel: {billing.get('phone')}")
    print(f"\n   Items:")
    for item in result.get("line_items", []):
        print(f"     - {item.get('name')} x{item.get('quantity')} ${item.get('total')}")


def cmd_pages(args):
    """Listar páginas de WordPress."""
    config = _get_config()
    if not _check_config(config):
        return

    result = _wp_api(config, "pages?per_page=50")
    if isinstance(result, list):
        print(f"\n📄 Páginas ({len(result)}):\n")
        for p in result:
            print(f"  #{p.get('id')}  {p.get('title',{}).get('rendered','')}")
    elif "error" in result:
        print(f"❌ Error: {result.get('error')}")


def cmd_categories(args):
    """Listar categorías de WooCommerce."""
    config = _get_config()
    if not _check_config(config):
        return

    result = _wc_api(config, "products/categories?per_page=50")
    if isinstance(result, list):
        print(f"\n🏷️  Categorías ({len(result)}):\n")
        for c in result:
            parent = f" → {c.get('name')}" if c.get('parent') else ""
            print(f"  #{c.get('id')}  {c.get('name')}  ({c.get('count')} productos)")
    elif "error" in result:
        print(f"❌ Error: {result.get('error')}")


def cmd_create_product(args):
    """Crear un producto simple en WooCommerce."""
    config = _get_config()
    if not _check_config(config):
        return

    name = args.name
    price = args.price
    categories_list = getattr(args, "categories", "")
    description = getattr(args, "description", "")

    # Parsear categorías (formato: "18,19" o "Podcast, Streaming")
    cat_ids = []
    if categories_list:
        for c in categories_list.split(","):
            c = c.strip()
            if c.isdigit():
                cat_ids.append({"id": int(c)})

    product_data = {
        "name": name,
        "type": "simple",
        "regular_price": str(price),
        "description": description,
        "stock_status": "instock",
    }

    if cat_ids:
        product_data["categories"] = cat_ids

    print(f"→ Creando producto: {name} (${price})...")
    result = _wc_api(config, "products", method="POST", data=product_data)

    if "id" in result:
        print(f"✅ Producto creado: #{result['id']} {result['name']} - ${result['price']}")
        print(f"   {config['url']}/producto/{result.get('slug','')}")
    else:
        print(f"❌ Error: {result.get('error')}")


def cmd_update_stock(args):
    """Actualizar stock de un producto."""
    config = _get_config()
    if not _check_config(config):
        return

    pid = args.product_id
    stock = getattr(args, "stock", "instock")

    result = _wc_api(config, f"products/{pid}", method="PUT", data={"stock_status": stock})
    if "id" in result:
        print(f"✅ Producto #{pid} actualizado: stock = {stock}")
    else:
        print(f"❌ Error: {result.get('error')}")


def cmd_post(args):
    """Crear un post en WordPress."""
    config = _get_config()
    if not _check_config(config):
        return

    title = args.title
    content = getattr(args, "content", "")
    status = getattr(args, "status", "draft")

    username = config.get("username")
    app_password = config.get("app_password")

    if not username or not app_password:
        print("❌ Se necesita Application Password para crear posts.")
        print("   Configure: bmb config set wp.username <user>")
        print("             bmb config set wp.app_password <password>")
        print(f"   Generar en: {config['url']}/wp-admin/profile.php")
        return

    data = {
        "title": title,
        "content": content,
        "status": status,
    }

    print(f"→ Publicando: {title} (status: {status})...")
    result = _wp_api(config, "posts", method="POST", data=data)

    if "id" in result:
        link = result.get("link", "")
        print(f"✅ Post creado: #{result['id']}")
        print(f"   {link}")
    else:
        print(f"❌ Error: {result.get('error')}")
