#!/usr/bin/env bash
# Fixtures only. Live model verification is an explicit matching_live.py check.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
shell_root=$(cd -- "$here/../.." && pwd)
repo=$(cd -- "$shell_root/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
export PYTHONDONTWRITEBYTECODE=1
mkdir -p "$tmp/runtime"
chmod 700 "$tmp/runtime"
env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE \
    HOME="$tmp" XDG_CONFIG_HOME="$tmp/config" XDG_DATA_HOME="$tmp/data" \
    XDG_CACHE_HOME="$tmp/cache" XDG_STATE_HOME="$tmp/state" XDG_RUNTIME_DIR="$tmp/runtime" \
    QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input "$here"
python3 "$here/cli.py"
luajit "$here/hotkeys_fixture.lua" "$repo/config/hypr/launcher-bindings.lua"
bash "$here/native.sh"
python3 "$here/extensions_helper_test.py"
python3 "$here/extensions_qml_test.py"
bash "$here/host-check.sh"
LAUNCHER_QML_SHIM_ROOT="$shell_root" bash "$here/integrations.sh"
printf 'LAUNCHER_TEST_PASS\n'
