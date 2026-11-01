-- Rex config. Docs: rex config --help, rex keymap, rex -C <client> actions
-- Apply changes with: rex config reload

-- tmux-style bindings, mirroring config/tmux/tmux.conf (prefix C-a).
local P = "ctrl+a>"

-- send-prefix: ctrl+a twice (or ctrl+a a) still reaches the shell
rex.bind(P .. "ctrl+a", "pane.send_key", { key = "ctrl+a" })
rex.bind(P .. "a", "pane.send_key", { key = "ctrl+a" })

-- windows (Rex calls them tabs)
rex.bind(P .. "c", "client.tab.new")
rex.bind(P .. "ctrl+h", "client.tab.previous")
rex.bind(P .. "ctrl+l", "client.tab.next")
for i = 1, 9 do
  rex.bind(P .. i, "client.tab.goto", { index = i })
end

-- splits: | and - (keys are written unshifted, so | is shift+\)
rex.bind(P .. "shift+\\", "pane.split", { direction = "right" })
rex.bind(P .. "-", "pane.split", { direction = "down" })

-- panes
rex.bind(P .. "z", "pane.zoom")
rex.bind(P .. "x", "pane.close")
rex.bind(P .. "=", "pane.balance") -- closest thing to select-layout tiled

-- misc
rex.bind("cmd+shift+s", "client.sidebar.toggle")
rex.bind(P .. "s", "session.switch")
rex.bind(P .. "r", "client.config.reload")

-- Resize like tmux's `bind -r H resize-pane -L 10`: prefix+H resizes once, then
-- leaves you in a resize mode where h/j/k/l (or H/J/K/L) keep resizing.
-- Escape or Enter leaves it. Unlike tmux there's no repeat timeout.
rex.mode("resize", { exclusive = true })
rex.action{
  name = "resize_repeat",
  title = "Resize Pane (repeat)",
  args = { direction = "string" },
  run = function(_, args)
    rex.client.queue("pane.resize", { direction = args.direction, amount = 10 })
    rex.client.queue("client.mode.enter", { name = "resize" })
  end,
}
rex.bind("resize/enter", "client.mode.exit")

for key, dir in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
  rex.bind(P .. key, "pane.focus", { direction = dir })
  rex.bind(P .. "shift+" .. key, "resize_repeat", { direction = dir })
  rex.bind("resize/" .. key, "pane.resize", { direction = dir, amount = 10 })
  rex.bind("resize/shift+" .. key, "pane.resize", { direction = dir, amount = 10 })
end
