#!/usr/bin/env bash
# fake-logind.sh DIR: fake `gdbus` and `systemd-inhibit` in DIR for the sleep
# fade and face tests, so no test reaches the system bus or logind.
#
#   gdbus monitor ...   prints what gdbus prints once subscribed (logind's
#                       owner), then every line written to $FAKE_LOGIND_FIFO
#                       (the test writes PrepareForSleep lines there); with no
#                       FIFO it idles.
#   gdbus call ...      prints PreparingForSleep: $FAKE_PREPARING (false);
#                       with FAKE_READ_HANG=1 it never answers.
#   systemd-inhibit ... logs "inhibit PID ARGS" to $FAKE_INHIBIT_LOG, runs
#                       the command (the shell's `cat`) as its child the way
#                       the real one does, and logs "released PID" when it
#                       ends, "term PID" on SIGTERM (setpriv's parent death
#                       signal).
set -euo pipefail
dir=$1
mkdir -p "$dir"
cat >"$dir/gdbus" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
monitor)
    printf 'Monitoring signals on object /org/freedesktop/login1 owned by org.freedesktop.login1\n'
    printf 'The name org.freedesktop.login1 is owned by :1.11\n'
    if [ -n "${FAKE_LOGIND_FIFO:-}" ]; then exec cat "$FAKE_LOGIND_FIFO"; fi
    exec sleep 3600
    ;;
call)
    if [ -n "${FAKE_READ_HANG:-}" ]; then exec sleep 3600; fi
    printf '(<%s>,)\n' "${FAKE_PREPARING:-false}"
    ;;
*) exit 2 ;;
esac
EOF
cat >"$dir/systemd-inhibit" <<'EOF'
#!/usr/bin/env bash
log=${FAKE_INHIBIT_LOG:-/dev/null}
printf 'inhibit %s %s\n' "$$" "$*" >>"$log"
trap 'printf "term %s\n" "$$" >>"$log"; kill "$child" 2>/dev/null; exit 143' TERM
args=()
for a in "$@"; do case "$a" in --*) ;; *) args+=("$a") ;; esac; done
"${args[@]}" <&0 &
child=$!
wait "$child" || true
printf 'released %s\n' "$$" >>"$log"
EOF
chmod +x "$dir/gdbus" "$dir/systemd-inhibit"
