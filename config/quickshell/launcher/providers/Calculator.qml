import QtQuick
import "../core/Calculator.js" as Calc

// Arithmetic at the prompt: `12*34`, `sqrt(2)`, `2^10 % 7`, `pi*3`. Enter
// copies the result. The parser is the bounded one spoken input already uses
// (core/Calculator.js): a tokenizer and a recursive-descent grammar, never
// eval. A bare number or word is not a question, so typing an app name never
// shows a stray answer row.
Item {
  id: root
  property var host: null

  readonly property var provider: ({
    apiVersion: 1,
    id: "calculator",
    name: "Calculator",
    icon: "󰃬",
    color: "#e5c07b",
    description: "Arithmetic with functions and constants; Enter copies the result",
    settings: [{ key: "precision", type: "string", label: "Significant digits", "default": "12" }],
    query: function(ctx) { return root.query(ctx) }
  })

  // At least one operator or a function call. "42" alone is not asked anything.
  function looksLikeMath(q) {
    return /[-+*\/^%×÷]/.test(q) || /\b(sqrt|sin|cos|tan|log|ln|abs|round|ceil|floor)\s*\(/.test(q)
  }

  function query(ctx) {
    if (ctx.scope) return []
    var q = String(ctx.query || "").trim()
    if (!q || !root.looksLikeMath(q)) return []
    var result = Calc.evaluate(q)
    if (!result || result.value === undefined) return []
    var text = Calc.format(result.value, ctx.settings && ctx.settings.precision)
    return [{ id: "calc", title: text, subtitle: q + " =", icon: "󰃬", section: "Calculator", verb: "Copy result",
              tier: "answer", score: 196, action: { type: "copy", text: text },
              preview: text, previewLabel: "RESULT", previewDetail: q }]
  }
}
