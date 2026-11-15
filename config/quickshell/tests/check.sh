#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT

luajit "$root/../hypr/tests/style.lua" "$root/../hypr/hyprland.lua" "$root/../../themes/"*/hyprland.lua
# The Copilot key's latch resets when the island's Stop ends dictation (M3 review).
(cd "$root/../.." && luajit config/hypr/tests/copilot.lua)
bash "$root/tests/menu-keys.sh"
bash "$root/tests/bar-drag.sh"
bash "$root/launcher/tests/check.sh"
bash "$root/tests/voxtype-osd.sh"
node "$root/tests/clipboard-model.cjs"
node "$root/tests/window-switcher-model.cjs"
python3 -B "$root/tests/battery-top-up.py"
python3 -B "$root/tests/audio-hotplug.py"
"$root/tests/net.sh"
# Island shell foundation (PLAN M0): tokens, motion, Kit, services.
bash "$root/tests/tokens.sh"
node "$root/tests/token-parity.cjs"
# tst_spring, tst_kit, then the Lucide icon provenance check. That one reads
# lucide-static from $XDG_CACHE_HOME/quickshell-tests (downloaded once);
# QS_TESTS_OFFLINE=1 lets it pass with a SKIP line when neither is available.
bash "$root/tests/kit.sh" ${QS_TESTS_OFFLINE:+--offline-ok}
bash "$root/tests/services.sh"
# Island capsule (PLAN M1): the focus shapes, the state machine, the workspace
# order, and lib/Celestial.js still matching its generator and shapes.luau.
# tst_workspace_strip runs inside kit.sh above.
node "$root/tests/celestial.cjs"
node "$root/tests/island-machine.cjs"
node "$root/tests/workspace-order.cjs"
python3 -B "$root/tools/gen-celestial.py" --check
# The Crew (PLAN M2): the model, the Linux agent scan and the jump helper.
# tst_pixel_sprite runs inside kit.sh above.
node "$root/tests/crew-model.cjs"
python3 -B "$root/../../bin/tests/omniwm-agents.py"
python3 -B "$root/../../bin/tests/crew-jump.py"
# The island's own states (PLAN M3): the calendar grid. The machine's
# priority, queue and return run in island-machine.cjs above, dictation's
# routing in voxtype-osd.sh, and the states themselves, the Context lane and
# the notification timeouts in check.qml below.
node "$root/tests/calendar.cjs"
# The launcher restyle (PLAN M5): clipboard history keeps filling with the old
# picker gone (ClipboardStore against fake wl-paste and cliphist). Match
# ranges, clipboard metadata and the Colors contrast row are qmltests in
# launcher/tests (check.sh above); the island and panel hosts run in check.qml.
bash "$root/tests/clipboard-store.sh"

formatter=$(command -v qmlformat || printf /usr/lib/qt6/bin/qmlformat)
for file in "$root"/*.qml "$root"/Kit/*.qml "$root"/Island/*.qml; do
    "$formatter" "$file" >/dev/null
done
# Singletons may import a sibling .js, so those ride along with the .qml.
cp "$root"/*.qml "$tmp/"
cp "$root/battery-top-up.py" "$tmp/"
cp "$root"/*.js "$tmp/" 2>/dev/null || true
# lib/ holds the scripts Motion.qml and Tokens.qml import; Kit/ is qs.Kit and
# Island/ is qs.Island.
cp -R "$root/assets" "$root/launcher" "$root/Commons" "$root/Ui" "$root/lib" "$root/Kit" "$root/Island" "$tmp/"
cp "$root/tests/check.qml" "$tmp/shell.qml"
# SHELL_CREW=off: the Crew singleton polls no fleet or /proc and runs no jump.
# About 10 s: the M3 check's fifteen beats (600 ms each) hold the final check.
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen SHELL_CREW=off timeout 15 qs -p "$tmp" --no-color 2>&1 | tee "$tmp/result"
grep -q CAPSULE_TEST_PASS "$tmp/result"
# Prefs writes capsule.json on first load, after FileView reports that it is absent.
! grep -E 'CAPSULE_TEST_FAIL|ReferenceError|TypeError|Failed to load|Binding loop|Required property|WARN scene:' "$tmp/result" \
    | grep -qv 'QML FileView.*capsule.json failed: File does not exist'
