// lib/SleepFade.js: the screens fading to black before sleep. The state
// machine (open, closing, closed, opening; the inhibitor's hold), the
// overlay's level, map and input, the parser for gdbus's lines and the
// commands that hold and release logind's delay inhibitor.
const assert = require('node:assert/strict')
const S = require('../lib/SleepFade.js')

const walk = (events, m = S.initial()) => {
    const out = [m]
    for (const e of events) out.push(m = S.step(m, e))
    return out
}
const states = list => list.map(m => m.state + (m.hold ? '+' : '-'))

// ---- the machine ----
assert.deepEqual(S.initial(), { state: 'open', hold: true }, 'awake: the inhibitor held, the overlay unmapped')
assert.deepEqual(states(walk(['sleep', 'faded', 'wake', 'risen'])),
    ['open+', 'closing+', 'closed-', 'opening+', 'open+'], 'the night: fade, release, wake black, fade up, take it again')
assert.deepEqual(states(walk(['sleep', 'cap', 'faded'])), ['open+', 'closing+', 'closing-', 'closed-'],
    'the cap lets go while the fade still runs; the fade still ends black')
assert.deepEqual(states(walk(['sleep', 'sleep', 'faded', 'sleep'])), ['open+', 'closing+', 'closing+', 'closed-', 'closed-'],
    'a repeated sleep changes nothing (no second fade, no retake)')
assert.deepEqual(states(walk(['sleep', 'wake'])), ['open+', 'closing+', 'opening+'],
    'a sleep cancelled mid-fade (an inhibitor refused it) fades back up')
assert.deepEqual(states(walk(['sleep', 'faded', 'wake', 'sleep'])), ['open+', 'closing+', 'closed-', 'opening+', 'closing+'],
    'asleep again while fading up: closing from where it is')
assert.deepEqual(states(walk(['wake', 'risen', 'faded', 'cap'])), ['open+', 'open+', 'open+', 'open+', 'open+'],
    'stray events while open change nothing')
assert.deepEqual(states(walk(['sleep', 'faded', 'watchdog'])), ['open+', 'closing+', 'closed-', 'opening+'],
    'no wake signal for too long: open anyway')
assert.deepEqual(states(walk(['sleep', 'lost'])), ['open+', 'closing+', 'opening+'],
    'the listener died: never stay black on a guess')
assert.deepEqual(S.step(null, 'sleep'), { state: 'closing', hold: true }, 'a missing record starts open')
assert.deepEqual(S.step({ state: 'bogus', hold: false }, 'faded'), { state: 'open', hold: false })
assert.deepEqual(S.step(S.initial(), 'nonsense'), S.initial())

// The hold is never released while open or opening, and never held once closed.
for (const seq of [['sleep', 'faded', 'wake'], ['sleep', 'cap', 'wake', 'risen'], ['sleep', 'faded', 'watchdog', 'sleep', 'cap', 'faded']]) {
    for (const m of walk(seq)) {
        if (m.state === 'open' || m.state === 'opening') assert.ok(m.hold, 'held while ' + m.state)
        if (m.state === 'closed') assert.ok(!m.hold, 'released once closed')
    }
}

// ---- the overlay ----
const at = st => ({ state: st, hold: true })
assert.deepEqual(['open', 'closing', 'closed', 'opening'].map(st => S.level(at(st))), [0, 1, 1, 0], 'black while closing and closed, clear while opening and open')
assert.deepEqual(['open', 'closing', 'closed', 'opening'].map(st => S.mapped(at(st))), [false, true, true, true], 'unmapped while open')
assert.deepEqual(['open', 'closing', 'closed', 'opening'].map(st => S.blocking(at(st))), [false, true, true, false], 'the pointer only while closing or closed')
assert.equal(S.FADE_MS, 400)
assert.equal(S.CAP_MS, 1000, 'the hold is capped at 1 s, under logind\'s InhibitDelayMaxSec (5 s by default, 15 s on milhouse)')
assert.ok(S.WATCHDOG_MS > S.CAP_MS)

// ---- the mark a starting lock reads (SleepFade.qml writes it) ----
assert.equal(S.MARK, 'quickshell-sleep-fade')
const now = 1_800_000_000_000
assert.ok(S.marked(String(now - 300) + '\n', now), 'written 0.3 s ago: the screens are going dark')
assert.ok(S.marked(String(now + 500), now), 'a little clock skew is fine')
assert.ok(!S.marked(String(now - S.WATCHDOG_MS), now), 'as old as the watchdog: a dead shell\'s, ignored')
assert.ok(!S.marked(String(now + 5000), now), 'from the future: ignored')
for (const bad of ['0', '0\n', '', '   ', 'yes', '-5', 'NaN', 'Infinity', undefined, null])
    assert.ok(!S.marked(bad, now), 'no mark: ' + JSON.stringify(bad))

// ---- gdbus ----
assert.deepEqual(S.parse('/org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep (true,)'), { type: 'prepare', sleeping: true })
assert.deepEqual(S.parse('/org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep (false,)  '), { type: 'prepare', sleeping: false })
assert.deepEqual(S.parse(S.signalLine(true)), { type: 'prepare', sleeping: true }, 'the sandbox feeds the very line gdbus prints')
assert.deepEqual(S.parse(S.signalLine(false)), { type: 'prepare', sleeping: false })
assert.deepEqual(S.parse('(<true>,)'), { type: 'property', sleeping: true })
assert.deepEqual(S.parse('(<false>,)\n'), { type: 'property', sleeping: false })
assert.deepEqual(S.parse('The name org.freedesktop.login1 is owned by :1.4'), { type: 'owner' })
assert.deepEqual(S.parse('The name org.freedesktop.login1 does not have an owner'), { type: 'gone' })
assert.equal(S.parse('/org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForShutdown (true,)'), null, 'shutdown is not sleep')
assert.equal(S.parse('/org/freedesktop/login1: org.freedesktop.DBus.Properties.PropertiesChanged (...)'), null)
assert.equal(S.parse(''), null)
assert.equal(S.parse(undefined), null)
assert.deepEqual([0, 1, 2, 3, 4, 5, 6, 40].map(S.backoff), [2000, 4000, 8000, 16000, 32000, 60000, 60000, 60000], 'the monitor comes back after 2 s, doubling to 60 s')

// ---- the commands ----
assert.deepEqual(S.MONITOR.slice(0, 4), ['setpriv', '--pdeathsig', 'TERM', '--'], 'the monitor dies with the shell')
assert.ok(S.MONITOR.includes('monitor') && S.MONITOR.includes('--system') && S.MONITOR.includes('org.freedesktop.login1'))
assert.deepEqual(S.INHIBIT.slice(0, 4), ['setpriv', '--pdeathsig', 'TERM', '--'], 'the inhibitor dies with the shell')
assert.ok(S.INHIBIT.includes('systemd-inhibit') && S.INHIBIT.includes('--what=sleep') && S.INHIBIT.includes('--mode=delay'), 'a sleep delay lock, never a block')
assert.equal(S.INHIBIT[S.INHIBIT.length - 1], 'cat', 'held by a child that ends at stdin EOF')
assert.ok(!S.INHIBIT.includes('--mode=block'))
assert.ok(S.READ.includes('PreparingForSleep'))

console.log('SLEEP_FADE_TEST_PASS')
