# OmniWM

Native OmniWM 0.7.4 configuration based on `../hypr/`, with macOS app rules
from `../aerospace/`. No Karabiner, skhd, or shortcut daemon required.

`settings.toml` is a full schema-v4 file because OmniWM requires every hotkey
action exactly once, including unassigned actions. It live-reloads; changes in
OmniWM Settings also write back to this file. Local IPC is enabled for the bundled
`/Applications/OmniWM.app/Contents/MacOS/omniwmctl` CLI.

## Workspaces

Like Hyprland and AeroSpace, there are two sets: nine plain numbered workspaces
and eight lettered ones. OmniWM workspace IDs must be positive integers, so the
lettered workspaces are numbers 11–18 with a letter display name.

| Number | Label / Option key | Purpose | Layout |
| --- | --- | --- | --- |
| 1–9 | 1–9 | General purpose, no app rules | Dwindle |
| 11 | A | AI | Dwindle |
| 12 | C | Chat: Discord, Messages | Dwindle |
| 13 | D | Development: Ghostty, WezTerm, VS Code | Dwindle |
| 14 | N | Notes / spare | Dwindle |
| 15 | S | Productivity: Slack, Obsidian, Notion, calendar, mail, Linear | Dwindle |
| 16 | W | Web: Brave Origin, Helium, Safari, Chrome | Dwindle |
| 17 | X | OmniFocus | Dwindle |
| 18 | Z | Zoom | Dwindle |

Option + digit or letter switches; add Shift to send the focused window without
following. All are fixed workspace targets that survive monitor reassignment;
OmniWM's per-monitor slot actions are left unassigned. Hotkey IDs are zero-based
(`switchWorkspace.10` is workspace 11); IDs above `.8` need OmniWM 0.7.4+.

B→W and P→S duplicate aliases are omitted because each OmniWM action takes one
binding. N stays unassigned to apps, as in Hyprland: Obsidian goes to S, not N.

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
| Option + grave | Built-in Quake terminal: bottom, 80% wide, 65% high |
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
- Clipboard history is enabled. No global keyboard remapping is enabled.
- Borders are 2pt, inner gaps 8pt (Hyprland's two 4px half-gaps), and side/bottom
  outer gaps 8pt. Top clearance matches AeroSpace's 50pt below the menu bar
  (SketchyBar: y_offset 6 + height 36 + 8pt gap). OmniWM measures `outer.top`
  from the physical edge and subtracts the menu bar, so it is menu bar + 50:
  89 on the notched built-in display (39pt bar), 74 via `monitorGapOverrides`
  on the Studio Displays (24pt bar).
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
