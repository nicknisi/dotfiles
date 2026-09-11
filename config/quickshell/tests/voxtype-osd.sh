#!/usr/bin/env bash
# Fixture state/audio only. Offscreen Qt has no layer-shell backend.
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
qs=$(command -v qs)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
export HOME="$tmp" XDG_CONFIG_HOME="$tmp/config" XDG_STATE_HOME="$tmp/state"
export XDG_DATA_HOME="$tmp/data" XDG_CACHE_HOME="$tmp/cache" XDG_RUNTIME_DIR="$tmp/runtime"
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software
unset DISPLAY WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE
mkdir -p "$tmp/bin" "$tmp/qml" "$tmp/runtime/voxtype"
chmod 700 "$tmp/runtime"
printf 'idle\n' > "$tmp/runtime/voxtype/state"
cp "$root"/*.qml "$root"/*.js "$tmp/qml/"
cp -R "$root/Commons" "$root/Ui" "$root/launcher" "$tmp/qml/"
cp "$root/tests/voxtype-osd.qml" "$tmp/qml/shell.qml"
# Guard the native input policy, then test the content in a regular window.
grep -qF 'WlrLayershell.keyboardFocus: WlrKeyboardFocus.None' "$root/VoxtypeOsd.qml"
grep -qF 'exclusionMode: ExclusionMode.Ignore' "$root/VoxtypeOsd.qml"
awk '
  /^PanelWindow \{/ { print "FloatingWindow {"; next }
  /^    (anchors\.bottom|margins\.bottom|exclusionMode|WlrLayershell\.)/ { next }
  { print }
' "$root/VoxtypeOsd.qml" > "$tmp/qml/VoxtypeOsd.qml"
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
