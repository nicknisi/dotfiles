#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
TMP=$(mktemp -d)
trap '[[ -f "$TMP/run/capture-wf-recorder.pid" ]] && kill "$(<"$TMP/run/capture-wf-recorder.pid")" 2>/dev/null || true; rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"

cat >"$TMP/bin/grim" <<'EOF'
#!/usr/bin/env bash
output=${!#}
if [[ $output == - ]]; then
  printf 'png-data'
else
  printf 'png-data' >"$output"
fi
EOF
cat >"$TMP/bin/wl-copy" <<'EOF'
#!/usr/bin/env bash
if [[ ${1:-} == --type ]]; then
  printf '%s\n' "$2" >"$WL_COPY_TEST_TYPE"
  shift 2
else
  : >"$WL_COPY_TEST_TYPE"
fi
cat >"$WL_COPY_TEST_OUTPUT"
EOF
cat >"$TMP/bin/slurp" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
cat >"$TMP/bin/notify-send" <<'EOF'
#!/usr/bin/env bash
:
EOF
cat >"$TMP/bin/wf-recorder" <<'EOF'
#!/usr/bin/env python3
import pathlib
import signal
import sys

output = pathlib.Path(sys.argv[sys.argv.index("-f") + 1])
def stop(_signal, _frame):
    output.write_text("video")
    raise SystemExit(0)
signal.signal(signal.SIGINT, stop)
signal.pause()
EOF
chmod +x "$TMP/bin"/*

export PATH="$TMP/bin:$PATH"
export XDG_STATE_HOME="$TMP/state"
export XDG_RUNTIME_DIR="$TMP/run"
export WL_COPY_TEST_OUTPUT="$TMP/copied"
export WL_COPY_TEST_TYPE="$TMP/copied.type"
mkdir -p "$XDG_RUNTIME_DIR"

"$ROOT/bin/capture" shot screen "$TMP/shot.png"
[[ $(<"$TMP/shot.png") == png-data && $(<"$WL_COPY_TEST_OUTPUT") == png-data ]]
[[ $(<"$WL_COPY_TEST_TYPE") == image/png ]]

set +e
"$ROOT/bin/capture" shot region "$TMP/cancelled.png"
status=$?
set -e
[[ $status == 130 && ! -e "$TMP/cancelled.png" ]]

printf '%s\n' "$$" >"$XDG_RUNTIME_DIR/capture-wf-recorder.pid"
[[ $("$ROOT/bin/capture" status) == idle ]]
[[ ! -e "$XDG_RUNTIME_DIR/capture-wf-recorder.pid" ]]

"$ROOT/bin/capture" record screen "$TMP/recording.mp4"
[[ $("$ROOT/bin/capture" status) == recording ]]
"$ROOT/bin/capture" record stop
[[ $("$ROOT/bin/capture" status) == idle ]]
[[ $(<"$TMP/recording.mp4") == video ]]
[[ $(<"$WL_COPY_TEST_OUTPUT") == video && $(<"$WL_COPY_TEST_TYPE") == video/mp4 ]]

printf 'CAPTURE_TEST_PASS\n'
