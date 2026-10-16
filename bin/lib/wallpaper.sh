
#!/usr/bin/env bash

WALLPAPER_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/singularity"
WALLPAPER_STATE_FILE="$WALLPAPER_STATE_DIR/current-wallpaper"

# Return all supported wallpapers in alphabetical order.
wallpaper_collect() {
    local name="$1"
    local backgrounds_dir="$THEMES_DIR/$name/backgrounds"
    local file

    [[ -d "$backgrounds_dir" ]] || return 1

    while IFS= read -r file; do
        case "${file,,}" in
            *.png|*.jpg|*.jpeg|*.webp|*.avif|*.bmp)
                printf '%s\n' "$file"
                ;;
        esac
    done < <(find "$backgrounds_dir" -maxdepth 1 -type f -print | sort)
}

# Return the default wallpaper for a theme.
wallpaper_find_default() {
    local name="$1"
    local wallpaper

    wallpaper="$(wallpaper_collect "$name")" || return 1
    [[ -n "$wallpaper" ]] || return 1

    printf '%s\n' "${wallpaper%%$'\n'*}"
}

# Apply a wallpaper using the Singularity transition.
wallpaper_apply() {
    local wallpaper="$1"

    awww img "$wallpaper" \
        --transition-type fade \
        --transition-duration 1.2 \
        --transition-fps 60 \
        --transition-step 40 \
        --transition-pos center
}

# Save the applied wallpaper.
wallpaper_save_current() {
    local wallpaper="$1"

    mkdir -p "$WALLPAPER_STATE_DIR" || {
        echo "Error: failed to create wallpaper state directory." >&2
        return 1
    }

    printf '%s\n' "$wallpaper" > "$WALLPAPER_STATE_FILE" || {
        echo "Error: failed to save wallpaper state." >&2
        return 1
    }
}

# Apply a wallpaper and update the persisted state.
wallpaper_select() {
    local wallpaper="$1"

    if [[ ! -f "$wallpaper" ]]; then
        echo "Error: wallpaper not found: $wallpaper" >&2
        return 1
    fi

    if ! wallpaper_apply "$wallpaper"; then
        echo "Error: failed to apply wallpaper." >&2
        return 1
    fi

    wallpaper_save_current "$wallpaper" || return 1

    echo "Wallpaper set to: $wallpaper"
}

# Set the default wallpaper for a theme.
wallpaper_set() {
    if (($# > 1)); then
        echo "Usage: singularity wallpaper set [theme]" >&2
        return 2
    fi

    local name="${1:-}"
    local wallpaper

    if [[ -z "$name" ]]; then
        name="$(theme_read_current)"
    fi

    if [[ -z "$name" ]]; then
        echo "Error: no theme selected." >&2
        return 1
    fi

    if ! theme_exists "$name"; then
        echo "Error: theme not found: $name" >&2
        return 1
    fi

    if ! wallpaper="$(wallpaper_find_default "$name")"; then
        echo "Error: no wallpaper found for theme: $name" >&2
        return 1
    fi

    wallpaper_select "$wallpaper"
}

# List wallpapers for a theme.
wallpaper_list() {
    if (($# > 1)); then
        echo "Usage: singularity wallpaper list [theme]" >&2
        return 2
    fi

    local name="${1:-}"
    local wallpaper
    local -a wallpapers=()

    if [[ -z "$name" ]]; then
        name="$(theme_read_current)"
    fi

    if [[ -z "$name" ]]; then
        echo "Error: no theme selected." >&2
        return 1
    fi

    if ! theme_exists "$name"; then
        echo "Error: theme not found: $name" >&2
        return 1
    fi

    mapfile -t wallpapers < <(wallpaper_collect "$name")

    if ((${#wallpapers[@]} == 0)); then
        echo "No wallpapers found for theme: $name" >&2
        return 1
    fi

    local current=""
    if [[ -f "$WALLPAPER_STATE_FILE" ]]; then
        IFS= read -r current < "$WALLPAPER_STATE_FILE" || :
    fi

    printf 'Wallpapers for %s:\n' "$name"

    local i
    for i in "${!wallpapers[@]}"; do
        if [[ "${wallpapers[$i]}" == "$current" ]]; then
            printf '  %d. %s [current]\n' \
                "$((i + 1))" "$(basename -- "${wallpapers[$i]}")"
        else
            printf '  %d. %s\n' \
                "$((i + 1))" "$(basename -- "${wallpapers[$i]}")"
        fi
    done
}

# Display the persisted wallpaper path.
wallpaper_current() {
    if [[ ! -f "$WALLPAPER_STATE_FILE" ]]; then
        echo "No wallpaper recorded."
        return 1
    fi

    cat -- "$WALLPAPER_STATE_FILE"
}

# Navigate through wallpapers in the current theme.
wallpaper_navigate() {
    local direction="$1"
    local name
    local current=""
    local wallpaper
    local index=-1
    local count
    local next_index
    local -a wallpapers=()

    case "$direction" in
        next|previous) ;;
        *)
            echo "Error: invalid wallpaper direction: $direction" >&2
            return 2
            ;;
    esac

    name="$(theme_read_current)"

    if [[ -z "$name" ]]; then
        echo "Error: no theme selected." >&2
        return 1
    fi

    if ! theme_exists "$name"; then
        echo "Error: theme not found: $name" >&2
        return 1
    fi

    mapfile -t wallpapers < <(wallpaper_collect "$name")
    count="${#wallpapers[@]}"

    if ((count == 0)); then
        echo "Error: no wallpapers found for theme: $name" >&2
        return 1
    fi

    if [[ -f "$WALLPAPER_STATE_FILE" ]]; then
        IFS= read -r current < "$WALLPAPER_STATE_FILE" || :
    fi

    local i
    for i in "${!wallpapers[@]}"; do
        if [[ "${wallpapers[$i]}" == "$current" ]]; then
            index="$i"
            break
        fi
    done

    if ((index < 0)); then
        if [[ "$direction" == "next" ]]; then
            next_index=0
        else
            next_index=$((count - 1))
        fi
    elif [[ "$direction" == "next" ]]; then
        next_index=$(((index + 1) % count))
    else
        next_index=$(((index - 1 + count) % count))
    fi

    wallpaper="${wallpapers[$next_index]}"
    wallpaper_select "$wallpaper"
}

wallpaper_next() {
    wallpaper_navigate next
}

wallpaper_previous() {
    wallpaper_navigate previous
}
