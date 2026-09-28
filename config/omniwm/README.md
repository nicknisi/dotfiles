# OmniWM

Native OmniWM 0.7.3 configuration based on `../hypr/`, with macOS app rules
from `../aerospace/`. No Karabiner, skhd, or shortcut daemon required.

`settings.toml` is a full schema-v3 file because OmniWM requires every hotkey
action exactly once, including unassigned actions. It live-reloads; changes in
OmniWM Settings also write back to this file. Local IPC is enabled for the bundled
`/Applications/OmniWM.app/Contents/MacOS/omniwmctl` CLI.

## Workspaces

| Number | Label / Option key | Purpose | Layout |
| --- | --- | --- | --- |
| 1 | A | AI | Dwindle |
| 2 | C | Chat: Discord, Messages | Dwindle |
| 3 | D | Development: Ghostty, WezTerm, VS Code | Niri (scrolling) |
| 4 | N | Notes / spare | Dwindle |
| 5 | S | Productivity: Slack, Obsidian, Notion, calendar, mail, Linear | Dwindle |
| 6 | W | Web: Brave Origin, Helium, Safari, Chrome | Dwindle |
| 7 | X | OmniFocus | Dwindle |
| 8 | Z | Zoom | Dwindle |
| 9 | 9 | Spare | Dwindle |

Option + letter switches; add Shift to send the focused window without following.
These are fixed workspace targets, so the letter shortcuts survive monitor
reassignment. Option + 1–8 (and Shift to send) uses OmniWM's **current-monitor
slots**; Option + 9 targets workspace 9 directly. All workspaces start on Main,
so numbers and letters reach the same nine workspaces. If you distribute them
across monitors, the slot numbers become monitor-local; letter targets stay fixed.

This replaces Hyprland's separate numbered and lettered sets with nine shared
workspaces. B→W and P→S duplicate aliases are omitted. N stays unassigned to apps,
as in Hyprland: Obsidian goes to S, not N.

## Window keys

All use **Option** in place of Super, leaving Command shortcuts to macOS apps.

| Keys | Action |
| --- | --- |
| Option + H/J/K/L | Focus left/down/up/right |
| Option + Shift + H/J/K/L | Move (Dwindle joins/extracts groups; Niri moves across/within columns) |
| Option + Shift + −/= | Shrink/grow focused window, Dwindle only |
| Option + −/= | Shrink/grow column width, Niri only |
| Control + Option + Shift + −/= | Shrink/grow window height, Niri only |
| Option + F | Fill workspace, retaining outer gaps |
| Option + Shift + F | macOS native fullscreen (creates a macOS Space) |
| Option + Shift + Space | Toggle floating |
| Option + Q | Close focused window, not quit the app |
| Option + / | Toggle split, Dwindle only |
| Option + , | Toggle tabbed column, Niri only |
| Control + Option + L | Toggle Dwindle / Niri on current workspace |
| Option + Tab | Focus previous window (not Hyprland's thumbnail switcher) |
| Option + Shift + Tab | Overview |
| Control + Option + Tab | Previous workspace |
| Control + Option + Shift + H/L | Move the current workspace and all its windows to the left/right monitor |
| Option + Space | OmniWM command palette |
| Option + grave | Built-in Quake terminal: top, 70% wide, 50% high |
| Option + drag / right-drag | Swap tiled windows / resize |

Dwindle groups use J/K to change tabs; Shift+H/J/K/L joins or extracts a tab.
There is no direct Hyprland group-toggle equivalent. Dwindle smart resize uses
OmniWM's step size, not Hyprland's 100px helper.

Three-finger horizontal swipes switch workspaces; four-finger swipes scroll Niri.
Disable conflicting macOS gestures in System Settings → Trackpad → More Gestures
if macOS intercepts them. This config does not change system preferences.

## Differences and setup

- OmniWM app rules assign the **first tracked window** of an app; subsequent
  windows open on the workspace active at creation. Existing windows are not
  forcibly moved when the config reloads. This differs from Hyprland's routing
  of every new window.
- Quake is OmniWM's embedded terminal, not a Ghostty application window.
- No shell-command hotkeys: Option+Return (Ghostty), Option+Shift+Return (browser),
  theme cycling, lock, and capture shortcuts are not ported. Use existing macOS
  or Raycast shortcuts instead. Command+Space remains untouched.
- Clipboard history stays disabled. No global keyboard remapping is enabled.
- Borders are 2pt, inner gaps 8pt (Hyprland's two 4px half-gaps), and side/bottom
  outer gaps 8pt. Top clearance is 40pt measured from the physical screen edge;
  macOS menu-bar/notch geometry means it is not a pixel-perfect Linux match.
- Don't run AeroSpace alongside OmniWM. SketchyBar supports both WMs; with IPC
  enabled, start `sketchybar` to use its workspace pills and custom widgets (see
  `../sketchybar/README.md`). Disable the native workspace bar separately if desired.
  An existing `borders` process can draw an extra border. Neither service is stopped
  or changed by installing this config.

Install through the repository's normal symlink mechanism after backing up any
existing `~/.config/omniwm` directory:

```sh
mise bootstrap dotfiles apply ~/.config/omniwm
python3 config/omniwm/check.py
/Applications/OmniWM.app/Contents/MacOS/omniwmctl query workspaces \
  --fields number,display-name,layout --format table
```

The Python check validates our mapping and collision invariants, not OmniWM's
entire schema. Settings → Troubleshooting provides OmniWM's own diagnostics.

References: [settings](https://omniwm.app/config/settings-reference/),
[keys](https://omniwm.app/guides/keyboard-shortcuts/),
[app rules](https://omniwm.app/features/app-rules/).
