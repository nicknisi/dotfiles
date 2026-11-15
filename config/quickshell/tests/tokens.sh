#!/usr/bin/env bash
# Tokens.qml and lib/TokenMath.js under qmltestrunner (tests/tst_tokens.qml).
# check.sh runs tests/token-parity.cjs (TokenMath against bin/theme-color for
# every pack) beside it.
#
# qmltestrunner cannot load Quickshell, so the real Tokens.qml sits beside stub
# Theme and Motion singletons. Tokens reads exactly Theme.palette,
# Motion.effects and Motion.spring; the test writes effects to time the fade.
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/lib"
cp "$root/Tokens.qml" "$root/tests/tst_tokens.qml" "$tmp/"
cp "$root/lib/TokenMath.js" "$tmp/lib/"
printf 'singleton Theme 1.0 Theme.qml\nsingleton Motion 1.0 Motion.qml\nsingleton Tokens 1.0 Tokens.qml\n' >"$tmp/qmldir"
cat >"$tmp/Theme.qml" <<'QML'
pragma Singleton
import QtQuick
QtObject { property var palette: ({}) }
QML
cat >"$tmp/Motion.qml" <<'QML'
pragma Singleton
import QtQuick
QtObject {
    property int effects: 0
    property var spring: [0.30, 0.553, 0.06, 1.0, 1, 1]
}
QML
runner=$(command -v qmltestrunner || printf /usr/lib/qt6/bin/qmltestrunner)
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic \
    timeout -k 5 60 "$runner" -input "$tmp/tst_tokens.qml" 2>&1 | tee "$tmp/result"
grep -qE '^Totals: [0-9]+ passed, 0 failed' "$tmp/result"
# `! grep` would not stop the script here (set -e ignores a negated command).
if grep -E 'ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|is not a type|is not defined|Received signal' "$tmp/result"; then
    echo "TOKENS_TEST_FAIL: qmltestrunner logged errors" >&2
    exit 1
fi

printf 'TOKENS_TEST_PASS\n'
