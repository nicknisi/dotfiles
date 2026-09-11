#!/usr/bin/env bash
# Isolated native-provider regression checks. No real launch, dispatch or copy.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
python=$(command -v python3)
qs=$(command -v quickshell)
qmltest=${QMLTESTRUNNER:-/usr/lib/qt6/bin/qmltestrunner}
home=$(mktemp -d)
trap 'rm -rf -- "$home"' EXIT
export HOME=$home XDG_CONFIG_HOME=$home/config XDG_CACHE_HOME=$home/cache
export XDG_DATA_HOME=$home/data XDG_DATA_DIRS=$home/system XDG_STATE_HOME=$home/state
export XDG_RUNTIME_DIR=$home/runtime QT_QPA_PLATFORM=offscreen
export DBUS_SESSION_BUS_ADDRESS=unix:path=$home/no-session-bus
export DBUS_SYSTEM_BUS_ADDRESS=unix:path=$home/no-system-bus
export PYTHONDONTWRITEBYTECODE=1
unset WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE
mkdir -p "$XDG_RUNTIME_DIR" "$XDG_DATA_HOME/applications" "$home/bin" "$home/work dir"
chmod 700 "$XDG_RUNTIME_DIR"
luajit native_helpers.lua
"$qmltest" -input tst_hotkeys.qml
"$python" - <<'PY'
import base64, os, shutil, sys
from pathlib import Path
home = Path.home()
# Quickshell forbids imports outside its config root. Mirror the shell under
# the test HOME and load the test through that root, never the resident shell.
shutil.copytree(Path.cwd().parents[1], home / 'qml')
(home / 'qml/shell.qml').write_text('import QtQuick\nimport Quickshell\nScope { Loader { source: "launcher/tests/native.qml" } }\n')
icon = home / 'fixture.png'
icon.write_bytes(base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABAQMAAAAl21bKAAAAA1BMVEX/AAAZ4gk3AAAACklEQVQI12NgAAAAAgAB4iG8MwAAAABJRU5ErkJggg=='))
entries = home / 'data/applications'
(entries / 'native-fixture.desktop').write_text(f'''[Desktop Entry]
Type=Application
Name=Native Fixture
Exec=printf --fixture "a b" "literal;value"
Terminal=true
Path={home}/work dir
Icon={icon}
''')
(entries / 'native-hidden.desktop').write_text('[Desktop Entry]\nType=Application\nName=Hidden Fixture\nExec=unused\nNoDisplay=true\n')
# Record only operation names, never command arguments or clipboard data.
for name in ['notify-send', 'uwsm-app', 'ghostty', 'hyprctl', 'cliphist', 'clipboard-list', 'clipboard-paste', 'wl-copy', 'theme', 'pacman', 'flatpak', 'sudo']:
    path = home / 'bin' / name
    body = '#!/bin/sh\nprintf "%s\\n" "' + name + '" >> "$HOME/operations"\n' + ('exit 0\n' if name == 'notify-send' else 'exit 77\n')
    if name == 'hyprctl':
        body = '#!/bin/sh\nif [ "$1" = -j ] && [ "$2" = getoption ]; then printf "hyprctl-read\\n" >> "$HOME/operations"; exit 0; fi\nprintf "unexpected-hyprctl\\n" >> "$HOME/operations"\nexit 77\n'
    path.write_text(body)
    path.chmod(0o700)
# Exercise the existing clipboard-list script, backed only by numeric fixtures.
shutil.copyfile(Path.cwd().parents[3] / 'bin/clipboard-list', home / 'bin/clipboard-list')
(home / 'bin/clipboard-list').chmod(0o700)
(home / 'bin/cliphist').write_text(f'''#!{sys.executable}
import sys
from pathlib import Path
home = Path({str(home)!r})
with (home / 'operations').open('a') as log:
    log.write('cliphist-' + sys.argv[1] + '\\n')
if sys.argv[1:] == ['list']:
    print('42\\tfixture summary\\n43\\t[[ binary data png ]]\\n44\\t[[ binary data unknown ]]')
elif sys.argv[1:] == ['decode', '42']:
    sys.stdout.buffer.write(b'fixture selection body\\nline two')
elif sys.argv[1:] == ['decode', '43']:
    sys.stdout.buffer.write((home / 'fixture.png').read_bytes())
else:
    sys.exit(77)
''')
(home / 'bin/cliphist').chmod(0o700)
metadata = home / 'cache/cliphist/media.tsv'
metadata.parent.mkdir(parents=True, exist_ok=True)
metadata.write_text('44\tvideo/mp4\t1024\n')
PY
export PATH="$home/bin:$PATH"
timeout 15 "$qs" --no-color --path "$home/qml/shell.qml" >"$home/native.log" 2>&1 || {
  printf 'Native QML process failed.\n'
  # This test never loads real clipboard data.
  grep -E 'ERROR|WARN|NATIVE_' "$home/native.log" || true
  exit 1
}
grep 'NATIVE_PASS:' "$home/native.log"
if grep -E 'NATIVE_FAIL|ERROR|ReferenceError|TypeError|Binding loop' "$home/native.log"; then exit 1; fi
[[ $(grep -c '^notify-send$' "$home/operations") == 1 ]] || { printf 'Expected exactly one expiry notification.\n'; exit 1; }
if grep -vE '^(hyprctl-read|notify-send|cliphist-list|cliphist-decode)$' "$home/operations"; then printf 'Unexpected native operation.\n'; exit 1; fi
[[ $(grep -c '^cliphist-list$' "$home/operations") == 1 ]]
[[ $(grep -c '^cliphist-decode$' "$home/operations") == 2 ]]
[[ -z $(find "$home/cache/quickshell" -name 'clipboard-preview-*' -print) ]]
printf 'Native expiry sent one fixture notification while the palette was closed.\n'
