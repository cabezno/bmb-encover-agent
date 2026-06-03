# Divi + WooCommerce Page Setup Guide

## The Problem
Divi `et_pb_text` modules do NOT process WooCommerce shortcodes (`[products]`, `[product_category]`, etc.). They render as literal text, leaving the page broken.

## Solutions (by use case)

### Case 1: Full WooCommerce shop with Divi header/footer
Set page content to empty string (`""`). WooCommerce renders its default template inside Divi's theme wrapper. The page will have the Divi header, footer, and styling but NOT custom Divi sections above/below the products.

### Case 2: Custom header section before WooCommerce content
Use Gutenberg blocks for the header, then a shortcode block for WooCommerce:

```
<!-- wp:heading {"level":1,"textAlign":"center","style":{"color":{"text":"#ffffff"}}} -->
<h1 class="wp-block-heading has-text-align-center" style="color:#ffffff">Shop</h1>
<!-- /wp:heading -->

<!-- wp:shortcode -->
[products limit="30" columns="3" orderby="menu_order" order="ASC"]
<!-- /wp:shortcode -->
```

This works because Gutenberg processes shortcodes properly.

### Case 3: Fully custom Divi layout with products
Use Divi's **Theme Builder** to create a custom WooCommerce product archive template. This is the advanced approach — set in Divi → Theme Builder → Add New Template → WooCommerce → Shop Page.

### Known Good Styles for GrabarPodcast
- Background: `#000000` with gradient overlay
- Accent: Purple `#8300E9`
- Text: White `#FFFFFF`
- Buttons: Pill shape `border-radius: 50px`, bold Inter font
