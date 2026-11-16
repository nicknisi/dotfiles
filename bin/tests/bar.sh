#!/usr/bin/env bash
# bin/bar (PLAN M9): the Linux branch against a fake `qs` that keeps the
# look in a file and answers the island's `look` IPC as Look.qml does (set,
# list), and the macOS path, which still stops without OmniWM. Bash 3.2 and
# BSD tools: no GNU-only flags here either.
set -euo pipefail
here=$(cd -- "$(dirname -- "$0")/.." && pwd)
bar="$here/bar"
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT

fail() {
    echo "BAR_TEST_FAIL: $*" >&2
    exit 1
}

# The fake island: the look in $tmp/look, every call logged in $tmp/calls.
cat >"$tmp/qs" <<'EOF'
#!/usr/bin/env bash
dir=$(dirname "$0")
echo "$*" >>"$dir/calls"
[ "$1 $2 $3" = "ipc call look" ] || { echo "fake qs: $*" >&2; exit 2; }
now=$(cat "$dir/look" 2>/dev/null || echo crew)
case "$4" in
  list)
    for n in crew phosphor bridge arcade liner outrun; do
      mark=" "; [ "$n" = "$now" ] && mark="*"
      printf '%s %s\tline for %s\n' "$mark" "$n" "$n"
    done ;;
  set)
    n=$5; [ "$n" = none ] && n=crew
    case " crew phosphor bridge arcade liner outrun " in
      *" $n "*) echo "$n" >"$dir/look"; echo ok ;;
      *) echo "error: unknown look \"$5\" (looks: crew phosphor bridge arcade liner outrun, or none)" ;;
    esac ;;
  get) echo "$now" ;;
esac
EOF
chmod +x "$tmp/qs"

run() {
    BAR_OS=Linux BAR_QS="$tmp/qs" bash "$bar" "$@"
}

out=$(run arcade) || fail "bar arcade exited non-zero"
[ "$out" = "bar: arcade" ] || fail "bar arcade said: $out"
[ "$(cat "$tmp/look")" = arcade ] || fail "the look was not set"
grep -q '^ipc call look set arcade$' "$tmp/calls" || fail "set went out as: $(cat "$tmp/calls")"

out=$(run) || fail "bar with no argument exited non-zero"
printf '%s\n' "$out" | grep -q '^\* arcade' || fail "the listing does not mark arcade: $out"
[ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" = 6 ] || fail "the listing is not six looks: $out"

run next >/dev/null || fail "bar next exited non-zero"
[ "$(cat "$tmp/look")" = liner ] || fail "next from arcade is not liner: $(cat "$tmp/look")"
run next >/dev/null && run next >/dev/null
[ "$(cat "$tmp/look")" = crew ] || fail "next wraps from outrun to crew: $(cat "$tmp/look")"
run prev >/dev/null
[ "$(cat "$tmp/look")" = outrun ] || fail "prev wraps from crew to outrun: $(cat "$tmp/look")"

run none >/dev/null || fail "bar none exited non-zero"
[ "$(cat "$tmp/look")" = crew ] || fail "none is the plain island"

if err=$(run sky 2>&1); then fail "an unknown look passed: $err"; fi
printf '%s\n' "$err" | grep -q '^bar: error: unknown look "sky"' || fail "an unknown look said: $err"
[ "$(cat "$tmp/look")" = crew ] || fail "an unknown look changed the look"

run --help | grep -q 'On Linux the look is the Quickshell island' || fail "the help does not mention Linux"

# macOS: OmniWM's path, unchanged, never calls qs.
: >"$tmp/calls"
if err=$(BAR_OS=Darwin BAR_QS="$tmp/qs" HOME="$tmp" bash "$bar" arcade 2>&1); then
    [ -x /Applications/OmniWM.app/Contents/MacOS/omniwmctl ] || fail "macOS without OmniWM passed: $err"
else
    [ "$err" = "bar: OmniWM isn't installed" ] || [ -x /Applications/OmniWM.app/Contents/MacOS/omniwmctl ] || fail "macOS said: $err"
fi
[ ! -s "$tmp/calls" ] || fail "the macOS path called qs"

echo "BAR_TEST_PASS"
