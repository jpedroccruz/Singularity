
#!/usr/bin/env bash

THEMES_DIR="$SINGULARITY_ROOT/themes"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/singularity"
STATE_FILE="$STATE_DIR/current-theme"

theme_list_names() {
    if [[ ! -d "$THEMES_DIR" ]]; then
        echo "Error: themes directory not found: $THEMES_DIR" >&2
        return 1
    fi

    find "$THEMES_DIR" \
        -mindepth 1 -maxdepth 1 -type d \
        -printf '%f\n' | sort
}

theme_read_current() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    fi
}

theme_exists() {
    [[ -d "$THEMES_DIR/$1" ]]
}

theme_save_current() {
    local name="$1"
    local temporary_file

    mkdir -p "$STATE_DIR"
    temporary_file="$(mktemp "$STATE_DIR/.current-theme.XXXXXX")"

    printf '%s\n' "$name" > "$temporary_file"
    mv -f -- "$temporary_file" "$STATE_FILE"
}

theme_set() {
    if (($# != 1)); then
        echo "Usage: singularity theme set <name>" >&2
        return 2
    fi

    local name="$1"

    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "Error: invalid theme name: $name" >&2
        return 2
    fi

    if ! theme_exists "$name"; then
        echo "Error: theme not found: $name" >&2
        echo "Run 'singularity theme list' to see available themes." >&2
        return 1
    fi

    if ! python "$SINGULARITY_ROOT/bin/lib/render.py" "$name"; then
        echo "Error: failed to render theme: $name" >&2
        return 1
    fi

    if ! gsettings set org.gnome.desktop.interface gtk-theme "Singularity-$name-Dark"; then
        echo "Error: failed to apply GTK theme." >&2
        return 1
    fi

    if ! gsettings set org.gnome.desktop.interface icon-theme "Singularity-$name-Dark"; then
        echo "Error: failed to apply icon theme." >&2
        return 1
    fi

    if ! nwg-look -x; then
        echo "Error: failed to export GTK settings." >&2
        return 1
    fi

    theme_save_current "$name"

    echo "Theme set to: $name"
}

theme_current() {
    if (($# != 0)); then
        echo "Usage: singularity theme current" >&2
        return 2
    fi

    local name
    name="$(theme_read_current)"

    if [[ -z "$name" ]]; then
        echo "No theme selected."
        return 1
    fi

    printf '%s\n' "$name"
}

theme_list() {
    if (($# != 0)); then
        echo "Usage: singularity theme list" >&2
        return 2
    fi

    local current
    current="$(theme_read_current)"

    local name
    local found=0

    while IFS= read -r name; do
        [[ -n "$name" ]] || continue
        found=1

        if [[ "$name" == "$current" ]]; then
            printf '* %s (current)\n' "$name"
        else
            printf '  %s\n' "$name"
        fi
    done < <(theme_list_names)

    if ((found == 0)); then
        echo "No themes found in $THEMES_DIR"
    fi
}

theme_move() {
    local direction="$1"
    local current
    local -a themes=()

    mapfile -t themes < <(theme_list_names)

    if ((${#themes[@]} == 0)); then
        echo "Error: no themes available." >&2
        return 1
    fi

    current="$(theme_read_current)"

    local index=-1
    local i

    for i in "${!themes[@]}"; do
        if [[ "${themes[$i]}" == "$current" ]]; then
            index="$i"
            break
        fi
    done

    if ((index == -1)); then
        if [[ "$direction" == "next" ]]; then
            index=0
        else
            index=$((${#themes[@]} - 1))
        fi
    else
        if [[ "$direction" == "next" ]]; then
            index=$(((index + 1) % ${#themes[@]}))
        else
            index=$(((index - 1 + ${#themes[@]}) % ${#themes[@]}))
        fi
    fi

    theme_set "${themes[$index]}"
}

theme_next() {
    if (($# != 0)); then
        echo "Usage: singularity theme next" >&2
        return 2
    fi

    theme_move next
}

theme_previous() {
    if (($# != 0)); then
        echo "Usage: singularity theme previous" >&2
        return 2
    fi

    theme_move previous
}
