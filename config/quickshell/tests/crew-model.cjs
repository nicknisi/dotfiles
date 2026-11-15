// lib/CrewModel.js (PLAN M2): moods, display strings, sort, the fleet + scan
// merge, and the two edges the island opens for (hail: attention false to
// true; vibes: attention > 0 to 0). Payload shapes are what `fleet list --json`
// and `omniwm-agents --print` print (checked on milhouse).
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const C = require('../lib/CrewModel.js')

const NOW = 1794715378
const fleetAgent = (o) => Object.assign({
    pane: '%0', windowId: '@0', window: 'dotfiles', session: 'projects', label: 'island mocks', agentType: 'claude',
    status: 'BUSY', needsAttention: false, ts: NOW, timestampKind: 'observed', hookTs: 0, project: '~/Developer/dotfiles',
    git: { worktreeRoot: '/home/x/Developer/dotfiles' }
}, o)
const scanAgent = (o) => Object.assign({
    kind: 'claude', host: 'tmux', age: '3h', state: 'busy', label: '', where: '', pid: 100, pane: '', session: '', windowId: ''
}, o)

// ---- moods and strings ------------------------------------------------------------
{
    const m = C.build({
        fleet: { agents: [
            fleetAgent({}),
            fleetAgent({ pane: '%2', windowId: '@1', agentType: 'pi', status: 'QUESTION', needsAttention: true, label: 'artifact' }),
            fleetAgent({ pane: '%3', windowId: '@2', agentType: 'codex', status: 'IDLE', ts: NOW - 12 * 60, timestampKind: 'state_change', label: 'tests' }),
            fleetAgent({ pane: '%4', agentType: 'opencode', status: 'DONE', needsAttention: true, label: 'review' }),
            fleetAgent({ pane: '%5', agentType: 'claude', status: 'IDLE', label: 'scraped idle', timestampKind: 'observed' })
        ] },
        scan: { agents: [
            scanAgent({ pid: 3157, pane: '%0', session: 'projects', windowId: '@0', age: '3h' }),
            scanAgent({ pid: 11818, kind: 'pi', pane: '%2', age: '5m' }),
            scanAgent({ pid: 6010, kind: 'pi', host: 'riker', state: 'running', label: '#12 Rebuild the crew', where: '~/Developer/dotfiles/.riker/worktrees/12' }),
            scanAgent({ pid: 7000, kind: 'claude', host: 'rex', state: 'running', where: '~/Developer/rex' }),
            scanAgent({ pid: 5000, kind: 'claude', host: 'ghostty', state: 'running', label: 'notes', where: '~/Developer/notes', age: '2d' })
        ], spend: { today: 4.371 } }
    }, NOW)
    const by = Object.fromEntries(m.agents.map(a => [a.id, a]))

    assert.equal(m.total, 8, 'five fleet agents plus three outside tmux')
    assert.equal(m.attention, 2)
    assert.equal(m.spendToday, 4.371)

    assert.equal(by['%0'].mood, 'working')
    assert.equal(by['%0'].name, 'Claude Code')
    assert.equal(by['%0'].where, 'dotfiles · island mocks', 'working tmux: repo · label')
    assert.equal(by['%0'].state, 'working')
    assert.equal(by['%0'].pid, 3157, 'the scan adds the pid by pane')
    assert.equal(by['%0'].age, '3h')
    assert.ok(by['%0'].jumpable)

    assert.equal(by['%2'].mood, 'needs')
    assert.equal(by['%2'].name, 'Pi')
    assert.equal(by['%2'].where, 'tmux · waiting for approval', 'needs: host · reason')
    assert.equal(by['%2'].state, 'needs you')
    assert.equal(by['%4'].where, 'tmux · done, waiting for you', 'DONE with attention')
    assert.equal(by['%4'].name, 'OpenCode')

    assert.equal(by['%3'].mood, 'asleep')
    assert.equal(by['%3'].name, 'Codex')
    assert.equal(by['%3'].where, 'idle 12 min', 'a state change time gives the idle duration')
    assert.equal(by['%3'].state, 'asleep')
    assert.equal(by['%5'].where, 'dotfiles · scraped idle', 'an observed timestamp is not an idle time')

    const riker = by['pid:6010']
    assert.equal(riker.name, 'Riker · worker')
    assert.equal(riker.where, 'Riker job #12 · dotfiles')
    assert.ok(riker.riker && riker.mood === 'working', 'a running Riker worker wears the hat')
    assert.equal(riker.jumpable, false, 'Riker has no window')
    assert.equal(by['pid:7000'].name, 'Rex')
    assert.equal(by['pid:7000'].jumpable, false)
    const bare = by['pid:5000']
    assert.equal(bare.where, 'notes · ghostty', 'outside tmux: repo · terminal')
    assert.ok(bare.jumpable && bare.pane === '' && bare.pid === 5000)

    // Sort: needs you, then working, then host, then label.
    assert.deepEqual(m.agents.map(a => a.id), ['%2', '%4', 'pid:5000', 'pid:7000', 'pid:6010', '%0', '%5', '%3'])
    assert.ok(m.agents.every(a => C.MOODS[a.mood]), 'every record has a known mood')
    assert.deepEqual(C.HOP, [0, -2, -4, -2], 'needs hops 4 px (Personal board)')
    assert.equal(C.HOP_PERIOD, 500)
    assert.deepEqual(C.MOODS.needs.frames.slice(0, 8), C.HOP.concat(C.HOP), 'two hops')
    assert.ok(C.MOODS.needs.frames.length === 32 && C.MOODS.needs.frames.slice(8).every(v => v === 0), 'then 3 s still (OmniWM waves 0.9 s of every 4 s)')
    assert.deepEqual(C.MOODS.working.frames, [0, -1, -2, -1], 'working bobs 2 px')
    assert.equal(C.MOODS.needs.period, 4000)
    assert.equal(C.MOODS.working.period, 1000, 'the bob runs on the shared clock: 4 frames of 250 ms')
    assert.equal(C.MOODS.asleep.period, 0, 'asleep bots hold still')
    assert.equal(C.MOODS.needs.color, 'accent')
    assert.equal(C.MOODS.asleep.color, 'inkDim')
}

// ---- merge rules ------------------------------------------------------------------
{
    const scan = { agents: [scanAgent({ pid: 1, pane: '%0', state: 'idle', label: 'from scan', where: '~/a' }),
        scanAgent({ pid: 2, host: 'ghostty', state: 'running', where: '~/b' })] }
    const noFleet = C.build({ fleet: null, scan }, NOW)
    assert.deepEqual(noFleet.agents.map(a => a.id).sort(), ['%0', 'pid:2'], 'without fleet the scan\'s tmux rows stand in')
    assert.equal(noFleet.agents.find(a => a.id === '%0').mood, 'asleep')
    const withFleet = C.build({ fleet: { agents: [] }, scan }, NOW)
    assert.deepEqual(withFleet.agents.map(a => a.id), ['pid:2'], 'with fleet, fleet owns tmux: an agent gone from fleet is gone')
    const onlyFleet = C.build({ fleet: { agents: [fleetAgent({ project: '' , git: null })] }, scan: null }, NOW)
    assert.equal(onlyFleet.total, 1)
    assert.equal(onlyFleet.agents[0].pid, null, 'no scan, no pid')
    assert.equal(onlyFleet.spendToday, null, 'no scan, no spend')
    assert.deepEqual(C.build(null, NOW), C.empty())
    assert.deepEqual(C.build({ fleet: { agents: [{ label: 'no pane' }] }, scan: null }, NOW).agents, [], 'fleet rows without a pane are dropped')
    assert.equal(C.fromScan({ kind: 'pi' }, 3).id, 'scan:3', 'a row with neither pane nor pid still gets an id')
}

// ---- edges ------------------------------------------------------------------------
{
    const model = (agents) => C.build({ fleet: { agents }, scan: null }, NOW)
    const calm = model([fleetAgent({ pane: '%1' }), fleetAgent({ pane: '%2', agentType: 'pi' })])
    const one = model([fleetAgent({ pane: '%1' }), fleetAgent({ pane: '%2', agentType: 'pi', status: 'QUESTION', needsAttention: true })])
    const two = model([fleetAgent({ pane: '%1', needsAttention: true, status: 'DONE' }), fleetAgent({ pane: '%2', agentType: 'pi', status: 'QUESTION', needsAttention: true })])

    assert.deepEqual(C.edges(null, one), { hails: [], vibes: false }, 'the first read is a baseline')
    assert.deepEqual(C.edges(calm, one), { hails: ['%2'], vibes: false }, 'attention false -> true hails')
    assert.deepEqual(C.edges(one, one), { hails: [], vibes: false }, 'still needing you is not news')
    assert.deepEqual(C.edges(one, two), { hails: ['%1'], vibes: false }, 'only the newcomer hails')
    assert.deepEqual(C.edges(two, one), { hails: [], vibes: false }, 'one handled of two: no vibes yet')
    assert.deepEqual(C.edges(one, calm), { hails: [], vibes: true }, 'the last one handled: vibes')
    assert.deepEqual(C.edges(calm, calm), { hails: [], vibes: false })
    const gone = model([fleetAgent({ pane: '%1' })])
    assert.deepEqual(C.edges(one, gone), { hails: [], vibes: true }, 'the waiting agent exiting also clears attention')
    const newcomer = model([fleetAgent({ pane: '%1' }), fleetAgent({ pane: '%9', status: 'QUESTION', needsAttention: true })])
    assert.deepEqual(C.edges(calm, newcomer).hails, ['%9'], 'a new agent already waiting hails')
    assert.equal(C.hailTarget(two, '%2').id, '%2', 'the hail shows the agent it was raised for')
    assert.equal(C.hailTarget(two, '%7').id, '%1', 'else the first that needs you')
    assert.equal(C.hailTarget(calm, '%2'), null)
}

// ---- display helpers ---------------------------------------------------------------
assert.equal(C.money(12.4), '$12')
assert.equal(C.money(10), '$10')
assert.equal(C.money(4.371), '$4.37')
assert.equal(C.money(0), '$0.00')
assert.equal(C.money(null), '')
assert.equal(C.money(undefined), '')
assert.equal(C.duration(20), '1 min', 'never 0 min')
assert.equal(C.duration(12 * 60), '12 min')
assert.equal(C.duration(3 * 3600 + 100), '3 h')
assert.equal(C.duration(2 * 86400), '2 d')
assert.equal(C.basename('~/Developer/dotfiles/'), 'dotfiles')
assert.deepEqual(C.rikerPath('~/Developer/dotfiles/.riker/worktrees/12/sub'), { job: '12', repo: 'dotfiles' })
assert.equal(C.rikerPath('~/x'), null)
assert.equal(C.kindName('gemini'), 'Gemini', 'unknown kinds are title-cased')
assert.equal(C.kindName(''), 'Agent')

const twelve = Array.from({ length: 12 }, (_, i) => ({ id: 'a' + i }))
assert.deepEqual(C.strip(twelve).shown.length, 8, 'the rest pill draws 8 bots')
assert.equal(C.strip(twelve).more, 4, 'then +4')
assert.equal(C.strip(twelve.slice(0, 3)).more, 0)
assert.equal(C.rows(twelve).shown.length, 7, 'the panel lists 7 rows')
assert.equal(C.rows(twelve).more, 5)
// The footer sits two gaps below the last row (the board's flex spacer):
// Personal board DOM, panel 460 x 332 for four rows.
assert.equal(C.panelHeight(4), 16 + 30 + 8 + 4 * 52 + 3 * 8 + 8 + 8 + 14 + 16, '4 rows')
assert.equal(C.panelHeight(4), 332)
assert.equal(C.panelHeight(0), 16 + 30 + 8 + 52 + 8 + 8 + 14 + 16, 'an empty crew keeps one row of room for its line')
assert.ok(C.panelHeight(7) <= 560 && C.panelHeight(12) <= 560, 'the panel always fits the 560 ceiling')
assert.equal(C.panelHeight(12), C.panelHeight(7) + 8 + 16, 'the +N more line')
assert.equal(C.panelHeight(12), 536)

// One clock per group of bots: the shortest frame among the moods that move.
assert.equal(C.clockStep(['needs', 'working', 'asleep']), 125, 'a needs bot: 125 ms ticks (500 ms hop)')
assert.equal(C.clockStep(['working', 'asleep', 'working']), 250, 'only working bots: 250 ms ticks')
assert.equal(C.clockStep(['asleep']), 0, 'nobody moves: no clock')
assert.equal(C.clockStep([]), 0)
assert.equal(C.clockStep(['bogus', undefined]), 0)
for (const m of Object.keys(C.MOODS)) {
    const step = C.clockStep([m])
    if (step) assert.equal(C.MOODS[m].period / C.MOODS[m].frames.length % C.clockStep(['needs']), 0, m + ' frames land on the fastest tick')
}

{
    const m = C.build({ fleet: { agents: [fleetAgent({ pane: '%2', agentType: 'pi', status: 'QUESTION', needsAttention: true })] }, scan: null }, NOW)
    assert.deepEqual(C.hail(m.agents[0], 0), { title: 'Pi needs you', subtitle: 'Waiting for approval in tmux · dotfiles', button: 'Go to pane' })
    assert.equal(C.hail(m.agents[0], 2).subtitle, 'Waiting for approval in tmux · dotfiles · +2 more')
    assert.equal(C.hail(Object.assign({}, m.agents[0], { host: 'ghostty' }), 0).button, 'Go to window')
    assert.equal(C.summary(m), 'Crew: 1 agent, 1 needs you')
    assert.equal(C.summary(C.empty()), 'Crew: 0 agents')
    assert.deepEqual(C.jumpArgs(m.agents[0]), ['--pane', '%2', '--session', 'projects', '--window', '@0'])
    assert.deepEqual(C.jumpArgs({ jumpable: true, pane: '', pid: 5000 }), ['--pid', '5000'])
    assert.deepEqual(C.jumpArgs({ jumpable: false, pane: '%1' }), [], 'no jump for Riker or Rex')
    assert.deepEqual(C.jumpArgs(null), [])
}

// ---- sprites ----------------------------------------------------------------------
for (const [name, rows] of Object.entries(C.SPRITES)) {
    assert.equal(rows.length, 8, name + ' is 8 rows')
    assert.ok(rows.every(r => r.length === 8 && /^[#.]+$/.test(r)), name + ' is 8 x 8 of # and .')
}
assert.deepEqual(Object.keys(C.SPRITES).sort(), ['awake', 'hat', 'sleep', 'wave'])

// ---- the fixtures the sandbox shoots ------------------------------------------------
{
    const dir = path.join(__dirname, 'fixtures')
    const load = (n) => JSON.parse(fs.readFileSync(path.join(dir, n + '.json'), 'utf8'))
    const built = (n) => { const f = load(n); return C.build(f.crew, f.crew.now) }
    assert.equal(built('crew-0').total, 0)
    assert.deepEqual(built('crew-1').agents.map(a => a.mood), ['working'])
    assert.deepEqual(built('crew-3').agents.map(a => a.mood), ['needs', 'working', 'asleep'])
    const four = built('crew-4')
    assert.deepEqual(four.agents.map(a => a.mood), ['needs', 'working', 'working', 'asleep'], 'crew-4: needs first')
    assert.deepEqual(four.agents.map(a => a.name), ['Pi', 'Riker · worker', 'Claude Code', 'Codex'])
    assert.deepEqual(four.agents.map(a => a.where), ['tmux · waiting for approval', 'Riker job #12 · dotfiles', 'dotfiles · island mocks', 'idle 12 min'])
    assert.ok(four.agents[1].riker, 'crew-4 has the hat')
    assert.equal(C.money(four.spendToday), '$4.37')
    const many = built('crew-many')
    assert.ok(many.total > C.MAX_BOTS && many.total > C.MAX_ROWS, 'crew-many overflows both the pill and the panel')
    const calm = built('crew-calm')
    const hailing = C.build(load('crew-hail').crew, load('crew-hail').crew.now)
    assert.deepEqual(C.edges(calm, hailing).hails.length, 1, 'crew-calm then crew-hail raises one hail')
    assert.equal(C.edges(hailing, calm).vibes, true, 'crew-hail then crew-calm brings vibes')
    assert.equal(load('crew-stale').crew.fresh, false)
}

console.log('CREW_MODEL_PASS')
