
#!/usr/bin/env python3

import re
import sys
import tomllib
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[2]
THEMES_DIR = ROOT_DIR / "themes"
TEMPLATES_DIR = ROOT_DIR / "templates"
CURRENT_DIR = ROOT_DIR / "current"
QUICKSHELL_DIR = ROOT_DIR / "quickshell"


def render_template(
    template_file: Path,
    output_file: Path,
    values: dict[str, str],
) -> None:
    template = template_file.read_text(encoding="utf-8")

    for key, value in values.items():
        template = template.replace(f"{{{{ {key} }}}}", value)

    if re.search(r"\{\{\s*[\w]+\s*\}\}", template):
        raise ValueError(
            f"Existem placeholders não resolvidos em {template_file}"
        )

    output_file.parent.mkdir(parents=True, exist_ok=True)
    output_file.write_text(template, encoding="utf-8")


def load_theme_colors(theme_name: str) -> dict:
    colors_file = THEMES_DIR / theme_name / "colors.toml"

    if not colors_file.is_file():
        raise FileNotFoundError(
            f"Arquivo de cores não encontrado: {colors_file}"
        )

    with colors_file.open("rb") as file:
        colors = tomllib.load(file)

    accent = colors.get("accent")

    if not isinstance(accent, str):
        raise ValueError(
            "A chave 'accent' precisa ser uma string no colors.toml."
        )

    if not re.fullmatch(r"#[0-9a-fA-F]{6}", accent):
        raise ValueError(
            f"Cor accent inválida: {accent}. Esperado: #RRGGBB."
        )

    return colors


def render_hypr_colors(colors: dict) -> None:
    template_file = TEMPLATES_DIR / "colors.lua.tpl"
    output_file = CURRENT_DIR / "colors.lua"

    if not template_file.is_file():
        raise FileNotFoundError(
            f"Template não encontrado: {template_file}"
        )

    render_template(
        template_file,
        output_file,
        {"accent": colors["accent"]},
    )

    print(f"Hyprland: {output_file}")


def render_starship(colors: dict) -> None:
    template_file = TEMPLATES_DIR / "starship.toml.tpl"
    output_file = CURRENT_DIR / "starship.toml"

    if not template_file.is_file():
        raise FileNotFoundError(
            f"Template não encontrado: {template_file}"
        )

    render_template(
        template_file,
        output_file,
        {"accent": colors["accent"]},
    )

    print(f"Starship: {output_file}")



def render_quickshell_logo(colors: dict) -> None:
    template_file = (
        TEMPLATES_DIR / "singularity.svg.tpl"
    )
    output_file = (
        CURRENT_DIR / "singularity.svg"
    )

    if not template_file.is_file():
        raise FileNotFoundError(
            f"Template não encontrado: {template_file}"
        )

    accent = colors.get("accent")

    if not isinstance(accent, str) or not re.fullmatch(
        r"#[0-9a-fA-F]{6}", accent
    ):
        raise ValueError("A cor accent é inválida.")

    render_template(
        template_file,
        output_file,
        {"accent": accent},
    )

    print(f"Quickshell logo: {output_file}")

def render_quickshell(colors: dict) -> None:
    template_file = TEMPLATES_DIR / "Theme.qml.tpl"
    output_file = CURRENT_DIR / "Theme.qml"

    required_colors = [
        "accent",
        "selection",
        "muted",
        "background",
        "dark_background",
        "darker_background",
        "lighter_background",
        "foreground",
        "dark_foreground",
        "light_foreground",
        "bright_foreground",
    ]

    missing_colors = [
        key
        for key in required_colors
        if not isinstance(colors.get(key), str)
    ]

    if missing_colors:
        raise ValueError(
            "Cores ausentes ou inválidas no colors.toml: "
            + ", ".join(missing_colors)
        )

    if not template_file.is_file():
        raise FileNotFoundError(
            f"Template não encontrado: {template_file}"
        )

    render_template(
        template_file,
        output_file,
        {key: colors[key] for key in required_colors},
    )

    print(f"Quickshell: {output_file}")


def main() -> int:
    if len(sys.argv) != 2:
        print(
            "Uso: python bin/lib/render.py <nome-do-tema>",
            file=sys.stderr,
        )
        return 2

    theme_name = sys.argv[1]

    if not re.fullmatch(r"[a-zA-Z0-9_-]+", theme_name):
        print(f"Nome de tema inválido: {theme_name}", file=sys.stderr)
        return 2

    try:
        colors = load_theme_colors(theme_name)

        render_hypr_colors(colors)
        render_starship(colors)
        render_quickshell_logo(colors)
        render_quickshell(colors)

    except (OSError, ValueError, tomllib.TOMLDecodeError) as error:
        print(f"Erro ao renderizar tema: {error}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
