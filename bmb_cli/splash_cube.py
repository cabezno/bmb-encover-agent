"""Cubo 3D rotatorio animado — splash de bienvenida para BMB Undercover Agent.

Renderiza un cubo 3D wireframe con z-buffer, lo muestra unos segundos
y termina. Sin loop infinito.
"""

import math
import os
import shutil
import sys
import time


def _get_terminal_size():
    """Get terminal size, fallback to 80x24."""
    try:
        size = shutil.get_terminal_size()
        return size.columns, size.lines
    except Exception:
        return 80, 24


def render_cube_frame(A: float, B: float, width: int, height: int) -> str:
    """Render a single frame of a rotating 3D cube.

    Args:
        A: Rotation angle around X axis.
        B: Rotation angle around Y axis.
        width: Terminal width in chars.
        height: Terminal height in lines.

    Returns:
        String ready to print (with ANSI for colors).
    """
    # z-buffer + screen buffer
    screen = [" "] * (width * height)
    z_buffer = [0.0] * (width * height)

    cube_size = 12
    K1 = 25
    z_offset = 80

    # Caracteres para profundidad — más brillante = más cerca
    lum_chars = "@%#*+=-:. "

    # 12 aristas del cubo
    edges = [
        (0, 1), (1, 2), (2, 3), (3, 0),   # front face
        (4, 5), (5, 6), (6, 7), (7, 4),   # back face
        (0, 4), (1, 5), (2, 6), (3, 7),   # connecting edges
    ]

    # 8 vértices del cubo
    vertices = [
        (-1, -1, -1), ( 1, -1, -1), ( 1,  1, -1), (-1,  1, -1),
        (-1, -1,  1), ( 1, -1,  1), ( 1,  1,  1), (-1,  1,  1),
    ]
    # Escalar
    vertices = [(x * cube_size, y * cube_size, z * cube_size) for x, y, z in vertices]

    # Rotar y proyectar todos los vértices
    projected = []
    for x, y, z in vertices:
        # Rotación X
        nx = x
        ny = y * math.cos(A) - z * math.sin(A)
        nz = y * math.sin(A) + z * math.cos(A)
        x, y, z = nx, ny, nz

        # Rotación Y
        nx = x * math.cos(B) + z * math.sin(B)
        ny = y
        nz = -x * math.sin(B) + z * math.cos(B)
        x, y, z = nx, ny, nz

        z += z_offset
        ooz = 1.0 / z
        xp = int(width / 2 + K1 * x * ooz)
        yp = int(height / 2 - K1 * y * ooz)
        projected.append((xp, yp, ooz))

    # Dibujar aristas (líneas entre vértices proyectados)
    for i, j in edges:
        x1, y1, _ = projected[i]
        x2, y2, _ = projected[j]

        # Bresenham para dibujar línea
        dx = abs(x2 - x1)
        dy = -abs(y2 - y1)
        sx = 1 if x1 < x2 else -1
        sy = 1 if y1 < y2 else -1
        err = dx + dy

        x, y = x1, y1
        while True:
            if 0 <= x < width and 0 <= y < height:
                # Calcular profundidad interpolada para z-buffer
                # (usamos distancia al centro del segmento)
                z_val = 0.5  # valor fijo para aristas
                pos = x + y * width
                if z_val > z_buffer[pos]:
                    z_buffer[pos] = z_val
                    # Colores verde degradado según posición Y
                    rel_y = y / height
                    if rel_y < 0.3:
                        screen[pos] = "\033[38;2;0;255;136m█"
                    elif rel_y < 0.6:
                        screen[pos] = "\033[38;2;0;204;102m█"
                    else:
                        screen[pos] = "\033[38;2;0;153;68m█"

            if x == x2 and y == y2:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x += sx
            if e2 <= dx:
                err += dx
                y += sy

    # Componer la salida
    lines = []
    for y in range(height):
        row = []
        for x in range(width):
            ch = screen[x + y * width]
            if ch == " ":
                row.append(" ")
            else:
                row.append(ch)
        lines.append("".join(row))
    return "\n".join(lines)


def show_splash(duration: float = 2.0, fps: int = 20):
    """Show the rotating 3D cube splash for a given duration.

    Args:
        duration: Seconds to animate.
        fps: Frames per second.
    """
    A, B = 0.0, 0.0
    frame_time = 1.0 / fps
    frames = int(duration * fps)
    term_width, term_height = _get_terminal_size()
    # Leave room for the label below
    term_height -= 2

    for _ in range(frames):
        frame = render_cube_frame(A, B, term_width, term_height)
        sys.stdout.write("\033[H" + frame)
        sys.stdout.flush()
        A += 0.08
        B += 0.05
        time.sleep(frame_time)

    # limpiar pantalla al final
    sys.stdout.write("\033[H\033[J")
    sys.stdout.flush()


if __name__ == "__main__":
    try:
        show_splash(duration=3.0)
    except KeyboardInterrupt:
        sys.stdout.write("\033[H\033[J")
        sys.stdout.flush()
