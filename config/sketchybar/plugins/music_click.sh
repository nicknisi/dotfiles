#!/usr/bin/env bash
# Control the same system Now Playing session that the music chip displays.
# Left = play/pause, right = next track, then refresh the chip.

CMD=togglePlayPause
[ "$BUTTON" = "right" ] && CMD=next
nowplaying-cli "$CMD" 2>/dev/null

sleep 0.3
exec "$CONFIG_DIR/plugins/music.sh"
