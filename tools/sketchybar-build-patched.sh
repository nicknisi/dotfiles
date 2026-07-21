#!/usr/bin/env bash
# Build sketchybar with the Tahoe secondary-display menu bar fix and install
# it over the brew Cellar binary (backed up as sketchybar.orig, formula pinned
# so `brew upgrade` can't silently revert the patch).
#
# Why: on macOS Tahoe with "Displays have separate Spaces" disabled (the
# AeroSpace-recommended mode), macOS paints a menu bar on secondary displays
# but reports a zero top inset for them (NSScreen visibleFrame == frame), so
# stock sketchybar draws the bar underneath the menu bar on every display
# except the main one. The patch falls back to the main display's inset.
# Patch: tools/sketchybar-tahoe-menubar-inset.patch (upstream: FelixKratz/SketchyBar)
set -euo pipefail

VERSION="${1:-$(brew list --versions sketchybar | awk '{print $2}')}"
PATCH="$(cd "$(dirname "$0")" && pwd)/sketchybar-tahoe-menubar-inset.patch"
BUILD_DIR="$(mktemp -d)"
CELLAR_BIN="$(brew --cellar sketchybar)/$VERSION/bin"

echo "Building sketchybar v$VERSION with menu bar inset patch..."
git clone --depth 1 --branch "v$VERSION" https://github.com/FelixKratz/SketchyBar.git "$BUILD_DIR"
git -C "$BUILD_DIR" apply "$PATCH"
make -C "$BUILD_DIR"

echo "Installing over $CELLAR_BIN/sketchybar (backup: sketchybar.orig)..."
[ -f "$CELLAR_BIN/sketchybar.orig" ] || cp "$CELLAR_BIN/sketchybar" "$CELLAR_BIN/sketchybar.orig"
# -f: brew installs the binary read-only (555); unlink-and-recreate instead of open-for-write
cp -f "$BUILD_DIR/bin/sketchybar" "$CELLAR_BIN/sketchybar"
brew pin sketchybar

# Lifecycle is tied to AeroSpace (after-startup-command + watchdog item),
# NOT brew services — a launchd service would keep the bar alive without
# the WM. Relaunch directly, and only if AeroSpace is running.
pkill -x sketchybar 2>/dev/null || true
sleep 1
if pgrep -xq AeroSpace; then
  (nohup sketchybar >/dev/null 2>&1 &)
  echo "Relaunched sketchybar."
else
  echo "AeroSpace not running — sketchybar will start with it."
fi
rm -rf "$BUILD_DIR"
echo "Done. Revert: cp sketchybar.orig over sketchybar (or brew reinstall) + brew unpin sketchybar"
