#!/usr/bin/env bash
# Music chip clicks: left = play/pause, right = next track. Targets
# whichever player is active (Music first, then Spotify), then re-runs
# the plugin so the chip reflects the change now, not at the next poll.

CMD=playpause
[ "$BUTTON" = "right" ] && CMD=nextTrack

osascript -l JavaScript -e "
  const act = (name) => {
    try {
      const a = Application(name);
      if (a.running() && a.playerState() !== 'stopped') return a;
    } catch (e) {}
    return null;
  };
  const p = act('Music') || act('Spotify');
  if (p) p.$CMD();
" 2>/dev/null

sleep 0.3
exec "$CONFIG_DIR/plugins/music.sh"
