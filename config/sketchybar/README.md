# SketchyBar

The existing Phosphor bar supports **OmniWM and AeroSpace**. It detects the running
WM (preferring OmniWM), preserves workspace labels and app icons, and routes
workspace/agent/GitHub clicks through `plugins/wm.sh`.

## OmniWM

1. Enable **IPC** in OmniWM (`general.ipcEnabled = true` in its settings).
2. Start `sketchybar` from a terminal **after OmniWM is running**. AeroSpace's
   startup hook is not involved. Automatic startup ordering is not configured;
   if a login service starts the bar too early, run `sketchybar --reload` once
   OmniWM and IPC are ready.
3. Optionally turn off OmniWM's native workspace bar in its settings. This config
   does not change it or OmniWM's layout gaps; leave enough top clearance for
   SketchyBar's 36pt bar, 6pt offset, and the macOS menu bar.

`omniwmctl watch` pushes focus, workspace, window-inventory, display, and layout
changes. Reloading SketchyBar replaces its subscription; transient IPC disconnects
reconnect automatically. The CLI is found on PATH, with the bundled
`/Applications/OmniWM.app/Contents/MacOS/omniwmctl` as a fallback.

Pill IDs use OmniWM's workspace **numbers**, while their text uses **display
names**. Agent/spend clicks resolve `D` and GitHub right-click resolves `W` against
those display names. Empty workspaces are hidden unless active. The focused title
and fleet widgets retain the existing appearance and behavior.

Run `sketchybar --reload` after adding/removing workspaces or switching WMs.
Renaming existing OmniWM workspace labels is picked up on the next render.
The watchdog exits SketchyBar only when **neither** supported WM is running.

## Checks

```sh
python3 config/sketchybar/tests/workspaces.py
bash config/sketchybar/tests/music.sh
```

Workspace tests use isolated command stubs: they never switch real workspaces,
launch a bar, or kill real processes. The scripts require Homebrew Bash (4+),
just like the existing associative-array workspace renderer.
