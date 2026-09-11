.pragma library
.import "Calculator.js" as Calc

// Speech normalization applies only to local search, never AI prompts or clipboard.
var VERB = /^(?:please\s+)?(?:can you\s+|could you\s+)?(?:launch|open up|open|run|start|go to|goto|show me|show|find|search for|search|look up|toggle|turn on|turn off|switch to|switch)\s+/i
var STOP = { the: true, a: true, an: true, my: true, please: true, up: true }
var TRAIL = /[\s.,!?;:…]+$/
var LEAD = /^[\s.,!?;:…"'“”‘’]+/

function normalize(transcript) {
  var expression = arithmetic(transcript)
  if (expression) return expression
  var t = String(transcript || "").replace(/\s+/g, " ").trim().replace(TRAIL, "").replace(LEAD, "")
  if (!t) return ""
  var verbless = t.replace(VERB, "")
  var words = verbless.split(" ").filter(function(w) { return w && !STOP[w.toLowerCase().replace(TRAIL, "")] })
  var out = words.join(" ").replace(TRAIL, "").trim()
  return out || t
}

// Accept a whole spoken expression, never replace operator words in prose.
function arithmetic(text) {
  var q = String(text || "").toLowerCase().trim().replace(/[?!.,]+$/, "")
  if (q.length > 256) return ""
  q = q.replace(/^(?:please\s+)?(?:what is|what's|calculate|compute)\s+/, "")
  var digits = { zero:0, one:1, two:2, three:3, four:4, five:5, six:6, seven:7, eight:8, nine:9,
    ten:10, eleven:11, twelve:12, thirteen:13, fourteen:14, fifteen:15, sixteen:16, seventeen:17, eighteen:18, nineteen:19,
    twenty:20, thirty:30, forty:40, fifty:50, sixty:60, seventy:70, eighty:80, ninety:90 }
  q = q.replace(/\bpoint ((?:(?:zero|one|two|three|four|five|six|seven|eight|nine)(?:\s+|$))+)/g, function(_, tail) {
    return "." + tail.trim().split(/\s+/).map(function(w) { return digits[w] }).join("") + " "
  })
  q = q.replace(/\b(twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety)[ -](one|two|three|four|five|six|seven|eight|nine)\b/g, function(_, a, b) { return String(digits[a] + digits[b]) })
  q = q.replace(/\b[a-z]+\b/g, function(w) { return Object.prototype.hasOwnProperty.call(digits, w) ? String(digits[w]) : w })
  q = q.replace(/\b([1-9]) hundred(?: and)?(?: (\d{1,2}))?\b/g, function(_, a, b) { return String(Number(a) * 100 + Number(b || 0)) })
  q = q.replace(/\b(\d+)\s*point\s*(\d+)\b/g, "$1.$2").replace(/(\d)\s+\.(\d)/g, "$1.$2")
  q = q.replace(/\bto the power of\b/g, "**").replace(/\bmultiplied by\b/g, "*").replace(/\bdivided by\b/g, "/")
    .replace(/\bplus\b/g, "+").replace(/\bminus\b/g, "-").replace(/\btimes\b/g, "*").replace(/\bnegative\b/g, "-").replace(/\bpercent\b/g, "%")
  var sub = /^subtract (\d+(?:\.\d+)?) from (\d+(?:\.\d+)?)$/.exec(q)
  if (sub) q = sub[2] + " - " + sub[1]
  if (!/^[\d\s.+*/%()^-]+(?:of\s+\d+(?:\.\d+)?)?$/.test(q) || !/[+*/%^-]/.test(q)) return ""
  var result = Calc.evaluate(q)
  return result && result.value !== undefined ? q.trim() : ""
}
