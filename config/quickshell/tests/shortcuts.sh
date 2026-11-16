#!/usr/bin/env bash
# The control center and calendar shortcuts (Hosts/PanelShortcuts.qml, bound to
# Super+Alt+C and Super+Alt+D in config/hypr/hyprland.lua) and the rounded
# screen corners' IPC (ScreenCorners.qml), run offscreen from a copy of the
# shell with fakes for the islands, bars and palette:
#   - island mode: the focused monitor's island toggles cc or cal (the first
#     island when the focused monitor has none), "error: ..." with no island;
#     over a fullscreen window it raises the island for the panel
#     (IslandView.toggleRaised) rather than open it under the window;
#   - classic modes: the bar's anchored panel; an open palette closes first
#     and the panel opens after it; "error: ..." with no bar;
#   - `corners on|off|toggle|radius N|inspect`: the prefs change and persist,
#     a radius outside 4..48 or not a whole number is refused with the range,
#     a radius change animates to the new one and the strips settle on it,
#     and `drawn` (what the scrim surfaces paint) follows the strips, 0 off;
#   - the surfaces that fill with the scrim paint the corners over it
#     (tests/corner-cover.py: the window switcher, the polkit window, the
#     bars' power menu), handed ScreenCorners by shell.qml;
#   - shell.qml builds both.
# config/hypr/tests/shortcuts.sh checks the binds name these shortcuts.
# Nothing here talks to a compositor (QT_QPA_PLATFORM=offscreen, no
# WAYLAND_DISPLAY, no HYPRLAND_INSTANCE_SIGNATURE); HOME and XDG point into
# a temp dir.
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/home" "$tmp/runtime"
chmod 700 "$tmp/runtime"

for wiring in 'PanelShortcuts {' 'ScreenCorners {' 'paletteHost: launcher'; do
    grep -qF "$wiring" "$root/shell.qml" || { echo "SHORTCUTS_FAIL: shell.qml lacks $wiring" >&2; exit 1; }
done
python3 -B "$root/tests/corner-cover.py" "$root" || { echo "SHORTCUTS_FAIL: a scrim surface would grey the corners" >&2; exit 1; }

# Quickshell resolves `import qs` against the config root: copy the shell and
# put the test in place of shell.qml.
mkdir -p "$tmp/shell"
(cd "$root" && tar --exclude=./tests --exclude=./launcher -cf - .) | tar -xf - -C "$tmp/shell"
cat > "$tmp/shell/shell.qml" <<'QML'
import Quickshell
import QtQuick
import qs
import qs.Hosts

ShellRoot {
    id: test

    component FakeView: QtObject {
        property var calls: []
        property var raisedCalls: []
        function toggle(state) { calls = calls.concat([state]); return "ok"; }
        function toggleRaised(state) { raisedCalls = raisedCalls.concat([state]); return "ok"; }
    }
    component FakeIsland: QtObject {
        property var screen
        property FakeView view: FakeView {}
    }
    component FakeBar: QtObject {
        property var screen
        property FakeView host: FakeView {}
    }
    FakeIsland { id: islandA; screen: ({ name: "A-1" }) }
    FakeIsland { id: islandB; screen: ({ name: "B-1" }) }
    FakeBar { id: barA; screen: ({ name: "A-1" }) }
    FakeBar { id: barB; screen: ({ name: "B-1" }) }
    QtObject {
        id: palette
        property bool opened: false
        property int closes: 0
        function close() { opened = false; closes++; }
    }

    PanelShortcuts { id: panels; paletteHost: palette }
    ScreenCorners { id: corners; windows: false }

    function check(c, m) { if (!c) throw new Error(m); }
    function fail(e) { console.error("SHORTCUTS_FAIL: " + e.message); Qt.quit(); }

    Timer {
        interval: 200
        running: Prefs.loaded
        onTriggered: {
            try {
                // ---- the control center and the calendar ----
                Prefs.setBarMode("island");
                panels.islands = [islandA, islandB];
                panels.focused = "B-1";
                test.check(panels.toggle("cc") === "ok", "island mode answers ok");
                test.check(JSON.stringify(islandB.view.calls) === '["cc"]' && islandA.view.calls.length === 0, "the focused monitor's island opens cc: " + JSON.stringify([islandA.view.calls, islandB.view.calls]));
                panels.toggle("cal");
                test.check(islandB.view.calls[1] === "cal", "and cal");
                // Over a fullscreen window on B-1: raised for the panel, not
                // opened under the window; A-1 has none.
                panels.fullscreenNames = ["B-1"];
                test.check(panels.toggle("cc") === "ok" && JSON.stringify(islandB.view.raisedCalls) === '["cc"]' && islandB.view.calls.length === 2, "over fullscreen the island rises for cc: " + JSON.stringify(islandB.view.raisedCalls));
                panels.toggle("cal");
                test.check(JSON.stringify(islandB.view.raisedCalls) === '["cc","cal"]', "and for cal");
                panels.fullscreenNames = [];
                panels.focused = "NOPE-1";
                panels.toggle("cc");
                test.check(islandA.view.calls[0] === "cc" && islandA.view.raisedCalls.length === 0, "an unknown monitor falls back to the first island");
                panels.islands = [];
                test.check(panels.toggle("cc") === "error: no island window yet", "no island, an error");

                Prefs.setBarMode("pill");
                panels.bars = [barA, barB];
                panels.focused = "A-1";
                test.check(panels.toggle("cal") === "ok", "classic mode answers ok");
                test.check(JSON.stringify(barA.host.calls) === '["cal"]' && barB.host.calls.length === 0, "the focused monitor's bar opens cal");
                test.check(islandA.view.calls.length === 1, "classic mode leaves the islands alone");
                palette.opened = true;
                test.check(panels.toggle("cc") === "ok", "with the palette open: ok");
                test.check(!palette.opened && palette.closes === 1, "the palette closes first");
                test.check(barA.host.calls.length === 1, "and the panel waits for it");
                afterPalette.start();
            } catch (e) { test.fail(e); }
        }
    }
    Timer {
        id: afterPalette
        interval: 50
        onTriggered: {
            try {
                test.check(JSON.stringify(barA.host.calls) === '["cal","cc"]', "then the panel opens: " + JSON.stringify(barA.host.calls));
                panels.bars = [];
                test.check(panels.toggle("cc") === "error: no bar window yet", "no bar, an error");

                // ---- the corners ----
                test.check(Prefs.screenCorners === true && Prefs.screenCornerRadius === 14, "on, 14 px by default");
                const fresh = JSON.parse(corners.ipc.inspect());
                test.check(fresh.on && fresh.radius === 14 && fresh.shown === 14 && !fresh.animating, "inspect: " + JSON.stringify(fresh));
                test.check(corners.drawn === 14, "the scrim surfaces paint 14: " + corners.drawn);
                test.check(JSON.stringify(fresh.range) === "[4,48]" && fresh.strips.length === 0 && fresh.frames === 0, "inspect's range, no windows here: " + JSON.stringify(fresh));
                test.check(corners.ipc.toggle() === "ok: off" && Prefs.screenCorners === false, "toggle turns them off");
                test.check(corners.ipc.toggle() === "ok: on" && Prefs.screenCorners === true, "and on");
                test.check(corners.ipc.off() === "ok" && !Prefs.screenCorners && corners.drawn === 0, "off: the scrim surfaces paint none");
                test.check(corners.ipc.on() === "ok" && Prefs.screenCorners && corners.drawn === 14, "on");
                for (const bad of ["3", "49", "0", "-5", "14.5", "abc", "", "1e1"]) {
                    const said = corners.ipc.radius(bad);
                    test.check(said.indexOf("error: the radius is a whole number from 4 to 48") === 0, "radius " + JSON.stringify(bad) + " refused: " + said);
                }
                test.check(Prefs.screenCornerRadius === 14, "a refused radius changes nothing");
                test.check(corners.ipc.radius("4") === "ok" && corners.ipc.radius("48") === "ok", "4 and 48 are in range");
                // From a settled 48 (hidden corners snap): shrinking to 24.
                corners.ipc.off();
                corners.ipc.radius("30");
                corners.ipc.radius("48");
                corners.ipc.on();
                test.check(corners.shown === 48 && corners.span === 48, "settled at 48: " + corners.shown);
                test.check(corners.ipc.radius(" 24 ") === "ok" && Prefs.screenCornerRadius === 24, "24 (spaces trimmed)");
                const moving = JSON.parse(corners.ipc.inspect());
                test.check(moving.animating && moving.radius === 24, "a radius change animates: " + JSON.stringify(moving));
                test.check(corners.span === 48, "the strips take the larger radius while it runs: " + corners.span);
                test.check(corners.drawn === corners.shown, "the scrim surfaces follow the strips through it: " + corners.drawn + " vs " + corners.shown);
                afterRadius.start();
            } catch (e) { test.fail(e); }
        }
    }
    Timer {
        id: afterRadius
        interval: Motion.spatial + 300
        onTriggered: {
            try {
                const settled = JSON.parse(corners.ipc.inspect());
                test.check(!settled.animating && settled.shown === 24 && corners.span === 24, "and settles on it: " + JSON.stringify(settled) + " span " + corners.span);
                test.check(corners.drawn === 24, "drawn settles on 24 too: " + corners.drawn);
                // Hidden corners snap (above too).
                Prefs.setScreenCorners(false);
                corners.ipc.radius("30");
                test.check(corners.shown === 30 && corners.span === 30 && !JSON.parse(corners.ipc.inspect()).animating, "hidden, a radius change snaps");
                Prefs.setScreenCorners(true);
                corners.ipc.radius("24");
                corners.ipc.off();
                persisted.start();
            } catch (e) { test.fail(e); }
        }
    }
    Timer {
        id: persisted
        interval: 300
        onTriggered: {
            console.log("SHORTCUTS_QML_PASS");
            Qt.quit();
        }
    }
}
QML

out=$(env -i PATH="/usr/bin:/bin" HOME="$tmp/home" XDG_RUNTIME_DIR="$tmp/runtime" XDG_CONFIG_HOME="$tmp/home/.config" \
    XDG_STATE_HOME="$tmp/home/.local/state" XDG_CACHE_HOME="$tmp/home/.cache" XDG_DATA_HOME="$tmp/home/.local/share" \
    SHELL_SANDBOX=1 QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic \
    /usr/bin/timeout 20 "$(command -v qs)" -p "$tmp/shell" --no-color 2>&1) || true
grep -q SHORTCUTS_QML_PASS <<<"$out" || { printf '%s\n' "$out"; echo "SHORTCUTS_FAIL: the QML checks did not pass" >&2; exit 1; }
if grep -E 'SHORTCUTS_FAIL|ReferenceError|TypeError|Failed to load|Binding loop' <<<"$out"; then
    exit 1
fi
# The prefs reached the file (Prefs' capsule.json): corners off, radius 24.
state=$(find "$tmp/home/.local/state" -name capsule.json | head -1)
[[ -n $state ]] || { echo "SHORTCUTS_FAIL: no capsule.json written" >&2; exit 1; }
python3 -B - "$state" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert d.get("screenCorners") is False and d.get("screenCornerRadius") == 24, d
PY
printf 'SHORTCUTS_PASS: Super+Alt+C/D on the focused island or bar, the palette first; corners IPC, range, animation, persistence\n'
