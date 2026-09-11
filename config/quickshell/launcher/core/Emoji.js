.pragma library
.import "Match.js" as Match

function title(keywords) {
  var ws = String(keywords || "").split(/\s+/).slice(0, 6).join(" ")
  return ws.charAt(0).toUpperCase() + ws.slice(1)
}

// data: [{e, k}] from the bundled Unicode emoji-test dataset. Returns at most `limit` rows.
function search(data, query, limit) {
  var out = []
  for (var i = 0; i < data.length; i++) {
    var s = Match.match(query, data[i].k, "")
    if (s) out.push({ index: i, e: data[i].e, k: data[i].k, score: s })
  }
  out.sort(function(a, b) { return b.score - a.score || a.index - b.index })
  return out.slice(0, limit || 80)
}
