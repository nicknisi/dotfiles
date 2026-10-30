#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
# shellcheck source=/dev/null
source "$ROOT/bin/update-all"

printf 'git 2.50\nfd 10.1\nold 1.0\npython 3.12.1 3.12.2\n' >"$TMP/before"
printf 'git 2.51\nfd 10.1\nnew 0.1\npython 3.12.2\n\n' >"$TMP/after"
: >"$TMP/empty"

[ "$(changes "$TMP/before" "$TMP/after")" = "$(printf 'git\t2.50\t2.51\nnew\t(new)\t0.1\nold\t1.0\t(removed)')" ]
[ "$(changes "$TMP/empty" "$TMP/after" | grep -c .)" = 4 ] # empty "before" must not swallow "after"
[ -z "$(changes "$TMP/after" "$TMP/after")" ]
echo ok
