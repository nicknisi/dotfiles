#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"
mkdir -p "$HOME" "$TMP/bin" "$TMP/themes/templates"
cp "$ROOT/bin/theme-color" "$TMP/bin/"
cp "$ROOT/themes/templates/gtk.css.tpl" "$TMP/themes/templates/"
# Exercise the real CLI/rendering/state paths, but never touch the live desktop.
awk '
  /^case "\$\{1:-\}" in$/ {
    print "reload_apps() { :; }"
    print "finale() { :; }"
    print "plymouth_hint() { :; }"
    print "thumbs_background() { :; }"
    print "paint_wallpaper() { :; }"
    print "mac_wallpaper() { :; }"
    print "notify-send() { :; }"
    print "wofi() { cat >/dev/null; printf '\''%s\\n'\'' alpha; }"
  }
  { print }
' "$ROOT/bin/theme" >"$TMP/bin/theme"
chmod +x "$TMP/bin/theme"
for name in alpha beta empty; do
  mkdir -p "$TMP/themes/$name"
  cp "$ROOT/themes/gruvbox/colors.toml" "$TMP/themes/$name/"
done
for name in alpha beta; do
  mkdir -p "$TMP/themes/$name/backgrounds"
  touch "$TMP/themes/$name/backgrounds/1-first.png" "$TMP/themes/$name/backgrounds/2-second image.png"
done
theme() { "$TMP/bin/theme" "$@"; }
STATE="$HOME/.local/state/theme/current"
alpha="$TMP/themes/alpha/backgrounds"
beta="$TMP/themes/beta/backgrounds"
assert_wall() { [[ "$(readlink "$STATE/background")" == "$1" ]]; }

theme set alpha
assert_wall "$alpha/1-first.png"
theme bg 2
assert_wall "$alpha/2-second image.png"
theme beta 2
theme alpha
assert_wall "$alpha/2-second image.png"
theme next
assert_wall "$beta/2-second image.png"
theme prev
assert_wall "$alpha/2-second image.png"
theme refresh
assert_wall "$alpha/2-second image.png"
# Picker previews show the wallpaper that applying the theme will restore.
theme _rows themes >"$TMP/rows.json"
python3 - "$TMP/rows.json" "$alpha/2-second image.png" <<'PY'
import json, sys
rows = json.load(open(sys.argv[1]))
assert next(row for row in rows if row['name'] == 'alpha')['image'] == sys.argv[2]
PY
# The fallback menu must restore too.
theme beta
theme menu
assert_wall "$alpha/2-second image.png"
# Explicit indices override the saved wallpaper and replace it.
theme alpha 1
theme beta
theme alpha
assert_wall "$alpha/1-first.png"
# An external path (including spaces) also survives a theme switch.
touch "$TMP/external image.png"
theme bg "$TMP/external image.png"
theme beta
theme alpha
assert_wall "$TMP/external image.png"
# Deleted saved images fall back to the first image.
rm "$TMP/external image.png"
theme beta
theme alpha
assert_wall "$alpha/1-first.png"
# Invalid explicit choices must leave state unchanged.
if theme alpha 99 >/dev/null 2>&1; then exit 1; fi
assert_wall "$alpha/1-first.png"
# Packs without backgrounds still apply, preserving the current wallpaper.
theme empty
assert_wall "$alpha/1-first.png"
[[ "$(theme current)" == empty ]]
[[ ! -e "$STATE/wallpapers/empty" ]]
printf 'THEME_WALLPAPERS_PASS\n'
