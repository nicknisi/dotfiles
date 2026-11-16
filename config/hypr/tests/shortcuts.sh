#!/usr/bin/env bash
# The shell's keys are global shortcuts (shortcuts.lua says what it checks).
# This collects the name of every GlobalShortcut with appid "quickshell" in
# config/quickshell's QML for it. Linux only (check.sh); nothing here binds,
# dispatches or talks to a compositor.
set -euo pipefail
here=$(cd -- "$(dirname -- "$0")/.." && pwd)
qml=$(cd -- "$here/../quickshell" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
python3 -B - "$qml" >"$tmp/names" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
block = re.compile(r"\bGlobalShortcut\s*\{([^{}]*)\}", re.S)
for path in sorted(root.rglob("*.qml")):
    if "tests" in path.relative_to(root).parts:
        continue
    for body in block.findall(path.read_text()):
        appid = re.search(r'\bappid:\s*"([^"]*)"', body)
        name = re.search(r'\bname:\s*"([^"]*)"', body)
        if appid and name and appid.group(1) == "quickshell":
            print(name.group(1))
PY
[ -s "$tmp/names" ] || { echo "HYPR_SHORTCUTS_FAIL: no GlobalShortcut found under $qml" >&2; exit 1; }
luajit "$here/tests/shortcuts.lua" "$here/hyprland.lua" "$tmp/names"
