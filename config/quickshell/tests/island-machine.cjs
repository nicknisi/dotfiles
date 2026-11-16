// lib/IslandMachine.js: the island's states (PLAN M1, M2, M3).
// enter/leave/pin, the panelOpen set, timers restarting on go(), and the
// sizes, radius and rest-width rules the island morphs by; M2 adds the Crew's
// crew panel (hover-like, never narrower than the rest pill), the hail that
// peeks, holds under the pointer and pins on a click, vibes, and offer(); M3
// adds the arbitration between the island's own transients (polkit > open
// panel > dict > osd > notif > flash > live > rest), the notification queue,
// the return to the interrupted state, and the notification timeout rule.
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
assert.deepEqual(open.sort(), ['cal', 'cc', 'crew', 'hover', 'launcher', 'polkit', 'power', 'themes', 'wallpapers'].sort(), 'panels plus pinned hover and crew')
assert.equal(M.panelOpen(hover), false, 'unpinned hover is not a panel')
for (const s of ['rest', 'notif', 'osd', 'dict', 'flash', 'hail', 'vibes', 'moment']) assert.equal(M.panelOpen(M.go(rest, s)), false, s + ' is not a panel')
assert.deepEqual(M.PANELS.slice().sort(), ['cal', 'cc', 'launcher', 'polkit', 'power', 'themes', 'wallpapers'])

// ---- timers ----------------------------------------------------------------------
assert.deepEqual(M.TIMERS, { notif: 4200, osd: 1400, flash: 1400, hail: 5000, vibes: 4000, moment: 5000 })
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
assert.deepEqual(M.PRIORITY, ['polkit', 'panel', 'dict', 'osd', 'notif', 'hail', 'flash', 'vibes', 'moment', 'live', 'rest'])
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
    crew: [460, 332], hail: [360, 52], vibes: [240, 44], themes: [1240, 600], wallpapers: [780, 444], moment: [360, 40] }
assert.deepEqual(M.DIMS, dims)
for (const s of M.STATES) assert.ok(M.DIMS[s], s + ' has a size')
assert.equal(M.WINDOW_HEIGHT, 648, 'window: 8 + 600 (the themes picker, M7) + 40')
assert.equal(M.TALLEST, Math.max(...Object.values(M.DIMS).map(d => d[1])), 'the tallest state sets the window')
assert.deepEqual(M.size(rest, 0), [360, 38])
assert.deepEqual(M.size(rest, 420), [420, 38], 'rest hugs its content')
assert.deepEqual(M.size(rest, 300), [360, 38], 'with a 360 minimum')
assert.deepEqual(M.size(pinned, 420), [720, 136], 'hover keeps 720 for any pill up to 720')
assert.deepEqual(M.size(pinned, 801), [804, 136], 'a rest pill wider than 720 widens hover with it (M3)')
// The hug rule: four 22 px letters (94) and a 5-glyph clock fit in 360.
assert.equal(M.restWidth(40.3, 4 * 22 + 3 * 2, 0), 360)
assert.equal(M.restWidth(40.3, 94, 180), 482, 'a wide right zone widens both sides, clock stays centred')
assert.equal(M.restWidth(41, 160, 20) % 2, 0, 'even, so the pill sits on whole pixels')
assert.equal(M.restWidth(41, 160, 20), 2 * Math.ceil((41 + 2 * (16 + 24 + 160)) / 2))
assert.equal(M.restWidth(undefined, undefined, undefined), 360)
// The live segment sits 12 right of the clock, the right zone 12 past it.
assert.equal(M.restWidth(40.3, 94, 0, 0), M.restWidth(40.3, 94, 0), 'no segment: the M1 rule')
assert.equal(M.restWidth(40.3, 94, 0, 150), 2 * Math.ceil((40.3 + 2 * (16 + 12 + 150)) / 2), 'a segment alone')
assert.equal(M.restWidth(40.3, 94, 64, 150), 2 * Math.ceil((40.3 + 2 * (16 + 12 + 150 + 12 + 64)) / 2), 'segment, then Context and bots')
assert.equal(M.restWidth(40.3, 300, 0, 20), 2 * Math.ceil((40.3 + 2 * (16 + 24 + 300)) / 2), 'a wider left zone still sets the width')

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

// Sizes: the crew panel hugs its height under the window's 600, the cards their
// width. The crew panel's width is the rest pill's when that is wider than 460,
// so the bots that opened it stay under the pointer (M2 review).
assert.deepEqual(M.size(crewPinned, 0, 332), [460, 332])
assert.deepEqual(M.size(crewPinned, 392, 332), [460, 332], 'crew-4: the 392 pill grows into the 460 panel')
assert.deepEqual(M.size(crewPinned, 608, 536), [608, 536], 'a 608 pill keeps its width in the panel')
assert.deepEqual(M.size(crewPinned, 501, 0), [504, 332], 'rounded up to a multiple of 4 like the pill')
assert.deepEqual(M.size(crewPinned, 999, 900), [1000, 600], 'the crew panel never outgrows the window')
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
assert.deepEqual(M.size(M.go(rest, 'flash'), 201), [204, 52], 'flash hugs its words with no minimum')
const launcher = M.go(rest, 'launcher')
assert.deepEqual(M.size(launcher, 760, 472), [760, 472], 'M5: the palette is its content, 760 x 472')
assert.deepEqual(M.size(launcher), [760, 472], 'before it measures, the launcher takes its default')
assert.deepEqual(M.size(launcher, 300, 172.5), [300, 173], 'a picker hugs both sides, with no minimum')
assert.deepEqual(M.size(launcher, 421, 900), [424, 600], 'rounded to the width step and capped at the window')
// The pickers (M7): their content's size, open panels under polkit, and the
// launcher, cc or a banner they cover comes back the same way.
const pickItem = (id, timeout) => ({ id, timeout })
const themes = M.go(rest, 'themes'), walls = M.go(rest, 'wallpapers')
assert.deepEqual(M.size(themes, 1240, 600), [1240, 600], 'M7: the themes panel, 1240 x 600')
assert.deepEqual(M.size(themes), [1240, 600], 'before it measures, the themes panel takes its default')
assert.deepEqual(M.size(walls, 780, 252), [780, 252], 'a theme with one row of wallpapers is shorter')
assert.deepEqual(M.size(walls, 780, 444), [780, 444])
assert.deepEqual(M.size(themes, 1088.5, 600), [1092, 600], 'a narrow screen\'s 7 columns round to the width step')
assert.ok(M.panelOpen(themes) && M.panelOpen(walls) && !themes.pinned, 'both are open panels, never pinned')
assert.deepEqual(['themes', 'wallpapers'].map(s => M.rank(M.go(rest, s))), [1, 1], 'they rank as an open panel')
assert.equal(M.offer(themes, 'notif', pickItem(3, 4200)), themes, 'a banner waits behind the picker')
{
  const tabbed = M.cover(themes, 'wallpapers')
  assert.deepEqual([tabbed.state, tabbed.pinned, tabbed.timer], ['wallpapers', false, 0], 'Tab: themes -> wallpapers in place')
  const crit = M.notify(rest, pickItem(9, 0))
  const t = M.cover(crit, 'themes')
  assert.deepEqual([t.state, t.queue], ['themes', [pickItem(9, 0)]], 'the picker covers a critical banner, which waits')
  assert.deepEqual([M.settle(M.dismiss(t), {}).state], ['notif'], 'and shows again once the picker closes')
}
// The launcher covers a banner without losing it (M5 review): the one
// showing, and what it interrupted, wait on the queue for the palette to close.
{
  const it = (id, timeout) => ({ id, timeout })
  const crit = M.notify(rest, it(7, 0))
  assert.equal(crit.state, 'notif')
  const pal = M.cover(crit, 'launcher')
  assert.deepEqual([pal.state, pal.item, pal.back, pal.queue], ['launcher', undefined, undefined, [it(7, 0)]], 'the critical banner waits')
  assert.deepEqual(M.notifIds(pal), [7], 'and stays held, so it is not expired')
  assert.equal(M.settle(pal, {}), pal, 'nothing shows over the palette')
  const back = M.settle(M.dismiss(pal), {})
  assert.deepEqual([back.state, back.item, back.timer], ['notif', it(7, 0), 0], 'closing the palette shows it again, still untimed')
  // The OSD over banner 1, banner 2 waiting: 1 rejoins the queue behind 2.
  const osd = M.notify(M.offer(M.notify(rest, it(1, 4200)), 'osd'), it(2, 4200))
  assert.deepEqual([osd.state, osd.back.item.id, osd.queue.map(x => x.id)], ['osd', 1, [2]])
  const p2 = M.cover(osd, 'launcher')
  assert.deepEqual([p2.back, p2.queue.map(x => x.id)], [undefined, [2, 1]], 'queued after what was waiting, the covered one newest')
  const after = M.settle(M.dismiss(p2), {})
  assert.deepEqual([after.item.id, after.queue.map(x => x.id)], [1, [2]], 'the one the palette covered comes back first, then the rest')
  assert.deepEqual(M.cover(rest, 'launcher'), M.go(rest, 'launcher'), 'with nothing showing it is go()')
  assert.equal(M.cover(rest, 'nope'), rest)
  // M5 x M6: the control center and the power menu open over a banner the
  // same way, and the palette and cc hand the island to each other with the
  // queue kept and no stop at rest.
  for (const s of ['cc', 'power']) {
    const c = M.cover(crit, s)
    assert.deepEqual([c.state, c.item, c.queue], [s, undefined, [it(7, 0)]], s + ' covers the critical banner')
    assert.equal(M.settle(c, {}), c, 'nothing shows over ' + s)
    assert.equal(M.settle(M.dismiss(c), {}).item.id, 7, 'closing ' + s + ' shows it again')
  }
  const cc = M.cover(crit, 'cc')
  const pal2 = M.cover(cc, 'launcher')
  assert.deepEqual([pal2.state, pal2.queue], ['launcher', [it(7, 0)]], 'cc -> launcher: straight there, the banner still waiting')
  const back2 = M.cover(pal2, 'cc')
  assert.deepEqual([back2.state, back2.queue], ['cc', [it(7, 0)]], 'launcher -> cc: the same')
  assert.deepEqual(['launcher', 'cc', 'power'].map(s => M.rank(M.go(rest, s))), [1, 1, 1], 'all three rank as an open panel, under polkit')
  const open = M.go(rest, 'cc')
  assert.equal(M.offer(open, 'osd'), open, 'the OSD is dropped under cc')
}

// ---- M3: notification timeouts (DECISION 2, island-modes 9.1) --------------------
assert.equal(M.notifTimeout(3000, false), 3000, 'the sender timeout when it sets one')
assert.equal(M.notifTimeout(-1, false), 4200, 'else the board\'s 4200')
assert.equal(M.notifTimeout(0, false), 4200, 'a 0 ("never") reads as the default, as the toasts always did')
assert.equal(M.notifTimeout(undefined, false), 4200)
assert.equal(M.notifTimeout(3000, true), 0, 'critical never expires')
assert.equal(M.notifTimeout(-1, true), 0)

// ---- M3: priority among the island's own transients ------------------------------
// polkit > open panel > dict > osd > notif > flash > live > rest
const chain = ['polkit', 'cc', 'dict', 'osd', 'notif', 'flash', 'rest']
for (let i = 0; i < chain.length - 1; i++) assert.ok(rank(chain[i]) < rank(chain[i + 1]), chain[i] + ' outranks ' + chain[i + 1])
assert.ok(M.PRIORITY.indexOf('flash') < M.PRIORITY.indexOf('live') && M.PRIORITY.indexOf('live') < M.PRIORITY.indexOf('rest'), 'flash > live > rest')
const item = (id, timeout) => ({ id: id, timeout: timeout === undefined ? 4200 : timeout })
const n1 = M.notify(rest, item(1))
assert.deepEqual(n1, { state: 'notif', pinned: false, timer: 4200, seq: 1, item: item(1) }, 'a notification takes rest')
assert.equal(M.notify(rest, item(7, 2500)).timer, 2500, 'with its own timeout')
assert.equal(M.notify(rest, item(8, 0)).timer, 0, 'a critical one (timeout 0) has no timer')
// What outranks a notif keeps the island; the notif waits.
for (const from of [pinned, crewPinned, M.go(rest, 'cc'), M.go(rest, 'cal'), M.go(rest, 'dict'), M.go(rest, 'osd')]) {
    const q = M.notify(from, item(2))
    assert.equal(q.state, from.state, 'a notif waits behind ' + from.state)
    assert.equal(q.seq, from.seq, 'queueing does not restart the ' + from.state + ' timer')
    assert.deepEqual(q.queue, [item(2)])
}
// A notif takes over unpinned hover, a hail and flash, and returns to the first two.
for (const from of [hover, crewHover, hail, hailHeld]) {
    const n = M.notify(from, item(3))
    assert.equal(n.state, 'notif', 'a notif takes ' + from.state)
    assert.equal(n.back.state, from.state, 'and remembers it')
    const after = M.expire(n, n.seq)
    assert.equal(after.state, from.state, 'a notif ending returns to the interrupted ' + from.state)
    assert.equal(after.pinned, from.pinned)
    assert.ok(after.seq > n.seq, 'with its timer restarted')
    assert.equal(after.timer, from.timer)
}
assert.equal(M.notify(M.go(rest, 'flash'), item(3)).back, undefined, 'a flash is not returned to')
assert.equal(M.notify(M.go(rest, 'vibes'), item(3)).back, undefined, 'nor vibes')
// The queue: one at a time, newest first, each with its own timer.
let q = M.notify(n1, item(2))
q = M.notify(q, item(3, 6000))
assert.equal(q.state, 'notif')
assert.equal(q.item.id, 1, 'the one showing keeps the island')
assert.equal(q.seq, n1.seq, 'new arrivals do not restart its timer')
assert.deepEqual(M.notifIds(q), [1, 2, 3])
q = M.expire(q, q.seq)
assert.deepEqual([q.state, q.item.id, q.timer], ['notif', 3, 6000], 'the newest waiting shows next, with its timeout')
assert.deepEqual(q.queue, [item(2)])
q = M.finish(q)
assert.deepEqual([q.state, q.item.id], ['notif', 2], 'Dismiss or Open shows the next one')
assert.equal(q.queue, undefined, 'the queue empties')
q = M.finish(q)
assert.equal(q.state, 'rest', 'the last one returns to rest')
assert.deepEqual(M.notifIds(q), [])
// A queued notification shows once the panel in front of it closes (settle).
let p = M.notify(pinned, item(4))
assert.equal(M.settle(p, {}), p, 'settle leaves a panel alone')
p = M.dismiss(p)
assert.deepEqual([p.state, p.queue.length], ['rest', 1], 'closing the panel keeps the queue')
p = M.settle(p, {})
assert.deepEqual([p.state, p.item.id, p.queue], ['notif', 4, undefined], 'settle shows it')
assert.equal(M.settle(M.notify(M.go(rest, 'osd'), item(5)), {}).state, 'osd', 'settle waits out the OSD')
assert.equal(M.settle(M.dismiss(M.notify(pinned, item(5))), { blocked: true }).state, 'rest', 'and holds while a hand-off covers the island')
// The OSD interrupts a notif and returns to it; a new OSD restarts its timer
// and keeps what it returns to.
let o = M.offer(n1, 'osd')
assert.deepEqual([o.state, o.timer, o.back.state, o.back.item.id], ['osd', 1400, 'notif', 1], 'the OSD takes a notif and keeps it')
const o2 = M.offer(o, 'osd')
assert.ok(o2.seq > o.seq && o2.back === o.back, 'a repeated OSD restarts its timer, same return')
o = M.expire(o2, o2.seq)
assert.deepEqual([o.state, o.item.id, o.timer], ['notif', 1, 4200], 'back to the notif, its timer restarted')
assert.equal(M.offer(M.go(rest, 'dict'), 'osd').state, 'dict', 'dictation outranks the OSD: it is dropped')
assert.equal(M.offer(pinned, 'osd'), pinned, 'an open panel drops the OSD')
assert.equal(M.offer(M.go(rest, 'osd'), 'flash').state, 'osd', 'the OSD drops a flash')
assert.equal(M.offer(n1, 'flash'), n1, 'a notif drops a flash')
assert.equal(M.offer(rest, 'flash').state, 'flash', 'a flash takes rest')
assert.equal(M.expire(M.offer(rest, 'flash'), M.offer(rest, 'flash').seq).state, 'rest', 'and returns to it after 1400 ms')
// Dictation: a condition, not a timer. settle opens it over a notif or hover
// and finishes it when the condition ends, back to what it interrupted.
let d = M.settle(n1, { dict: true })
assert.deepEqual([d.state, d.timer, d.back.state], ['dict', 0, 'notif'], 'dictation takes a notif and keeps it')
assert.equal(M.settle(d, { dict: true }), d, 'settle is idempotent')
d = M.notify(d, item(9))
assert.deepEqual([d.state, d.queue.length], ['dict', 1], 'a notif arriving during dictation waits')
d = M.settle(d, { dict: false })
assert.deepEqual([d.state, d.item.id], ['notif', 1], 'dictation ending returns to the notif it covered')
assert.deepEqual(d.queue, [item(9)], 'and the waiting one stays queued')
assert.equal(M.settle(pinned, { dict: true }), pinned, 'dictation waits behind an open panel')
assert.equal(M.settle(M.dismiss(pinned), { dict: true }).state, 'dict', 'and shows once it closes')
assert.equal(M.settle(M.go(rest, 'dict'), { dict: false }).state, 'rest')
// Polkit outranks everything and returns to the panel it covered.
const pk = M.offer(M.go(rest, 'cc'), 'polkit')
assert.deepEqual([pk.state, pk.back.state], ['polkit', 'cc'])
// A paused notif (M3 review): the pointer coming to it pauses its timer with
// what it has left; leaving runs it on for that, never under RESUME_MIN.
const nh = M.enter(n1, undefined, 3100)
assert.deepEqual([nh.state, nh.held, nh.timer, nh.left, nh.item.id], ['notif', true, 0, 3100, 1], 'the pointer on a notif pauses it with 3100 ms left')
assert.ok(nh.seq > n1.seq, 'pausing starts a new seq, so the running timer cannot fire')
assert.ok(!M.closesOnLeave(nh) && M.resumesOnLeave(nh) && M.watchesLeave(nh) && !M.watchesLeave(n1), 'leaving resumes a paused notif; it never closes it')
const nr = M.leave(nh)
assert.deepEqual([nr.state, nr.held, nr.left, nr.timer, nr.item.id], ['notif', undefined, undefined, 3100, 1], 'leaving runs it on for what it had left')
assert.ok(nr.seq > nh.seq, 'a new seq: the host starts the timer again')
assert.equal(M.leave(M.enter(n1, undefined, 40)).timer, M.RESUME_MIN, 'a glance at its last moments leaves it RESUME_MIN')
assert.equal(M.enter(n1).left, n1.timer, 'without a count from the host it keeps its whole timer')
assert.equal(M.enter(nh, undefined, 10), nh, 'entering a paused notif again changes nothing')
assert.equal(M.leave(n1), n1, 'a running notif ignores the pointer leaving')
assert.equal(M.enter(M.notify(rest, item(8, 0))).held, undefined, 'a critical notif has no timer to pause')
// Interrupted while paused, it comes back paused, still with what it had left.
const nho = M.offer(nh, 'osd')
const nhb = M.expire(nho, nho.seq)
assert.deepEqual([nhb.state, nhb.held, nhb.left, nhb.timer], ['notif', true, 3100, 0], 'the OSD ending returns to the paused notif')
assert.equal(M.leave(nhb).timer, 3100)
assert.equal(M.freeze(nh).left, 3100, 'freeze keeps it')
assert.equal(M.enqueue(nh, item(2)).left, 3100, 'and so does a notification queueing behind it')
// The sender closing a notification takes it out wherever it is.
let g = M.notify(M.notify(n1, item(2)), item(3))
assert.deepEqual(M.notifIds(M.drop(g, 2)), [1, 3], 'out of the queue')
g = M.drop(g, 1)
assert.deepEqual([g.state, g.item.id], ['notif', 3], 'off the island: the next one shows')
assert.equal(M.drop(g, 42), g, 'an unknown id changes nothing')
const covered = M.offer(n1, 'osd')
const uncovered = M.drop(covered, 1)
assert.deepEqual([uncovered.state, uncovered.back], ['osd', undefined], 'out of the interrupted chain')
assert.equal(M.expire(uncovered, uncovered.seq).state, 'rest', 'so the OSD returns to rest')
// go() keeps the queue and drops what was showing and its return.
const gone = M.go(M.notify(M.offer(n1, 'osd'), item(2)), 'hover')
assert.deepEqual([gone.item, gone.back, gone.queue.length], [undefined, undefined, 1])
// freeze() stops a timer and changes nothing else (`island hold`).
const fz = M.freeze(o2)
assert.deepEqual([fz.state, fz.timer, fz.back], ['osd', 0, o2.back])
assert.equal(M.expire(fz, fz.seq), fz, 'a frozen state never expires')
for (const r of [rest, n1, q, d, g, fz, nh, nr, nhb]) for (const k of ['held', 'left', 'item', 'back', 'queue']) assert.ok(!(k in r) || r[k] !== undefined, 'no undefined ' + k)
// Two screens' islands hold the same notification (M3 review): it is
// released, so expired, only when the last of them lets go.
const A = {}, B = {}
let h = M.holdIds([], A, [1, 2])
h = M.holdIds(h.holders, B, [1, 2])
assert.deepEqual(h.released, [], 'holding releases nothing')
h = M.holdIds(h.holders, A, [2])
assert.deepEqual(h.released, [], 'one island letting go of 1 while the other holds it (paused) releases nothing')
h = M.holdIds(h.holders, B, [2])
assert.deepEqual(h.released, [1], 'the last one letting go releases it')
h = M.holdIds(h.holders, A, [])
assert.deepEqual([h.released, h.holders.length], [[], 1], 'B still holds 2')
h = M.holdIds(h.holders, B, [])
assert.deepEqual([h.released, h.holders], [[2], []], 'and its release empties the list')
assert.deepEqual(M.holdIds(undefined, A, [3]).holders, [{ owner: A, ids: [3] }])

// ---- M9: a look's moment, and the notch form -----------------------------------
// The moment peeks for 5 s like a hail, ranks just under vibes, takes rest or
// unpinned hover, waits for nothing (dropped behind anything else), and is
// never returned to.
const mo = M.offer(rest, 'moment')
assert.deepEqual([mo.state, mo.timer, mo.pinned], ['moment', 5000, false], 'a moment peeks from rest')
assert.equal(M.offer(M.go(rest, 'cc'), 'moment').state, 'cc', 'behind an open panel it is dropped')
assert.equal(M.offer(M.offer(rest, 'vibes'), 'moment').state, 'vibes', 'vibes outranks it')
assert.equal(M.offer(mo, 'vibes').state, 'vibes', 'and takes over from it')
assert.equal(M.offer(mo, 'hail').state, 'hail', 'a hail takes over from it')
assert.equal(M.finish(M.offer(mo, 'hail')).state, 'rest', 'and does not come back to it')
assert.equal(M.expire(mo, mo.seq).state, 'rest', 'its timer returns to rest')
assert.equal(M.panelOpen(mo), false, 'not a panel')
assert.deepEqual(M.size(mo, 431), [432, 40], 'it hugs its line')
// The pointer on a peeking moment acts as on the rest pill (M9 review): the
// dwell opens hover, a click pins it.
assert.deepEqual([M.enter(mo).state, M.enter(mo).pinned], ['hover', false], 'resting on a moment opens hover')
assert.deepEqual([M.enter(mo, 'crew').state], ['crew'])
assert.deepEqual([M.click(mo).state, M.click(mo).pinned], ['hover', true], 'a click on a moment pins hover')
// A look's rest bar hugs its row with no 360 floor; the plain pill keeps it.
assert.deepEqual(M.size(rest, 301), [360, 38], 'the plain pill: at least 360')
assert.deepEqual(M.size(rest, 301, 0, 0), [304, 38], 'a look: its own width, to the step')
assert.deepEqual(M.size(M.go(rest, 'hover'), 301, 0, 0), [304, 136], 'min replaces the state minimum')
// The notch silhouette (island-modes 8.1): the Island board's 444 x 40 path,
// moved left by its 12 px shoulder.
assert.equal(M.notchRadius(40), 18, 'the rest notch rounds 18')
assert.equal(M.notchRadius(136), 28, 'tall states 28')
assert.equal(M.notchRadius(48), 21.6)
assert.equal(M.notchPath(420, 40, 18), 'M -12 0 L 432 0 Q 420 0 420 12 L 420 22 Q 420 40 402 40 L 18 40 Q 0 40 0 22 L 0 12 Q 0 0 -12 0 Z')
const board = 'M0 0 L444 0 Q432 0 432 12 L432 22 Q432 40 414 40 L30 40 Q12 40 12 22 L12 12 Q12 0 0 0 Z'
const nums = p => (p.match(/-?\d+(\.\d+)?/g) || []).map(Number)
const shifted = nums(M.notchPath(420, 40, 18))
const want = nums(board)
assert.equal(shifted.length, want.length, 'same commands as the board')
// x and y alternate in every command's pairs; the board's x are 12 to the right.
for (let i = 0; i < want.length; i += 2) {
    assert.equal(shifted[i] + 12, want[i], 'x ' + i)
    assert.equal(shifted[i + 1], want[i + 1], 'y ' + i)
}
assert.equal(M.notchBodyPath(420, 40, 18), 'M 0 0 L 420 0 L 420 22 Q 420 40 402 40 L 18 40 Q 0 40 0 22 Z', 'the content mask has no shoulders')
// The hairline's corners are circles of the body's radius (the ClippingRectangle's
// own), so the ring never leaves the fill at mid-arc (M9 review).
assert.equal(M.notchRingPath(420, 40, 18, 1), 'M 419.5 12 L 419.5 22 A 17.5 17.5 0 0 1 402 39.5 L 18 39.5 A 17.5 17.5 0 0 1 0.5 22 L 0.5 12', 'the hairline: sides and bottom, half a stroke in, circular corners')
assert.equal(M.notchRingPath(420, 40, 0, 2), 'M 419 12 L 419 39 L 1 39 L 1 12', 'a square body (Arcade) has a square ring')
// Every point of the arc is R - i from the corner's centre: inside the fill.
{
    const R = 18, i = 0.5, W = 420, H = 40
    for (let k = 0; k <= 8; k++) {
        const a = (k / 8) * Math.PI / 2
        const x = W - R + (R - i) * Math.cos(a), y = H - R + (R - i) * Math.sin(a)
        assert.ok(Math.hypot(x - (W - R), y - (H - R)) <= R - i + 1e-9 && x <= W && y <= H, 'arc point ' + k + ' inside the body')
    }
}
assert.ok(!/NaN|undefined/.test(M.notchPath(undefined, null, 'x')), 'junk in, a path out')
assert.equal(M.NOTCH_REST_HEIGHT, 40)
// The plain notch's rest body is the board's 420 between the shoulders (the
// view passes NOTCH_REST_MIN as `min`); wider content still widens it.
assert.equal(M.NOTCH_REST_MIN, 420)
assert.deepEqual(M.size(rest, 360, 0, M.NOTCH_REST_MIN), [420, 38], 'the notch at rest: 420, not the float\'s 360')
assert.deepEqual(M.size(rest, 441, 0, M.NOTCH_REST_MIN), [444, 38], 'and hugs past it, to the step')
console.log('ISLAND_MACHINE_PASS')
