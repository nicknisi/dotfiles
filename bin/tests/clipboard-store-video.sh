#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/run"

cat >"$TMP/bin/cliphist" <<'EOF'
#!/usr/bin/env bash
case $1 in
store) cat >"$CLIPHIST_TEST_OUTPUT" ;;
list) [[ ! -f $CLIPHIST_TEST_OUTPUT ]] || printf '42\tvideo preview\n' ;;
decode) [[ $2 == 42 ]] && cat "$CLIPHIST_TEST_OUTPUT" ;;
*) exit 2 ;;
esac
EOF
cat >"$TMP/bin/notify-send" <<'EOF'
#!/usr/bin/env bash
:
EOF
chmod +x "$TMP/bin"/*

export PATH="$TMP/bin:$PATH"
export XDG_RUNTIME_DIR="$TMP/run"
export XDG_CACHE_HOME="$TMP/cache"
export CLIPHIST_TEST_OUTPUT="$TMP/stored"
export CLIPHIST_VIDEO_MAX_BYTES=5

printf 'video' | "$ROOT/bin/clipboard-store-video"
[[ $(<"$TMP/stored") == video ]]
grep -q $'^42\tvideo/unknown\t5$' "$XDG_CACHE_HOME/cliphist/media.tsv"
"$ROOT/bin/clipboard-list" | grep -q $'^42\t\[\[ binary data 5B video/unknown \]\]$'

rm "$TMP/stored"
printf 'larger' | "$ROOT/bin/clipboard-store-video"
[[ ! -e "$TMP/stored" ]]

CLIPBOARD_STATE=sensitive printf 'video' | CLIPBOARD_STATE=sensitive "$ROOT/bin/clipboard-store-video"
[[ ! -e "$TMP/stored" ]]

printf 'CLIPBOARD_VIDEO_STORE_TEST_PASS\n'
