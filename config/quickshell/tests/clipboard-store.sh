#!/usr/bin/env bash
# ClipboardStore (PLAN M5): clipboard history keeps filling with the old
# picker retired. The real ClipboardStore.qml runs offscreen against fake
# wl-paste, cliphist and clipboard-store-video on PATH, with a stand-in for
# the launcher, and must:
#   - start the text, image and video watchers (wl-paste --watch ... store),
#     so what each fake "copies" lands in the fake history;
#   - open the launcher's clipboard scope for `clipboard open/toggle SCREEN`
#     and the Super+V global shortcut (toggleFocused, the focused monitor),
#     and close only that scope;
#   - wipe the history and the decoded media when the scope's confirmed
#     Ctrl+Delete says so (the engine's clipboardWipeConfirmed), then reload
#     the open scope;
#   - start none of them under SHELL_SANDBOX=1.
# Nothing touches the real clipboard or history: PATH holds only the fakes
# and a few coreutils, and HOME/XDG dirs point into a temp dir.
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/shell" "$tmp/bin" "$tmp/home" "$tmp/runtime"
chmod 700 "$tmp/runtime"
cp "$root/ClipboardStore.qml" "$tmp/shell/"

# wl-paste --type T --watch CMD...: "copies" one item of type T into CMD's
# stdin, as the real one does on each clipboard change, then keeps watching.
cat > "$tmp/bin/wl-paste" <<'SH'
#!/bin/sh
type=""
while [ $# -gt 0 ]; do
    case "$1" in
        --type) type="$2"; shift 2 ;;
        --watch) shift; break ;;
        *) shift ;;
    esac
done
case "$type" in
    text) printf 'hello from the clipboard' | "$@" ;;
    image) printf '\211PNG fake image' | CLIPBOARD_STATE=image "$@" ;;
    video) printf 'fake video' | "$@" ;;
esac
exec sleep 30
SH
# cliphist store: one line per stored item in $FAKE_HISTORY.
cat > "$tmp/bin/cliphist" <<'SH'
#!/bin/sh
[ "$1" = wipe ] && { : > "$FAKE_HISTORY.wiped"; exit 0; }
[ "$1" = store ] || exit 1
printf '%s\t%s\n' "${CLIPBOARD_STATE:-text}" "$(cat)" >> "$FAKE_HISTORY"
SH
cat > "$tmp/bin/clipboard-store-video" <<'SH'
#!/bin/sh
printf 'video\t%s\n' "$(cat)" >> "$FAKE_HISTORY"
SH
chmod +x "$tmp/bin/wl-paste" "$tmp/bin/cliphist" "$tmp/bin/clipboard-store-video"
for tool in sh cat sleep printf rm; do
    path=$(command -v "$tool" || true)
    [[ -n $path && $path == /* ]] && ln -s "$path" "$tmp/bin/$tool"
done

cat > "$tmp/shell/shell.qml" <<'QML'
import Quickshell
import QtQuick
ShellRoot {
    id: test
    readonly property bool sandbox: Quickshell.env("SHELL_SANDBOX") === "1"
    // Launcher.qml's shape: launcherHost is the engine.
    QtObject {
        id: launcher
        property var opens: []
        property var launcherHost: QtObject {
            property bool opened: false
            property string scope: ""
            property var targetScreen: null
            property int cancels: 0
            signal clipboardWipeConfirmed()
            function openRoute(route, payload) { launcher.opens = launcher.opens.concat([route]); opened = true; scope = route }
            function cancel() { cancels++; opened = false; scope = "" }
        }
        function targetScreen() { return null }
    }
    ClipboardStore { id: store; launcher: launcher }
    function check(c, m) { if (!c) throw new Error(m) }
    Timer {
        interval: 1500
        running: true
        onTriggered: {
            try {
                const h = launcher.launcherHost;
                if (test.sandbox) {
                    test.check(!store.capturing && !store.watchers.text && !store.watchers.image && !store.watchers.video, "the sandbox starts no watcher");
                    console.log("CLIPBOARD_STORE_SANDBOX_PASS");
                    Qt.quit();
                    return;
                }
                test.check(store.capturing && store.watchers.text && store.watchers.image && store.watchers.video, "all three watchers run: " + JSON.stringify(store.watchers));
                store.open("NOPE-1");
                test.check(launcher.opens.length === 1 && launcher.opens[0] === "clipboard" && store.opened, "open shows the launcher's clipboard scope");
                store.close();
                test.check(!h.opened && h.cancels === 1, "close closes it");
                store.open("NOPE-1");
                h.scope = "applications";
                store.close();
                test.check(h.opened && h.cancels === 1, "close leaves a palette in another scope alone");
                h.cancel();
                // The scope's confirmed Ctrl+Delete: the engine signals, the store wipes.
                store.open("NOPE-1");
                h.clipboardWipeConfirmed();
                afterWipe.start();
                return;
            } catch (e) {
                console.error("CLIPBOARD_STORE_FAIL: " + e.message);
            }
            Qt.quit();
        }
    }
    Timer {
        id: afterWipe
        interval: 1000
        onTriggered: {
            try {
                test.check(launcher.opens.length === 4 && launcher.opens[3] === "clipboard", "the open scope reloads after the wipe: " + launcher.opens);
                launcher.launcherHost.cancel();
                // Super+V (the clipboard-toggle global shortcut): the focused
                // monitor's scope, and a second press closes it.
                test.check(typeof store.toggleFocused === "function", "the store has toggleFocused for the Super+V shortcut");
                store.toggleFocused();
                test.check(store.opened && launcher.launcherHost.opened && launcher.opens.length === 5, "Super+V opens the clipboard scope");
                store.toggleFocused();
                test.check(!store.opened && !launcher.launcherHost.opened, "a second Super+V closes it");
                console.log("CLIPBOARD_STORE_PASS");
            } catch (e) {
                console.error("CLIPBOARD_STORE_FAIL: " + e.message);
            }
            Qt.quit();
        }
    }
}
QML

run() {
    env -i PATH="$tmp/bin" HOME="$tmp/home" XDG_RUNTIME_DIR="$tmp/runtime" XDG_CONFIG_HOME="$tmp/home/.config" \
        XDG_STATE_HOME="$tmp/home/.local/state" XDG_CACHE_HOME="$tmp/home/.cache" XDG_DATA_HOME="$tmp/home/.local/share" \
        FAKE_HISTORY="$tmp/history" QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic "$@" \
        /usr/bin/timeout 15 "$(command -v qs)" -p "$tmp/shell" --no-color 2>&1
}
mkdir -p "$tmp/runtime/quickshell-clipboard-media" "$tmp/home/.cache/cliphist"
: > "$tmp/runtime/quickshell-clipboard-media/7.png"
: > "$tmp/home/.cache/cliphist/media.tsv"
out=$(run)
grep -q CLIPBOARD_STORE_PASS <<<"$out" || { printf '%s\n' "$out"; exit 1; }
[[ -e $tmp/history.wiped && ! -e $tmp/runtime/quickshell-clipboard-media && ! -e $tmp/home/.cache/cliphist/media.tsv ]]
! grep -E 'CLIPBOARD_STORE_FAIL|ReferenceError|TypeError|Failed to load|Binding loop|WARN scene:' <<<"$out"
grep -qx $'text\thello from the clipboard' "$tmp/history"
grep -q $'^image\t' "$tmp/history"
grep -qx $'video\tfake video' "$tmp/history"
[[ $(wc -l < "$tmp/history") == 3 ]]

rm -f "$tmp/history"
out=$(run SHELL_SANDBOX=1)
grep -q CLIPBOARD_STORE_SANDBOX_PASS <<<"$out" || { printf '%s\n' "$out"; exit 1; }
[[ ! -e $tmp/history ]]
printf 'CLIPBOARD_STORE_PASS: text, image and video stored; Super+V scope; Ctrl+Delete wipe; none in the sandbox\n'
