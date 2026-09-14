#!/usr/bin/env bash
# Now-playing chip: album art rendered inside the chip (as the icon's
# background image) + "Title - Artist". Hidden when silent, dimmed when paused.
# Polls system Now Playing every 5s through nowplaying-cli because the native
# media_change event does not fire on this unsigned build. Metadata and artwork
# come from one snapshot; bin/album-art caches the normalized image.
# Clicks: left = play/pause, right = next track (music_click.sh).

source "$CONFIG_DIR/colors.sh"

NP=$("$HOME/Developer/dotfiles/bin/current-song" --json 2>/dev/null)
SONG=$(jq -r '.song // empty' <<<"$NP" 2>/dev/null)
STATE=$(jq -r '.state // empty' <<<"$NP" 2>/dev/null)

# Hide only when no player is open with a track; paused stays, dimmed.
if [ -z "$SONG" ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

LABEL_COLOR="$FG" NOTE_COLOR="$MAGENTA"
[ "$STATE" = "paused" ] && LABEL_COLOR="$FG_DIM" NOTE_COLOR="$GREY"

ART=$("$HOME/Developer/dotfiles/bin/album-art" <<<"$NP" 2>/dev/null)
if [ -n "$ART" ]; then
  sketchybar --animate tanh 30 --set "$NAME" drawing=on \
    label="$SONG" label.color="$LABEL_COLOR" \
    icon="" icon.width=30 \
    icon.background.drawing=on \
    icon.background.image="$ART" \
    icon.background.image.scale=0.5 \
    icon.background.corner_radius=4 \
    icon.background.height=24
else
  sketchybar --animate tanh 30 --set "$NAME" drawing=on \
    label="$SONG" label.color="$LABEL_COLOR" \
    icon="♪" icon.color="$NOTE_COLOR" icon.width=dynamic icon.background.drawing=off
fi
