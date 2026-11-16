// lib/NightLight.js: the night light's rules (NightLight.qml). Schedule edges
// across midnight and over both daylight-saving nights, the manual override
// until the next edge, hyprctl's answers as hyprsunset 0.4.0 gives them, and
// hyprsunset.conf's profiles firing between two ticks. In a zone with
// daylight saving (America/Chicago: 2026-11-01 and 2027-03-14), so an edge
// built by adding hours would show.
process.env.TZ = 'America/Chicago'
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const N = require('../lib/NightLight.js')

// Local wall-clock time, built the way the rules build edges.
const at = (y, mo, d, h, mi) => new Date(y, mo - 1, d, h, mi, 0, 0).getTime()
const hm = ms => { const d = new Date(ms); return [d.getMonth() + 1, d.getDate(), d.getHours(), d.getMinutes()] }

// ---- times and warmth ----
assert.equal(N.parseTime('20:00'), 1200)
assert.equal(N.parseTime('7:05'), 425)
for (const bad of ['24:00', '12:60', '', '2000', null, undefined, 'x:yz']) assert.equal(N.parseTime(bad), -1, 'junk time ' + bad)
assert.equal(N.formatTime(425), '07:05')
assert.equal(N.formatTime(-30), '23:30', 'wraps back over midnight')
assert.equal(N.formatTime(1440 + 15), '00:15')
assert.equal(N.time('7:5', '20:00'), '20:00', 'one-digit minutes are junk')
assert.equal(N.time('7:05', '20:00'), '07:05')
assert.equal(N.stepTime('23:30', 1, '07:00'), '00:00', 'a step over midnight wraps')
assert.equal(N.stepTime('00:00', -1, '07:00'), '23:30')
assert.equal(N.stepTime('20:10', 1, '07:00'), '20:30', 'snaps to the step going up')
assert.equal(N.stepTime('20:10', -1, '07:00'), '20:00', 'and going down')
assert.equal(N.stepTime('06:30', 1, '07:00'), '07:30', 'never onto the other end: the window cannot go empty')
assert.equal(N.stepTime('07:30', -1, '07:00'), '06:30')
assert.equal(N.kelvin(4000), 4000)
assert.equal(N.kelvin(2000), 2500, 'clamped to the warmest')
assert.equal(N.kelvin(9000), 6000, 'and to neutral')
assert.equal(N.kelvin(4049), 4000, 'on 100 K')
assert.equal(N.kelvin('junk'), 4000, 'the default for junk')
assert.equal(N.fraction(6000), 0, 'neutral at the left')
assert.equal(N.fraction(2500), 1, 'warmest at the right')
assert.equal(N.fromFraction(N.fraction(4000)), 4000, 'the slider round-trips')
assert.equal(N.fromFraction(N.fraction(3700) + N.FRACTION_STEP), 3600, 'one slider step is 100 K warmer')

// ---- the window, across midnight ----
const f = N.parseTime('20:00'), t = N.parseTime('07:00')
const inside = m => N.inWindow(m, f, t)
assert.deepEqual([19 * 60 + 59, 20 * 60, 23 * 60 + 59, 0, 6 * 60 + 59, 7 * 60, 12 * 60].map(inside), [false, true, true, true, true, false, false], '20:00 to 07:00 covers midnight')
assert.ok(N.inWindow(9 * 60, 8 * 60, 17 * 60) && !N.inWindow(17 * 60, 8 * 60, 17 * 60), 'a daytime window')
assert.ok(!N.inWindow(600, 600, 600), 'From equal to To is an empty window')

const sched = { schedule: 'custom', from: '20:00', to: '07:00', manual: false, override: '', until: 0 }
// The next edge, strictly after now.
assert.deepEqual(hm(N.nextEdge(at(2026, 11, 14, 19, 0), '20:00', '07:00')), [11, 14, 20, 0], 'evening: tonight at 20:00')
assert.deepEqual(hm(N.nextEdge(at(2026, 11, 14, 21, 0), '20:00', '07:00')), [11, 15, 7, 0], 'night: 07:00 tomorrow')
assert.deepEqual(hm(N.nextEdge(at(2026, 11, 14, 23, 59), '20:00', '07:00')), [11, 15, 7, 0], 'one minute to midnight')
assert.deepEqual(hm(N.nextEdge(at(2026, 11, 15, 0, 30), '20:00', '07:00')), [11, 15, 7, 0], 'after midnight: this morning')
assert.deepEqual(hm(N.nextEdge(at(2026, 11, 15, 7, 0), '20:00', '07:00')), [11, 15, 20, 0], 'exactly on an edge: the next one')
assert.deepEqual(hm(N.nextEdge(at(2026, 12, 31, 22, 0), '20:00', '07:00')), [1, 1, 7, 0], 'over the new year')
assert.equal(N.nextEdge(at(2026, 11, 14, 12, 0), '10:00', '10:00'), 0, 'no edges in an empty window')

// effective(): on by the schedule, and when it next flips.
let e = N.effective(sched, at(2026, 11, 14, 19, 59))
assert.ok(!e.on && !e.scheduled && !e.overridden)
assert.deepEqual(hm(e.changesAt), [11, 14, 20, 0])
e = N.effective(sched, at(2026, 11, 14, 20, 0))
assert.ok(e.on && e.scheduled, 'on at 20:00')
assert.deepEqual(hm(e.changesAt), [11, 15, 7, 0], 'until 07:00 the next morning')
assert.ok(N.effective(sched, at(2026, 11, 15, 0, 0)).on, 'still on at midnight')
assert.ok(N.effective(sched, at(2026, 11, 15, 6, 59)).on, 'and at 06:59')
assert.ok(!N.effective(sched, at(2026, 11, 15, 7, 0)).on, 'off at 07:00')

// Without a schedule: the manual state, nothing ahead.
e = N.effective({ schedule: 'off', from: '20:00', to: '07:00', manual: true, override: 'off', until: at(2027, 1, 1, 0, 0) }, at(2026, 11, 14, 12, 0))
assert.ok(e.on && !e.overridden && e.changesAt === 0, 'the manual state rules, an override is ignored without a schedule')
assert.deepEqual(N.setOn({ schedule: 'off' }, at(2026, 11, 14, 12, 0), false), { manual: false, override: '', until: 0 })
assert.deepEqual(N.toggle({ schedule: 'off', manual: false }, 0), { manual: true, override: '', until: 0 })

// ---- the manual override, until the next schedule edge ----
// Off at 23:00, inside the window: off until 07:00, then the schedule (off
// by day) and on again at 20:00.
let s = Object.assign({}, sched, N.toggle(sched, at(2026, 11, 14, 23, 0)))
assert.equal(s.override, 'off')
assert.deepEqual(hm(s.until), [11, 15, 7, 0], 'the override holds to the next edge')
assert.ok(!N.effective(s, at(2026, 11, 14, 23, 30)).on && N.effective(s, at(2026, 11, 14, 23, 30)).overridden)
assert.ok(!N.effective(s, at(2026, 11, 15, 6, 59)).on, 'still off through the night')
e = N.effective(s, at(2026, 11, 14, 23, 30))
assert.deepEqual(hm(e.changesAt), [11, 15, 20, 0], 'the next flip is tomorrow evening: the override runs out into the same off')
e = N.effective(s, at(2026, 11, 15, 7, 0))
assert.ok(!e.on && !e.overridden, 'at 07:00 the override has run out')
assert.ok(N.effective(s, at(2026, 11, 15, 20, 0)).on, 'and the schedule turns it on that evening')
// On at noon, outside the window: on until 20:00, and the schedule keeps it
// on until 07:00.
s = Object.assign({}, sched, N.setOn(sched, at(2026, 11, 14, 12, 0), true))
assert.equal(s.override, 'on')
assert.deepEqual(hm(s.until), [11, 14, 20, 0])
e = N.effective(s, at(2026, 11, 14, 12, 0))
assert.ok(e.on && e.overridden)
assert.deepEqual(hm(e.changesAt), [11, 15, 7, 0], 'on until 07:00: the override runs into the window')
assert.ok(N.effective(s, at(2026, 11, 14, 22, 0)).on && !N.effective(s, at(2026, 11, 14, 22, 0)).overridden, 'the schedule holds it after 20:00')
// A toggle back to what the schedule says clears the override.
assert.deepEqual(N.setOn(s, at(2026, 11, 14, 13, 0), false), { override: '', until: 0 })
assert.deepEqual(N.setOn(sched, at(2026, 11, 14, 22, 0), true), { override: '', until: 0 }, 'on inside the window is no override')
// An override past its moment is ignored even before the service clears it.
assert.ok(!N.effective(Object.assign({}, sched, { override: 'on', until: at(2026, 11, 14, 12, 0) }), at(2026, 11, 14, 13, 0)).on)

// ---- daylight saving ----
// Fall back on 2026-11-01 (02:00 CDT -> 01:00 CST): the 07:00 edge is at
// 07:00 on the clock, 12 h after 20:00, not 11.
e = N.effective(sched, at(2026, 10, 31, 21, 0))
assert.ok(e.on)
assert.deepEqual(hm(e.changesAt), [11, 1, 7, 0], 'fall back: off at 07:00 by the clock')
assert.equal((e.changesAt - at(2026, 10, 31, 20, 0)) / 3600000, 12, 'a 12-hour night')
// Spring forward on 2027-03-14 (02:00 -> 03:00): a 10-hour night.
e = N.effective(sched, at(2027, 3, 13, 21, 0))
assert.deepEqual(hm(e.changesAt), [3, 14, 7, 0], 'spring forward: off at 07:00 by the clock')
assert.equal((e.changesAt - at(2027, 3, 13, 20, 0)) / 3600000, 10, 'a 10-hour night')
// A window edge inside the skipped hour lands on the next real time.
assert.deepEqual(hm(N.nextEdge(at(2027, 3, 14, 1, 0), '02:30', '07:00')), [3, 14, 3, 30])

// ---- hyprctl's answers (hyprsunset 0.4.0, probed in the sandbox) ----
assert.deepEqual(N.reply(0, 'ok'), { ok: true, kind: 'ok', value: 0, message: '' })
assert.deepEqual(N.reply(0, '4000\n'), { ok: true, kind: 'value', value: 4000, message: '' })
let r = N.reply(3, "Couldn't connect to /run/user/1000/hypr/sig/.hyprsunset.sock. (3)")
assert.ok(!r.ok && r.kind === 'stopped' && r.message === 'hyprsunset is not running', 'no socket: not running')
r = N.reply(0, 'Invalid temperature (should be an integer in range 1000-20000)')
assert.ok(!r.ok && r.kind === 'error' && /Invalid temperature/.test(r.message), 'hyprsunset refusing exits 0')
assert.equal(N.reply(0, 'invalid command').kind, 'error')
assert.equal(N.reply(1, '').kind, 'error', 'a failed hyprctl with nothing said')
assert.equal(N.reply(0, '').kind, 'error', 'no answer')
assert.deepEqual(N.command({ on: true, temperature: 4000 }), ['hyprctl', 'hyprsunset', 'temperature', '4000'])
assert.deepEqual(N.command({ on: true, temperature: 100 }), ['hyprctl', 'hyprsunset', 'temperature', '2500'], 'clamped before it goes out')
assert.deepEqual(N.command({ on: false, temperature: 4000 }), ['hyprctl', 'hyprsunset', 'identity'])

// ---- hyprsunset.conf's profiles ----
const conf = fs.readFileSync(path.join(__dirname, '../../hypr/hyprsunset.conf'), 'utf8')
assert.deepEqual(N.parseProfiles(conf), [{ minute: 420, identity: true, temperature: 6000 }], 'the dotfiles conf: identity at 07:00; the commented 20:00 profile is a comment')
const profiles = N.parseProfiles('profile {\n  time = 07:00\n  identity = true\n}\nprofile {\n    time = 21:30\n    temperature = 3500\n}\nprofile {\n time = 25:00\n identity = true\n}\n')
assert.deepEqual(profiles, [{ minute: 420, identity: true, temperature: 6000 }, { minute: 1290, identity: false, temperature: 3500 }], 'a bad time is skipped, as hyprsunset skips it')
assert.equal(N.crossed(profiles, at(2026, 11, 15, 6, 59) + 30000, at(2026, 11, 15, 7, 0) + 30000), profiles[0], 'the tick over 07:00 sees it fire')
assert.equal(N.crossed(profiles, at(2026, 11, 15, 7, 0) + 30000, at(2026, 11, 15, 7, 1) + 30000), null, 'and the next tick does not')
assert.equal(N.crossed(profiles, at(2026, 11, 15, 7, 0), at(2026, 11, 15, 7, 1)), null, 'a tick starting exactly at 07:00 counted it already')
assert.equal(N.crossed(profiles, at(2026, 11, 15, 3, 0), at(2026, 11, 15, 22, 0)), profiles[1], 'a long gap (suspend): the latest one fired wins')
const midnight = N.parseProfiles('profile { time = 00:00\n identity = true }')
assert.equal(N.crossed(midnight, at(2026, 11, 14, 23, 59) + 30000, at(2026, 11, 15, 0, 0) + 30000), midnight[0], 'across midnight')
assert.ok(N.profileDiffers(profiles[0], { on: true, temperature: 4000 }), 'identity while on: put it back')
assert.ok(!N.profileDiffers(profiles[0], { on: false, temperature: 4000 }), 'identity while off: leave it')
assert.ok(!N.profileDiffers(profiles[1], { on: true, temperature: 3500 }), 'the same warmth: leave it')
assert.ok(N.profileDiffers(profiles[1], { on: true, temperature: 4000 }) && N.profileDiffers(profiles[1], { on: false }), 'another warmth, or a tint while off: put it back')

// ---- the journal (USER_UNIT + _SYSTEMD_USER_UNIT, --output=cat) ----
// Lines as milhouse's journal has them for hyprsunset 0.4.0.
const unit = 'hyprsunset.service'
assert.deepEqual(N.journalEvent('Started An application to enable a blue-light filter on Hyprland..', unit), { kind: 'lifecycle', started: true })
assert.deepEqual(N.journalEvent('Stopping An application to enable a blue-light filter on Hyprland....', unit), { kind: 'lifecycle', started: false })
assert.deepEqual(N.journalEvent('Stopped An application to enable a blue-light filter on Hyprland..', unit), { kind: 'lifecycle', started: false })
assert.deepEqual(N.journalEvent('Failed to start An application to enable a blue-light filter on Hyprland..', unit), { kind: 'lifecycle', started: false })
assert.deepEqual(N.journalEvent("hyprsunset.service: Main process exited, code=exited, status=1/FAILURE", unit), { kind: 'lifecycle', started: false }, 'a crash: the manager names the unit')
assert.deepEqual(N.journalEvent('┣ Switched to new profile from: 7:0', unit), { kind: 'profile', minute: 420 }, 'hyprsunset switching by itself')
assert.deepEqual(N.journalEvent('┣ Switched to new profile from: 21:30', unit), { kind: 'profile', minute: 1290 })
assert.deepEqual(N.journalEvent('┣ Switched to new profile from: 99:99', unit), { kind: 'profile', minute: -1 }, 'an unreadable time is still a switch')
for (const quiet of ['┃', '╹', '┏ hyprsunset v0.4.0 ━━╸', '┣ Calculated the CTM to be [mat3x3: 1, 0, 0, 0, 1, 0, 0, 0, 1]', '┣ Resetting the matrix (--identity passed)',
    '┣ already initialized, applying CTM instantly', '┣ Found new output with ID 73, binding', '┣ Applying profile from: 7:0', '┣ Exiting on user interrupt', '', null])
    assert.equal(N.journalEvent(quiet, unit), null, 'hyprsunset\'s other output is ignored: ' + quiet)
assert.equal(N.journalEvent('┣ Failed to bind', unit), null, 'its own lines never read as the manager\'s')
assert.deepEqual(N.profileAt(N.parseProfiles(conf), 420), { minute: 420, identity: true, temperature: 6000 })
assert.equal(N.profileAt(N.parseProfiles(conf), 1290), null)
assert.equal(N.profileAt(null, 420), null)

assert.equal(N.clock(at(2026, 11, 15, 7, 0)), '07:00')
assert.equal(N.clock(0), '')

console.log('NIGHTLIGHT_RULES_PASS')
