#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/themes/gruvbox" "$TMP/themes/everforest"
cp "$ROOT/bin/theme" "$ROOT/bin/theme-color" "$TMP/bin/"
cp "$ROOT/themes/gruvbox/colors.toml" "$TMP/themes/gruvbox/"
cp "$ROOT/themes/everforest/colors.toml" "$TMP/themes/everforest/"

colors=()
while IFS=$'\t' read -r key color; do
  case "$key" in background | foreground | accent | color[0-9]*) colors+=("xc:$color") ;; esac
done < <("$TMP/bin/theme-color" -f "$TMP/themes/gruvbox/colors.toml" --all)

image="$TMP/gruvbox-stripes.png"
magick "${colors[@]}" +append "$image"
magick "$image" -resize 400x240\! "$image"
mkdir -p "$TMP/themes/gruvbox/backgrounds"
cp "$image" "$TMP/themes/gruvbox/backgrounds/3-existing.png"
output=$("$TMP/bin/theme" adopt "$image")
grep -q -- '-> gruvbox (score ' <<<"$output"
[[ -f "$TMP/themes/gruvbox/backgrounds/4-gruvbox-stripes.png" ]]

magick -size 32x32 xc:white "$TMP/white.png"
if "$TMP/bin/theme" adopt "$TMP/white.png" >"$TMP/out" 2>"$TMP/err"; then
  printf 'unrelated image unexpectedly matched\n' >&2
  exit 1
fi
grep -q 'no close match' "$TMP/err"
[[ ! -e "$TMP/themes/gruvbox/backgrounds/5-white.png" ]]

printf 'THEME_ADOPT_TEST_PASS\n'
