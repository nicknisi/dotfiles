// lib/WorkspaceOrder.js: which workspaces the island shows, in which order (PLAN M1).
const assert = require('node:assert/strict')
const O = require('../lib/WorkspaceOrder.js')

// The fixed order: letters A W C D N S X Z, then 1-9, then everything else A-Z.
assert.deepEqual(O.LETTERS, ['A', 'W', 'C', 'D', 'N', 'S', 'X', 'Z'])
assert.deepEqual(O.sort(['Z', 'X', 'S', 'N', 'D', 'C', 'W', 'A']), ['A', 'W', 'C', 'D', 'N', 'S', 'X', 'Z'])
assert.deepEqual(O.sort(['S', 'D', 'W', 'C']), ['W', 'C', 'D', 'S'], 'the boards read W C D S')
assert.deepEqual(O.sort(['3', '1', '9', '2']), ['1', '2', '3', '9'])
assert.deepEqual(O.sort(['9', 'Z', '1', 'A']), ['A', 'Z', '1', '9'], 'letters before numbers')
assert.deepEqual(O.sort(['music', '10', 'B', '2', 'W', 'alpha']), ['W', '2', '10', 'B', 'alpha', 'music'],
    'other names (10, B, lower case) after 1-9, by code point')
assert.deepEqual(O.sort(['10', '1']), ['1', '10'], '10 is not in the 1-9 group')
const input = ['S', 'W']
O.sort(input)
assert.deepEqual(input, ['S', 'W'], 'sort() leaves its input alone')
assert.equal(O.compare('W', 'W'), 0)

// shown(): occupied or focused, no special workspaces, focus and urgency flags.
const live = [
    { name: 'S', windows: 2 },
    { name: 'D', windows: 1, urgent: true },
    { name: 'special:scratch', windows: 3 },
    { name: 'N', windows: 0 },
    { name: 'C', windows: 1, urgent: true },
    { name: 'W', windows: 4 },
    { name: 'W', windows: 1 },
    { name: '', windows: 1 },
    null,
]
assert.deepEqual(O.shown(live, 'D'), [
    { name: 'W', focused: false, urgent: false },
    { name: 'C', focused: false, urgent: true },
    { name: 'D', focused: true, urgent: false },
    { name: 'S', focused: false, urgent: false },
], 'W C D S with D focused; urgency only on unfocused; duplicates and blanks dropped')
assert.deepEqual(O.shown(live, 'N').map(w => w.name), ['W', 'C', 'D', 'N', 'S'], 'an empty workspace shows while focused')
assert.deepEqual(O.shown(live, 'special:scratch').map(w => w.name), ['W', 'C', 'D', 'S'], 'the scratchpad never shows')
assert.deepEqual(O.shown([], 'A'), [], 'no records, nothing shown (focus alone is not a record)')
assert.deepEqual(O.shown(undefined, ''), [])
assert.deepEqual(O.shown([{ name: 3, windows: 1 }], '3'), [{ name: '3', focused: true, urgent: false }], 'names are strings')
console.log('WORKSPACE_ORDER_PASS')
