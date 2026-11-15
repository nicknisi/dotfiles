// lib/TokenMath.js derive() against bin/theme-color --json, every pack in themes/.
// theme-color is the canonical rule set; TokenMath is its port for Quickshell.
// Input is the pack's colors.json with the shell tokens taken out, which is what a
// colors.json written before the tokens existed looks like, so derive() has to
// rebuild every one of them from the base palette. 0 mismatches or it fails.
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const { execFileSync } = require('node:child_process')
const TokenMath = require('../lib/TokenMath.js')

const repo = path.resolve(__dirname, '../../..')
const themeColor = path.join(repo, 'bin/theme-color')
const themes = path.join(repo, 'themes')

// snake_case key in colors.json -> camelCase key from derive()
const TOKENS = {
    surface: 'surface', raised: 'raised', overlay: 'overlay', hairline: 'hairline',
    fill_low: 'fillLow', fill_high: 'fillHigh', ink_dim: 'inkDim', ink_mid: 'inkMid',
    faint: 'faint', accent_tint: 'accentTint', on_accent: 'onAccent', on_fg: 'onFg',
    bad: 'bad', darker: 'darker', shadow_alpha: 'shadowAlpha',
}
// palette keys derive() passes through or falls back on; resolved packs always carry them
const PASSTHROUGH = {
    background: 'bg', foreground: 'fg', accent: 'accent', mode: 'mode', name: 'name', tagline: 'tagline',
    red: 'red', green: 'green', yellow: 'yellow', blue: 'blue', magenta: 'magenta', cyan: 'cyan',
    muted: 'muted', dark_foreground: 'darkFg', bright_magenta: 'magentaBright',
}

// bin/theme sources theme.conf and passes THEME_MODE through as --mode
function themeMode(pack) {
    const conf = path.join(themes, pack, 'theme.conf')
    if (!fs.existsSync(conf)) return ''
    const m = fs.readFileSync(conf, 'utf8').match(/^\s*THEME_MODE=["']?(dark|light)?["']?\s*$/m)
    return m && m[1] ? m[1] : ''
}

// the pack's own darker_background (or darker_bg), as theme-color's parse() reads it
function rawDarker(pack) {
    const toml = fs.readFileSync(path.join(themes, pack, 'colors.toml'), 'utf8')
    const m = toml.match(/^\s*["']?darker_(?:background|bg)["']?\s*=\s*["']?#?([0-9a-fA-F]{6})/m)
    return m ? '#' + m[1].toLowerCase() : null
}

const packs = fs.readdirSync(themes)
    .filter(name => fs.existsSync(path.join(themes, name, 'colors.toml')))
    .sort()
assert.equal(packs.length, 37, `expected 37 packs, found ${packs.length}`)

const mismatches = []
let compared = 0
for (const pack of packs) {
    const mode = themeMode(pack)
    const args = ['-f', path.join(themes, pack, 'colors.toml'), '--name', pack]
    if (mode) args.push('--mode', mode)
    const json = JSON.parse(execFileSync(themeColor, [...args, '--json'], { encoding: 'utf8' }))
    for (const key of Object.keys(TOKENS))
        assert.ok(key in json, `${pack}: theme-color --json has no ${key}`)

    const bare = Object.assign({}, json)
    for (const key of Object.keys(TOKENS)) delete bare[key]
    // derive() reads darker_background as the pack's own value, like the mocks'
    // palettes (null when the pack has none). The resolved JSON always fills it,
    // so put back what colors.toml says. See the caveat in TokenMath.js.
    delete bare.darker_background
    delete bare.darker_bg
    const own = rawDarker(pack)
    if (own) bare.darker_background = own
    // both the old colors.json (no tokens) and the new one (tokens present) must agree
    for (const [label, input] of [['bare', bare], ['full', json]]) {
        const d = TokenMath.derive(input)
        for (const [snake, camel] of Object.entries(Object.assign({}, TOKENS, PASSTHROUGH))) {
            compared++
            const want = String(json[snake])
            const got = String(d[camel])
            if (want !== got) mismatches.push(`${pack} (${label}) ${snake}: theme-color ${want}, TokenMath ${got}`)
        }
    }
    // the two contrast fixes hold everywhere, not just on the packs that needed them
    if (TokenMath.contrast(json.bad, json.surface) < 4.5)
        mismatches.push(`${pack}: bad ${json.bad} is ${TokenMath.contrast(json.bad, json.surface).toFixed(2)}:1 on surface`)
    if (TokenMath.contrast(json.on_fg, json.foreground) < 4.5)
        mismatches.push(`${pack}: on_fg ${json.on_fg} is ${TokenMath.contrast(json.on_fg, json.foreground).toFixed(2)}:1 on fg`)
}

if (mismatches.length) {
    console.error(mismatches.join('\n'))
    console.error(`TOKEN_PARITY_FAIL ${mismatches.length} mismatches in ${compared} comparisons`)
    process.exit(1)
}
console.log(`TOKEN_PARITY_PASS ${packs.length} packs, ${compared} comparisons, 0 mismatches`)
