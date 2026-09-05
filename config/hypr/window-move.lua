-- window-move.lua: SUPER+SHIFT+hjkl, in-process.
--
-- Hyprland's movewindow only moves into an EXISTING neighbour. Given a column of
-- two windows already against the screen edge -- one full-height window beside a
-- stacked pair -- pressing "move right" on the lower one does nothing, because
-- there is no window to its right to move into.
--
-- So: try the plain move, and if nothing shifted, flip the split of the pair the
-- window belongs to and try again. The flip only happens when that pair runs
-- ACROSS the requested direction, which is what keeps a window at the bottom of
-- a column from rearranging the workspace when pushed further down.
--
-- This replaces a python helper that did the same thing over hyprctl. hl.bind
-- takes a plain Lua function, and the getters below run inside the compositor,
-- so a keypress costs no processes at all.

local GAP_SLACK = 40 -- gaps and rounding, when comparing edges

local function near(a, b)
  return math.abs(a - b) <= GAP_SLACK
end

-- Dwindle halves a rectangle, so a window's sibling shares its x and width when
-- stacked above/below it, or its y and height when beside it. Matching on plain
-- overlap instead is too loose: a full-height window in the next column overlaps
-- vertically without being the sibling.
--
-- Returns the sibling and the axis it sits on ("v" stacked, "h" side by side).
local function sibling(win)
  local ws = win.workspace.id
  for _, c in ipairs(hl.get_windows()) do
    if c.address ~= win.address and not c.floating and not c.hidden and c.workspace.id == ws then
      if near(win.at.x, c.at.x) and near(win.size.x, c.size.x) and not near(win.at.y, c.at.y) then
        return c, "v"
      end
      if near(win.at.y, c.at.y) and near(win.size.y, c.size.y) and not near(win.at.x, c.at.x) then
        return c, "h"
      end
    end
  end
  return nil, nil
end

-- Is the window already on the far side of its sibling, in the direction asked?
local function already_placed(win, sib, dir)
  if dir == "r" then return win.at.x > sib.at.x end
  if dir == "l" then return win.at.x < sib.at.x end
  if dir == "d" then return win.at.y > sib.at.y end
  return win.at.y < sib.at.y
end

local function geom(win)
  if not win then return nil end
  return win.at.x, win.at.y, win.size.x, win.size.y
end

local function same_geom(x, y, w, h, win)
  if not win then return false end
  local nx, ny, nw, nh = geom(win)
  return nx == x and ny == y and nw == w and nh == h
end

-- Exposed globally so it can be exercised with
--   hyprctl dispatch '(function() hypr_move("r") return hl.dsp.no_op() end)()'
function hypr_move(dir)
  local win = hl.get_active_window()
  if not win then return end

  if win.floating then
    hl.dispatch(hl.dsp.window.move({ direction = dir }))
    return
  end

  local x, y, w, h = geom(win)
  local _, axis = sibling(win) -- read before the move, while the layout is intact

  hl.dispatch(hl.dsp.window.move({ direction = dir }))

  if not same_geom(x, y, w, h, hl.get_active_window()) then
    return -- the plain move did the job
  end

  local wanted = (dir == "l" or dir == "r") and "v" or "h"
  if axis ~= wanted then
    return -- at the end of its own axis; leave it alone
  end

  hl.dispatch(hl.dsp.layout("togglesplit"))

  -- The flip preserves order, so the upper window becomes the left one. That
  -- already places a window pushed towards the far side, and moving again would
  -- undo the flip rather than no-op, so only move when it landed on the near
  -- side.
  local me = hl.get_active_window()
  local sib = me and sibling(me)
  if me and sib and not already_placed(me, sib, dir) then
    hl.dispatch(hl.dsp.window.move({ direction = dir }))
  end
end

for key, dir in pairs({ H = "l", J = "d", K = "u", L = "r" }) do
  hl.bind("SUPER + " .. key, hl.dsp.focus({ direction = dir }))
  hl.bind("SUPER + SHIFT + " .. key, function() hypr_move(dir) end)
end
