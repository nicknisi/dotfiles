#!/usr/bin/env bash
# Explicitly build a static engine and a source/architecture/digest manifest.
# No executable is included in the portable checkout.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="${CARGO_BUILD_TARGET:-x86_64-unknown-linux-gnu}"
OUT="$ROOT/matching/bin"
mkdir -p "$OUT"
BUILDER=()
if ! command -v cargo >/dev/null || ! cargo --version >/dev/null 2>&1; then
  command -v mise >/dev/null || { printf '%s\n' 'Install cargo or mise to build the matching engine' >&2; exit 1; }
  BUILDER=(mise exec rust@stable --)
fi
SOURCE="$(luajit "$ROOT/helpers/matching-start.lua" --engine-fingerprint)"
# +crt-static avoids a dependency on the build machine's glibc version.
RUSTFLAGS="-C target-feature=+crt-static" "${BUILDER[@]}" cargo build --release --locked --quiet \
  --manifest-path "$ROOT/matching/engine/Cargo.toml" --target "$TARGET" \
  --target-dir "${CARGO_TARGET_DIR:-$ROOT/matching/engine/target}"
[[ "$SOURCE" == "$(luajit "$ROOT/helpers/matching-start.lua" --engine-fingerprint)" ]]
install -m 755 "${CARGO_TARGET_DIR:-$ROOT/matching/engine/target}/$TARGET/release/keystroke-matching" "$OUT/keystroke-matching.tmp"
mv -fT -- "$OUT/keystroke-matching.tmp" "$OUT/keystroke-matching"
RUSTC_VERSION="$("${BUILDER[@]}" rustc --version)" luajit - "$ROOT" "$TARGET" "$SOURCE" <<'LUA'
local root, target, source = arg[1], arg[2], arg[3]
package.path = root .. '/helpers/?.lua;' .. package.path
local U = require('runtime')
local M = require('matching-start')
local machine = U.run({'uname', '-m'})
assert(machine.code == 0, machine.stderr)
local manifest = U.encode({machine = machine.stdout:gsub('%s+$', ''), target = target, source = source,
  sha256 = M.sha256(M.SHIPPED_ENGINE), rustc = os.getenv('RUSTC_VERSION')})
U.atomic_write(M.SHIPPED_ENGINE .. '.json', manifest .. '\n', 420)
print(manifest)
LUA
