// lib/Calendar.js: the island calendar's grid (PLAN M3), every month of
// 2026 and 2027, in a zone with daylight-saving changes so a shifted cell
// would show (America/Chicago: March and November).
process.env.TZ = 'America/Chicago'
const assert = require('node:assert/strict')
const C = require('../lib/Calendar.js')

assert.deepEqual(C.WEEKDAYS, ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'], 'Sunday first (Main board)')
let months = 0
for (const year of [2026, 2027]) {
    for (let month = 0; month < 12; month++) {
        const name = C.title(year, month)
        const cells = C.cells(year, month, null)
        assert.equal(cells.length, 42, name + ': six rows of seven')
        cells.forEach((c, i) => assert.equal(new Date(c.year, c.month, c.day).getDay(), i % 7, name + ' cell ' + i + ' sits under its weekday'))
        const lead = new Date(year, month, 1).getDay()
        const inside = cells.filter(c => c.inMonth)
        assert.equal(inside.length, C.daysIn(year, month), name + ': every day of the month once')
        assert.equal(cells.findIndex(c => c.inMonth), lead, name + ': the 1st under its weekday')
        inside.forEach((c, i) => assert.equal(c.day, i + 1, name + ': days in order'))
        // Leading days: the previous month's last ones, consecutive.
        const prev = C.shift(year, month, -1)
        cells.slice(0, lead).forEach((c, i) => {
            assert.deepEqual([c.year, c.month, c.day, c.inMonth], [prev.year, prev.month, C.daysIn(prev.year, prev.month) - lead + 1 + i, false], name + ' lead ' + i)
        })
        // Trailing days: the next month from the 1st.
        const next = C.shift(year, month, 1)
        cells.slice(lead + inside.length).forEach((c, i) => {
            assert.deepEqual([c.year, c.month, c.day, c.inMonth], [next.year, next.month, i + 1, false], name + ' trail ' + i)
        })
        // Today: marked on its own cell only, and only in its own month's grid.
        const today = new Date(year, month, 14, 23, 30)
        const marked = C.cells(year, month, today).filter(c => c.today)
        assert.deepEqual(marked.map(c => c.key), [year + '-' + String(month + 1).padStart(2, '0') + '-14'], name + ': today is the 14th')
        assert.equal(C.cells(next.year, next.month, today).filter(c => c.today).length, 0, name + ': today is not marked a month on')
        months++
    }
}
assert.equal(months, 24)
// The board's month: November 2026 starts on a Sunday, so no leading days.
const nov = C.cells(2026, 10, new Date(2026, 10, 14))
assert.equal(nov[0].day, 1)
assert.equal(nov.findIndex(c => c.today), 13, 'Saturday the 14th is the second row\'s last cell')
assert.equal(C.title(2026, 10), 'November 2026')
assert.deepEqual(C.shift(2026, 11, 1), { year: 2027, month: 0 }, 'December rolls into January')
assert.deepEqual(C.shift(2026, 0, -1), { year: 2025, month: 11 })
// A leading cell may carry today's mark (today is the 30th of the month before).
assert.equal(C.cells(2027, 4, new Date(2027, 3, 30)).filter(c => c.today && !c.inMonth).length, 1, 'today in the leading days is marked too')
console.log('CALENDAR_PASS')
