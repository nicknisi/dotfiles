// lib/IslandMachine.js: the island's states (PLAN M1).
// enter/leave/pin, the panelOpen set, timers restarting on go(), and the
// sizes, radius and rest-width rules the island morphs by.
const assert = require('node:assert/strict')
const M = require('../lib/IslandMachine.js')

const rest = M.initial()
assert.deepEqual(rest, { state: 'rest', pinned: false, timer: 0, seq: 0 })

// ---- pointer -------------------------------------------------------------------
const hover = M.enter(rest)
assert.equal(hover.state, 'hover')
assert.equal(hover.pinned, false, 'the dwell opens hover unpinned')
assert.equal(M.leave(hover).state, 'rest', 'leaving unpinned hover returns to rest')
assert.equal(M.enter(hover), hover, 'entering again changes nothing')
const pinned = M.click(rest)
assert.equal(pinned.state, 'hover')
assert.equal(pinned.pinned, true, 'a click on the rest pill pins')
assert.equal(M.leave(pinned), pinned, 'pinned hover ignores the pointer leaving')
assert.equal(M.click(hover).pinned, true, 'a click on unpinned hover pins it')
assert.equal(M.click(pinned), pinned, 'a click on pinned hover changes nothing')
assert.equal(M.dismiss(pinned).state, 'rest', 'outside click or Esc closes pinned hover')
assert.equal(M.dismiss(rest), rest, 'dismissing rest is a no-op')
assert.equal(rest.state, 'rest', 'functions never change their input')

// go() pins exactly for hover, and ignores unknown states
assert.equal(M.go(rest, 'hover').pinned, true)
for (const s of M.STATES) if (s !== 'hover') assert.equal(M.go(pinned, s).pinned, false, s + ' is never pinned')
assert.equal(M.go(rest, 'bogus'), rest, 'unknown states are refused')
assert.ok(!M.isState('bogus') && M.isState('cc'))
// pointer events only act from rest and hover
const cc = M.go(rest, 'cc')
assert.equal(M.enter(cc), cc)
assert.equal(M.leave(cc), cc)
assert.equal(M.click(cc), cc)

// ---- panelOpen -------------------------------------------------------------------
const open = M.STATES.filter(s => M.panelOpen(M.go(rest, s)))
assert.deepEqual(open.sort(), ['cal', 'cc', 'hover', 'launcher', 'polkit', 'power'].sort(), 'panels plus pinned hover')
assert.equal(M.panelOpen(hover), false, 'unpinned hover is not a panel')
for (const s of ['rest', 'notif', 'osd', 'dict', 'flash']) assert.equal(M.panelOpen(M.go(rest, s)), false, s + ' is not a panel')
assert.deepEqual(M.PANELS.slice().sort(), ['cal', 'cc', 'launcher', 'polkit', 'power'])

// ---- timers ----------------------------------------------------------------------
assert.deepEqual(M.TIMERS, { notif: 4200, osd: 1400, flash: 1400 })
const osd1 = M.go(rest, 'osd')
assert.equal(osd1.timer, 1400)
const osd2 = M.go(osd1, 'osd')
assert.equal(osd2.timer, 1400)
assert.ok(osd2.seq > osd1.seq, 'every go() restarts the timer')
assert.equal(M.expire(osd2, osd1.seq), osd2, 'a timer from before the latest go() is ignored')
assert.equal(M.expire(osd2, osd2.seq).state, 'rest', 'the current timer returns to rest')
assert.equal(M.go(rest, 'notif').timer, 4200)
assert.equal(M.go(rest, 'hover').timer, 0)
assert.equal(M.expire(pinned, pinned.seq), pinned, 'states without a timer never expire')
const notif = M.go(rest, 'notif')
assert.equal(M.expire(M.go(notif, 'cc'), notif.seq).state, 'cc', 'leaving a timed state cancels its timer')
assert.equal(M.DWELL, 250, 'hover opens after a 250 ms dwell (DECISION 1)')
assert.equal(M.LEAVE_GRACE, 150)

// ---- priority --------------------------------------------------------------------
assert.deepEqual(M.PRIORITY, ['polkit', 'panel', 'dict', 'osd', 'notif', 'flash', 'live', 'rest'])
const rank = s => M.rank(M.go(rest, s))
assert.ok(rank('polkit') < rank('cc') && rank('cc') === rank('launcher') && rank('cc') === rank('hover'))
assert.ok(rank('cc') < rank('dict') && rank('dict') < rank('osd') && rank('osd') < rank('notif') && rank('notif') < rank('flash'))
assert.ok(rank('flash') < rank('rest'))
assert.equal(M.rank(hover), M.rank(rest), 'unpinned hover ranks with rest')

// ---- geometry --------------------------------------------------------------------
assert.equal(M.radiusFor(38), 19)
assert.equal(M.radiusFor(44), 22)
assert.equal(M.radiusFor(48), 24)
assert.equal(M.radiusFor(136), 28, 'radius min(28, h/2)')
assert.equal(M.radiusFor(560), 28)
const dims = { rest: [360, 38], hover: [720, 136], launcher: [760, 472], cc: [760, 560], cal: [400, 368], notif: [520, 92],
    osd: [340, 44], dict: [360, 48], polkit: [480, 272], power: [600, 156], flash: [360, 52] }
assert.deepEqual(M.DIMS, dims)
for (const s of M.STATES) assert.ok(M.DIMS[s], s + ' has a size')
assert.equal(M.WINDOW_HEIGHT, 608, 'window: 8 + 560 + 40')
assert.deepEqual(M.size(rest, 0), [360, 38])
assert.deepEqual(M.size(rest, 420), [420, 38], 'rest hugs its content')
assert.deepEqual(M.size(rest, 300), [360, 38], 'with a 360 minimum')
assert.deepEqual(M.size(pinned, 420), [720, 136], 'hover does not hug')
// The hug rule: four 22 px letters (94) and a 5-glyph clock fit in 360.
assert.equal(M.restWidth(40.3, 4 * 22 + 3 * 2, 0), 360)
assert.equal(M.restWidth(40.3, 94, 180), 482, 'a wide right zone widens both sides, clock stays centred')
assert.equal(M.restWidth(41, 160, 20) % 2, 0, 'even, so the pill sits on whole pixels')
assert.equal(M.restWidth(41, 160, 20), 2 * Math.ceil((41 + 2 * (16 + 24 + 160)) / 2))
assert.equal(M.restWidth(undefined, undefined, undefined), 360)
console.log('ISLAND_MACHINE_PASS')
