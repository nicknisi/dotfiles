#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"

cat >"$TMP/bin/cliphist" <<'EOF'
#!/usr/bin/env bash
[[ $1 == decode && $2 == 42 ]]
printf media
EOF
cat >"$TMP/bin/wl-copy" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$CLIPBOARD_PASTE_COPY_ARGS"
cat >"$CLIPBOARD_PASTE_COPY_DATA"
EOF
cat >"$TMP/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
if [[ $1 == activewindow ]]; then
  printf '{}\n'
else
  printf '%s\n' "$*" >"$CLIPBOARD_PASTE_DISPATCH"
fi
EOF
cat >"$TMP/bin/jq" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
printf '%s\n' "$CLIPBOARD_PASTE_CLASS"
EOF
cat >"$TMP/bin/wtype" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$1" >"$CLIPBOARD_PASTE_TYPED"
EOF
chmod +x "$TMP/bin"/*

export PATH="$TMP/bin:$PATH"
export CLIPBOARD_PASTE_COPY_ARGS="$TMP/copy.args"
export CLIPBOARD_PASTE_COPY_DATA="$TMP/copy.data"
export CLIPBOARD_PASTE_DISPATCH="$TMP/dispatch"
export CLIPBOARD_PASTE_TYPED="$TMP/typed"

export CLIPBOARD_PASTE_CLASS=com.mitchellh.ghostty
media="$TMP/cache/42.png"
"$ROOT/bin/clipboard-paste" 42 image/png "$media"
[[ $(<"$media") == media && $(<"$CLIPBOARD_PASTE_COPY_DATA") == media ]]
[[ $(<"$CLIPBOARD_PASTE_COPY_ARGS") == "--type image/png" ]]
[[ $(<"$CLIPBOARD_PASTE_TYPED") == "$media" && ! -e $CLIPBOARD_PASTE_DISPATCH ]]

rm -f "$CLIPBOARD_PASTE_TYPED"
"$ROOT/bin/clipboard-paste" 42 "" ""
grep -q 'mods = "CTRL SHIFT"' "$CLIPBOARD_PASTE_DISPATCH"

rm -f "$CLIPBOARD_PASTE_DISPATCH"
export CLIPBOARD_PASTE_CLASS=org.gnome.Nautilus
"$ROOT/bin/clipboard-paste" 42 image/png "$media"
[[ $(<"$CLIPBOARD_PASTE_COPY_ARGS") == "--type x-special/gnome-copied-files" ]]
[[ $(<"$CLIPBOARD_PASTE_COPY_DATA") == $'copy\nfile://'$media ]]
grep -q 'mods = "CTRL"' "$CLIPBOARD_PASTE_DISPATCH"
[[ ! -e $CLIPBOARD_PASTE_TYPED ]]

export CLIPBOARD_PASTE_CLASS=firefox
"$ROOT/bin/clipboard-paste" 42 "" ""
grep -q 'mods = "CTRL"' "$CLIPBOARD_PASTE_DISPATCH"

printf 'CLIPBOARD_PASTE_TEST_PASS\n'
