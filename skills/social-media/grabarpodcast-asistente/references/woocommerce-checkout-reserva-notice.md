# Checkout Banner: Coordinación de Reservas

## Estado (May 14, 2026)
Banner implementado en Tienda (ID 394) y Finalizar Compra (ID 396) de grabarpodcast.com.

## Diseño actual
Fondo negro, texto blanco, botón naranja (#e67e22) "📲 Consultar por WhatsApp" centrado.
Mensaje: "📅 IMPORTANTE: Las reservas requieren coordinación previa. Luego de tu compra te contactaremos por WhatsApp para acordar fecha y horario."

## Problema conocido: BANNER DUPLICADO
Al editar las páginas por API REST, cada escritura agrega UN banner más sin eliminar el anterior. Esto pasa porque:
1. WordPress escapa el HTML y lo guarda como `&lt;div&gt;...&lt;/div&gt;` en lugar de `<div>...</div>`
2. Las expresiones regulares en Python no detectan los banners escapados
3. Cada intento de "limpiar y re-agregar" acumula banners

## Solución aplicada
Eliminar TODAS las ocurrencias de `IMPORTANTE` primero (tanto en HTML directo como escapado), verificar que count sea 0, recién ahí agregar UNO. Código:

```python
# Eliminar cualquier bloque con IMPORTANTE
while 'IMPORTANTE' in content:
    content = re.sub(r'<!-- wp:group.*?IMPORTANTE.*?<!-- /wp:group -->', '', content, count=1, flags=re.DOTALL)
    content = re.sub(r'<div[^>]*>[\s\S]*?IMPORTANTE[\s\S]*?</div>', '', content, count=1, flags=re.DOTALL)

# Verificar
if content.count("IMPORTANTE") == 0:
    # Recién ahora agregar uno
    new_content = banner + '\n\n' + content
```

## API REST para edición
```python
s = requests.Session()
s.post("https://grabarpodcast.com/wp-login.php", data={
    "log": USER,
    "pwd": PASSWORD,
    "wp-submit": "Iniciar sesión",
    "redirect_to": "/wp-admin/",
    "testcookie": "1"
})
r = s.get("https://grabarpodcast.com/wp-admin/admin-ajax.php?action=rest-nonce")
nonce = r.text.strip()

# Obtener
r = s.get(f"https://grabarpodcast.com/wp-json/wp/v2/pages/{page_id}",
          headers={"X-WP-Nonce": nonce})
content = r.json()['content']['rendered']

# Actualizar
r = s.post(f"https://grabarpodcast.com/wp-json/wp/v2/pages/{page_id}",
           json={"content": new_content},
           headers={"X-WP-Nonce": nonce, "Content-Type": "application/json"})
```

No usar XML-RPC para páginas con bloques Gutenberg.
