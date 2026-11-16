// lib/FaceModel.js: where the profile picture comes from, the file check,
// the atomic copy and the picker's listing, with the real `sh`, `find`,
// `stat`, `mktemp` and `mv` on generated files (no photo of anyone). The
// checks that the lock and the image reader rely on: a FIFO, a directory, a
// symlink loop, an empty file and one over 32 MiB never pass.
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { spawnSync } = require('node:child_process')
const F = require('../lib/FaceModel.js')

const run = argv => {
    const r = spawnSync(argv[0], argv.slice(1), { encoding: 'utf8', timeout: 10000 })
    return { code: r.status, out: r.stdout, err: r.stderr }
}

// ---- paths ----
assert.equal(F.cleanPath('/home/n/'), '/home/n')
assert.equal(F.cleanPath('relative/p'), '', 'relative paths refused')
assert.equal(F.cleanPath('/a\nb'), '', 'control characters refused')
assert.equal(F.cleanPath(''), '')
assert.equal(F.safeUser('nicknisi'), 'nicknisi')
assert.equal(F.safeUser('../root'), '')
assert.equal(F.safeUser('..'), '')
assert.deepEqual(F.candidates('/home/n', 'n', '/var/lib/AccountsService/icons'), [
    { kind: 'face', path: '/home/n/.face' },
    { kind: 'system', path: '/var/lib/AccountsService/icons/n' }
], '~/.face first, then AccountsService')
assert.deepEqual(F.candidates('/home/n', '../x', '/icons'), [{ kind: 'face', path: '/home/n/.face' }], 'a strange user name names no icon')
assert.equal(F.facePath(''), '')
assert.equal(F.initial('nick'), 'N')
assert.equal(F.initial(''), '?')
assert.equal(F.tilde('/home/n/Pictures', '/home/n'), '~/Pictures')
assert.equal(F.tilde('/srv/p', '/home/n'), '/srv/p')
assert.equal(F.fileUrl('/home/n/a b#c.png', '1-2'), 'file:///home/n/a%20b%23c.png?v=1-2', 'each segment escaped, the version in the query')
assert.equal(F.fileUrl('nope', ''), '')

// ---- sources ----
const cands = F.candidates('/h', 'u', '/i')
assert.deepEqual(F.sources(cands, []), [], 'nothing checked: the initial')
let src = F.sources(cands, F.parseCheck('no\t/h/.face\tmissing\nok\t/i/u\t10\t20\n'))
assert.deepEqual(src.map(s => s.kind), ['system'], 'a missing ~/.face falls to the AccountsService icon')
assert.equal(src[0].url, 'file:///i/u?v=20-10')
src = F.sources(cands, F.parseCheck('ok\t/h/.face\t5\t6\nok\t/i/u\t10\t20\n'))
assert.deepEqual(src.map(s => s.kind), ['face', 'system'], 'both, in order')
assert.deepEqual(F.parseCheck('garbage\nok\tonly-two\n'), [], 'junk lines dropped')

// ---- the check, on real files ----
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'face-model-'))
try {
    const p = n => path.join(tmp, n)
    fs.writeFileSync(p('empty'), '')
    fs.writeFileSync(p('text.png'), 'not an image at all\n')
    fs.writeFileSync(p('ok.png'), Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAEElEQVR4nGP4z8AARwzEcQCukw/x0F8jngAAAABJRU5ErkJggg==', 'base64'))
    // 33 MiB sparse: over the cap without the disk.
    fs.closeSync(fs.openSync(p('large.png'), 'w'))
    fs.truncateSync(p('large.png'), 33 * 1024 * 1024)
    fs.mkdirSync(p('dir'))
    fs.symlinkSync(p('loopB'), p('loopA'))
    fs.symlinkSync(p('loopA'), p('loopB'))
    fs.symlinkSync(p('ok.png'), p('link.png'))
    fs.symlinkSync(p('gone'), p('dangling'))
    assert.equal(run(['mkfifo', p('fifo')]).code, 0)
    fs.writeFileSync(p('secret.png'), 'x')
    fs.chmodSync(p('secret.png'), 0o000)
    const names = ['missing', 'empty', 'text.png', 'ok.png', 'large.png', 'dir', 'loopA', 'link.png', 'dangling', 'fifo', 'secret.png']
    const t0 = Date.now()
    const r = run(F.checkCommand(names.map(p), F.MAX_BYTES))
    assert.ok(Date.now() - t0 < 3000, 'the check never waits on a FIFO: ' + (Date.now() - t0) + ' ms')
    assert.equal(r.code, 0, r.err)
    const rows = F.parseCheck(r.out)
    const why = Object.fromEntries(rows.map(x => [path.basename(x.path), x.ok ? 'ok' : x.why]))
    const root = process.getuid && process.getuid() === 0
    assert.deepEqual(why, {
        missing: 'missing', empty: 'empty', 'text.png': 'ok', 'ok.png': 'ok', 'large.png': 'large', dir: 'type',
        loopA: 'type', 'link.png': 'ok', dangling: 'type', fifo: 'type', 'secret.png': root ? 'ok' : 'unreadable'
    }, 'only readable regular files of 1 byte to 32 MiB pass; the decode decides the rest')
    assert.equal(rows.find(x => x.path.endsWith('ok.png')).size, fs.statSync(p('ok.png')).size)

    // ---- set: atomic, never through a symlink ----
    const home = p('home')
    fs.mkdirSync(home)
    assert.equal(F.setError(p('ok.png'), home), '')
    assert.equal(F.setError('ok.png', home), 'the path must be absolute')
    assert.equal(F.setError(home + '/.face', home), 'that is the profile picture already')
    // A symlink at ~/.face pointing at a file we must not write.
    fs.writeFileSync(p('victim'), 'keep me')
    fs.symlinkSync(p('victim'), home + '/.face')
    let s = run(F.setCommand(p('ok.png'), home))
    assert.equal(s.code, 0, s.err)
    assert.ok(fs.lstatSync(home + '/.face').isFile(), '~/.face is a regular file now, not the symlink')
    assert.equal(fs.readFileSync(p('victim'), 'utf8'), 'keep me', 'the symlink was replaced, never followed')
    assert.deepEqual(fs.readFileSync(home + '/.face'), fs.readFileSync(p('ok.png')))
    assert.equal((fs.statSync(home + '/.face').mode & 0o777).toString(8), '644')
    assert.deepEqual(fs.readdirSync(home), ['.face'], 'no temp file left behind')
    // A directory at ~/.face is not moved into.
    fs.rmSync(home + '/.face')
    fs.mkdirSync(home + '/.face')
    s = run(F.setCommand(p('ok.png'), home))
    assert.notEqual(s.code, 0, 'a directory at ~/.face refuses the copy')
    assert.deepEqual(fs.readdirSync(home + '/.face'), [], 'nothing moved into it')
    assert.deepEqual(fs.readdirSync(home), ['.face'], 'and the temp file is gone')
    fs.rmdirSync(home + '/.face')
    // A source that is not a readable file.
    s = run(F.setCommand(p('dir'), home))
    assert.equal(s.code, 3)
    assert.deepEqual(fs.readdirSync(home), [])
    // Clear removes it (a symlink there goes, its target stays).
    fs.symlinkSync(p('victim'), home + '/.face')
    assert.equal(run(F.clearCommand(home)).code, 0)
    assert.ok(!fs.existsSync(home + '/.face') && fs.existsSync(p('victim')))
    assert.equal(run(F.clearCommand(home)).code, 0, 'clearing nothing is fine')

    // ---- the picker's listing ----
    const pics = p('Pictures')
    fs.mkdirSync(path.join(pics, 'sub', 'deeper'), { recursive: true })
    fs.mkdirSync(path.join(pics, '.hidden'))
    const put = (rel, sec) => {
        fs.writeFileSync(path.join(pics, rel), 'x')
        fs.utimesSync(path.join(pics, rel), sec, sec)
    }
    put('old.png', 1000)
    put('new.JPG', 3000)
    put('sub/mid.webp', 2000)
    put('sub/deeper/too-deep.png', 4000)
    put('.hidden/h.png', 5000)
    put('.dot.png', 5000)
    put('notes.txt', 6000)
    const l = run(F.listCommand(pics))
    assert.equal(l.code, 0, l.err)
    const list = F.parseList(l.out, pics, 120)
    assert.deepEqual(list.map(x => x.name), ['new.JPG', 'sub/mid.webp', 'old.png'], 'images two levels deep, newest first, no hidden files')
    assert.equal(list[0].path, path.join(pics, 'new.JPG'))
    assert.deepEqual(F.parseList(l.out, pics, 1).map(x => x.name), ['new.JPG'], 'capped')
    assert.deepEqual(F.parseList(run(F.listCommand(p('nowhere'))).out, p('nowhere'), 120), [], 'no ~/Pictures: none')
} finally {
    try { fs.chmodSync(path.join(tmp, 'secret.png'), 0o600) } catch {}
    fs.rmSync(tmp, { recursive: true, force: true })
}

// ---- the sheet and the report ----
let sh = F.sheet({ kind: 'face' })
assert.equal(sh.status, 'From ~/.face')
assert.ok(sh.footerEnabled && sh.footer === 'Remove picture' && !sh.hasSwitch)
assert.deepEqual(sh.groups, [])
sh = F.sheet({ kind: 'system' })
assert.equal(sh.status, 'From AccountsService')
assert.ok(!sh.footerEnabled, 'nothing of ours to remove')
sh = F.sheet({ kind: '', busy: true })
assert.equal(sh.status, 'Saving…')
sh = F.sheet({ kind: '', error: '/x: not an image' })
assert.equal(sh.status, 'Initial')
assert.equal(sh.groups[0].rows[0].sub, '/x: not an image')
assert.ok(sh.groups[0].rows[0].bad && sh.groups[0].rows[0].inert)
const rep = F.report({ kind: '', checked: F.parseCheck('no\t/h/.face\tempty\nok\t/i/u\t9\t1\n') })
assert.equal(rep.kind, 'initial')
assert.deepEqual(rep.candidates, [{ path: '/h/.face', ok: false, why: 'empty' }, { path: '/i/u', ok: true, size: 9 }])

console.log('FACE_MODEL_TEST_PASS')
