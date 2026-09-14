#!/usr/bin/env bash
# Run on macOS: bash config/sketchybar/tests/music.sh
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
trap 'echo "Failed at line $LINENO: $BASH_COMMAND" >&2' ERR
export HOME="$WORK/home" CONFIG_DIR="$ROOT/config/sketchybar" NAME=music
export METADATA="$WORK/metadata.json" CALLS="$WORK/calls" RENDER="$WORK/render"
mkdir -p "$WORK/bin" "$HOME/Developer/dotfiles"
ln -s "$ROOT/bin" "$HOME/Developer/dotfiles/bin"
export PATH="$WORK/bin:$PATH"

cat > "$WORK/bin/nowplaying-cli" <<'EOF'
#!/usr/bin/env bash
if [[ $1 == get ]]; then
  [[ ${CLI_FAIL:-0} == 0 ]] || exit 1
  cat "$METADATA"
else
  printf '%s\n' "$*" >> "$CALLS"
fi
EOF
cat > "$WORK/bin/sketchybar" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$RENDER"
EOF
printf '#!/bin/bash\nexit 0\n' > "$WORK/bin/sleep"
chmod +x "$WORK/bin/"*
source "$CONFIG_DIR/colors.sh"

# Browser metadata, quotes, and a non-unit playback rate survive the JSON path.
printf '%s\n' '{"title":"A \"browser\" track","artist":"Artist","playbackRate":0.5,"clientBundleIdentifier":"com.brave.Browser"}' > "$METADATA"
NP=$("$ROOT/bin/current-song" --json)
jq -e '.app == "com.brave.Browser" and .state == "playing" and .song == "A \"browser\" track - Artist"' <<< "$NP" >/dev/null
[[ $("$ROOT/bin/current-song") == 'A "browser" track - Artist' ]]
bash "$CONFIG_DIR/plugins/music.sh"
grep -Fxq 'label=A "browser" track - Artist' "$RENDER"
grep -Fxq "label.color=$FG" "$RENDER"
grep -Fxq 'icon.background.drawing=off' "$RENDER"

# Artwork uses the same snapshot and caches by image content, not a short title.
PNG='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aWQAAAABJRU5ErkJggg=='
jq --arg art "$PNG" '.artworkData = $art' "$METADATA" > "$WORK/with-art.json"
mv "$WORK/with-art.json" "$METADATA"
NP=$("$ROOT/bin/current-song" --json)
ART=$("$ROOT/bin/album-art" <<< "$NP")
[[ -s $ART && $("$ROOT/bin/album-art" <<< "$NP") == "$ART" ]]
sips -g pixelWidth -g pixelHeight "$ART" | grep -q 'pixelWidth: 48'
bash "$CONFIG_DIR/plugins/music.sh"
grep -Fxq "icon.background.image=$ART" "$RENDER"
grep -Fxq 'icon.background.drawing=on' "$RENDER"

# Paused media stays dimmed. Missing artwork clears the previous thumbnail.
printf '%s\n' '{"title":"Paused video","playbackRate":0}' > "$METADATA"
[[ -z $("$ROOT/bin/current-song") ]]
bash "$CONFIG_DIR/plugins/music.sh"
grep -Fxq 'drawing=on' "$RENDER"
grep -Fxq 'label=Paused video' "$RENDER"
grep -Fxq "label.color=$FG_DIM" "$RENDER"
grep -Fxq 'icon.background.drawing=off' "$RENDER"
if "$ROOT/bin/album-art" <<< '{"artwork":"invalid"}' >/dev/null 2>&1; then
  echo 'Invalid artwork was accepted' >&2
  exit 1
fi

# No media, malformed metadata, and CLI failure hide the chip without stale text.
for metadata in '{}' 'null' 'not JSON'; do
  printf '%s\n' "$metadata" > "$METADATA"
  [[ -z $("$ROOT/bin/current-song" --json) ]]
  bash "$CONFIG_DIR/plugins/music.sh"
  grep -Fxq 'drawing=off' "$RENDER"
done
printf '%s\n' '{"title":"Unavailable player","playbackRate":1}' > "$METADATA"
CLI_FAIL=1 bash "$CONFIG_DIR/plugins/music.sh"
grep -Fxq 'drawing=off' "$RENDER"

# Clicks target the system session, never a separately selected Music/Spotify app.
BUTTON=left bash "$CONFIG_DIR/plugins/music_click.sh"
BUTTON=right bash "$CONFIG_DIR/plugins/music_click.sh"
[[ $(< "$CALLS") == $'togglePlayPause\nnext' ]]
printf 'Music checks passed: system metadata, artwork, paused/empty states, and controls.\n'
