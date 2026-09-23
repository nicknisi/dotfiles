const assert = require('node:assert/strict')
const model = require('../WindowSwitcherModel.js')
const a = { id: 'a', active: true, recency: 0 }
const b = { id: 'b', active: false, recency: 1 }
const c = { id: 'c', active: false, recency: 2 }
const original = [c, a, b]
const rows = model.snapshot(original)
assert.deepEqual(rows.map(w => w.id), ['a', 'b', 'c'])
assert.deepEqual(original, [c, a, b], 'snapshot does not reorder its input')
let index = model.cycle(0, 1, rows.length)
assert.equal(rows[index].id, 'b', 'first Tab selects previous window')
index = model.cycle(index, 1, rows.length)
assert.equal(rows[index].id, 'c')
assert.equal(model.cycle(index, 1, 3), 0, 'forward wraps')
assert.equal(model.cycle(0, -1, 3), 2, 'reverse wraps')
assert.equal(model.cycle(0, 1, 1), 0)
assert.equal(model.cycle(0, 1, 0), -1)
// Focus changes cannot reshuffle an open switcher.
b.recency = 7
assert.deepEqual(rows.map(w => w.id), ['a', 'b', 'c'])
assert.deepEqual(model.surviving(rows, ['b', 'c'], 1), { rows: [b, c], selected: 0 })
assert.deepEqual(model.surviving(rows, ['a', 'c'], 1), { rows: [a, c], selected: 1 })
assert.deepEqual(model.surviving(rows, ['a', 'b'], 2), { rows: [a, b], selected: 1 })
assert.deepEqual(model.surviving(rows, [], 0), { rows: [], selected: -1 })
console.log('WINDOW_SWITCHER_MODEL_PASS')
