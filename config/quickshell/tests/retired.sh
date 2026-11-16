#!/usr/bin/env bash
# What M10 retired stays retired: the old Hud and its pages, the media card,
# the toasts and the notification center, the avatar, and the old Theme's
# surface colours. Source checks only; the features live on in the control
# center's sheets, the classic banner cards and Tokens.
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
fail() { echo "RETIRED_TEST_FAIL: $*" >&2; exit 1; }

# Spelled in halves so this file does not mention them either.
avatar='Nick''Avatar'
sprites='assets/''nick'
if grep -rIl --exclude-dir=node_modules -e "$avatar" -e "$sprites" "$root"; then
    fail "no file in config/quickshell mentions the retired avatar"
fi
[[ ! -e "$root/$sprites" ]] || fail "the avatar's sprites are gone"

gone=(Hud HudHome MediaCard NotificationCenter Notifications Sys Spark Gauge Flip
    AudioMenu NetMenu BtMenu DisplayMenu CaffeineMenu ClockMenu TailscaleMenu ThemeMenu TrayMenu BatteryMenu
    TrayMenuEntries TrayMenuEntry MenuAction MenuHeading MenuHint MenuRule MenuSlider
    BarModule PopupSurface ShellSurface TailscaleIcon "$avatar")
for name in "${gone[@]}"; do
    [[ ! -e "$root/$name.qml" ]] || fail "$name.qml is retired"
done
[[ ! -e "$root/MenuAnchor.js" ]] || fail "MenuAnchor.js is retired"
# No QML builds one, and no loader or import names one by path.
pattern=$(printf '%s|' "${gone[@]}"); pattern=${pattern%|}
if grep -rnE --include='*.qml' --include='*.js' "^\s*(${pattern})\s*\{|\"(\.\./)*(${pattern})\.qml\"|MenuAnchor\.js" "$root"; then
    fail "a retired component is still built or loaded"
fi

# The old Theme's surface colours have no consumers left (Tokens has them).
if grep -rnE --include='*.qml' --include='*.js' 'Theme\.(surface|raised|secondary|accentText)\b' "$root" | grep -v '^\S*/Theme\.qml:'; then
    fail "Theme.surface, raised, secondary and accentText moved to Tokens"
fi

# The island's surfaces are opaque with no blur: none of their layer
# namespaces is in hyprland.lua's shell-blur rule.
rule=$(grep -A2 'name = "shell-blur"' "$root/../hypr/hyprland.lua" | grep -o 'namespace = "[^"]*"')
[[ -n "$rule" ]] || fail "the shell-blur rule is where this test looks for it"
for ns in quickshell quickshell-island quickshell-island-scrim quickshell-anchored quickshell-notifications quickshell-polkit launcher theme-picker window-switcher; do
    if grep -qE "[(|]${ns}[|)]" <<<"$rule"; then
        fail "shell-blur matches $ns: $rule"
    fi
done
printf 'RETIRED_TEST_PASS\n'
