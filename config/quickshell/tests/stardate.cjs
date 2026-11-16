// lib/Stardate.js (the Bridge look's clock) and LookModel's small pure pieces:
// Arcade's hearts, Phosphor's faces, the status and away-team lines, the
// stars, the look names (PLAN M9). In a zone with daylight saving, so a
// shifted day would show (America/Chicago: March and November).
process.env.TZ = 'America/Chicago'
const assert = require('node:assert/strict')
const S = require('../lib/Stardate.js')
const L = require('../lib/LookModel.js')

// ---- stardate ----
// The Looks board's, from OmniWM's bridge/lib/look.luau.
assert.equal(S.format(new Date(2026, 10, 14, 10, 45)), '80869.7', 'the board: 2026-11-14 10:45')
assert.equal(S.dayOfYear(new Date(2026, 10, 14)), 318, 'Nov 14 is day 318 of 2026')
assert.equal(S.dayOfYear(new Date(2026, 0, 1, 0, 0)), 1, 'Jan 1 is day 1')
assert.equal(S.dayOfYear(new Date(2028, 11, 31, 23, 59)), 366, 'a leap year has a day 366')
assert.equal(S.format(new Date(2026, 0, 1, 0, 0)), '80000.0', 'midnight, 1 January 2026')
// The daylight-saving days count whole: 8 March 2026 (spring forward) and 1 November (fall back).
assert.equal(S.dayOfYear(new Date(2026, 2, 8, 12)), 67)
assert.equal(S.dayOfYear(new Date(2026, 10, 1, 12)), 305)
// The Lua formula, step by step, against value() for every minute of
// 2026 and 2027. Then format() itself against printf's %.1f (the exact
// binary value rounded, an exact tie to the even digit; python3's '%.1f' is
// C's) on a sample of those minutes: every minute that sits on a tie, and
// every 997th of the rest.
let minutes = 0, last = -Infinity, ties = 0
const samples = []
for (const year of [2026, 2027]) {
    for (let t = new Date(year, 0, 1).getTime(); new Date(t).getFullYear() === year; t += 60000) {
        const d = new Date(t)
        const yday = S.dayOfYear(d)
        const lua = (year - 1946) * 1000 + (((yday - 1) + (d.getHours() + d.getMinutes() / 60) / 24) / 365) * 1000
        const v = S.value(d)
        if (Math.abs(v - lua) > 1e-9) assert.fail(`${d}: ${v} != ${lua}`)
        if (Number.isInteger(v * 20) && !Number.isInteger(v * 10)) {
            ties++
            samples.push(d)
        } else if (minutes % 997 === 0) samples.push(d)
        // The clock only goes forward (one fall-back hour repeats its values).
        if (v < last - 1 / 24 / 365 * 1000 - 1e-9) assert.fail(`${d}: went back from ${last} to ${v}`)
        last = v
        minutes++
    }
}
assert.ok(minutes >= 2 * 525600 - 120, 'every minute of two years: ' + minutes)
assert.ok(ties > 0, 'some minutes sit on a tie: ' + ties)
assert.equal(S.format(new Date(2026, 0, 1, 10, 57)), '80001.2', 'a tie goes to the even digit, as printf does')
// printf itself, through python3 (C's %.1f), on value() of each sampled
// minute, against S.format() of the same minute (M9 review: the check used to
// compare printf with a copy of format()'s tie rule, so a regression in
// format() itself slipped past).
const { execFileSync } = require('node:child_process')
const printed = execFileSync('python3', ['-I', '-c', 'import sys\nfor l in sys.stdin: print("%.1f" % float(l))'],
    { input: samples.map(d => S.value(d).toPrecision(17)).join('\n') + '\n', encoding: 'utf8' }).trim().split('\n')
const mine = samples.map(d => S.format(d))
assert.equal(mine.length, printed.length)
for (let k = 0; k < mine.length; k++)
    if (mine[k] !== printed[k]) assert.fail(`${samples[k]}: format() ${mine[k]}, printf ${printed[k]}`)
assert.ok(samples.length > ties, 'ties and a spread of the rest: ' + samples.length)
assert.equal(S.format(new Date(2027, 11, 31, 23, 59)), '82000.0', 'the last minute of 2027 rounds up to the next thousand')

// ---- hearts: ceil(percent / 25), 0 to 4; -1 without a battery ----
const hearts = [[0, 0], [1, 1], [25, 1], [26, 2], [50, 2], [51, 3], [75, 3], [76, 4], [100, 4], [140, 4]]
for (const [p, n] of hearts) assert.equal(L.hearts(p), n, p + '% is ' + n + ' hearts')
assert.equal(L.hearts(25), 1, "Main's 25% battery is one heart (the board)")
for (const none of [null, undefined, '', NaN, 'x', -1]) assert.equal(L.hearts(none), -1, 'no battery: ' + String(none))

// ---- Phosphor's faces, the board's (OmniWM's [o_o] lost to the mock) ----
assert.deepEqual([L.face('working'), L.face('needs'), L.face('asleep'), L.face('?')], ['[^_^]', '[O_O]!', '[-_-]z', '[-_-]z'])

// ---- Arcade's status line and Bridge's away team ----
const crew = [{ attention: false }, { attention: false }, { attention: true }, { attention: false }]
assert.deepEqual(L.arcadeStatus(crew, 4, 4.37), { score: 'HI 4', crew: 'Crew x4', needs: 'Player 3 needs you' }, "the board's line")
assert.deepEqual(L.arcadeStatus([], 0, null), { score: '', crew: 'Crew x0', needs: '' }, 'no spend, nobody waiting')
assert.equal(L.awayTeam(4, 0), 'Away team 4')
assert.equal(L.awayTeam(4, 1), 'Away team 4 · 1 hailing', "OmniWM's hailing count")

// ---- stars: the board's formula, inside the island ----
const st = L.stars(400, 38)
assert.ok(st.length >= 3 && st.length <= 12, 'thinned to the island: ' + st.length)
st.forEach((s, i) => {
    assert.ok(s.x >= 0 && s.x + 2 <= 400 && s.y >= 0 && s.y + 2 <= 38, 'star ' + i + ' inside')
    assert.equal(s.alpha, [0.25, 0.45, 0.7][i % 3])
})
assert.deepEqual(L.stars(2, 2), [], 'no room, no stars')

// ---- names ----
assert.deepEqual(L.LOOKS, ['crew', 'phosphor', 'bridge', 'arcade', 'liner', 'outrun'])
assert.equal(L.canonical('none'), 'crew', '"none" is the plain island')
assert.equal(L.canonical(' Phosphor '), 'phosphor')
for (const bad of ['sky', 'blueprint', 'matrix', '', null, undefined]) assert.equal(L.canonical(bad), '', 'not a Linux look: ' + bad)
assert.equal(L.shows('crew', true), false, 'crew draws nothing of its own')
assert.equal(L.shows('arcade', true), true)
assert.deepEqual(L.LOOKS.map(L.vibesLine), ['vibes: immaculate', 'vibes: immaculate', 'engage', 'STAGE CLEAR', 'vibes: immaculate', 'vibes: immaculate'])
assert.deepEqual(L.LOOKS.map(L.momentKind), ['', 'signoff', 'hail', 'hail', 'signoff', 'nowplaying'])

console.log('stardate.cjs: ok (' + minutes + ' minutes against the formula, ' + samples.length + ' against printf, ' + ties + ' of them ties)')
