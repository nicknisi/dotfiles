#!/usr/bin/env bash
# The lock screen and the polkit prompt (PLAN M8).
#
#   1. lib/LockMachine.js against a fake PamContext (tests/lock-machine.cjs):
#      Success, Failed, MaxTries, Error, timeouts, stray signals; the buffer
#      cleared on every exit.
#   2. Source rules: the leaves stay free of Quickshell; lock.qml unlocks in
#      one place and never on destruction; nothing in the lock logs the
#      password, captures the screen, watches files or reads the clipboard
#      (no paste on the lock); hyprland.lua turns on
#      misc:allow_session_lock_restore (PLAN DECISION 4) and lock.qml marks a
#      real unlock for bin/shell-lock's watcher; the lock content starts out
#      (shown false) so the lock-in motion runs.
#   3. qmltestrunner: tst_auth_card, tst_lock_surface, tst_polkit (the polkit
#      prompt against Island/FixtureAuthFlow.qml).
#   4. The real PamContext, offscreen, against test PAM stacks
#      (tests/lock-pam.qml, tests/lock-pam-stacks.sh): never /etc/pam.d, never
#      the real password, and the test password never in the log.
#   5. lock.qml run by file path, offscreen (no compositor, so it never
#      locks): it loads its singletons; its only IPC target is `lock` with
#      `secure` (false here) and `inspect`; no verb anywhere unlocks; the
#      sandbox-only overrides (test PAM stack, `lockpose`) are ignored unless
#      SHELL_SANDBOX=1 and SBX_RUNTIME is this XDG_RUNTIME_DIR.
#   6. bin/shell-lock against a fake qs and hyprlock (bin/tests/shell-lock.sh).
#
# Every Quickshell here runs offscreen with its own XDG_RUNTIME_DIR, no
# WAYLAND_DISPLAY and no HYPRLAND_INSTANCE_SIGNATURE: nothing reaches the live
# session. Keep TMPDIR short (check.sh's note): the IPC socket lives under it.
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
pids=()
cleanup() {
    for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done
    rm -rf -- "$tmp"
}
trap cleanup EXIT
fail() {
    echo "LOCK_TEST_FAIL: $*" >&2
    exit 1
}

# ---- 1 ---------------------------------------------------------------------------
node "$root/tests/lock-machine.cjs"

# ---- 2 ---------------------------------------------------------------------------
leaves=("$root"/Lock/{AuthCard,LockButton,MediaPill,StatusPill,LockSurface}.qml "$root"/Island/{PolkitLayer,FixtureAuthFlow,PowerLayer}.qml "$root/Kit/SecretField.qml")
if grep -nE '^\s*import\s+Quickshell' "${leaves[@]}"; then
    fail "lock and polkit leaves must not import Quickshell"
fi
lockfiles=("$root/lock.qml" "$root"/Lock/*.qml "$root/lib/LockMachine.js")
n=$(grep -c 'lock\.locked = false' "$root/lock.qml" || true)
[ "$n" = 1 ] || fail "lock.qml must set locked = false in exactly one place (found $n)"
grep -B12 'lock\.locked = false' "$root/lock.qml" | grep -q 'lockAuth\.unlocking' || fail "the one unlock must sit behind lockAuth.unlocking"
if grep -nE '\.unlock\(\)|locked:\s*false|locked\s*=\s*!|unlockexp' "${lockfiles[@]}"; then
    fail "no other way to unlock"
fi
if grep -nE 'onDestruction[^\n]*(locked|unlock)' "${lockfiles[@]}"; then
    fail "never unlock on destruction"
fi
grep -q 'settings.watchFiles: false' "$root/lock.qml" || fail "lock.qml must not watch files"
if grep -nE 'console\.[a-z]+\(.*(buffer|password|secret|respon|auth\.m\b|\.m\.)' "${lockfiles[@]}" "$root/Island/PolkitLayer.qml"; then
    fail "never log the password or the record"
fi
if grep -n 'console\.' "$root/lib/LockMachine.js"; then
    fail "LockMachine.js logs nothing"
fi
if grep -nE 'ScreencopyView|grabToImage|"grim"|Screencopy' "${lockfiles[@]}"; then
    fail "the lock never captures the screen"
fi
# No paste (M8 review): a password left in the clipboard would unlock for
# anyone at the keyboard.
if grep -nE 'clipboardText|pasteRequested|wl-paste' "${lockfiles[@]}" "$root/Kit/SecretField.qml"; then
    fail "the lock never reads the clipboard and the secret field never pastes"
fi
# PLAN DECISION 4: a crashed lock can be relaunched (shell-lock's watcher).
grep -qE '^\s*allow_session_lock_restore = true,' "$root/../hypr/hyprland.lua" || fail "hyprland.lua sets misc:allow_session_lock_restore = true (PLAN DECISION 4)"
grep -q 'SHELL_LOCK_DONE' "$root/lock.qml" || fail "lock.qml marks a real unlock for shell-lock's watcher"
n=$(grep -c 'root\.markUnlocked()' "$root/lock.qml" || true)
[ "$n" = 1 ] || fail "lock.qml marks the unlock in one place, after the one unlock (found $n)"
grep -A3 'lock\.locked = false' "$root/lock.qml" | grep -q 'root\.markUnlocked()' || fail "the unlock mark follows the one unlock"
# The lock-in motion (M8 review): the content is never built shown.
grep -qE '^\s*property bool shown: false$' "$root/lock.qml" || fail "lock.qml starts with shown false, so the lock-in motion runs"
if grep -nE 'shown:\s*true' "$root/lock.qml"; then fail "nothing in lock.qml is built shown"; fi
grep -q 'lock_cmd = shell-lock || hyprlock' "$root/../hypr/hypridle.conf" || fail "hypridle runs shell-lock, hyprlock as fallback"
grep -q 'inhibit_sleep = 3' "$root/../hypr/hypridle.conf" || fail "hypridle waits for the lock before sleep"
grep -q 'on_unlock_cmd = shell-lock --unlocked' "$root/../hypr/hypridle.conf" || fail "hypridle ends displaced lock instances on every unlock"

# ---- 3 ---------------------------------------------------------------------------
qs="$tmp/qs"
mkdir -p "$qs/lib" "$qs/Kit" "$qs/Island" "$qs/Lock" "$qs/tests"
cp "$root/Motion.qml" "$qs/"
cp "$root/lib/Spring.js" "$root/lib/LockMachine.js" "$qs/lib/"
cp "$root"/Kit/*.qml "$root"/Kit/*.js "$qs/Kit/"
cp "$root"/Island/{PowerLayer,PolkitLayer,FixtureAuthFlow}.qml "$qs/Island/"
cp "$root"/Lock/{AuthCard,LockButton,MediaPill,StatusPill,LockSurface}.qml "$qs/Lock/"
cp "$root"/tests/{tst_auth_card,tst_lock_surface,tst_polkit}.qml "$qs/tests/"
cat > "$qs/qmldir" <<'EOF'
module qs
singleton Tokens 1.0 Tokens.qml
singleton Motion 1.0 Motion.qml
singleton Prefs 1.0 Prefs.qml
EOF
for dir in Kit Island Lock; do
    {
        echo "module qs.$dir"
        for f in "$qs/$dir"/*.qml; do
            n=$(basename "$f" .qml)
            echo "$n 1.0 $n.qml"
        done
    } > "$qs/$dir/qmldir"
done
cat > "$qs/Prefs.qml" <<'QML'
pragma Singleton
import QtQuick
QtObject {
    property string motion: "spring"
    property bool reducedMotion: false
}
QML
# hackerman, main-tokens.md 1.4 (panels.sh's stub).
cat > "$qs/Tokens.qml" <<'QML'
pragma Singleton
import QtQuick
QtObject {
    property color bg: "#0b0c16"
    property color fg: "#ddf7ff"
    readonly property color ink: fg
    property color accent: "#82fb9c"
    property color surface: "#13151f"
    property color raised: "#1c1f29"
    property color overlay: "#242832"
    property color hairline: "#2f353e"
    property color fillLow: "#1f232c"
    property color fillHigh: "#2d323c"
    property color inkDim: "#8d9ea6"
    property color inkMid: "#78868f"
    property color faint: "#5a646d"
    property color accentTint: "#253a33"
    // Bound after creation: Qt drops an initializer on an on<Capital> name.
    property color onAccent
    property color onFg
    Component.onCompleted: {
        onAccent = "#0b0c16";
        onFg = "#0b0c16";
    }
    property color bad: "#ff6b6b"
    property color darker: "#06060c"
    readonly property color scrim: Qt.rgba(11 / 255, 12 / 255, 22 / 255, 0.56)
    readonly property color shadow: Qt.rgba(0, 0, 0, 0.45)
}
QML
runner=$(command -v qmltestrunner || printf /usr/lib/qt6/bin/qmltestrunner)
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic \
    timeout -k 5 90 "$runner" -import "$tmp" -input "$qs/tests" 2>&1 | tee "$tmp/result"
grep -qE '^Totals: [0-9]+ passed, 0 failed' "$tmp/result" || fail "qmltestrunner"
if grep -E 'ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|is not a type|is not defined|Icon: no icon named|Received signal|insufficiently annotated' "$tmp/result"; then
    fail "qmltestrunner logged errors"
fi

# ---- the offscreen Quickshell env ---------------------------------------------------
rt="$tmp/rt"
mkdir -p "$rt"
chmod 700 "$rt"
offscreen_env=(env -u WAYLAND_DISPLAY -u DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE -u SHELL_SANDBOX -u SBX_RUNTIME
    XDG_RUNTIME_DIR="$rt" XDG_STATE_HOME="$tmp/state" QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic)
offscreen() { "${offscreen_env[@]}" "$@"; }
errors='ReferenceError|TypeError|Failed to load|Binding loop|Required property|is not a type|Cannot assign|Unable to assign|insufficiently annotated'

# ---- 4 ---------------------------------------------------------------------------
pam="$tmp/pam"
secret=$(bash "$root/tests/lock-pam-stacks.sh" "$pam")
pamcfg="$tmp/pamcfg"
mkdir -p "$pamcfg/Lock" "$pamcfg/lib"
cp "$root/Lock/LockAuth.qml" "$pamcfg/Lock/"
cp "$root/lib/LockMachine.js" "$pamcfg/lib/"
cp "$root/tests/lock-pam.qml" "$pamcfg/shell.qml"
offscreen LOCK_PAM_DIR="$pam" LOCK_PAM_SECRET="$secret" timeout 40 qs -p "$pamcfg" --no-color >"$tmp/pam.log" 2>&1 || true
grep 'LOCK_PAM_' "$tmp/pam.log"
grep -q LOCK_PAM_PASS "$tmp/pam.log" || { tail -20 "$tmp/pam.log" >&2; fail "real PamContext against the test stacks"; }
if grep -E "$errors" "$tmp/pam.log"; then fail "lock-pam.qml logged errors"; fi
if grep -qF -- "$secret" "$tmp/pam.log"; then fail "the test password reached the log"; fi
for f in "$rt"/quickshell/by-id/*/log.qslog; do
    [ -f "$f" ] && grep -qaF -- "$secret" "$f" && fail "the test password reached Quickshell's log file"
done

# ---- 5 ---------------------------------------------------------------------------
cfg="$tmp/cfg"
cp -R "$root" "$cfg"
rm -rf "$cfg/tests"
qml="$cfg/lock.qml"

# start NAME ENV...: run lock.qml in the background until it has loaded.
start() {
    local name=$1
    shift
    # env directly, not the function: $! must be qs itself.
    "${offscreen_env[@]}" "$@" qs -n -p "$qml" --no-color >"$tmp/$name.log" 2>&1 &
    pids+=($!)
    for _ in $(seq 1 60); do
        grep -q 'Configuration Loaded' "$tmp/$name.log" && break
        grep -q 'Failed to load' "$tmp/$name.log" && break
        sleep 0.2
    done
    grep -q 'Configuration Loaded' "$tmp/$name.log" || { cat "$tmp/$name.log" >&2; fail "lock.qml did not load ($name)"; }
    sleep 0.5
}
stop() {
    for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done
    for p in "${pids[@]}"; do wait "$p" 2>/dev/null || true; done
    pids=()
}
ipc() { offscreen "$@"; }

# Outside the sandbox, with every sandbox override set except the guard's.
start plain SHELL_SANDBOX=1 SHELL_LOCK_PAM_DIR="$pam" SHELL_LOCK_PAM_CONFIG=t-pass
ipc qs ipc -p "$qml" show >"$tmp/show.txt"
cat "$tmp/show.txt"
[ "$(grep -c '^target ' "$tmp/show.txt")" = 1 ] && grep -qx 'target lock' "$tmp/show.txt" || fail "one IPC target, lock"
grep -E '^\s+function' "$tmp/show.txt" | sed -E 's/^\s+function ([a-zA-Z]+).*/\1/' | sort | tr '\n' ' ' >"$tmp/verbs.txt"
[ "$(cat "$tmp/verbs.txt")" = "inspect secure " ] || fail "lock answers secure and inspect only: $(cat "$tmp/verbs.txt")"
if grep -qi 'unlock' "$tmp/show.txt"; then fail "no IPC verb unlocks"; fi
[ "$(ipc qs ipc -p "$qml" call lock secure)" = false ] || fail "offscreen, the lock is never secure"
inspect=$(ipc qs ipc -p "$qml" call lock inspect)
echo "$inspect"
echo "$inspect" | grep -q '"sandbox":false' || fail "SHELL_SANDBOX=1 alone is not the sandbox"
echo "$inspect" | grep -q '"config":"hyprlock"' || fail "outside the sandbox PAM is hyprlock: $inspect"
echo "$inspect" | grep -q '"sandboxDir":false' || fail "outside the sandbox PAM reads /etc/pam.d"
echo "$inspect" | grep -q '"typed":-1' || fail "inspect reports no typing outside the sandbox"
echo "$inspect" | grep -q '"parts":null' || fail "inspect reports no part geometry (with the bullet count) outside the sandbox"
echo "$inspect" | grep -q '"barMode":""' || fail "no main shell prefs: no bar mode (the island's spring): $inspect"
echo "$inspect" | grep -q '"fromIsland":true,' || fail "no main shell prefs: the capsule springs from the island: $inspect"
if ipc qs ipc -p "$qml" call lockpose pose '{}' 2>&1 | grep -q '^ok'; then fail "lockpose answers outside the sandbox"; fi
stop
grep -q 'Cannot start session lock' "$tmp/plain.log" || fail "offscreen, the session lock should refuse to start"
if grep -E "$errors" "$tmp/plain.log"; then fail "lock.qml logged errors"; fi

# The main shell's Prefs, where Quickshell keeps them for <cfg>/shell.qml:
# in pill mode the capsule fades in place rather than springing from the
# island's 360 (M10).
prefs="$tmp/state/quickshell/by-shell/$(printf '%s' "$cfg/shell.qml" | md5sum | cut -d' ' -f1)"
mkdir -p "$prefs"
printf '{"barMode": "pill", "edge": "top"}\n' >"$prefs/capsule.json"
# Inside the sandbox guard: the overrides apply, and lockpose draws only.
start sandbox SHELL_SANDBOX=1 SBX_RUNTIME="$rt" SHELL_LOCK_PAM_DIR="$pam" SHELL_LOCK_PAM_CONFIG=t-pass
ipc qs ipc -p "$qml" show >"$tmp/show2.txt"
grep -qx 'target lockpose' "$tmp/show2.txt" || fail "lockpose in the sandbox"
if grep -qi 'unlock' "$tmp/show2.txt"; then fail "no IPC verb unlocks, even in the sandbox"; fi
inspect=$(ipc qs ipc -p "$qml" call lock inspect)
echo "$inspect" | grep -q '"sandbox":true' || fail "the sandbox guard: $inspect"
echo "$inspect" | grep -q '"config":"t-pass"' && echo "$inspect" | grep -q '"sandboxDir":true' || fail "the test PAM stack in the sandbox: $inspect"
echo "$inspect" | grep -q '"barMode":"pill"' || fail "lock.qml reads the main shell's bar mode: $inspect"
echo "$inspect" | grep -q '"fromIsland":false,' || fail "in pill the capsule fades in place: $inspect"
[ "$(ipc qs ipc -p "$qml" call lockpose pose '{"auth":{"phase":"unlocking"}}')" = ok ] || fail "lockpose pose"
sleep 0.5
inspect=$(ipc qs ipc -p "$qml" call lock inspect)
echo "$inspect" | grep -q '"phase":"idle"' || fail "a pose never moves the real record: $inspect"
[ "$(ipc qs ipc -p "$qml" call lock secure)" = false ] || fail "still not secure"
stop
if grep -E "$errors" "$tmp/sandbox.log"; then fail "lock.qml logged errors (sandbox)"; fi

# ---- 6 ---------------------------------------------------------------------------
bash "$root/../../bin/tests/shell-lock.sh"

echo LOCK_TEST_PASS
