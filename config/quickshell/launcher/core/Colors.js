.pragma library

// "#ff6644" or "fa8" -> HEX / RGB / HSL strings plus a swatch color.
function parse(text) {
  var q = String(text || "").trim()
  var m = /^#?([a-fA-F0-9]{6}|[a-fA-F0-9]{3})$/.exec(q)
  if (!m) return null
  if (q.charAt(0) !== "#" && !/[a-fA-F]/.test(q)) return null
  var hex = m[1].length === 6 ? m[1] : m[1].split("").map(function(c) { return c + c }).join("")
  var r = parseInt(hex.substr(0, 2), 16), g = parseInt(hex.substr(2, 2), 16), b = parseInt(hex.substr(4, 2), 16)
  var rf = r / 255, gf = g / 255, bf = b / 255
  var max = Math.max(rf, gf, bf), min = Math.min(rf, gf, bf)
  var l = (max + min) / 2, h = 0, s = 0
  if (max !== min) {
    var d = max - min
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
    if (max === rf) h = (gf - bf) / d + (gf < bf ? 6 : 0)
    else if (max === gf) h = (bf - rf) / d + 2
    else h = (rf - gf) / d + 4
    h /= 6
  }
  return {
    swatch: "#" + hex,
    values: [
      { label: "HEX", text: "#" + hex.toUpperCase() },
      { label: "RGB", text: "rgb(" + r + ", " + g + ", " + b + ")" },
      { label: "HSL", text: "hsl(" + Math.round(h * 360) + ", " + Math.round(s * 100) + "%, " + Math.round(l * 100) + "%)" }
    ]
  }
}
