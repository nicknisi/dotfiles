function rowText(row) {
    return [row.name, row.genericName, row.comment, String(row.keywords || "")]
        .filter(function(value) { return value; })
        .join(" ")
        .toLowerCase();
}

function score(row, text) {
    var needle = String(text || "").trim().toLowerCase();
    if (!needle) return row.kind === "action" ? 10000 + row.order : 0;

    var name = String(row.name || "").toLowerCase();
    var haystack = rowText(row);
    if (name === needle) return 0;
    if (name.indexOf(needle) === 0) return 10 + name.length - needle.length;
    var nameIndex = name.indexOf(needle);
    if (nameIndex >= 0) return 30 + nameIndex;
    var textIndex = haystack.indexOf(needle);
    if (textIndex >= 0) return 50 + textIndex;

    var cursor = -1;
    var gaps = 0;
    for (var i = 0; i < needle.length; i++) {
        var next = haystack.indexOf(needle[i], cursor + 1);
        if (next < 0) return -1;
        gaps += next - cursor - 1;
        cursor = next;
    }
    return 100 + gaps + cursor;
}

function buildResults(text, apps, actions) {
    var rows = [];
    for (var i = 0; i < apps.length; i++) rows.push(apps[i]);
    for (var j = 0; j < actions.length; j++) rows.push(actions[j]);

    var ranked = [];
    for (var k = 0; k < rows.length; k++) {
        var points = score(rows[k], text);
        if (points >= 0) ranked.push({ row: rows[k], points: points });
    }
    ranked.sort(function(a, b) {
        return a.points - b.points || String(a.row.name).localeCompare(String(b.row.name));
    });
    return ranked.map(function(item) { return item.row; });
}

if (typeof module !== "undefined") {
    module.exports = { score: score, buildResults: buildResults };
}
