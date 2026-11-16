#!/usr/bin/env bash
# The daemon's dictation, offscreen: tests/voxtype-osd.qml drives a real
# VoiceSession through fixture state files with a fake voxtype and audio
# bridge, and checks lib/Dictation.js (which surface each bar mode shows:
# VoxtypeOsd's popup, or the island's dict state) and VoxtypeCard, the popup's
# content. Offscreen Qt has no layer-shell backend, so the window itself is
# only checked for its input policy, on qmlformat's output so the check
# reads the properties and not the file's layout.
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
qs=$(command -v qs)
qmlformat=$(command -v qmlformat6 || command -v qmlformat || command -v /usr/lib/qt6/bin/qmlformat)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT

# The popup must never take the keyboard, a click or screen space: dictation
# types into the focused window.
"$qmlformat" "$root/VoxtypeOsd.qml" > "$tmp/osd.qml"
policy() { grep -Eq "^[[:space:]]*$1[[:space:]]*\$" "$tmp/osd.qml" || { echo "VoxtypeOsd.qml: missing \`$1\`" >&2; exit 1; }; }
policy 'WlrLayershell\.keyboardFocus: WlrKeyboardFocus\.None'
policy 'exclusionMode: ExclusionMode\.Ignore'
policy 'mask: Region \{\}'
policy 'visible: Dictation\.surface\(Dictation\.phase\(voice\), Prefs\.barMode\) === "osd"'

export HOME="$tmp" XDG_CONFIG_HOME="$tmp/config" XDG_STATE_HOME="$tmp/state"
export XDG_DATA_HOME="$tmp/data" XDG_CACHE_HOME="$tmp/cache" XDG_RUNTIME_DIR="$tmp/runtime"
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QPA_PLATFORMTHEME=generic
unset DISPLAY WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE
mkdir -p "$tmp/bin" "$tmp/qml" "$tmp/runtime/voxtype"
chmod 700 "$tmp/runtime"
printf 'idle\n' > "$tmp/runtime/voxtype/state"
cp "$root"/*.qml "$root"/*.js "$tmp/qml/"
# lib/ holds Dictation.js and the scripts Motion.qml and Tokens.qml import; Kit/ is qs.Kit.
cp -R "$root/Commons" "$root/Ui" "$root/launcher" "$root/lib" "$root/Kit" "$tmp/qml/"
cp "$root/tests/voxtype-osd.qml" "$tmp/qml/shell.qml"
cat > "$tmp/bin/voxtype" <<'SH'
#!/bin/sh
case "$*" in
  --version) printf 'voxtype 1.0.1\n' ;;
  'record stop --help') printf '%s\n' '--wait-file' ;;
  *) printf '%s\n' "$*" >> "$HOME/unexpected-commands"; exit 1 ;;
esac
SH
cat > "$tmp/bin/voxtype-audio-bridge" <<'SH'
#!/bin/sh
printf '%s\n' '{"peak":0.3,"rms":0.1,"vad":1,"ts_ms":1}'
exec sleep 10
SH
chmod +x "$tmp/bin/voxtype" "$tmp/bin/voxtype-audio-bridge"
if ! timeout 10 "$qs" --no-color -p "$tmp/qml" > "$tmp/result" 2>&1; then
  tail -30 "$tmp/result"; exit 1
fi
if grep -E 'VOXTYPE_OSD_FAIL|ERROR|ReferenceError|TypeError|Binding loop' "$tmp/result"; then exit 1; fi
grep VOXTYPE_OSD_PASS "$tmp/result"
test ! -e "$tmp/unexpected-commands"
