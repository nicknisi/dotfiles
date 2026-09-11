.pragma library

// Bounded arithmetic: a hand-written tokenizer and recursive-descent parser.
// Never evaluates user input as code. Grammar mirrors the review prototype:
// + - * / % // ** ^, unary +/-, parentheses, sqrt sin cos tan log ln abs round
// ceil floor, constants pi e tau, "15% of 80" and "5%" percentages.

var FUNCS = {
  sqrt: Math.sqrt, sin: Math.sin, cos: Math.cos, tan: Math.tan,
  log: function(x) { return Math.log(x) / Math.LN10 }, ln: Math.log,
  abs: Math.abs, round: function(x) { return Math.round(x) },
  ceil: Math.ceil, floor: Math.floor
}
var CONSTS = { pi: Math.PI, e: Math.E, tau: 2 * Math.PI }
var MAX_TOKENS = 90

function CalcError(kind, message) {
  this.kind = kind          // "syntax" for incomplete/malformed, "value" for out of range
  this.message = message
}

function preprocess(text) {
  var t = String(text || "")
  if (t.length > 256) throw new CalcError("value", "Expression too long")
  t = t.trim().replace(/^=+/, "").trim().replace(/×/g, "*").replace(/÷/g, "/").replace(/\^/g, "**")
  t = t.replace(/(\d+(?:\.\d+)?)\s*%\s+of\s+/gi, "($1/100)*")
  t = t.replace(/(\d+(?:\.\d+)?)%(?!\s*\d)/g, "($1/100)")
  return t
}

function tokenize(text) {
  var tokens = [], i = 0
  while (i < text.length) {
    var c = text.charAt(i)
    if (c === " " || c === "\t") { i++; continue }
    var m
    if ((m = /^\d+(?:\.\d*)?(?:e[+-]?\d+)?|^\.\d+(?:e[+-]?\d+)?/i.exec(text.slice(i)))) {
      tokens.push({ t: "num", v: parseFloat(m[0]) }); i += m[0].length; continue
    }
    if ((m = /^[a-z_][a-z0-9_]*/i.exec(text.slice(i)))) {
      tokens.push({ t: "id", v: m[0].toLowerCase() }); i += m[0].length; continue
    }
    if (text.substr(i, 2) === "**" || text.substr(i, 2) === "//") { tokens.push({ t: "op", v: text.substr(i, 2) }); i += 2; continue }
    if ("+-*/%()".indexOf(c) >= 0) { tokens.push({ t: "op", v: c }); i++; continue }
    throw new CalcError("syntax", "Unsupported character")
  }
  if (tokens.length > MAX_TOKENS) throw new CalcError("value", "Expression too complex")
  return tokens
}

function check(v) {
  if (typeof v !== "number" || !isFinite(v) || Math.abs(v) > 1e150) throw new CalcError("value", "Result out of range")
  return v
}

function floorMod(a, b) {
  if (b === 0) throw new CalcError("value", "Division by zero")
  return a - b * Math.floor(a / b)
}

function Parser(tokens) { this.tokens = tokens; this.pos = 0 }
Parser.prototype.peek = function() { return this.tokens[this.pos] }
Parser.prototype.next = function() { return this.tokens[this.pos++] }
Parser.prototype.isOp = function(v) { var t = this.peek(); return t && t.t === "op" && t.v === v }
Parser.prototype.expr = function() {
  var v = this.term()
  while (this.isOp("+") || this.isOp("-")) {
    var op = this.next().v, r = this.term()
    v = check(op === "+" ? v + r : v - r)
  }
  return v
}
Parser.prototype.term = function() {
  var v = this.unary()
  while (this.isOp("*") || this.isOp("/") || this.isOp("%") || this.isOp("//")) {
    var op = this.next().v, r = this.unary()
    if (op === "*") v = v * r
    else if (op === "/") { if (r === 0) throw new CalcError("value", "Division by zero"); v = v / r }
    else if (op === "%") v = floorMod(v, r)
    else { if (r === 0) throw new CalcError("value", "Division by zero"); v = Math.floor(v / r) }
    check(v)
  }
  return v
}
Parser.prototype.unary = function() {
  if (this.isOp("+")) { this.next(); return this.unary() }
  if (this.isOp("-")) { this.next(); return check(-this.unary()) }
  return this.power()
}
Parser.prototype.power = function() {
  var base = this.primary()
  if (this.isOp("**")) {
    this.next()
    var exp = this.unary()   // right-associative, like Python
    if (Math.abs(exp) > 1000 || Math.abs(base) > 1e100) throw new CalcError("value", "Exponent too large")
    return check(Math.pow(base, exp))
  }
  return base
}
Parser.prototype.primary = function() {
  var t = this.next()
  if (!t) throw new CalcError("syntax", "Incomplete expression")
  if (t.t === "num") return check(t.v)
  if (t.t === "id") {
    if (CONSTS[t.v] !== undefined && !this.isOp("(")) return CONSTS[t.v]
    if (FUNCS[t.v] && this.isOp("(")) {
      this.next()
      var arg = this.expr()
      if (!this.isOp(")")) throw new CalcError("syntax", "Expected )")
      this.next()
      return check(FUNCS[t.v](arg))
    }
    throw new CalcError("value", "Unsupported expression")
  }
  if (t.t === "op" && t.v === "(") {
    var v = this.expr()
    if (!this.isOp(")")) throw new CalcError("syntax", "Expected )")
    this.next()
    return v
  }
  throw new CalcError("syntax", "Unexpected token")
}

function calculate(text) {
  var tokens = tokenize(preprocess(text))
  if (!tokens.length) throw new CalcError("syntax", "Empty expression")
  var p = new Parser(tokens)
  var v = p.expr()
  if (p.pos !== tokens.length) throw new CalcError("syntax", "Unexpected trailing input")
  return check(v)
}

// Python-like %g formatting with `precision` significant digits.
function format(value, precision) {
  var p = Math.max(1, Math.min(21, Number(precision) || 12))
  var n = Number(Number(value).toPrecision(p))
  if (Math.abs(n) >= 1e16 || (n !== 0 && Math.abs(n) < 1e-4)) return n.toExponential(Math.max(0, p - 1)).replace(/\.?0+e/, "e")
  return String(n)
}

// Returns { value } or { partial: prefix } (an unfinished expression whose
// prefix evaluates) or null (not arithmetic).
function evaluate(text) {
  try {
    return { value: calculate(text) }
  } catch (e) {
    if (!(e instanceof CalcError) || e.kind !== "syntax") return null
    var partial = String(text || "").trim()
    var prefix = partial.replace(/[+\-*\/^×÷%]+\s*$/, "").trim()
    if (!prefix || prefix === partial) return null
    try { calculate(prefix); return { partial: partial } } catch (e2) { return null }
  }
}
