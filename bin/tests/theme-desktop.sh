#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home" XDG_DATA_HOME="$TMP/data" QS_CALLS="$TMP/qs-calls"
mkdir -p "$HOME" "$TMP/main checkout/bin" "$TMP/trial checkout/bin" "$TMP/stubs"
cp "$ROOT/bin/theme" "$TMP/main checkout/bin/"
# Generate the launchers from a disposable checkout without applying a theme.
awk '
  /^case "\$\{1:-\}" in$/ {
    print "ensure_desktop_entries"
    print "exit 0"
  }
  { print }
' "$ROOT/bin/theme" >"$TMP/trial checkout/bin/theme"
bash "$TMP/trial checkout/bin/theme"
rm -rf "$TMP/trial checkout"

# Use the real picker CLI, but never open the live desktop overlay.
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >>"$QS_CALLS"\n' >"$TMP/stubs/qs"
chmod +x "$TMP/stubs/qs"
export PATH="$TMP/main checkout/bin:$TMP/stubs:$PATH"
python3 - <<'PY'
import os
from pathlib import Path
import shlex
import subprocess

applications = Path(os.environ['XDG_DATA_HOME']) / 'applications'
for name, kind in [('theme-picker', 'themes'), ('theme-wallpaper', 'backgrounds')]:
    lines = (applications / f'{name}.desktop').read_text().splitlines()
    command = next(line[5:] for line in lines if line.startswith('Exec='))
    argv = shlex.split(command)
    assert argv == ['theme', 'picker', kind], f'{name}: checkout-specific command: {command}'
    subprocess.run(argv, check=True)
assert Path(os.environ['QS_CALLS']).read_text().splitlines() == [
    'ipc call picker open themes',
    'ipc call picker open backgrounds',
]
PY
printf 'THEME_DESKTOP_PASS\n'
