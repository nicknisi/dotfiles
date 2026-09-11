#!/usr/bin/env python3
"""Offscreen native Extensions/SettingsProvider lifecycle, using only a local fixture."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

from extensions_helper_test import ExtensionsTest, MID

ROOT = Path(__file__).resolve().parents[1]


class ProviderTest(ExtensionsTest):
    # Reuse only the isolated local-git fixture, not its test methods.
    def test_provider_lifecycle(self):
        if not shutil.which("quickshell"):
            self.skipTest("quickshell is unavailable")
        (self.src / "Service.qml").write_text('''import QtQuick
Item {
  id: root
  property var manifest: null
  property var shell: null
  property string rootDir: ""
  property Component surface: Item { property var host: null; property string marker: "fixture-view" }
  readonly property var provider: ({ apiVersion: 1, name: "Probe", icon: "P", view: root.surface,
    settings: [{ key: "greeting", type: "string", label: "Greeting", "default": "Hello" }],
    patterns: [{ id: "hello", regex: "^hello", boost: 20, example: "hello friend" }],
    query: function(ctx) { return [{ id: "hello", title: ctx.settings.greeting, score: 1, action: { type: "noop" } }] }
  })
}
''')
        self.push()
        index = self.work / "index.json"
        index.write_text(json.dumps({"version": 1, "extensions": [{"id": MID, "name": "Probe", "repo": self.url, "tags": ["test"]}]}))
        (self.home / "cache/keystroke").mkdir(parents=True)
        runtime = self.work / "runtime"
        runtime.mkdir(mode=0o700)
        # Only this trusted local repository is ever loaded, and only in this offscreen process.
        project = self.work / "project"
        (project / "providers").mkdir(parents=True)
        shutil.copytree(ROOT / "core", project / "core")
        for name in ("Extensions.qml", "SettingsProvider.qml"):
            shutil.copy2(ROOT / "providers" / name, project / "providers" / name)
        bump = self.work / "bump.py"
        bump.write_text('''import json, subprocess
from pathlib import Path
src = Path(%r)
m = json.loads((src / "manifest.json").read_text()); m["version"] = "2.0.0"
(src / "manifest.json").write_text(json.dumps(m))
for cmd in (["git", "-c", "core.hooksPath=/dev/null", "commit", "-qam", "v2"], ["git", "-c", "core.hooksPath=/dev/null", "push", "-q", %r, "main"]):
    subprocess.run(cmd, cwd=src, check=True, timeout=10)
''' % (str(self.src), str(self.bare)))
        harness = self.work / "shell.qml"
        harness.write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import "project/providers" as Providers
import "project/core/Extensions.js" as Extensions
import "project/core/Settings.js" as Settings
import "project/core/Patterns.js" as Patterns
ShellRoot {
  id: test
  property int stage: 0
  property int failures: 0
  property int checks: 0
  property var rows: []
  property string mid: %(mid)s
  function check(ok, what) { checks++; if (!ok) { failures++; console.log("FAIL", what) } }
  function row(id) { return rows.filter(function(r) { return r.id === id })[0] }
  function query(scope, q) {
    rows = ext.query({ scope: scope, query: q || "", settings: host.settingsFor(null), pending: function() {} })
    return rows
  }
  function activate(r, confirmed, alternate) { return ext.activate(r, { confirmed: !!confirmed, alternate: !!alternate }) }
  function idle() { return !ext.job && !ext.fetching && !scanner.running && !retry.running }
  QtObject {
    id: host
    property string rootDir: %(root)s
    property var registry: reg
    property var config: ({ version: 1, providers: {} })
    property string configPath: %(config)s
    property var paletteSchema: []
    property string voiceStamp: ""
    property string matchingStamp: ""
    property string statusMessage: ""
    property string errorMessage: ""
    property string scope: "extensions"
    property string indexUrl: %(index)s
    property int saved: 0
    property int backs: 0
    function requery() {}
    function goBack() { backs++ }
    function voiceModel() { return null }
    function matchingModel() { return null }
    function paletteValues() { return {} }
    function providerEnabled(e) { return Settings.isEnabled(config, ["providers", e.key], e.source !== "community") }
    function registryEntry(key) { return key === "extensions" ? { key: key, provider: ext.provider, source: "bundled" } : reg.entries.filter(function(e) { return e.key === key })[0] || null }
    function settingsFor(e) { return !e || e.key === "extensions" ? { autoCheck: false, indexUrl: indexUrl } : Settings.values(config, ["providers", e.key], e.provider.settings || []) }
    function saveConfig(next, afterSaved) { config = next; saved++; reg.scan(); if (afterSaved) afterSaved() }
  }
  QtObject {
    id: reg
    property var manifests: ({})
    property var problems: []
    property var entries: []
    property var services: ({})
    property int loads: 0
    property bool scanAgain: false
    function scan() {
      if (scanner.running) { scanAgain = true; return }
      scanner.command = Extensions.scanArgv(host.rootDir, Extensions.enabledIds(host.config))
      scanner.running = true
    }
    function apply(text) {
      var found = Extensions.parseScan(text), next = ({}), out = []
      manifests = found.manifests; problems = found.problems
      for (var id in manifests) {
        if (manifests[id].__enabled !== true) continue
        if (services[id]) next[id] = services[id]
        else {
          var url = Extensions.serviceUrl(manifests[id])
          var component = Qt.createComponent(url, Component.PreferSynchronous)
          test.check(component.status === Component.Ready, "validated service compiles: " + component.errorString())
          if (component.status !== Component.Ready) continue
          next[id] = component.createObject(test, { manifest: Extensions.publicManifest(manifests[id]), rootDir: host.rootDir })
          loads++
        }
        var p = next[id].provider
        out.push({ key: id, pluginId: id, name: p.name, provider: p, source: "community", patterns: Patterns.compile(p.patterns).patterns })
      }
      for (var gone in services) if (!next[gone]) services[gone].destroy()
      services = next; entries = out
    }
  }
  Process {
    id: scanner
    stdout: StdioCollector { id: scanOutput }
    onExited: function(code) {
      if (code === 0) reg.apply(scanOutput.text)
      else reg.scanAgain = true
      if (reg.scanAgain) { reg.scanAgain = false; retry.start() }
    }
  }
  Timer { id: retry; interval: 100; onTriggered: reg.scan() }
  Providers.Extensions { id: ext; host: host }
  Providers.SettingsProvider { id: settingsProvider; host: host }
  Process { id: bumpProc; command: ["python3", %(bump)s]; onExited: function(code) { test.check(code === 0, "local upstream bump") } }
  Timer { interval: 50; repeat: true; running: true; onTriggered: test.advance() }
  Timer { interval: 35000; running: true; onTriggered: { console.log("FAIL timeout", test.stage, host.errorMessage, JSON.stringify(ext.job)); Qt.quit() } }
  function advance() {
    switch (stage) {
    case 0:
      check(JSON.stringify(Extensions.helperArgv(host.rootDir)) === JSON.stringify(["luajit", host.rootDir + "/helpers/extensions.lua"]), "production extension lifecycle uses LuaJIT")
      stage = 1; reg.scan(); query("extensions", ""); return
    case 1:
      if (!idle()) return
      query("extensions", "")
      check(!!row("discover/" + mid), "local index is discoverable: " + ext.fetchError)
      var offer = row("discover/" + mid)
      if (!offer) { stage = 9; Qt.quit(); return }
      check(offer.confirm.indexOf("unsandboxed") > 0, "explicit unsandboxed warning")
      activate(offer, false)
      check(ext.job === null, "unconfirmed activation cannot start a job")
      check(reg.loads === 0 && host.saved === 0, "no code or config before consent")
      host.errorMessage = ""
      activate(offer, true)
      check(ext.job && ext.job.kind === "install", "confirmed installation job starts")
      check(query("extensions", "")[0].id === "job", "progress row shown")
      stage = 2; return
    case 2:
      if (!idle() || !reg.services[mid]) return
      check(host.errorMessage === "", "install succeeds: " + host.errorMessage)
      check(host.statusMessage === "Installed Probe", "quiet check preserves install status")
      check(host.config.providers[mid].enabled === true, "confirmed decision explicitly enables extension")
      check(reg.loads === 1, "service loaded once")
      check(!!reg.manifests[mid].__sourceDir, "enabled scan has validated source path")
      var entry = host.registryEntry(mid)
      check(Patterns.evaluate(entry.patterns, "hello world").boost === 20, "API 1 pattern boosts retained")
      check(entry.provider.query({ settings: host.settingsFor(entry) })[0].title === "Hello", "API 1 schema defaults retained")
      var view = entry.provider.view.createObject(test, { host: host })
      check(view && view.marker === "fixture-view", "API 1 custom view remains usable")
      if (view) view.destroy()
      check(!!settingsProvider.current().screens["settings/" + mid + "/greeting"], "provider schema is searchable")
      query("extensions/" + mid, "")
      var off = activate(row(mid + "/enabled"), true)
      host.saveConfig(Settings.withValue(host.config, off.path, off.key, off.value, off.schema))
      stage = 3; return
    case 3:
      if (!idle() || reg.services[mid]) return
      check(!reg.manifests[mid].__sourceDir, "disabled scan does not expose loadable directory")
      var model = settingsProvider.model()
      check(model.entries.some(function(e) { return e.key === test.mid && !e.enabled }), "disabled metadata stays in Settings")
      check(!settingsProvider.current().screens["settings/" + mid + "/greeting"], "disabled code is not loaded for schema introspection")
      query("extensions/" + mid, "")
      check(row(mid + "/enabled").confirm.indexOf("unsandboxed") > 0, "explicit re-enable warning")
      var on = activate(row(mid + "/enabled"), true)
      host.saveConfig(Settings.withValue(host.config, on.path, on.key, on.value, on.schema))
      stage = 4; return
    case 4:
      if (!idle() || !reg.services[mid]) return
      check(reg.loads === 2, "re-enable reinstantiates service")
      bumpProc.running = true; stage = 5; return
    case 5:
      if (bumpProc.running || !idle()) return
      ext.check([mid], false); stage = 6; return
    case 6:
      if (!idle()) return
      check(host.statusMessage === "1 update available", "new remote commit detected")
      query("extensions/" + mid, "")
      check(row(mid + "/update").action.op === "update", "update action offered")
      // Queue the same local fixture twice to expose check/update job overlap.
      // The second clean no-op update must wait, not race the first quiet check.
      ext.updateQueue([mid, mid])
      check(ext.job.queue.length === 1, "sequential update queue starts")
      stage = 7; return
    case 7:
      if (!idle() || reg.manifests[mid].version !== "2.0.0") return
      check(host.errorMessage === "", "update succeeds: " + host.errorMessage)
      check(host.statusMessage === Extensions.updatedText("Probe"), "update honestly advises restart")
      query("extensions/" + mid, "")
      check(row(mid + "/update").action.op === "check", "post-update check is quiet and fresh")
      var checked = ext.checkedAt
      ext.finish({ kind: "check", label: "Checking" }, 1, "offline failure")
      check(host.errorMessage.indexOf("offline failure") > 0 && ext.checkedAt === checked, "failed check is not reported up to date")
      host.errorMessage = ""
      host.scope = "extensions/" + mid
      activate(row(mid + "/remove"), true); stage = 8; return
    case 8:
      if (!idle() || reg.manifests[mid]) return
      check(!reg.services[mid], "remove unloads the service")
      check(host.statusMessage === "Removed Probe" && host.backs === 1, "remove status and back navigation")
      check(host.config.providers[mid].enabled === false, "remove revokes permission before a same-ID reinstallation")
      check(query("extensions/" + mid, "")[0].id === "gone", "removed detail is unavailable")
      host.indexUrl = %(missingindex)s
      ext.refresh(); stage = 9; return
    case 9:
      if (!idle()) return
      check(ext.fetchError.length > 0, "index fetch errors are visible")
      query("extensions", "")
      check(!ext.fetching && ext.indexEntries.length === 0, "failed indexes do not cause a query/retry loop or show the previous catalog")
      console.log(failures ? "FAIL provider lifecycle" : "PASS provider lifecycle", checks, "checks")
      stage = 10; Qt.quit(); return
    }
  }
}
''' % {"mid": json.dumps(MID), "root": json.dumps(str(ROOT)), "config": json.dumps(str(self.home / "config/keystroke/keystroke.json")),
       "index": json.dumps(index.as_uri()), "missingindex": json.dumps((self.work / "missing.json").as_uri()), "bump": json.dumps(str(bump))})
        env = dict(self.env, QT_QPA_PLATFORM="offscreen", QT_QPA_PLATFORMTHEME="generic", QT_QUICK_BACKEND="software", QML_IMPORT_PATH=str(self.work))
        env.pop("DISPLAY", None)
        env.pop("WAYLAND_DISPLAY", None)
        result = subprocess.run(["quickshell", "-p", str(harness)], env=env, text=True, capture_output=True, timeout=45)
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, output)
        self.assertIn("PASS provider lifecycle", output, output)
        for error in ("FAIL", "TypeError", "ReferenceError", "Error:"):
            self.assertNotIn(error, output, output)
        self.assertFalse((self.work / "installer-ran").exists())
        print(next(line for line in output.splitlines() if "PASS provider lifecycle" in line))


if __name__ == "__main__":
    suite = unittest.TestSuite([ProviderTest("test_provider_lifecycle")])
    raise SystemExit(not unittest.TextTestRunner(verbosity=2).run(suite).wasSuccessful())
