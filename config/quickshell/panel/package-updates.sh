#!/usr/bin/env bash
set -eu

scan_cache_temp=
trap 'if [[ -n $scan_cache_temp && -f $scan_cache_temp ]]; then unlink -- "$scan_cache_temp"; fi' EXIT

scan_updates() {
    local checker official aur official_count aur_count total status
    local cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}
    checker=$(command -v checkupdates || printf '%s' "$HOME/.local/libexec/quickshell/checkupdates")

    status=0
    official=$("$checker" --nocolor) || status=$?
    if ((status != 0 && status != 2)); then
        return "$status"
    fi

    mkdir -p -- "$cache_dir"
    scan_cache_temp=$(mktemp -- "$cache_dir/.updates.XXXXXX")

    status=0
    aur=$(yay -Qua 2>"$scan_cache_temp") || status=$?
    if ((status != 0)) && { ((status != 1)) || [[ -n $aur || -s $scan_cache_temp ]]; }; then
        cat -- "$scan_cache_temp" >&2
        return "$status"
    fi

    official_count=$(awk 'NF {count++} END {print count+0}' <<< "$official")
    aur_count=$(awk 'NF {count++} END {print count+0}' <<< "$aur")
    total=$((official_count + aur_count))
    printf '%s\n' "$total" > "$scan_cache_temp"
    mv -f -- "$scan_cache_temp" "$cache_dir/updates"
    printf '%s\n' "$total"
}

case "${1:-}" in
    --scan)
        scan_updates
        ;;
    --update)
        status=0
        yay -Syu || status=$?
        printf '\nPress Enter to close...'
        read -r _ || true
        exit "$status"
        ;;
    *)
        exit 2
        ;;
esac
