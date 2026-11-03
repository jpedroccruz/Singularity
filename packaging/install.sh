#!/usr/bin/env bash

set -Eeuo pipefail

readonly INSTALL_DIR="/usr/share/singularity"
readonly BIN_DIR="/usr/local/bin"
readonly GTK_THEMES_DIR="/usr/share/themes"
readonly GTK_ICONS_DIR="/usr/share/icons"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
readonly PROJECT_ROOT

STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
readonly STATE_HOME

STATE_DIR="$STATE_HOME/singularity"
readonly STATE_DIR

CURRENT_DIR="$STATE_DIR/current"
readonly CURRENT_DIR

STAGING_DIR=""

readonly SHARED_DIRS=(
    bin
    hypr
    kitty
    quickshell
    templates
    themes
)

log() {
    printf '\033[1;34m[Singularity]\033[0m %s\n' "$1"
}

warn() {
    printf '\033[1;33m[Aviso]\033[0m %s\n' "$1" >&2
}

error() {
    printf '\033[1;31m[Erro]\033[0m %s\n' "$1" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 ||
        error "Comando obrigatório não encontrado: $1"
}

require_project() {
    local path

    for path in \
        "$PROJECT_ROOT/bin/singularity" \
        "$PROJECT_ROOT/bin/lib" \
        "$PROJECT_ROOT/hypr" \
        "$PROJECT_ROOT/kitty" \
        "$PROJECT_ROOT/quickshell" \
        "$PROJECT_ROOT/templates" \
        "$PROJECT_ROOT/themes" \
        "$PROJECT_ROOT/gtk-themes" \
        "$PROJECT_ROOT/gtk-icons" \
        "$SCRIPT_DIR/bin/singularity" \
        "$SCRIPT_DIR/bin/screensaver"
    do
        [[ -e "$path" ]] ||
            error "Arquivo ou diretório não encontrado: $path"
    done
}

require_config_directory() {
    local target="$1"
    local source="$2"
    local resolved_target
    local resolved_source

    if [[ -L "$target" ]]; then
        resolved_target="$(readlink -f -- "$target" 2>/dev/null || true)"
        resolved_source="$(readlink -f -- "$source" 2>/dev/null || true)"

        if [[ -n "$resolved_target" && "$resolved_target" == "$resolved_source" ]]; then
            log "Removendo link antigo de diretório: $target"
            rm -- "$target"
        else
            error "O caminho $target é um link simbólico para outro destino. Nenhuma alteração foi feita nele."
        fi
    fi

    if [[ -e "$target" && ! -d "$target" ]]; then
        error "O caminho existe, mas não é um diretório: $target"
    fi

    mkdir -p -- "$target"
}

link_file() {
    local source="$1"
    local target="$2"
    local existing_target

    if [[ ! -f "$source" ]]; then
        warn "Arquivo de origem não encontrado; ignorando: $source"
        return 0
    fi

    mkdir -p -- "$(dirname -- "$target")"

    if [[ -L "$target" ]]; then
        existing_target="$(readlink -m -- "$target" 2>/dev/null || true)"

        if [[ "$existing_target" == "$(readlink -m -- "$source")" ]]; then
            return 0
        fi

        warn "Link já existe e será preservado: $target"
        return 0
    fi

    if [[ -e "$target" ]]; then
        warn "Arquivo pessoal já existe e será preservado: $target"
        return 0
    fi

    ln -s -- "$source" "$target"
    log "Link criado: $target"
}

link_generated_file() {
    local source="$1"
    local target="$2"
    local existing_target
    local expected_target

    mkdir -p -- "$(dirname -- "$target")"

    if [[ -L "$target" ]]; then
        existing_target="$(readlink -m -- "$target" 2>/dev/null || true)"
        expected_target="$(readlink -m -- "$source")"

        if [[ "$existing_target" == "$expected_target" ]]; then
            return 0
        fi

        warn "Link existente será preservado: $target"
        return 0
    fi

    if [[ -e "$target" ]]; then
        warn "Arquivo pessoal já existe e será preservado: $target"
        return 0
    fi

    ln -s -- "$source" "$target"
    log "Link de arquivo gerado criado: $target"
}

link_tree() {
    local source_dir="$1"
    local target_dir="$2"
    local source_file
    local relative_path

    while IFS= read -r -d '' source_file; do
        relative_path="${source_file#"$source_dir"/}"
        link_file "$source_file" "$target_dir/$relative_path"
    done < <(find "$source_dir" -type f -print0)
}

install_shared_resources() {
    local directory
    local dynamic_link
    local unexpected_link

    local dynamic_links=(
        "bin/screensaver.py"
        "hypr/hyprlock.conf"
        "hypr/modules/colors.lua"
        "quickshell/theme/Theme.qml"
        "quickshell/modules/Bar/assets/singularity.svg"
    )

    log "Preparando recursos compartilhados..."

    if [[ -L "$INSTALL_DIR" ]]; then
        error "$INSTALL_DIR é um link simbólico. Verifique o destino antes de continuar."
    fi

    if [[ -e "$INSTALL_DIR" && ! -d "$INSTALL_DIR" ]]; then
        error "$INSTALL_DIR existe, mas não é um diretório."
    fi

    STAGING_DIR="$(mktemp -d)"

    for directory in "${SHARED_DIRS[@]}"; do
        cp -R -- "$PROJECT_ROOT/$directory" "$STAGING_DIR/"
    done

    # Remove links que apontam para arquivos gerados por usuário.
    for dynamic_link in "${dynamic_links[@]}"; do
        if [[ -L "$STAGING_DIR/$dynamic_link" ]]; then
            rm -- "$STAGING_DIR/$dynamic_link"
        fi
    done

    # Não permite instalar links simbólicos inesperados nos recursos globais.
    for directory in "${SHARED_DIRS[@]}"; do
        unexpected_link="$(find "$STAGING_DIR/$directory" -type l -print -quit)"

        if [[ -n "$unexpected_link" ]]; then
            error "Link simbólico inesperado nos recursos compartilhados: $unexpected_link"
        fi
    done

    sudo install -d "$INSTALL_DIR"

    for directory in "${SHARED_DIRS[@]}"; do
        sudo rm -rf -- "$INSTALL_DIR/$directory"
        sudo cp -R -- "$STAGING_DIR/$directory" "$INSTALL_DIR/"
    done

    rm -rf -- "$STAGING_DIR"
    STAGING_DIR=""

    log "Recursos compartilhados instalados em $INSTALL_DIR."
}

install_wrapper() {
    local source="$1"
    local command_name="$2"
    local target="$BIN_DIR/$command_name"
    local existing_target

    if [[ -L "$target" ]]; then
        existing_target="$(readlink -m -- "$target" 2>/dev/null || true)"

        if [[ "$existing_target" == "$(readlink -m -- "$source")" ]]; then
            return 0
        fi

        error "Já existe um link simbólico conflitante: $target"
    fi

    if [[ -e "$target" ]]; then
        if cmp -s -- "$source" "$target"; then
            sudo chmod 755 "$target"
            return 0
        fi

        error "Já existe um comando com conteúdo diferente: $target"
    fi

    sudo install -m 755 "$source" "$target"
    log "Comando instalado: $command_name"
}

install_shared_command() {
    local command_name="$1"
    local source="$INSTALL_DIR/bin/$command_name"
    local target="$BIN_DIR/$command_name"
    local existing_target

    [[ -f "$source" ]] ||
        error "Executável compartilhado não encontrado: $source"

    if [[ -L "$target" ]]; then
        existing_target="$(readlink -m -- "$target" 2>/dev/null || true)"

        if [[ "$existing_target" == "$(readlink -m -- "$source")" ]]; then
            return 0
        fi

        error "Já existe um link simbólico conflitante: $target"
    fi

    if [[ -e "$target" ]]; then
        error "Já existe um comando com esse nome: $target"
    fi

    sudo ln -s -- "$source" "$target"
    log "Comando vinculado: $command_name"
}

install_global_commands() {
    local command_name

    log "Instalando comandos globais..."

    sudo install -d "$BIN_DIR"

    install_wrapper "$SCRIPT_DIR/bin/singularity" "singularity"
    install_wrapper "$SCRIPT_DIR/bin/screensaver" "screensaver"

    local commands=(
        screenshot
        hyprlock-media
        hyprlock-song
        hyprlock-play-pause
    )

    for command_name in "${commands[@]}"; do
        install_shared_command "$command_name"
    done
}

install_gtk_resources() {
    local source
    local target
    local directory

    log "Instalando temas GTK e ícones..."

    sudo install -d "$GTK_THEMES_DIR" "$GTK_ICONS_DIR"

    for source in "$PROJECT_ROOT"/gtk-themes/*; do
        [[ -d "$source" ]] || continue

        directory="$(basename -- "$source")"
        target="$GTK_THEMES_DIR/$directory"

        if [[ -e "$target" || -L "$target" ]]; then
            warn "Tema GTK já existe e será preservado: $target"
            continue
        fi

        sudo cp -R -- "$source" "$GTK_THEMES_DIR/"
        log "Tema GTK instalado: $directory"
    done

    for source in "$PROJECT_ROOT"/gtk-icons/*; do
        [[ -d "$source" ]] || continue

        directory="$(basename -- "$source")"
        target="$GTK_ICONS_DIR/$directory"

        if [[ -e "$target" || -L "$target" ]]; then
            warn "Tema de ícones já existe e será preservado: $target"
            continue
        fi

        sudo cp -R -- "$source" "$GTK_ICONS_DIR/"
        log "Tema de ícones instalado: $directory"
    done
}

configure_user() {
    log "Configurando arquivos do usuário..."

    mkdir -p "$STATE_DIR" "$CURRENT_DIR" "$HOME/.config"

    # Migra os antigos links de diretório para diretórios reais.
    require_config_directory "$HOME/.config/hypr" "$PROJECT_ROOT/hypr"
    require_config_directory "$HOME/.config/kitty" "$PROJECT_ROOT/kitty"
    require_config_directory "$HOME/.config/quickshell" "$PROJECT_ROOT/quickshell"

    # Configurações estáticas: links individuais.
    link_tree "$PROJECT_ROOT/hypr" "$HOME/.config/hypr"
    link_tree "$PROJECT_ROOT/kitty" "$HOME/.config/kitty"
    link_tree "$PROJECT_ROOT/quickshell" "$HOME/.config/quickshell"

    # Configurações geradas pelo sistema de temas.
    link_generated_file \
        "$CURRENT_DIR/hyprlock.conf" \
        "$HOME/.config/hypr/hyprlock.conf"

    link_generated_file \
        "$CURRENT_DIR/colors.lua" \
        "$HOME/.config/hypr/modules/colors.lua"

    link_generated_file \
        "$CURRENT_DIR/Theme.qml" \
        "$HOME/.config/quickshell/theme/Theme.qml"

    link_generated_file \
        "$CURRENT_DIR/singularity.svg" \
        "$HOME/.config/quickshell/modules/Bar/assets/singularity.svg"

    # Starship também utiliza um arquivo gerado por usuário.
    link_generated_file \
        "$CURRENT_DIR/starship.toml" \
        "$HOME/.config/starship.toml"

    log "Configuração do usuário concluída."
}

main() {
    require_command bash
    require_command sudo
    require_command cp
    require_command find
    require_command ln
    require_command python3
    require_command readlink

    require_project

    log "Iniciando instalação do Singularity..."

    sudo -v

    install_shared_resources
    install_global_commands
    install_gtk_resources
    configure_user

    log "Instalação concluída."
    log "O repositório $PROJECT_ROOT foi preservado."
    log "Execute 'singularity theme set <nome>' para gerar os arquivos do tema."
}

trap 'if [[ -n "$STAGING_DIR" ]]; then rm -rf -- "$STAGING_DIR"; fi' EXIT

main "$@"
