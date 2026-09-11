import QtQuick
import Quickshell
import Quickshell.Io
import "Policy.js" as Policy

Item {
  id: root
  property var host: null
  property var settings: ({})
  property string home: Quickshell.env("HOME")
  property string threadId: ""
  property string turnId: ""
  property string completedTurnId: ""
  property string title: "Quick question"
  property string draft: ""
  property string error: ""
  property string activity: ""
  property string mode: "quick"
  property string cwd: home + "/.local/state/keystroke/questions"
  property string phase: "idle"
  readonly property bool busy: phase !== "idle"
  visible: false
  property bool loaded: false
  property bool cancelRequested: false
  property bool handoffPending: false
  property int epoch: 0
  property int turnSerial: 0
  property real startedTime: 0
  property int lastMs: 0
  property int firstTextMs: 0
  property string submitted: ""
  property var messages: []
  property var recent: []
  property var approvals: []
  property var deltas: ({})
  property var afterReady: null
  property var launchCommand: []
  property string launchError: ""
  signal changed()
  signal handoffReady(string threadId)
  readonly property alias server: rpc

  AppServer {
    id: rpc
    keepBusy: root.busy
    onReadyChanged: if (ready && root.afterReady) { var fn = root.afterReady; root.afterReady = null; fn() }
    onEvent: (method, params) => root.handleEvent(method, params)
    onServerRequest: (id, method, params) => root.handleRequest(id, method, params)
    onStopped: { root.loaded = false; if (root.handoffPending && !root.busy && root.threadId) { root.handoffPending = false; root.handoffReady(root.threadId) } }
    onDisconnected: function(message) {
      root.loaded = false; root.afterReady = null; root.handoffPending = false
      root.phase = "idle"; root.approvals = []; root.error = message
      if (root.submitted && !root.draft) root.draft = root.submitted
      root.saveRecent(); root.changed()
    }
  }
  FileView {
    id: historyFile
    path: root.home + "/.local/state/keystroke/codex.json"
    atomicWrites: true
    printErrors: false
    onLoaded: {
      try {
        var d = JSON.parse(text())
        if (d.version === 1 && Array.isArray(d.recent)) root.recent = d.recent.filter(x => Policy.safeId(x.id)).slice(0, 40)
      } catch (_) { root.error = "Could not read recent questions" }
    }
  }
  function saveRecent() {
    if (!Policy.safeId(threadId)) return
    var row = {id: threadId, title: title, cwd: cwd, mode: mode, draft: draft, updated: Date.now()}
    recent = [row].concat(recent.filter(x => x.id !== threadId)).slice(0, 40)
    historyFile.setText(JSON.stringify({version: 1, recent: recent}, null, 2) + "\n")
    changed()
  }
  function warm() { rpc.ensure() }
  function whenReady(fn) {
    if (rpc.ready) fn()
    else { afterReady = fn; rpc.ensure() }
  }
  function newQuestion(text, agentCwd) {
    if (busy) { error = "Stop the current answer before starting another question"; return false }
    saveRecent(); paint.stop(); deltas = ({})
    epoch++; threadId = ""; turnId = ""; loaded = false; messages = []
    mode = agentCwd ? "agent" : "quick"
    cwd = agentCwd || home + "/.local/state/keystroke/questions"
    title = mode === "agent" ? "Task" : "Quick question"
    draft = String(text || ""); error = ""; activity = ""; submitted = ""
    if (draft.trim()) submit()
    return true
  }
  function openRecent(row) {
    if (busy) return false
    saveRecent(); paint.stop(); deltas = ({})
    epoch++; threadId = row.id; title = row.title; cwd = row.cwd; mode = row.mode || "quick"
    draft = row.draft || ""; messages = []; loaded = false; error = ""; submitted = ""
    phase = "preparing"; cancelRequested = false
    var token = epoch
    whenReady(function() { if (token === root.epoch && !root.cancelRequested) root.prepare(function() { root.phase = "idle" }) })
    return true
  }
  function params() {
    var p = Policy.start(home, settings, rpc.configuration)
    if (mode === "agent") {
      p.cwd = cwd; p.environments = null; p.sandbox = "workspace-write"; p.approvalPolicy = "on-request"; p.approvalsReviewer = "user"
      p.baseInstructions = "You are Codex, an agent embedded in Keystroke. Complete the user's explicitly selected task using the available tools. Inspect before changing, follow the working folder's instructions, verify the result, and report concisely. Respect the working scope and request additional permission when needed."
      p.config = {"features.hooks": false, "model_reasoning_effort": "low", "web_search": "live"}
    }
    if (threadId) {
      p.threadId = threadId
      delete p.ephemeral; delete p.serviceName; delete p.historyMode; delete p.environments
    }
    return p
  }
  function prepare(done) {
    var token = epoch
    var model = settings.model || Policy.MODEL
    if (model && !rpc.models.some(x => x.model === model || x.id === model)) { fail("Selected model is unavailable: " + model); return }
    if (rpc.accountState !== "Signed in") { fail("Sign in using codex login, then reopen this question."); return }
    var existed = !!threadId
    rpc.request(existed ? "thread/resume" : "thread/start", params(), function(result, error) {
      if (token !== root.epoch) return
      if (error) { root.fail(Policy.plainError(error)); return }
      root.threadId = result.thread.id; root.loaded = true
      if (existed) root.restore(result.thread.turns || [])
      root.saveRecent()
      if (root.cancelRequested) { root.phase = "idle"; root.finishHandoff(); return }
      done()
    }, 45000)
  }
  function restore(turns) {
    var out = []
    for (var turn of turns) for (var item of turn.items || []) {
      if (item.type === "userMessage") out.push({id: item.id, role: "user", text: (item.content || []).filter(x => x.type === "text").map(x => x.text).join("\n")})
      else if (item.type === "agentMessage") out.push({id: item.id, role: "assistant", text: item.text || ""})
      else if (item.type === "commandExecution" || item.type === "fileChange") out.push({id: item.id, role: "activity", text: item.command || (item.changes || []).map(x => x.path).join("\n")})
    }
    messages = out.slice(-160)
  }
  function submit() {
    var text = draft
    if (!text.trim() || phase === "preparing" || phase === "sending" || phase === "stopping") return false
    if (busy) { steer(text); return true }
    error = ""; activity = "Connecting…"; cancelRequested = false
    submitted = text; phase = "preparing"; handoffPending = false
    var token = epoch
    whenReady(function() {
      if (token !== root.epoch || root.cancelRequested) return
      if (!root.loaded) root.prepare(function() { root.beginTurn(text) })
      else root.beginTurn(text)
    })
    return true
  }
  function beginTurn(text) {
    if (cancelRequested) { phase = "idle"; return }
    turnId = ""; completedTurnId = ""
    startedTime = Date.now(); lastMs = 0; firstTextMs = 0
    activity = "Answering…"; phase = "sending"
    if (title === "Quick question" || title === "Task") {
      title = text.replace(/\s+/g, " ").trim().slice(0, 80)
      rpc.request("thread/name/set", {threadId: threadId, name: title}, function() {})
    }
    var token = epoch, serial = ++turnSerial
    var p = {threadId: threadId, input: Policy.textInput(text), model: settings.model || Policy.MODEL,
      effort: "low", serviceTier: settings.fast === false ? "default" : "fast"}
    if (mode === "quick") p.environments = []
    rpc.request("turn/start", p, function(result, error) {
      if (token !== root.epoch || serial !== root.turnSerial) return
      if (error && root.handoffPending && !root.busy) return
      if (error) { root.fail(Policy.plainError(error)); return }
      if (root.completedTurnId !== result.turn.id) root.turnId = result.turn.id
      if (root.draft === text) root.draft = ""
      // Notifications can complete a turn before the start response arrives.
      if (root.phase === "sending") root.phase = "running"
      if (root.cancelRequested && root.busy) root.interrupt()
      root.saveRecent()
    })
  }
  function steer(text) {
    if (!turnId || phase !== "running" || approvals.length) return
    var token = epoch, serial = turnSerial
    rpc.request("turn/steer", {threadId: threadId, expectedTurnId: turnId, input: Policy.textInput(text)}, function(result, error) {
      if (token !== root.epoch || serial !== root.turnSerial) return
      if (error) { root.error = Policy.plainError(error); return }
      if (root.draft === text) root.draft = ""
      root.saveRecent()
    })
  }
  function fail(message) { phase = "idle"; error = message; activity = ""; handoffPending = false; saveRecent() }
  function stop() {
    if (!busy) return
    cancelRequested = true
    if (afterReady) { afterReady = null; phase = "idle"; finishHandoff(); return }
    if (turnId) interrupt()
    // Preparing/sending RPCs settle first, then their callbacks observe cancellation.
  }
  function interrupt() {
    if (!turnId || phase === "stopping") return
    phase = "stopping"; activity = "Stopping…"
    rpc.request("turn/interrupt", {threadId: threadId, turnId: turnId}, function(result, error) {
      if (error) { root.error = Policy.plainError(error); root.handoffPending = false }
    })
  }
  Timer { interval: 10000; running: root.phase === "stopping"; onTriggered: rpc.fail("Codex did not acknowledge stopping. The connection was closed; reopen the saved question to continue.") }
  function dismiss() { visible = false; handoffPending = false; stop(); saveRecent() }
  function shutdown() { dismiss(); rpc.shutdown(); loaded = false }
  function upsert(id, role, text) {
    var copy = messages.slice(), index = copy.findIndex(x => x.id === id)
    var item = {id: id, role: role, text: String(text || "").slice(-250000)}
    if (index < 0) copy.push(item); else copy[index] = item
    messages = copy.slice(-160)
  }
  function flush() {
    var copy = deltas; deltas = ({})
    for (var id in copy) {
      var existing = messages.find(x => x.id === id)
      upsert(id, "assistant", (existing ? existing.text : "") + copy[id])
    }
  }
  Timer { id: paint; interval: 32; onTriggered: root.flush() }
  function handleEvent(method, p) {
    if (p.threadId && p.threadId !== threadId) return
    if (!threadId) return
    if (method === "turn/started") {
      turnId = p.turn.id
      if (busy && phase !== "stopping") phase = "running"
      if (cancelRequested) interrupt()
    } else if (method === "item/agentMessage/delta") {
      if (!busy || (p.turnId && turnId && p.turnId !== turnId)) return
      if (!firstTextMs) firstTextMs = Date.now() - startedTime
      var copy = Object.assign({}, deltas); copy[p.itemId] = (copy[p.itemId] || "") + (p.delta || ""); deltas = copy
      if (!paint.running) paint.start()
    } else if (method === "item/started" || method === "item/completed") {
      if (p.turnId && turnId && p.turnId !== turnId) return
      flush()
      var item = p.item || {}
      if (item.type === "userMessage") upsert(item.id, "user", (item.content || []).filter(x => x.type === "text").map(x => x.text).join("\n"))
      else if (item.type === "agentMessage" && (method === "item/completed" || item.text)) upsert(item.id, "assistant", item.text)
      else if (item.type === "webSearch") activity = "Searching the web…"
      else if (item.type === "commandExecution") { activity = "Running: " + (item.command || "command"); upsert(item.id, "activity", item.command) }
      else if (item.type === "fileChange") { activity = "Updating files…"; upsert(item.id, "activity", (item.changes || []).map(x => x.path + "\n" + (x.diff || "")).join("\n")) }
      else if (item.type === "mcpToolCall") activity = "Using " + item.server + " · " + item.tool
    } else if (method === "turn/completed") {
      if (turnId && p.turn.id !== turnId) return
      flush(); completedTurnId = p.turn.id; phase = "idle"; turnId = ""; approvals = []; lastMs = Date.now() - startedTime
      error = p.turn.error ? Policy.plainError(p.turn.error) : ""
      activity = p.turn.status === "interrupted" ? "Stopped" : p.turn.status === "failed" ? "Failed" : "Done"
      if (p.turn.status === "failed" && !draft) draft = submitted
      submitted = ""; saveRecent(); finishHandoff()
    } else if (method === "error") error = Policy.plainError(p.error)
    else if (method === "serverRequest/resolved") approvals = approvals.filter(x => x.id !== p.requestId)
  }
  function handleRequest(id, method, p) {
    if (mode !== "agent" || !busy || p.threadId !== threadId || (p.turnId && p.turnId !== turnId)) { rpc.reject(id, "This capability is unavailable for the current turn"); return }
    if (method === "item/commandExecution/requestApproval" || method === "item/fileChange/requestApproval" || method === "item/permissions/requestApproval" || method === "item/tool/requestUserInput") {
      approvals = approvals.concat([{id: id, method: method, params: p}]); activity = "Waiting for your input"
    } else rpc.reject(id, "This request needs the full Codex app. Continue there to use it.")
  }
  function decide(accept, answer) {
    if (!approvals.length) return
    var a = approvals[0], p = a.params, result
    if (a.method === "item/permissions/requestApproval") result = {permissions: accept ? p.permissions : {}, scope: "turn"}
    else if (a.method === "item/tool/requestUserInput") {
      var answers = {}; for (var q of p.questions || []) answers[q.id] = {answers: [(answer && answer[q.id]) || "Cancelled"]}
      result = {answers: answers}
    } else result = {decision: accept ? "accept" : "decline"}
    rpc.respond(a.id, result); approvals = approvals.slice(1)
    if (!accept && a.method === "item/tool/requestUserInput") stop()
  }
  function requestHandoff() {
    if (!threadId) { error = "Send a question before continuing in Codex"; return }
    if (!rpc.ready && !busy) { handoffReady(threadId); return }
    handoffPending = true
    if (busy) stop(); else finishHandoff()
  }
  function finishHandoff() {
    if (!handoffPending || busy || !threadId) return
    saveRecent()
    // Unsubscribe retains the writer for a grace period. Exit our owned server
    // before opening another client, otherwise its resume fails with writer busy.
    loaded = false
    rpc.shutdown()
  }

  function answer() { var replies = messages.filter(x => x.role === "assistant"); return replies.length ? replies[replies.length - 1].text : "" }
  function approvalDetail(a) {
    if (!a) return ""
    var p = a.params, item = messages.find(x => x.id === p.itemId)
    return (p.reason || "") + (p.cwd ? "\nWorking folder: " + p.cwd : "") + "\n" + (p.command || (item ? item.text : ""))
      + (p.permissions ? "\n" + JSON.stringify(p.permissions, null, 2) : "")
      + (p.networkApprovalContext ? "\nNetwork: " + JSON.stringify(p.networkApprovalContext) : "")
      + (p.additionalPermissions ? "\nAdditional access: " + JSON.stringify(p.additionalPermissions) : "")
  }
}
