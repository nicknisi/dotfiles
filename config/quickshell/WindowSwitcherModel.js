// A switch keeps its opening MRU order even when focus and urgency change.
function snapshot(rows) {
    return rows.slice().sort(function(a, b) {
        if (a.active !== b.active) return a.active ? -1 : 1;
        return a.recency - b.recency;
    });
}

function cycle(index, delta, count) {
    return count ? ((index + delta) % count + count) % count : -1;
}

function surviving(rows, liveIds, selected) {
    var selectedId = rows[selected] ? rows[selected].id : null;
    var kept = rows.filter(function(row) { return liveIds.indexOf(row.id) !== -1; });
    var index = kept.findIndex(function(row) { return row.id === selectedId; });
    return { rows: kept, selected: index >= 0 ? index : Math.min(selected, kept.length - 1) };
}

if (typeof module !== "undefined") module.exports = { snapshot: snapshot, cycle: cycle, surviving: surviving };
