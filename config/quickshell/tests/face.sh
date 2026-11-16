#!/usr/bin/env bash
# The profile picture's file check never touches the lock (PLAN: face).
# lib/FaceModel.js's file check, copy and listing run on real files in
# tests/face-model.cjs. Here lock.qml itself, offscreen (no compositor, so it
# never locks), starts with each kind of bad ~/.face in a scratch HOME:
#
#   none, a 0-byte file, a non-image, a 50 MP image, a symlink loop, a FIFO,
#   a directory, an unreadable file and one over 32 MiB.
#
# What this covers is Face.refresh()'s check (one `sh` on the file) and the
# config load: for every one, lock.qml loads in about the same time as with
# no ~/.face, its only IPC target is still `lock` (secure, inspect), `secure`
# answers false at once, the PAM record is idle, the check ran and let
# through only what it should, and nothing errors. The FIFO would hang a
# reader that opened it: the check never does.
#
# What it does not cover: offscreen there are no lock surfaces, so no card
# and no FacePicture: nothing here decodes ~/.face, `secure` never turns
# true and the lock-in motion never runs. The decode under the lock-in
# motion is tst_lock_surface's (lock.sh: each bad file, the 50 MP one
# included, against the motion's timing, the UI thread's pulse, the field
# and the record), the decode itself tst_face_picture's (kit.sh). The whole
# path through bin/shell-lock with real lock surfaces is the sandbox's
# (.shell-rebuild/specs/shots/face/face-shot.sh lock-bad, outside this repo).
#
# A fake gdbus (tests/fake-logind.sh) keeps the lock's sleep listener off the
# system bus. Keep TMPDIR short (check.sh's note): the IPC socket lives under
# it.
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
pids=()
cleanup() {
    for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done
    chmod -R u+rwX "$tmp" 2>/dev/null || true
    rm -rf -- "$tmp"
}
trap cleanup EXIT
fail() {
    echo "FACE_TEST_FAIL: $*" >&2
    exit 1
}

node "$root/tests/face-model.cjs"

bash "$root/tests/fake-logind.sh" "$tmp/bin"
img="$tmp/img"
python3 -B "$root/tests/face-images.py" "$img" --big
cfg="$tmp/cfg"
cp -R "$root" "$cfg"
rm -rf "$cfg/tests"
qml="$cfg/lock.qml"
rt="$tmp/rt"
mkdir -p "$rt"
chmod 700 "$rt"
errors='ReferenceError|TypeError|Failed to load|Binding loop|Required property|is not a type|Cannot assign|Unable to assign|insufficiently annotated'

# make_home CASE: a scratch home whose ~/.face is that case.
make_home() {
    local h="$tmp/home-$1"
    mkdir -p "$h"
    case $1 in
    none) ;;
    empty) : >"$h/.face" ;;
    text) cp "$img/text.png" "$h/.face" ;;
    big) cp "$img/big.png" "$h/.face" ;;
    loop) ln -s .face2 "$h/.face" && ln -s .face "$h/.face2" ;;
    fifo) mkfifo "$h/.face" ;;
    dir) mkdir "$h/.face" ;;
    unreadable) cp "$img/face.png" "$h/.face" && chmod 000 "$h/.face" ;;
    large) : >"$h/.face" && truncate -s 33M "$h/.face" ;;
    good) cp "$img/face.png" "$h/.face" ;;
    esac
    printf '%s\n' "$h"
}

# The sources each case lets through to the decode: ~/.face's, plus the
# machine's own AccountsService icon when it has one (outside the sandbox
# the lock reads the real /var/lib/AccountsService/icons/$USER).
declare -A want=([none]=0 [empty]=0 [text]=1 [big]=1 [loop]=0 [fifo]=0 [dir]=0 [unreadable]=0 [large]=0 [good]=1)
[ "$(id -u)" = 0 ] && want[unreadable]=1
icon="/var/lib/AccountsService/icons/${USER:-$(id -un)}"
if [ -f "$icon" ] && [ -r "$icon" ] && [ -s "$icon" ]; then
    for k in "${!want[@]}"; do want[$k]=$((want[$k] + 1)); done
fi

base=""
for c in none good empty text big loop fifo dir unreadable large; do
    h=$(make_home "$c")
    log="$tmp/$c.log"
    t0=$(date +%s%N)
    env -u WAYLAND_DISPLAY -u DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE -u SHELL_SANDBOX -u SBX_RUNTIME \
        HOME="$h" PATH="$tmp/bin:$PATH" XDG_RUNTIME_DIR="$rt" XDG_STATE_HOME="$tmp/state" XDG_CACHE_HOME="$tmp/cache" \
        QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic \
        qs -n -p "$qml" --no-color >"$log" 2>&1 &
    pid=$!
    pids+=("$pid")
    for _ in $(seq 1 100); do
        grep -q 'Configuration Loaded' "$log" && break
        grep -q 'Failed to load' "$log" && break
        sleep 0.05
    done
    grep -q 'Configuration Loaded' "$log" || { cat "$log" >&2; fail "$c: lock.qml did not load"; }
    loaded=$(( ($(date +%s%N) - t0) / 1000000 ))
    ipc() { env -u WAYLAND_DISPLAY XDG_RUNTIME_DIR="$rt" HOME="$h" QT_QPA_PLATFORM=offscreen qs ipc --pid "$pid" "$@"; }
    s0=$(date +%s%N)
    secure=$(ipc call lock secure)
    answered=$(( ($(date +%s%N) - s0) / 1000000 ))
    [ "$secure" = false ] || fail "$c: secure answered $secure"
    ipc show >"$tmp/$c.show"
    [ "$(grep -c '^target ' "$tmp/$c.show")" = 1 ] && grep -qx 'target lock' "$tmp/$c.show" || fail "$c: one IPC target, lock: $(cat "$tmp/$c.show")"
    verbs=$(grep -E '^\s+function' "$tmp/$c.show" | sed -E 's/^\s+function ([a-zA-Z]+).*/\1/' | sort | tr '\n' ' ')
    [ "$verbs" = "inspect secure " ] || fail "$c: lock answers secure and inspect only: $verbs"
    # The check is one `sh`; give it a moment, then read what it let through.
    inspect=""
    for _ in $(seq 1 40); do
        inspect=$(ipc call lock inspect)
        grep -q '"checked":true' <<<"$inspect" && break
        sleep 0.05
    done
    grep -q '"checked":true' <<<"$inspect" || fail "$c: the face check never finished: $inspect"
    grep -q '"phase":"idle"' <<<"$inspect" || fail "$c: the PAM record moved: $inspect"
    grep -q '"locked":false' <<<"$inspect" || fail "$c: offscreen, never locked: $inspect"
    n=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["face"]["sources"])' "$inspect")
    [ "$n" = "${want[$c]}" ] || fail "$c: $n sources let through, want ${want[$c]}: $inspect"
    sleep 0.3
    kill "$pid"
    wait "$pid" 2>/dev/null || true
    pids=()
    if grep -E "$errors" "$log"; then fail "$c: lock.qml logged errors"; fi
    grep -q 'Cannot start session lock' "$log" || fail "$c: the session lock should refuse to start offscreen"
    [ -z "$base" ] && base=$loaded
    echo "face: $c: loaded in ${loaded} ms (none: ${base} ms), secure answered in ${answered} ms, ${n} source(s)"
    # A loaded machine can be slow; a reader stuck on ~/.face would never load.
    [ "$loaded" -le $((base + 2500)) ] || fail "$c: loading took ${loaded} ms against ${base} ms with no ~/.face"
done
echo FACE_TEST_PASS
