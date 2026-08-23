#!/usr/bin/env bash
# Now-playing chip + album-art thumb, hidden when silent or paused.
# Primary path: the native media_change event pushes $INFO JSON
# (state/title/artist/app) on every playback change — no polling. The slow
# update_freq=60 runs the old current-song AppleScript path as a fallback
# in case MediaRemote events don't fire on this macOS build (flaky for
# unsigned processes since 14.4). Artwork comes from bin/album-art and is
# cached per track; on the fallback path the playing app is sniffed first.

source "$CONFIG_DIR/colors.sh"

ART_ITEM="${NAME}_art"
ALBUM_ART="$HOME/Developer/dotfiles/bin/album-art"

if [ "$SENDER" = "media_change" ]; then
  STATE=$(jq -r '.state // empty' <<<"$INFO" 2>/dev/null)
  TITLE=$(jq -r '.title // empty' <<<"$INFO" 2>/dev/null)
  ARTIST=$(jq -r '.artist // empty' <<<"$INFO" 2>/dev/null)
  APP=$(jq -r '.app // empty' <<<"$INFO" 2>/dev/null)
  SONG=""
  [ "$STATE" = "playing" ] && [ -n "$TITLE" ] && SONG="$TITLE - $ARTIST"
else
  SONG=$("$HOME/Developer/dotfiles/bin/current-song" 2>/dev/null)
  APP=$(osascript -l JavaScript -e '
    let r = "";
    try { const s = Application("Spotify"); if (s.running() && s.playerState() === "playing") r = "Spotify"; } catch (e) {}
    try { const m = Application("Music"); if (r === "" && m.running() && m.playerState() === "playing") r = "Music"; } catch (e) {}
    r;' 2>/dev/null)
fi

if [ -z "$SONG" ]; then
  sketchybar --set "$NAME" drawing=off --set "$ART_ITEM" drawing=off
  exit 0
fi

ART=$("$ALBUM_ART" "$APP" "$SONG" 2>/dev/null)
ARGS=(--animate tanh 30 --set "$NAME" drawing=on label="$SONG")
if [ -n "$ART" ]; then
  ARGS+=(--set "$ART_ITEM" drawing=on
    background.image="$ART" background.image.scale=0.5)
else
  ARGS+=(--set "$ART_ITEM" drawing=off)
fi
sketchybar "${ARGS[@]}"
