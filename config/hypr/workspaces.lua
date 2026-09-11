-- workspaces.lua: the workspace half of the macOS aerospace config, ported.
--
-- aerospace used alt as its modifier because macOS keeps cmd for app shortcuts.
-- On Linux alt is not free: it opens menus, and alt+letter in a terminal is a
-- Meta sequence that zsh readline and nvim both rely on. Everything here is on
-- SUPER instead. Most letters and the structure are unchanged, so the muscle
-- memory carries over except for which key your thumb lands on.

-- key -> workspace, from [mode.main.binding] in aerospace.toml. Two aliases
-- come across as-is: b and w both reach W, p and s both reach S.
--
-- M (Mail) and T (Terminal) are unused, so they are dropped here. That leaves
-- SUPER+M, SUPER+T, and their shifted forms free.
local letters = {
  { key = "A", ws = "A" }, -- AI
  { key = "B", ws = "W" }, -- Web (alias of W)
  { key = "C", ws = "C" }, -- Chat
  { key = "D", ws = "D" }, -- Development
  { key = "N", ws = "N" }, -- Notes
  { key = "P", ws = "S" }, -- Productivity (alias of S)
  { key = "S", ws = "S" }, -- Productivity
  { key = "W", ws = "W" }, -- Web
  { key = "X", ws = "X" },
  { key = "Z", ws = "Z" }, -- Zoom / screen sharing
}

-- No persistent workspace rules on purpose. aerospace needed
-- persistent-workspaces so the bar could draw every slot; the quickshell bar
-- draws only workspaces that are focused or hold windows, so a persistent but
-- empty workspace would be created and then filtered straight back out.
-- Hyprland creates a named workspace on demand when you switch to it.
hl.workspace_rule({ workspace = "name:D", layout = "scrolling" })

-- Route new app windows like aerospace's on-window-detected rules and follow
-- them to their assigned workspace. Keep this ordered because later matching
-- rules win if entries ever overlap.
for _, app in ipairs({
  { class = "^discord$", workspace = "C" },
  { class = "^com\\.mitchellh\\.ghostty$", workspace = "D" },
  { class = "^brave-origin$", workspace = "W" },
  { class = "^Slack$", workspace = "S" },
  { class = "^md\\.obsidian\\.Obsidian$", workspace = "S" },
  { class = "^zoom$", workspace = "Z" },
}) do
  hl.window_rule({ match = { class = app.class }, workspace = "name:" .. app.workspace })
end

-- Named workspaces are addressed as "name:D". They also get a synthetic
-- negative id (-1337 counting down) which is not stable, so nothing should key
-- off it; the bar matches on the name.
--
-- follow = false is what makes SHIFT match aerospace's move-node-to-workspace:
-- send the window away and stay where you are. Note that `silent = true` looks
-- like it ought to do this and silently does nothing, because unrecognised keys
-- are accepted and dropped rather than rejected.
for _, m in ipairs(letters) do
  local target = "name:" .. m.ws
  hl.bind("SUPER + " .. m.key, hl.dsp.focus({ workspace = target }))
  hl.bind("SUPER + SHIFT + " .. m.key, hl.dsp.window.move({ workspace = target, follow = false }))
end

-- Workspaces 1-9 by keycode (10..18), so the binding survives layout changes.
for ws = 1, 9 do
  local key = "code:" .. tostring(ws + 9)
  hl.bind("SUPER + " .. key, hl.dsp.focus({ workspace = tostring(ws) }))
  hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ workspace = tostring(ws), follow = false }))
end

-- alt-tab / alt-shift-tab in aerospace.
hl.bind("SUPER + TAB", hl.dsp.focus({ workspace = "previous" }))
hl.bind("SUPER + SHIFT + TAB", hl.dsp.workspace.move({ monitor = "next" }))
