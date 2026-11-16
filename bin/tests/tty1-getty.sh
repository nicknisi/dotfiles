#!/usr/bin/env bash
# Tests config/mise/files/usr/local/lib/tty1-getty: autologin on the first
# start of a boot only, the stock password getty on every start after that.
# Runs a copy with the mark and agetty pointed into a temp dir; nothing needs
# root. Also checks the drop-in calls it and config.toml installs it.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
src=$root/config/mise/files/usr/local/lib/tty1-getty
dropin=$root/config/mise/files/etc/systemd/system/getty@tty1.service.d/autologin.conf
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail() { echo "TTY1_GETTY_FAIL: $*" >&2; exit 1; }

cat >"$tmp/agetty" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$(dirname "$0")/calls"
EOF
chmod +x "$tmp/agetty"
sed -e "s|^mark=/run/tty1-autologin.done$|mark=$tmp/run/tty1-autologin.done|" \
    -e "s|/usr/bin/agetty|$tmp/agetty|g" "$src" >"$tmp/tty1-getty"
grep -q "^mark=$tmp/run/" "$tmp/tty1-getty" || fail "mark line not found to redirect"
mkdir "$tmp/run"

run() { sh "$tmp/tty1-getty" linux; sed -n "${1}p" "$tmp/calls"; }

first=$(run 1)
[[ $first == *"--autologin nicknisi - linux" && $first == *"-p -f -- \\u"* ]] ||
  fail "first start should autologin: $first"
[ -e "$tmp/run/tty1-autologin.done" ] || fail "first start leaves the mark"

for n in 2 3; do
  again=$(run "$n")
  [ "$again" = "--noreset --noclear - linux" ] || fail "start $n should ask for the password: $again"
done

# No mark possible (the dir is gone): fail closed, ask for the password.
rm -rf "$tmp/run" "$tmp/calls"
closed=$(run 1)
[ "$closed" = "--noreset --noclear - linux" ] || fail "no mark should ask for the password: $closed"

# shellcheck disable=SC2016 # the literal ${TERM} in the unit
grep -qx 'ExecStart=-/usr/local/lib/tty1-getty ${TERM}' "$dropin" || fail "drop-in calls tty1-getty"
grep -q -- '--autologin' "$dropin" && fail "drop-in still autologs in itself"
grep -q '^\[bootstrap.files."/usr/local/lib/tty1-getty"\]' "$root/config/mise/config.toml" ||
  fail "config.toml installs tty1-getty"
[ -x "$src" ] || fail "tty1-getty is executable"
echo TTY1_GETTY_PASS
