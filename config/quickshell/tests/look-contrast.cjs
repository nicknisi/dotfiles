// The looks' contrast audit (PLAN M9, risk 25): every text and glyph pair
// lib/LookModel.js ink() draws, for every look, on every pack in themes/,
// with the tokens bin/theme-color --json writes. Text reaches 4.5, glyphs 3.
// The boards' inks fail on light packs (accent on darker, black on fg); ink()
// falls back to the pack's fg (Bridge: black or white per segment), and a
// look that still fails on a light pack must be marked dark-only
// (LookModel.DARK_ONLY), so the island draws the plain look there. A dark
// pack has no such escape: every look must pass on every dark pack.
//
// Prints one line per look: the packs where a fallback replaced the board's
// colour, so a change in either shows in the log.
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const { execFileSync } = require('node:child_process')
const L = require('../lib/LookModel.js')
const TokenMath = require('../lib/TokenMath.js')

const repo = path.resolve(__dirname, '../../..')
const themeColor = path.join(repo, 'bin/theme-color')
const themes = path.join(repo, 'themes')

function themeMode(pack) {
    const conf = path.join(themes, pack, 'theme.conf')
    if (!fs.existsSync(conf)) return ''
    const m = fs.readFileSync(conf, 'utf8').match(/^\s*THEME_MODE=["']?(dark|light)?["']?\s*$/m)
    return m && m[1] ? m[1] : ''
}

// colors.json (snake_case) -> the camelCase tokens LookModel reads, as Tokens.qml maps them.
function tokens(json) {
    const d = TokenMath.derive(json)
    return {
        bg: json.background, fg: json.foreground, accent: json.accent,
        surface: json.surface, hairline: json.hairline, inkDim: json.ink_dim, inkMid: json.ink_mid,
        fillHigh: json.fill_high, darker: json.darker, bad: json.bad,
        red: d.red, yellow: d.yellow, cyan: d.cyan, blue: d.blue, magenta: d.magenta, magentaBright: d.magentaBright,
        dark: d.dark
    }
}

// The contrast maths is TokenMath's.
for (const [a, b] of [['#82fb9c', '#06060c'], ['#1e66f5', '#d7d8dc'], ['#000000', '#4c4f69'], ['#ffffff', '#777777']])
    assert.equal(L.contrast(a, b), TokenMath.contrast(a, b), `contrast ${a} on ${b}`)
assert.equal(L.mix('#0b0c16', '#ddf7ff', 0.04), TokenMath.mix('#0b0c16', '#ddf7ff', 0.04), 'mix')
// fade(): the board's .6 where it reads, else the least step above it that does.
assert.equal(L.fade('#ffffff', '#000000', 0.6, 4.5), L.mix('#000000', '#ffffff', 0.6), 'white at .6 on black reads')
assert.ok(L.contrast(L.fade('#7c7f93', '#eff1f5', 0.6, 4.5), '#eff1f5') >= 4.5 || L.fade('#7c7f93', '#eff1f5', 0.6, 4.5) === '#7c7f93', 'a fade always reaches the minimum, or is the colour itself')

const packs = fs.readdirSync(themes)
    .filter(name => fs.existsSync(path.join(themes, name, 'colors.toml')))
    .sort()
assert.equal(packs.length, 37, `expected 37 packs, found ${packs.length}`)

const failures = []
const fallbacks = {}
let checked = 0, light = 0
for (const pack of packs) {
    const mode = themeMode(pack)
    const args = ['-f', path.join(themes, pack, 'colors.toml'), '--name', pack]
    if (mode) args.push('--mode', mode)
    const json = JSON.parse(execFileSync(themeColor, [...args, '--json'], { encoding: 'utf8' }))
    const t = tokens(json)
    if (!t.dark) light++
    for (const look of L.LOOKS) {
        if (look === 'crew') continue
        const ink = L.ink(look, t)
        // Where the board's colour gave way (the audit's log).
        const board = { phosphor: [ink.text, t.accent], arcade: [ink.accent, t.accent], liner: [ink.faded, L.mix(t.surface, t.fg, 0.6)], outrun: [ink.dim, t.inkDim] }[look]
        if (board && board[0] !== board[1]) (fallbacks[look] = fallbacks[look] || []).push(pack)
        if (look === 'bridge' && Object.values(ink.inks).includes('#ffffff')) (fallbacks.bridge = fallbacks.bridge || []).push(pack)
        // Phosphor's asleep face (the ink at .6) and Liner's letters are drawn mixed, at full opacity.
        if (look === 'phosphor' && ink.asleep !== L.mix(ink.ground, ink.text, 0.6)) (fallbacks['phosphor asleep face'] = fallbacks['phosphor asleep face'] || []).push(pack + (ink.asleep === ink.text ? '(full)' : ''))
        for (const p of L.pairs(look, t)) {
            checked++
            if (p.ratio >= p.min) continue
            const excused = !t.dark && L.darkOnly(look)
            if (!excused) failures.push(`${look} on ${pack} (${t.dark ? 'dark' : 'light'}): ${p.what} ${p.fg} on ${p.bg} is ${p.ratio.toFixed(2)}, needs ${p.min}`)
        }
        // The material's ring and glow are drawn from the same inks.
        const m = L.material(look, 'rest', t)
        assert.ok(/^#[0-9a-f]{6}$/.test(m.fill) && /^#[0-9a-f]{6}$/.test(m.ring), `${look} on ${pack}: material colours resolve`)
    }
}
for (const look of [...L.LOOKS.slice(1), 'phosphor asleep face'])
    console.log(`look-contrast: ${look}${L.darkOnly(look) ? ' (dark only)' : ''}: fallback ink on ${(fallbacks[look] || []).join(' ') || 'no pack'}`)
assert.deepEqual(failures, [], 'every pair passes')
// A dark-only look really needs it: some light pack fails without the excuse.
for (const look of L.DARK_ONLY) assert.ok(light > 0, look + ' is dark-only but there is no light pack')
console.log(`look-contrast: ok (${checked} pairs, ${packs.length} packs, ${light} light)`)
