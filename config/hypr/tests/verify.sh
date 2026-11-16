#!/usr/bin/env bash
# Hyprland's own check of hyprland.lua (PLAN M9): `Hyprland --verify-config`
# on a copy of config/hypr, away from the running session (no instance
# signature, no Wayland display, a private runtime dir and HOME, so it binds
# nothing the live compositor owns). It also checks the compositor spring:
# the shellSpatial curve is defined, the global leaf still runs on its bezier,
# and SWITCHOVER.md's one-line switch to the spring verifies too.
#
# Without Hyprland (macOS, CI) it prints a SKIP line and passes.
set -euo pipefail
here=$(cd -- "$(dirname -- "$0")/.." && pwd)
config="$here/hyprland.lua"

grep -q '^hl.curve("shellSpatial", { type = "spring", mass = 1, stiffness = 600, damping = 49 })$' "$config" \
    || { echo "HYPR_VERIFY_FAIL: no shellSpatial spring curve" >&2; exit 1; }
grep -q '^hl.animation({ leaf = "global", enabled = true, speed = 2.5, bezier = "default" })$' "$config" \
    || { echo "HYPR_VERIFY_FAIL: the global leaf left its bezier" >&2; exit 1; }
curve_line=$(grep -n '^hl.curve("shellSpatial"' "$config" | cut -d: -f1)
global_line=$(grep -n '^hl.animation({ leaf = "global"' "$config" | cut -d: -f1)
[ "$curve_line" -lt "$global_line" ] || { echo "HYPR_VERIFY_FAIL: the curve must come before the animation that names it" >&2; exit 1; }

if ! command -v Hyprland >/dev/null 2>&1; then
    echo "HYPR_VERIFY_SKIP: Hyprland is not installed"
    exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
mkdir -m 700 "$tmp/run"
verify() {
    env -u HYPRLAND_INSTANCE_SIGNATURE -u WAYLAND_DISPLAY -u DISPLAY XDG_RUNTIME_DIR="$tmp/run" HOME="$tmp" \
        timeout 30 Hyprland --verify-config -c "$1" >"$tmp/out" 2>&1 || true
    if ! grep -q '^config ok$' "$tmp/out"; then
        echo "HYPR_VERIFY_FAIL: $2" >&2
        tail -20 "$tmp/out" >&2
        exit 1
    fi
}

cp -R "$here" "$tmp/hypr"
verify "$tmp/hypr/hyprland.lua" "hyprland.lua does not verify"

# SWITCHOVER.md's switch: the global leaf on the spring.
sed -i.bak 's/^hl.animation({ leaf = "global", enabled = true, speed = 2.5, bezier = "default" })$/hl.animation({ leaf = "global", enabled = true, speed = 2.5, spring = "shellSpatial" })/' "$tmp/hypr/hyprland.lua"
grep -q 'spring = "shellSpatial"' "$tmp/hypr/hyprland.lua" || { echo "HYPR_VERIFY_FAIL: the switch did not apply" >&2; exit 1; }
verify "$tmp/hypr/hyprland.lua" "the switch to spring = \"shellSpatial\" does not verify"

# And a broken spring is caught, so the two passes above mean something.
cp "$tmp/hypr/hyprland.lua.bak" "$tmp/hypr/hyprland.lua"
sed -i 's/stiffness = 600, damping = 49/stiffness = "stiff", damping = 49/' "$tmp/hypr/hyprland.lua"
env -u HYPRLAND_INSTANCE_SIGNATURE -u WAYLAND_DISPLAY -u DISPLAY XDG_RUNTIME_DIR="$tmp/run" HOME="$tmp" \
    timeout 30 Hyprland --verify-config -c "$tmp/hypr/hyprland.lua" >"$tmp/out" 2>&1 || true
if grep -q '^config ok$' "$tmp/out"; then
    echo "HYPR_VERIFY_FAIL: --verify-config accepted a non-number stiffness" >&2
    exit 1
fi
echo "HYPR_VERIFY_PASS"
