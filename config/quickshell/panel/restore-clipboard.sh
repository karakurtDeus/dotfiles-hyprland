#!/usr/bin/env bash
set -eu

entry=$(mktemp)
trap 'rm -f -- "$entry"' EXIT

cliphist decode "$1" > "$entry"
mime=$(file --brief --mime-type -- "$entry")
case "$mime" in
    image/*) ;;
    *) mime='text/plain;charset=utf-8' ;;
esac

wl-copy --type "$mime" < "$entry"
