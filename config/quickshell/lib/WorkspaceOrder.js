// WorkspaceOrder.js - which workspaces the island shows, and in what order.
//
// Hyprland gives named workspaces unstable negative ids (config/hypr/workspaces.lua
// says not to key off them), so sorting by id orders them by creation time. The
// island uses a fixed order instead: the lettered workspaces in the order the
// `letters` table in workspaces.lua first reaches them (A, W, C, D, N, S, X, Z),
// then the numbered ones 1 to 9, then any other name alphabetically. That is why
// the mock's strip reads W C D S.
//
// Plain JS, no QML: tests/workspace-order.cjs requires it under node, and the
// island imports it. Kit/WorkspaceStrip takes the array shown() returns.

var LETTERS = ["A", "W", "C", "D", "N", "S", "X", "Z"];

// Group, then position inside the group: letters 0, digits 1 to 9 next, the rest last.
function rank(name) {
    var n = String(name);
    var letter = LETTERS.indexOf(n);
    if (letter >= 0) return [0, letter, ""];
    if (/^[1-9]$/.test(n)) return [1, Number(n), ""];
    return [2, 0, n];
}

function compare(a, b) {
    var ra = rank(a), rb = rank(b);
    if (ra[0] !== rb[0]) return ra[0] - rb[0];
    if (ra[1] !== rb[1]) return ra[1] - rb[1];
    return ra[2] < rb[2] ? -1 : ra[2] > rb[2] ? 1 : 0;
}

function sort(names) {
    return names.slice().sort(compare);
}

// The strip's items from plain workspace records.
//   list     [{ name, windows, urgent }]: windows is the toplevel count, urgent
//            whether any of them asks for attention
//   focused  the focused workspace's name
// Special workspaces (the scratchpad) are overlays, not places to go. A
// workspace shows when it holds windows or is focused; urgency only counts on
// one that is not focused, since visiting it is what clears it.
// Returns [{ name, focused, urgent }] in rank order, one per name.
function shown(list, focused) {
    var seen = {};
    var out = [];
    (list || []).forEach(function (w) {
        if (!w || w.name === undefined || w.name === null) return;
        var name = String(w.name);
        if (name === "" || name.indexOf("special:") === 0 || seen[name]) return;
        var isFocused = name === focused;
        if (!isFocused && !(Number(w.windows) > 0)) return;
        seen[name] = true;
        out.push({ name: name, focused: isFocused, urgent: !isFocused && w.urgent === true });
    });
    return out.sort(function (a, b) { return compare(a.name, b.name); });
}

if (typeof module !== "undefined")
    module.exports = { LETTERS: LETTERS, rank: rank, compare: compare, sort: sort, shown: shown };
