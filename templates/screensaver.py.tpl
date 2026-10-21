#!/usr/bin/env python3

import fcntl
import math
import os
import random
import re
import select
import shutil
import signal
import subprocess
import sys
import termios
import threading
import time
import tty

FPS = 15

# Tempo (s) após iniciar em que teclas/mouse são ignorados. Evita que o
# próprio aparecimento da janela (o cursor "entrando" nela) feche o protetor.
INPUT_GRACE = 0.8

# Intervalo mínimo (s) entre o fechamento do protetor e uma nova abertura
RELAUNCH_COOLDOWN = 0

# Classe da janela do kitty usada pelo protetor.
WINDOW_CLASS = "screensaver"

STATE_DIR = os.path.join(
    os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")),
    "screensaver",
)

# Paleta fixa: o screensaver não depende dos temas do Singularity.
DISK_COLORS = ["{{ muted }}", "{{ accent }}", "{{ foreground }}", "{{ bright_foreground }}"]
STAR_COLORS = ["{{ dark_foreground }}", "{{ foreground }}", "{{ bright_foreground }}"]

CHARS = " .,:;-=+*#%@"
RUNNING = True

# Geometria: unidades relativas ao raio da sombra.
R_IN = 1.15
R_OUT = 3.3
INCL = 0.15
EINSTEIN = 1.2
Q = 32

signal.signal(signal.SIGINT, lambda *_: stop())
signal.signal(signal.SIGTERM, lambda *_: stop())


def stop(*_):
    global RUNNING
    RUNNING = False


# --------------------------------------------------------------------------
# Paletas fixas e cores ANSI
# --------------------------------------------------------------------------

def hex_to_rgb(value):
    value = value.strip().lstrip("#")

    if len(value) == 3:
        value = "".join(char * 2 for char in value)

    if not re.fullmatch(r"[0-9a-fA-F]{6}", value):
        raise ValueError(f"Cor hexadecimal inválida: {value!r}")

    return tuple(
        int(value[index:index + 2], 16)
        for index in (0, 2, 4)
    )


def gradient(stops, position):
    rgb = [hex_to_rgb(color) for color in stops]

    if len(rgb) == 1:
        return rgb[0]

    position = max(0.0, min(1.0, position)) * (len(rgb) - 1)
    index = min(int(position), len(rgb) - 2)
    fraction = position - index

    return tuple(
        round(
            rgb[index][channel]
            + (rgb[index + 1][channel] - rgb[index][channel]) * fraction
        )
        for channel in range(3)
    )


def ansi(rgb):
    return f"\033[38;2;{rgb[0]};{rgb[1]};{rgb[2]}m"


def build_palettes():
    warm = []
    star = []
    glyphs = []

    for index in range(Q):
        level = index / (Q - 1)
        warm.append(ansi(gradient(DISK_COLORS, level)))
        star.append(ansi(gradient(STAR_COLORS, level)))
        glyphs.append(CHARS[round(level * (len(CHARS) - 1))])

    return warm, star, glyphs


WARM, STAR, GLYPH = build_palettes()


# --------------------------------------------------------------------------
# Cena estática: calculada uma vez por tamanho do terminal
# --------------------------------------------------------------------------

class Scene:
    pass


def build_scene(width, height):
    sc = Scene()
    sc.width, sc.height = width, height
    sc.cx, sc.cy = (width - 1) / 2, (height - 1) / 2

    # Uma célula de terminal é aproximadamente duas vezes mais alta
    # do que larga.
    sc.rs = max(3.0, min(height * 0.31, width / 13.0))
    rs = sc.rs

    base = [[0.0] * width for _ in range(height)]
    disk, arcs, ring = [], [], []

    for y in range(height):
        v = (y - sc.cy) / rs

        for x in range(width):
            u = (x - sc.cx) * 0.5 / rs
            b = max(1e-6, math.hypot(u, v))

            if b >= 1.0:
                base[y][x] = 0.06 * math.exp(-(b - 1.0) / 0.45)

            # Disco de acreção projetado.
            vv = v / INCL
            r = math.hypot(u, vv)

            if R_IN <= r <= R_OUT and not (v < 0 and b < 1.0):
                phi = math.atan2(vv, u)
                dop = 0.78 - 0.30 * (u / r)
                prof = (R_IN / r) ** 1.5
                edge_in = min(1.0, (r - R_IN) / 0.15)
                edge_out = min(1.0, (R_OUT - r) / 0.9)

                static = 1.35 * dop * prof * edge_in * edge_out

                if static > 0.03:
                    disk.append(
                        (x, y, phi, 1.5 / r ** 1.5, r, static)
                    )

            # Imagem do disco curvada pela gravidade.
            if 1.0 <= b <= 2.5:
                s = v / b

                if s < 0:
                    top = -s
                    weight = 0.15 + 0.85 * top ** 0.6
                    width_b = 0.17 + 0.27 * top
                else:
                    weight = 0.10 + 0.45 * s ** 0.6
                    width_b = 0.14 + 0.10 * s

                static = (
                    1.25
                    * weight
                    * math.exp(-(b - 1.0) / width_b)
                    * (0.78 - 0.30 * u / b)
                )

                if static > 0.03:
                    effective_r = R_IN + (b - 1.0) * 1.6

                    arcs.append(
                        (
                            x,
                            y,
                            math.atan2(v, u),
                            1.5 / effective_r ** 1.5,
                            effective_r,
                            static,
                        )
                    )

            # Anel de fótons.
            if 0.95 <= b <= 1.14:
                static = (
                    0.75
                    * math.exp(-((b - 1.03) / 0.08) ** 2)
                    * (0.75 - 0.25 * u / b)
                )

                if static > 0.03:
                    ring.append((x, y, math.atan2(v, u), static))

    sc.base = base
    sc.disk = disk
    sc.arcs = arcs
    sc.ring = ring

    sc.half_u = (width - 1) / 2 * 0.5 / rs
    sc.half_v = (height - 1) / 2 / rs

    number_of_stars = max(60, width * height // 28)

    sc.stars = [
        (
            random.uniform(-1, 1),
            random.uniform(-1, 1),
            random.uniform(0.30, 0.85),
            random.random() * math.tau,
        )
        for _ in range(number_of_stars)
    ]

    return sc


# --------------------------------------------------------------------------
# Renderização de um quadro
# --------------------------------------------------------------------------

def render(sc, t):
    width, height = sc.width, sc.height
    levels = [row[:] for row in sc.base]
    sin = math.sin

    for x, y, phi, weight, radius, static in sc.disk:
        angle = phi + weight * t

        value = static * (
            0.72
            + 0.17 * sin(2 * angle + radius * 5.0)
            + 0.11 * sin(7 * angle + radius * 21.0)
        )

        if value > levels[y][x]:
            levels[y][x] = value

    for x, y, theta, weight, radius, static in sc.arcs:
        angle = theta + weight * t

        value = static * (
            0.72
            + 0.17 * sin(2 * angle + radius * 5.0)
            + 0.11 * sin(7 * angle + radius * 21.0)
        )

        if value > levels[y][x]:
            levels[y][x] = value

    for x, y, theta, static in sc.ring:
        value = static * (
            0.88 + 0.12 * sin(3 * (theta + 0.9 * t))
        )

        if value > levels[y][x]:
            levels[y][x] = value

    # Estrelas com lente gravitacional.
    star_cells = set()
    cx, cy, rs = sc.cx, sc.cy, sc.rs
    einstein_squared = 4 * EINSTEIN * EINSTEIN
    drift = t * 0.012

    for nx, ny, brightness, phase in sc.stars:
        u0 = (((nx + 1 + drift) % 2) - 1) * sc.half_u
        v0 = ny * sc.half_v

        beta = max(1e-3, math.hypot(u0, v0))
        root = math.sqrt(beta * beta + einstein_squared)

        level = brightness * (
            0.55 + 0.45 * sin(t * 1.7 + phase)
        )

        images = [
            (
                u0 * (beta + root) / (2 * beta),
                v0 * (beta + root) / (2 * beta),
                level,
            )
        ]

        magnification = (root - beta) / 2

        if magnification > 1.05:
            images.append(
                (
                    -u0 / beta * magnification,
                    -v0 / beta * magnification,
                    level * 0.4,
                )
            )

        for u, v, brightness_level in images:
            x = int(round(cx + u * 2 * rs))
            y = int(round(cy + v * rs))

            if (
                0 <= x < width
                and 0 <= y < height
                and levels[y][x] < 0.08
            ):
                levels[y][x] = brightness_level
                star_cells.add(y * width + x)

    return levels, star_cells


def compose(sc, levels, star_cells):
    width, height = sc.width, sc.height
    out = ["\033[H"]
    max_level = Q - 1

    for y in range(height):
        row = []
        last_color = None
        current_levels = levels[y]

        for x in range(width):
            level = current_levels[x]
            cell = y * width + x

            if level < 0.03:
                row.append(" ")
                continue

            level = min(1.0, level)

            if cell not in star_cells:
                level = level ** 0.8

            index = int(level * max_level + 0.5)

            color = STAR[index] if cell in star_cells else WARM[index]

            if color != last_color:
                row.append(color)
                last_color = color

            row.append(GLYPH[index])

        row.append("\033[0m")
        out.append("".join(row))

    # Sem rodapé: a animação ocupa apenas a área do terminal.
    return "\n".join(out)


# --------------------------------------------------------------------------
# Fechar a janela do kitty ao terminar (opcional: --close-class=NOME)
# --------------------------------------------------------------------------

def get_close_class():
    """Classe da janela a fechar quando o protetor terminar, se informada."""
    args = sys.argv[1:]

    for index, arg in enumerate(args):
        if arg.startswith("--close-class="):
            value = arg.split("=", 1)[1]
        elif arg == "--close-class" and index + 1 < len(args):
            value = args[index + 1]
        else:
            continue

        if re.fullmatch(r"[A-Za-z0-9_-]+", value):
            return value

    return None


def close_window(window_class):
    """Pede ao Hyprland para fechar a janela com a classe indicada."""
    if not window_class:
        return

    expression = (
        f'hl.dsp.window.close({{ window = "class:^{window_class}$" }})'
    )

    try:
        subprocess.Popen(
            ["hyprctl", "dispatch", expression],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except OSError:
        pass


# --------------------------------------------------------------------------
# Abertura controlada (--launch), trava de instância única e intervalo mínimo
# --------------------------------------------------------------------------

LOCK_FILE = os.path.join(STATE_DIR, "screensaver.lock")
LAST_EXIT_FILE = os.path.join(STATE_DIR, "screensaver-last-exit")


def cli_value(name):
    """Valor de --nome=valor ou --nome valor, ou None se não informado."""
    args = sys.argv[1:]

    for index, arg in enumerate(args):
        if arg.startswith(f"--{name}="):
            return arg.split("=", 1)[1]

        if arg == f"--{name}" and index + 1 < len(args):
            return args[index + 1]

    return None


def get_cooldown():
    value = cli_value("cooldown")

    if value is None:
        return RELAUNCH_COOLDOWN

    try:
        return max(0.0, float(value))
    except ValueError:
        return RELAUNCH_COOLDOWN


def try_lock():
    """Tenta obter a trava de instância única. None se já houver outra."""
    try:
        os.makedirs(STATE_DIR, exist_ok=True)
        lock = open(LOCK_FILE, "a+")
    except OSError:
        # Sem como criar a trava: segue sem ela em vez de impedir de abrir.
        return open(os.devnull, "r")

    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        lock.close()
        return None

    return lock


def mark_exit():
    """Registra o momento em que o protetor terminou."""
    try:
        os.makedirs(STATE_DIR, exist_ok=True)
        with open(LAST_EXIT_FILE, "a"):
            pass
        os.utime(LAST_EXIT_FILE)
    except OSError:
        pass


def launch():
    """Abre o protetor no kitty, a menos que já esteja aberto ou tenha
    acabado de ser fechado. Usado pelo hypridle: screensaver.py --launch"""
    lock = try_lock()

    if lock is None:
        return 0  # já está rodando

    lock.close()

    try:
        age = time.time() - os.path.getmtime(LAST_EXIT_FILE)
    except OSError:
        age = None

    if age is not None and age < get_cooldown():
        return 0  # fechado há pouco tempo: não reabre

    command = [
        "kitty",
        "--class", WINDOW_CLASS,
        "--title", "Singularity Screensaver",
        "--override", "background_opacity=1.0",
        "--override", "background=black",
        "--override", "hide_window_decorations=yes",
        "--override", "confirm_os_window_close=0",
        "--override", "close_on_child_death=yes",
        "--start-as=fullscreen",
        sys.executable,
        os.path.abspath(__file__),
        f"--close-class={WINDOW_CLASS}",
    ]

    try:
        os.execvp(command[0], command)
    except OSError as error:
        print(f"Não foi possível iniciar o kitty: {error}", file=sys.stderr)
        return 1


# --------------------------------------------------------------------------
# Loop principal
# --------------------------------------------------------------------------

# Entra na tela alternativa, esconde o cursor e liga o rastreamento de mouse:
#   ?1003 = reporta qualquer movimento do mouse
#   ?1006 = formato SGR (sequências "\033[<...M")
TERM_ENTER = "\033[?1049h\033[?25l\033[2J\033[?1003h\033[?1006h"
TERM_LEAVE = "\033[?1006l\033[?1003l\033[0m\033[?25h\033[?1049l"


def main() -> int:
    random.seed()

    sys.stdout.write(TERM_ENTER)
    sys.stdout.flush()

    started = time.monotonic()
    old_size = None
    scene = None

    try:
        while RUNNING:
            frame_start = time.monotonic()

            size = shutil.get_terminal_size((100, 35))

            if size.columns < 30 or size.lines < 12:
                time.sleep(0.2)
                continue

            if size != old_size:
                sys.stdout.write("\033[2J")
                scene = build_scene(size.columns, size.lines)
                old_size = size

            levels, star_cells = render(
                scene,
                frame_start - started,
            )

            sys.stdout.write(compose(scene, levels, star_cells))
            sys.stdout.flush()

            elapsed = time.monotonic() - frame_start
            time.sleep(max(0.0, 1.0 / FPS - elapsed))

    finally:
        sys.stdout.write(TERM_LEAVE)
        sys.stdout.flush()

    return 0


def input_loop(fd):
    """Encerra o protetor com qualquer tecla, clique, rolagem ou movimento
    do mouse (depois do período de tolerância inicial)."""
    global RUNNING

    armed_at = time.monotonic() + INPUT_GRACE

    while RUNNING:
        ready, _, _ = select.select([fd], [], [], 0.1)

        if not ready:
            continue

        try:
            data = os.read(fd, 1024)
        except OSError:
            data = b""

        if not data:
            # stdin fechado: não há mais como receber entrada.
            RUNNING = False
            return

        if time.monotonic() >= armed_at:
            RUNNING = False
            return


if __name__ == "__main__":
    if "--launch" in sys.argv[1:]:
        raise SystemExit(launch())

    if not sys.stdout.isatty() or not sys.stdin.isatty():
        print("Execute este protetor dentro de um terminal interativo.")
        raise SystemExit(1)

    instance_lock = try_lock()

    if instance_lock is None:
        print("O protetor já está em execução.")
        raise SystemExit(0)

    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)

    try:
        tty.setcbreak(fd)

        threading.Thread(
            target=input_loop,
            args=(fd,),
            daemon=True,
        ).start()

        raise SystemExit(main())

    finally:
        # Descarta eventos de mouse ainda pendentes para não "vazarem"
        # como texto no shell depois que o protetor fechar.
        termios.tcflush(fd, termios.TCIFLUSH)
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)

        # Marca o fechamento (para o intervalo mínimo) e fecha a janela.
        mark_exit()
        close_window(get_close_class())