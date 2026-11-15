// Calendar.js - the island's month grid (PLAN M3, main-tokens 2.5.5).
//
// The Main board's calendar is always six rows of seven, Sunday first: 42
// cells, starting on the Sunday on or before the 1st, so the leading days
// belong to the month before and the trailing ones to the month after. The
// board's own loop only works for November 2026 (the 1st is a Sunday); this
// one works for any month.
//
// Dates are built from year, month and day every time (new Date(y, m, d)),
// never by adding milliseconds, so a daylight-saving change inside the grid
// cannot shift a cell. Month names are the board's English ones.
//
// No .pragma library: node loads this file too (tests/calendar.cjs).

var WEEKDAYS = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"];
var MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
var CELLS = 42;

function daysIn(year, month) {
    return new Date(year, month + 1, 0).getDate();
}

// year, month (0-11) moved by delta months.
function shift(year, month, delta) {
    var d = new Date(year, month + delta, 1);
    return { year: d.getFullYear(), month: d.getMonth() };
}

// "November 2026"
function title(year, month) {
    return MONTHS[month] + " " + year;
}

// The 42 cells for year, month (0-11). today is a Date (or null): its cell
// is marked. Each cell: { year, month, day, inMonth, today, key }, key
// "2026-11-14".
function cells(year, month, today) {
    var lead = new Date(year, month, 1).getDay();
    var t = today ? { y: today.getFullYear(), m: today.getMonth(), d: today.getDate() } : null;
    var out = [];
    for (var i = 0; i < CELLS; i++) {
        var date = new Date(year, month, 1 - lead + i);
        var y = date.getFullYear(), m = date.getMonth(), d = date.getDate();
        out.push({
            year: y,
            month: m,
            day: d,
            inMonth: m === month && y === year,
            today: t !== null && t.y === y && t.m === m && t.d === d,
            key: y + "-" + (m < 9 ? "0" : "") + (m + 1) + "-" + (d < 10 ? "0" : "") + d
        });
    }
    return out;
}

if (typeof module !== "undefined")
    module.exports = { WEEKDAYS: WEEKDAYS, MONTHS: MONTHS, CELLS: CELLS, daysIn: daysIn, shift: shift, title: title, cells: cells };
