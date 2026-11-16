// PickerNav.js - the theme and wallpaper pickers' grid, as pure functions
// (PLAN M7, launcher-pickers 7.3). Panels/PickerModel.qml holds the state and
// the keys; this decides where focus goes, so tests/tst_picker_nav.qml can
// check it with any rows.
//
// Rows are `theme _rows` records ({ name, label, current, ... }). A filter is
// a case-insensitive substring of the name or the label (ThemePicker's old
// matches()). Cards that do not match leave the grid and the rest reflow, so
// every move counts in positions among the matches, never in row indices.
//
//   step        Left / Right: the previous or next match, wrapping
//   vertical    Up / Down: the same column a row up or down; Down onto a
//               shorter last row lands on its last card; no wrap
//   edge        Home / End: the first or last match
//   fallback    the focused card stopped matching: the first match
//
// Indices are row indices; -1 means nothing to focus (no rows, no matches).

function matches(row, filter) {
    var needle = String(filter || "").toLowerCase();
    if (!needle) return true;
    if (!row) return false;
    return String(row.name || "").toLowerCase().indexOf(needle) >= 0
        || String(row.label || "").toLowerCase().indexOf(needle) >= 0;
}

// Row indices of the matches, in order.
function shown(rows, filter) {
    var out = [];
    for (var i = 0; i < (rows || []).length; i++)
        if (matches(rows[i], filter)) out.push(i);
    return out;
}

// Row index -> its position among the matches, -1 for a card filtered out.
function positions(rows, filter) {
    var out = [], p = 0;
    for (var i = 0; i < (rows || []).length; i++)
        out.push(matches(rows[i], filter) ? p++ : -1);
    return out;
}

function count(rows, filter) {
    return shown(rows, filter).length;
}

function positionOf(rows, filter, index) {
    var list = shown(rows, filter);
    return list.indexOf(index);
}

// The applied row, else the first; -1 for no rows.
function currentIndex(rows) {
    for (var i = 0; i < (rows || []).length; i++)
        if (rows[i] && rows[i].current === true) return i;
    return (rows || []).length > 0 ? 0 : -1;
}

function fallback(rows, filter, index) {
    var list = shown(rows, filter);
    if (list.length === 0) return -1;
    return list.indexOf(index) >= 0 ? index : list[0];
}

function step(rows, filter, index, dir) {
    var list = shown(rows, filter);
    if (list.length === 0) return -1;
    var p = list.indexOf(index);
    if (p < 0) return list[0];
    var n = list.length;
    return list[((p + (dir < 0 ? -1 : 1)) % n + n) % n];
}

function vertical(rows, filter, index, columns, dir) {
    var list = shown(rows, filter);
    if (list.length === 0) return -1;
    var p = list.indexOf(index);
    if (p < 0) return list[0];
    var cols = Math.max(1, columns | 0);
    var row = Math.floor(p / cols), lastRow = Math.floor((list.length - 1) / cols);
    if (dir < 0) return row === 0 ? index : list[p - cols];
    if (row === lastRow) return index;
    return list[Math.min(p + cols, list.length - 1)];
}

function edge(rows, filter, last) {
    var list = shown(rows, filter);
    if (list.length === 0) return -1;
    return last ? list[list.length - 1] : list[0];
}

// The grid row (0-based, among the matches) a card sits on.
function gridRow(rows, filter, index, columns) {
    var p = positionOf(rows, filter, index);
    return p < 0 ? -1 : Math.floor(p / Math.max(1, columns | 0));
}

// The first visible grid row that keeps `row` inside a `visibleRows`-row
// viewport whose first row is `top`, moving as little as possible.
function scrollTop(top, row, visibleRows, totalRows) {
    var t = top;
    if (row < 0) return Math.max(0, Math.min(t, Math.max(0, totalRows - visibleRows)));
    if (row < t) t = row;
    else if (row > t + visibleRows - 1) t = row - visibleRows + 1;
    return Math.max(0, Math.min(t, Math.max(0, totalRows - visibleRows)));
}

// Columns for a panel `width` wide: (width - 40 + 12) / (card + 12), between
// `min` and `max` (launcher-pickers 7.1: 8 at 1240, at least 4).
function columnsFor(width, card, min, max) {
    var n = Math.floor((width - 40 + 12) / (card + 12));
    return Math.max(min, Math.min(max, n));
}

// The filter after an edit key: Backspace drops a character, Ctrl+Backspace a
// word (and the spaces after it), Ctrl+U everything. `kind` is "char", "word"
// or "all".
function edited(filter, kind) {
    var f = String(filter || "");
    if (kind === "all") return "";
    if (kind === "word") return f.replace(/\s+$/, "").replace(/\S+$/, "");
    return f.slice(0, -1);
}

// A path -> a file:// URL, each segment escaped (spaces, #, ? in names).
function fileUrl(path) {
    if (!path) return "";
    return "file://" + String(path).split("/").map(encodeURIComponent).join("/");
}

if (typeof module !== "undefined")
    module.exports = {
        matches: matches, shown: shown, positions: positions, count: count, positionOf: positionOf,
        currentIndex: currentIndex, fallback: fallback, step: step, vertical: vertical, edge: edge,
        gridRow: gridRow, scrollTop: scrollTop, columnsFor: columnsFor, edited: edited, fileUrl: fileUrl
    };
