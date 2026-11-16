// lib/FindBin.js against throwaway checkouts: the checkout the shell runs
// from first (through the config link, as ~/.config/quickshell is), then,
// for the session's own config only, $DOTFILES/bin and PATH (PLAN M10:
// ThemePicker's bin/theme). A copy of the config (check.sh's, shoot.sh's)
// never reaches another checkout's script (M10 review).
'use strict'
const assert = require('node:assert/strict')
const { execFileSync } = require('node:child_process')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const F = require('../lib/FindBin.js')

const tmp = fs.realpathSync(fs.mkdtempSync(path.join(process.env.TMPDIR || os.tmpdir(), 'find-bin-')))
const script = (dir) => {
    fs.mkdirSync(path.join(dir, 'bin'), { recursive: true })
    fs.mkdirSync(path.join(dir, 'config', 'quickshell'), { recursive: true })
    const p = path.join(dir, 'bin', 'theme')
    fs.writeFileSync(p, '#!/bin/sh\n')
    fs.chmodSync(p, 0o755)
    return p
}
const find = (local, env, fallbacks = true) => {
    const [cmd, ...args] = F.command('theme', local, fallbacks)
    try {
        return execFileSync(cmd, args, { env: Object.assign({ PATH: '/usr/bin:/bin' }, env), encoding: 'utf8' }).trim()
    } catch (e) {
        return 'exit ' + e.status
    }
}
try {
    const main = script(path.join(tmp, 'dotfiles'))
    const worktree = script(path.join(tmp, 'worktree'))
    // ~/.config/quickshell, a link to the checkout's config/quickshell.
    fs.mkdirSync(path.join(tmp, 'home', '.config'), { recursive: true })
    const link = path.join(tmp, 'home', '.config', 'quickshell')
    fs.symlinkSync(path.join(tmp, 'dotfiles', 'config', 'quickshell'), link)
    assert.equal(find(link + '/../../bin/theme', {}), main, 'through the config link: the checkout it points into')
    assert.equal(find(path.join(tmp, 'worktree', 'config', 'quickshell') + '/../../bin/theme', { DOTFILES: path.join(tmp, 'dotfiles') }), worktree,
        'a worktree runs its own, whatever DOTFILES says')
    // A copy of the config outside any checkout (a link farm, a test copy).
    const copy = path.join(tmp, 'copy', 'quickshell')
    fs.mkdirSync(copy, { recursive: true })
    assert.equal(find(copy + '/../../bin/theme', { DOTFILES: path.join(tmp, 'dotfiles') }), main, 'a copy falls back to $DOTFILES/bin')
    assert.equal(find(copy + '/../../bin/theme', { PATH: path.join(tmp, 'worktree', 'bin') + ':/usr/bin:/bin' }), worktree, 'then to PATH')
    // Without the fallbacks (a test's or the sandbox's copy): its own or nothing.
    assert.equal(find(copy + '/../../bin/theme', { DOTFILES: path.join(tmp, 'dotfiles'), PATH: path.join(tmp, 'worktree', 'bin') + ':/usr/bin:/bin' }, false), 'exit 1',
        'a copy without fallbacks finds neither $DOTFILES/bin nor PATH')
    assert.equal(find(path.join(tmp, 'worktree', 'config', 'quickshell') + '/../../bin/theme', { DOTFILES: path.join(tmp, 'dotfiles') }, false), worktree,
        'without fallbacks a checkout still runs its own')
    // Not executable, or a directory of that name, does not count.
    fs.chmodSync(main, 0o644)
    assert.equal(find(link + '/../../bin/theme', { DOTFILES: path.join(tmp, 'dotfiles') }), 'exit 1', 'nothing executable: exit 1')
    assert.equal(find('', {}), 'exit 1', 'nothing at all: exit 1')
    // Who gets the fallbacks: the session's config dir alone, outside the
    // sandbox and dry runs.
    assert.equal(F.fallbacksFor('/home/n/.config/quickshell', '/home/n', '', false), true, '~/.config/quickshell')
    assert.equal(F.fallbacksFor('/home/n/.config/quickshell/', '/home/n/', null, false), true, 'trailing slashes')
    assert.equal(F.fallbacksFor('/x/cfg/quickshell', '/home/n', '/x/cfg', false), true, '$XDG_CONFIG_HOME/quickshell')
    assert.equal(F.fallbacksFor('/home/n/.config/quickshell', '/home/n', '/x/cfg', false), false, 'not the config Quickshell would pick')
    assert.equal(F.fallbacksFor('/tmp/claude-1000/qy/nocfg', '/home/n', '', false), false, 'a copy under TMPDIR')
    assert.equal(F.fallbacksFor('/home/n/Developer/dotfiles-island-m10/config/quickshell', '/home/n', '', false), false, 'a worktree run by path')
    assert.equal(F.fallbacksFor('/home/n/.config/quickshell', '/home/n', '', true), false, 'the sandbox or a dry run')
    assert.equal(F.fallbacksFor('', '', '', false), false, 'nothing known')
    assert.equal(F.fallbacksFor('/.config/quickshell', '', '', false), false, 'no HOME')
    assert.deepEqual(F.command('theme', '/a/../../bin/theme').slice(4), ['theme', '0', '/a/../../bin/theme'], 'fallbacks are off unless asked for')
    console.log('FIND_BIN_PASS')
} finally {
    fs.rmSync(tmp, { recursive: true, force: true })
}
