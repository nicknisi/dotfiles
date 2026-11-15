// lib/IslandMachine.js: the island's states (PLAN M1, M2).
// enter/leave/pin, the panelOpen set, timers restarting on go(), and the
// sizes, radius and rest-width rules the island morphs by; M2 adds the Crew's
// crew panel (hover-like, never narrower than the rest pill), the hail that
// peeks, holds under the pointer and pins on a click, vibes, and offer().
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

// go() pins exactly for hover and crew, and ignores unknown states
assert.equal(M.go(rest, 'hover').pinned, true)
assert.equal(M.go(rest, 'crew').pinned, true)
for (const s of M.STATES) if (s !== 'hover' && s !== 'crew') assert.equal(M.go(pinned, s).pinned, false, s + ' is never pinned')
assert.equal(M.go(rest, 'bogus'), rest, 'unknown states are refused')
assert.ok(!M.isState('bogus') && M.isState('cc'))
// pointer events only act from rest and hover
const cc = M.go(rest, 'cc')
assert.equal(M.enter(cc), cc)
assert.equal(M.leave(cc), cc)
assert.equal(M.click(cc), cc)

// ---- panelOpen -------------------------------------------------------------------
const open = M.STATES.filter(s => M.panelOpen(M.go(rest, s)))
assert.deepEqual(open.sort(), ['cal', 'cc', 'crew', 'hover', 'launcher', 'polkit', 'power'].sort(), 'panels plus pinned hover and crew')
assert.equal(M.panelOpen(hover), false, 'unpinned hover is not a panel')
for (const s of ['rest', 'notif', 'osd', 'dict', 'flash', 'hail', 'vibes']) assert.equal(M.panelOpen(M.go(rest, s)), false, s + ' is not a panel')
assert.deepEqual(M.PANELS.slice().sort(), ['cal', 'cc', 'launcher', 'polkit', 'power'])

// ---- timers ----------------------------------------------------------------------
assert.deepEqual(M.TIMERS, { notif: 4200, osd: 1400, flash: 1400, hail: 5000, vibes: 4000 })
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
assert.deepEqual(M.PRIORITY, ['polkit', 'panel', 'dict', 'osd', 'notif', 'hail', 'flash', 'vibes', 'live', 'rest'])
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
    osd: [340, 44], dict: [360, 48], polkit: [480, 272], power: [600, 156], flash: [360, 52],
    crew: [460, 332], hail: [360, 52], vibes: [240, 44] }
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

// ---- the Crew (M2) ------------------------------------------------------------------
// The crew panel behaves like hover: the dwell opens it unpinned from the bots,
// leaving closes it, a click pins it.
const crewHover = M.enter(rest, 'crew')
assert.equal(crewHover.state, 'crew')
assert.equal(crewHover.pinned, false, 'the dwell on the bots opens the crew panel unpinned')
assert.equal(M.enter(rest).state, 'hover', 'without a target the dwell opens hover')
assert.equal(M.enter(rest, 'cc').state, 'hover', 'only hover-like states open on the dwell')
assert.equal(M.leave(crewHover).state, 'rest', 'leaving the unpinned crew panel returns to rest')
assert.equal(M.panelOpen(crewHover), false, 'unpinned crew is not a panel')
const crewPinned = M.click(rest, 'crew')
assert.equal(crewPinned.state, 'crew')
assert.ok(crewPinned.pinned && M.panelOpen(crewPinned), 'a click on the bots pins the crew panel')
assert.equal(M.leave(crewPinned), crewPinned, 'the pinned crew panel ignores the pointer leaving')
assert.ok(M.click(crewHover).pinned && M.click(crewHover).state === 'crew', 'a click on the open crew panel pins it')
assert.equal(M.click(crewPinned), crewPinned)
assert.equal(M.dismiss(crewPinned).state, 'rest')
assert.equal(M.rank(crewHover), M.rank(rest), 'unpinned crew ranks with rest')
assert.equal(M.rank(crewPinned), M.rank(M.go(rest, 'cc')), 'pinned crew ranks as a panel')

// A hail peeks for 5 s. The pointer resting on it holds it (timer stopped)
// without pinning it: a held hail is not a panel, so it takes neither the
// focus grab nor the keyboard (M2 review: a hail opening under the pointer
// pinned itself and Enter in the terminal below ran crew-jump). Leaving
// closes a held hail; a click pins it.
const hail = M.go(rest, 'hail')
assert.ok(!hail.pinned && hail.timer === 5000 && !hail.held)
const hailHeld = M.enter(hail)
assert.deepEqual(hailHeld, { state: 'hail', pinned: false, timer: 0, seq: hail.seq + 1, held: true }, 'resting on a peeking hail holds it')
assert.ok(hailHeld.seq > hail.seq, 'holding starts a new seq, so the peek timer cannot fire')
assert.equal(M.expire(hailHeld, hail.seq), hailHeld, 'the old peek timer is ignored')
assert.equal(M.expire(hail, hail.seq).state, 'rest', 'an untouched hail goes back to rest')
assert.equal(M.leave(hail), hail, 'leaving does not cut the peek short')
assert.ok(!M.panelOpen(hailHeld) && !M.panelOpen(hail), 'neither a held nor a peeking hail is a panel')
assert.equal(M.enter(hailHeld), hailHeld, 'entering again changes nothing')
assert.ok(M.closesOnLeave(hailHeld) && !M.closesOnLeave(hail), 'a held hail closes when the pointer leaves')
assert.equal(M.leave(hailHeld).state, 'rest')
const hailPinned = M.click(hailHeld)
assert.ok(hailPinned.pinned && !hailPinned.held && M.panelOpen(hailPinned), 'a click on a held hail pins it: grab and keyboard')
assert.equal(M.leave(hailPinned), hailPinned, 'a pinned hail ignores the pointer leaving')
assert.ok(!M.closesOnLeave(hailPinned))
assert.equal(M.enter(hailPinned), hailPinned)
assert.ok(M.click(hail).pinned, 'a click on the peeking hail card pins it')
assert.deepEqual(M.pin(hail), { state: 'hail', pinned: true, timer: 0, seq: hail.seq + 1 })
assert.equal(M.go(hailHeld, 'hail').held, undefined, 'a new hail is never held')
assert.ok(M.closesOnLeave(hover) && M.closesOnLeave(crewHover) && !M.closesOnLeave(pinned) && !M.closesOnLeave(rest))
assert.equal(M.go(rest, 'vibes').timer, 4000, 'vibes shows for 4 s')

// offer(): a hail takes rest, unpinned hover or crew, flash or vibes, and waits
// behind a panel, dict, osd or notif; vibes only takes what ranks below it.
for (const from of [rest, hover, crewHover, M.go(rest, 'flash'), M.go(rest, 'vibes'), hail, hailHeld])
    assert.equal(M.offer(from, 'hail').state, 'hail', 'a hail takes ' + from.state + (from.pinned ? ' (pinned)' : ''))
for (const from of [pinned, crewPinned, hailPinned, M.go(rest, 'cc'), M.go(rest, 'notif'), M.go(rest, 'osd'), M.go(rest, 'dict')])
    assert.equal(M.offer(from, 'hail'), from, 'a hail waits behind ' + from.state + (from.pinned ? ' (pinned)' : ''))
assert.equal(M.offer(rest, 'vibes').state, 'vibes')
assert.equal(M.offer(hover, 'vibes').state, 'vibes', 'vibes may replace unpinned hover')
assert.equal(M.offer(hail, 'vibes'), hail, 'vibes never cuts a hail short by itself')
assert.equal(M.offer(rest, 'bogus'), rest)

// Sizes: the crew panel hugs its height under the window's 560, the cards their
// width. The crew panel's width is the rest pill's when that is wider than 460,
// so the bots that opened it stay under the pointer (M2 review).
assert.deepEqual(M.size(crewPinned, 0, 332), [460, 332])
assert.deepEqual(M.size(crewPinned, 392, 332), [460, 332], 'crew-4: the 392 pill grows into the 460 panel')
assert.deepEqual(M.size(crewPinned, 608, 536), [608, 536], 'a 608 pill keeps its width in the panel')
assert.deepEqual(M.size(crewPinned, 501, 0), [504, 332], 'rounded up to a multiple of 4 like the pill')
assert.deepEqual(M.size(crewPinned, 999, 900), [1000, 560], 'the crew panel never outgrows the window')
assert.deepEqual(M.size(crewPinned), [460, 332], 'before it measures, the panel takes its default')
for (const w of [360, 392, 460, 492, 504, 600, 608])
    assert.ok(M.size(crewPinned, w, 332)[0] >= M.size(rest, w)[0], 'the panel is never narrower than a ' + w + ' rest pill')
assert.deepEqual(M.size(hail, 401), [404, 52], 'the hail card hugs its width, rounded up to a multiple of 4')
assert.deepEqual(M.size(M.go(rest, 'vibes'), 213.4), [216, 44])
assert.deepEqual(M.size(hail, 0), [360, 52])
assert.deepEqual(M.size(rest, 361), [364, 38], 'a hugged rest width too')
assert.deepEqual(M.size(rest, 390), [392, 38], 'crew-4 on the rest pill')
// Centred on a 1920 logical screen at scale 1.5, every hugged or fixed width
// puts x on a whole device pixel.
for (const w of [361, 390, 401, 213.4, 455].map(v => M.size(hail, v)[0]).concat(Object.values(M.DIMS).map(d => d[0])))
    assert.equal(((1920 - w) / 2 * 1.5) % 1, 0, w + ' wide lands on a whole device pixel at 1.5')
assert.equal(M.radiusFor(52), 26, 'the hail card is fully round at 26')
assert.equal(M.radiusFor(44), 22)
console.log('ISLAND_MACHINE_PASS')
