#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/../.." && pwd)
qs_bin=$(command -v qs)
python_bin=$(command -v python3)
luajit_bin=$(command -v luajit)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
shims=0
if [[ ${1:-} == --shims-only ]]; then shims=1; fi
mkdir -p "$tmp/root" "$tmp/home/.local/state/theme/current" "$tmp/config" "$tmp/state" "$tmp/runtime/quickshell-launcher/request" "$tmp/bin"
chmod 700 "$tmp/runtime" "$tmp/runtime/quickshell-launcher" "$tmp/runtime/quickshell-launcher/request"
printf '{}\n' > "$tmp/home/.local/state/theme/current/colors.json"
mkdir -p "$tmp/data/keystroke/extensions/local.host-test"
printf '%s\n' '{"id":"local.host-test","name":"Host fixture","kinds":["service"],"entryPoints":{"service":"Service.qml"},"x-keystroke":{"apiVersion":1}}' > "$tmp/data/keystroke/extensions/local.host-test/manifest.json"
printf '%s\n' 'import QtQuick' 'Item { property var host: null; property var manifest: null; property var shell: null; property string omarchyPath: ""; readonly property var provider: ({ apiVersion: 1, name: "Host fixture", settings: [], query: function(ctx) { return [] } }) }' > "$tmp/data/keystroke/extensions/local.host-test/Service.qml"
printf '%s\n' '{"version":1,"palette":{"animations":"off"},"voice":{"enabled":false},"matching":{"mode":"off"},"providers":{"extensions":{"autoCheck":false,"indexUrl":"","autoUpdate":false,"marketplace":false}}}' > "$tmp/config/quickshell-launcher.json"
cp "$root"/*.qml "$root"/*.js "$tmp/root/"
cp -R "$root/Commons" "$root/Ui" "$root/launcher" "$tmp/root/"
cp "$root/launcher/tests/host-check.qml" "$tmp/root/shell.qml"
# Like upstream's palette checks, mount the unchanged card in a Qt Window.
# Offscreen Qt has no layer-shell backend. Monitor/layer behavior still needs
# a compositor check, and this replacement applies only to the temporary copy.
"$python_bin" - "$tmp/root/launcher/Keystroke.qml" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
source = path.read_text().replace('  PanelWindow {', '  Window {\n    transientParent: null\n    width: 1000; height: 800')
source = source.replace('    anchors { top: true; bottom: true; left: true; right: true }\n', '')
path.write_text('\n'.join(line for line in source.splitlines() if not any(token in line for token in ['exclusionMode:', 'WlrLayershell.', 'screen: root.targetScreen'])))
PY

# No session bus, compositor or real app tools. Only mkdir, the picker writer
# and read-only extension scans can execute. Probes and launches fail closed.
for command in sh bash python3 hyprctl voxtype codex claude chatgpt curl wget git fd cliphist wl-copy wl-paste wtype ydotool xdg-open uwsm-app ghostty notify-send systemctl loginctl capture theme clipboard-list uwsm rm; do
    printf '#!/bin/sh\nexit 1\n' > "$tmp/bin/$command"
    chmod +x "$tmp/bin/$command"
done
ln -s /usr/bin/mkdir "$tmp/bin/mkdir"
# shellcheck disable=SC2016 # The wrapper expands its own argv when invoked.
printf '#!/bin/sh\ncase "$1" in\n  "%s/launcher/helpers/picker-write.lua") exec "%s" "$@";;\n  "%s/launcher/helpers/extensions.lua") if [ "$2" = scan ]; then exec "%s" "$@"; fi;;\nesac\nexit 1\n' "$tmp/root" "$luajit_bin" "$tmp/root" "$luajit_bin" > "$tmp/bin/luajit"
chmod +x "$tmp/bin/luajit"
formatter=$(command -v qmlformat || printf /usr/lib/qt6/bin/qmlformat)
for file in "$root/Launcher.qml" "$root"/{Commons,Ui}/*.qml "$root/launcher/Keystroke.qml" "$root/launcher/providers/Registry.qml" "$root/launcher/ui"/*.qml "$root/launcher/tests/host-check.qml"; do
    "$formatter" "$file" >/dev/null
done

# Drive the production Lua writer directly, including hostile filesystem paths.
"$python_bin" - "$root/launcher/helpers/picker-write.lua" "$tmp" "$luajit_bin" <<'PY'
import os, pathlib, subprocess, sys
helper = pathlib.Path(sys.argv[1])
assert helper.is_file(), f'Missing migrated picker writer: {helper}'
tmp = pathlib.Path(sys.argv[2])
luajit = sys.argv[3]
base = tmp / 'runtime/quickshell-launcher'
request = base / 'writer-check'
request.mkdir(mode=0o700)
outside = tmp / 'home/outside'
outside.write_text('unchanged')
def run(selection, done, accepted='1', text='literal $(touch forbidden)\n<b>text</b>\t\\'):
    return subprocess.run([luajit, str(helper), str(base), str(selection), str(done), accepted, text], capture_output=True, timeout=5)
selection, done = request / 'selection', request / 'done'
assert run(selection, done).returncode == 0
assert selection.read_text() == 'literal $(touch forbidden)\n<b>text</b>\t\\\n'
assert done.read_bytes() == b''
assert selection.stat().st_mode & 0o777 == 0o600
assert done.stat().st_mode & 0o777 == 0o600
assert not (pathlib.Path.cwd() / 'forbidden').exists()
selection.unlink()
done.unlink()
assert run(selection, done, '0').returncode == 0
assert done.exists() and not selection.exists()
assert run(outside, done).returncode != 0
assert run(base / '../escape', done).returncode != 0
(request / 'link').symlink_to(tmp / 'home', target_is_directory=True)
assert run(request / 'link/outside', done).returncode != 0
selection.symlink_to(outside)
assert run(selection, done).returncode == 0
assert outside.read_text() == 'unchanged' and not selection.is_symlink()
selection.unlink()
os.link(outside, selection)
assert run(selection, done).returncode == 0
assert outside.read_text() == 'unchanged'
assert run(selection, selection).returncode != 0
# The completion marker must not follow leaf links either.
done.unlink()
done.symlink_to(outside)
assert run(selection, done).returncode == 0
assert outside.read_text() == 'unchanged' and not done.is_symlink()
done.unlink()
os.link(outside, done)
assert run(selection, done).returncode == 0
assert outside.read_text() == 'unchanged' and done.read_bytes() == b''
assert not list(request.glob('.launcher-*')), 'atomic temporary files must be removed'
print('HOST_PICKER_WRITER_PASS')
PY

env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE -u DBUS_SESSION_BUS_ADDRESS \
    HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/config" XDG_STATE_HOME="$tmp/state" \
    XDG_CACHE_HOME="$tmp/cache" XDG_DATA_HOME="$tmp/data" XDG_DATA_DIRS="$tmp/data" XDG_RUNTIME_DIR="$tmp/runtime" \
    PATH="$tmp/bin" QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QPA_PLATFORMTHEME=generic LAUNCHER_TEST_SHIMS_ONLY="$shims" \
    /usr/bin/timeout 15 "$qs_bin" -p "$tmp/root" --no-color 2>&1 | tee "$tmp/result"
if [[ $shims == 1 ]]; then
    grep -q HOST_SHIMS_PASS "$tmp/result"
else
    grep -q HOST_TEST_PASS "$tmp/result"
    "$python_bin" - "$tmp" <<'PY'
import json, pathlib, sys, time
root = pathlib.Path(sys.argv[1])
config = json.loads((root / 'config/quickshell-launcher.json').read_text())
assert config['hostTest'] is True
assert config['providers']['local.host-test']['enabled'] is False
assert json.loads((root / 'state/keystroke/usage.json').read_text())
bindings = (root / 'home/.config/hypr/launcher-voice.lua').read_text()
assert 'hl.bind' in bindings and 'qs ipc call launcher voiceHold' in bindings
assert 'omarchy' not in bindings
assert not (root / 'home/.config/hypr/bindings.lua').exists(), 'legacy bindings must not change'
done = root / 'runtime/quickshell-launcher/request/done'
for _ in range(50):
    if done.exists(): break
    time.sleep(.02)
assert done.exists()
assert done.with_name('selection').read_text() == 'Second\n'
print('HOST_PERSISTENCE_PASS')
PY
fi
! grep -E 'HOST_TEST_FAIL|ReferenceError|TypeError|Failed to load|Binding loop|Required property|Unable to assign|Cannot assign' "$tmp/result"
