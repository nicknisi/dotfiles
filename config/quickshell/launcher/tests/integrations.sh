#!/usr/bin/env bash
# Only fixtures, help/schema inspection and isolated HOME writes. No apps or audio.
set -euo pipefail
here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
export HOME="$work" XDG_CONFIG_HOME="$work/.config" XDG_DATA_HOME="$work/.local/share"
export XDG_CACHE_HOME="$work/.cache" XDG_RUNTIME_DIR="$work" PYTHONDONTWRITEBYTECODE=1
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QPA_PLATFORMTHEME=generic
unset DISPLAY WAYLAND_DISPLAY
qmltest="$(command -v qmltestrunner || true)"
qmltest="${qmltest:-/usr/lib/qt6/bin/qmltestrunner}"
for test in tst_ai.qml tst_voicebindings.qml tst_codexpolicy.qml tst_units.qml integrations_portability.qml; do
  "$qmltest" -input "$here/$test"
done
for test in bindings protocol codex voice clipboard matching matching_setup providers view; do
  python3 "$here/integrations_$test.py"
done
luajit "$here/tz_helper_check.lua"
