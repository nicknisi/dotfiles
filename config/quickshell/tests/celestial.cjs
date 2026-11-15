// lib/Celestial.js: the focus-shape paths (PLAN M1).
//
// Cookie6Sided is the shape the Main, Island and Personal boards draw on the
// focused workspace. Its path must start "M 95.2 50.0" and match the boards'
// path number for number within 0.05 (the boards print one decimal). The
// boards live outside the repo (.shell-rebuild/mocks in the main checkout), so
// the full comparison runs when Main.dc.html is found there or at $MOCKS_DIR,
// and is reported as skipped otherwise; the repo itself never holds a copy of
// that path, because lib/Celestial.js is the only file allowed to carry
// OmniWM's shape data. Also: every pool shape builds a closed path, the
// licence header is verbatim, and no other file carries the radii.
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const { execFileSync } = require('node:child_process')
const C = require('../lib/Celestial.js')

const config = path.resolve(__dirname, '..')
const repo = path.resolve(config, '../..')

// ---- licence -----------------------------------------------------------------
const luau = fs.readFileSync(path.join(repo, 'config/omniwm/shell/lib/shapes.luau'), 'utf8').split('\n')
const js = fs.readFileSync(path.join(config, 'lib/Celestial.js'), 'utf8').split('\n')
assert.equal(js[0], '// ' + luau[0].replace(/^-- /, ''), 'SPDX line copied verbatim')
assert.equal(js[1], '// ' + luau[1].replace(/^-- /, ''), 'copyright line copied verbatim')
assert.equal(js[0], '// SPDX-License-Identifier: GPL-2.0-only')
assert.match(js[1], /^\/\/ Copyright \(C\) 2026 OmniNull .* https:\/\/github\.com\/OmniNull\/OmniWM$/)

// Only Celestial.js carries the data: no other file under config/quickshell
// holds a run of Cookie6Sided's radii.
const signature = C.RADII.Cookie6Sided.slice(0, 6).map(v => v.toFixed(3)).join(', ')
const offenders = []
const walk = dir => {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name)
        if (entry.isDirectory()) {
            if (entry.name === 'node_modules' || entry.name === '.git') continue
            walk(full)
        } else if (/\.(qml|js|cjs|py|json|sh|md|txt)$/.test(entry.name) && full !== path.join(config, 'lib/Celestial.js')) {
            if (fs.readFileSync(full, 'utf8').includes(signature)) offenders.push(path.relative(config, full))
        }
    }
}
walk(config)
assert.deepEqual(offenders, [], 'shape radii appear outside lib/Celestial.js')

// ---- data ----------------------------------------------------------------------
assert.equal(C.SAMPLES, 72)
assert.equal(C.POOL.length, 18, 'FOCUSED_SHAPES has 18 names')
assert.deepEqual(C.POOL, ['Slanted', 'Oval', 'Pill', 'Triangle', 'Arrow', 'Diamond', 'Pentagon', 'Gem', 'VerySunny',
    'Sunny', 'Cookie4Sided', 'Cookie6Sided', 'Cookie7Sided', 'Cookie9Sided', 'Cookie12Sided', 'Clover4Leaf', 'SoftBurst', 'Ghostish'])
for (const name of C.NAMES) assert.equal(C.RADII[name].length, 72, name + ' has 72 radii')
assert.equal(C.RADII.Cookie6Sided[0], 0.452, 'Cookie6Sided radius[0]')
assert.deepEqual(C.radii('NoSuchShape'), C.RADII.Circle, 'unknown shapes fall back to Circle')
assert.notEqual(C.radii('Gem'), C.RADII.Gem, 'radii() hands out a copy')
// interpolation, wrapping at 360
assert.equal(C.radius('Cookie6Sided', 0), 0.452)
assert.ok(Math.abs(C.radius('Cookie6Sided', 2.5) - (C.RADII.Cookie6Sided[0] + C.RADII.Cookie6Sided[1]) / 2) < 1e-12)
assert.ok(Math.abs(C.radius('Cookie6Sided', 360) - 0.452) < 1e-12)
assert.ok(Math.abs(C.radius('Cookie6Sided', -5) - C.RADII.Cookie6Sided[71]) < 1e-12, 'negative angles wrap')

// ---- paths -----------------------------------------------------------------------
const numbers = d => (d.match(/-?\d+(?:\.\d+)?/g) || []).map(Number)
function closed(name, d) {
    assert.ok(d.startsWith('M '), name + ' starts with M')
    assert.ok(d.endsWith(' Z'), name + ' ends with Z')
    assert.equal((d.match(/C /g) || []).length, 72, name + ' has 72 cubic segments')
    const n = numbers(d)
    assert.equal(n.length, 2 + 72 * 6, name + ' number count')
    assert.ok(n.every(Number.isFinite), name + ' numbers are finite')
    assert.equal(n[n.length - 2], n[0], name + ' last x returns to the start')
    assert.equal(n[n.length - 1], n[1], name + ' last y returns to the start')
}
for (const name of C.POOL) closed(name, C.path(name))
for (const name of C.NAMES) closed(name, C.path(name, 0, 2))

const cookie = C.path('Cookie6Sided')
assert.ok(cookie.startsWith('M 95.2 50.0 '), 'Cookie6Sided starts M 95.2 50.0: ' + cookie.slice(0, 20))
assert.ok(C.path('Cookie6Sided', 0, 2).startsWith('M 95.20 50.00 '), 'two decimals as shapes.luau prints them')
assert.equal(C.pathFromRadii(C.radii('Cookie6Sided')), cookie, 'pathFromRadii(radii(name)) = path(name)')
// a morph's ends are the two shapes, and its middle is the radius average
const a = C.radii('Cookie6Sided'), b = C.radii('Gem')
assert.equal(C.pathFromRadii(C.lerpRadii(a, b, 0)), C.path('Cookie6Sided'))
assert.equal(C.pathFromRadii(C.lerpRadii(a, b, 1)), C.path('Gem'))
const mid = C.lerpRadii(a, b, 0.5)
assert.ok(mid.every((r, i) => Math.abs(r - (a[i] + b[i]) / 2) < 1e-12), 'halfway is the average')
closed('morph', C.pathFromRadii(mid))

// ---- against the boards ------------------------------------------------------------
function findMocks() {
    if (process.env.MOCKS_DIR) return process.env.MOCKS_DIR
    try {
        // A worktree shares .git with the main checkout, where .shell-rebuild lives.
        const common = execFileSync('git', ['-C', repo, 'rev-parse', '--path-format=absolute', '--git-common-dir'],
            { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim()
        return path.join(path.dirname(common), '.shell-rebuild/mocks')
    } catch (e) {
        return ''
    }
}
const main = path.join(findMocks(), 'Main.dc.html')
if (fs.existsSync(main)) {
    const m = fs.readFileSync(main, 'utf8').match(/shapeD:\s*'([^']+)'/)
    assert.ok(m, 'Main.dc.html has a shapeD path')
    const want = numbers(m[1]), got = numbers(cookie)
    assert.equal(got.length, want.length, 'same number count as the board')
    let worst = 0
    for (let i = 0; i < want.length; i++) worst = Math.max(worst, Math.abs(got[i] - want[i]))
    assert.ok(worst <= 0.05 + 1e-9, 'Cookie6Sided within 0.05 of the board, worst ' + worst.toFixed(4))
    console.log('celestial: Cookie6Sided matches Main.dc.html, worst ' + worst.toFixed(4))
} else {
    console.log('celestial: SKIP board comparison (no ' + main + ')')
}
console.log('CELESTIAL_PASS')
