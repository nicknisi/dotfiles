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

// WCAG 2 relative luminance of "#rrggbb", linearised at 0.03928 like the
// shell's token rules (lib/TokenMath.js), so "On bg" agrees with them.
function luminance(hex) {
  var h = String(hex || "").replace(/^#/, "")
  if (h.length === 3) h = h.split("").map(function(c) { return c + c }).join("")
  var c = [0, 2, 4].map(function(i) {
    var v = parseInt(h.substr(i, 2), 16) / 255
    return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
  })
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
}

function contrast(a, b) {
  var x = luminance(a), y = luminance(b)
  return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05)
}

// "15.1 : 1": one decimal, rounded half up.
function ratioText(ratio) {
  return (Math.round(Number(ratio) * 10) / 10).toFixed(1) + " : 1"
}

// The WCAG level a ratio reaches for body text, or "AA large" for large text only.
function level(ratio) {
  var r = Number(ratio)
  return r >= 7 ? "AAA" : r >= 4.5 ? "AA" : r >= 3 ? "AA large" : "Fail"
}

// The swatch's caption: "<theme> <key>" when the colour is one of the current
// pack's colors.json values, else the upper-case hex.
function caption(swatch, palette, themeName) {
  var want = String(swatch || "").toLowerCase()
  var keys = Object.keys(palette || {})
  for (var i = 0; i < keys.length; i++) {
    var v = palette[keys[i]]
    if (typeof v === "string" && v.toLowerCase() === want) return (themeName ? themeName + " " : "") + keys[i]
  }
  return want.toUpperCase()
}

// parse() plus the "On bg" row: the colour's contrast against `bg`.
function answer(text, bg) {
  var parsed = parse(text)
  if (!parsed) return null
  var ratio = contrast(parsed.swatch, bg)
  parsed.contrast = { label: "On bg", text: ratioText(ratio), ratio: ratio, level: level(ratio) }
  return parsed
}
