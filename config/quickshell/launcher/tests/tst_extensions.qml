import QtQuick
import QtTest
import "../core/Extensions.js" as Extensions
import "../core/Match.js" as Match

TestCase {
    name: "Extensions"
    property string rootDir: "/opt/launcher"
    property string timerId: "io.github.evindor.keystroke-timer"
    property string dir: "/home/me/.local/share/keystroke/extensions/"
    function manifest(id, enabled) {
        var m = { id: id, name: id === timerId ? "Timer" : "Hello", version: "1.0.0", author: "A", description: "Countdown timers",
                  homepage: "https://github.com/evindor/keystroke-timer", kinds: ["service"], entryPoints: { service: "Service.qml" },
                  "x-keystroke": { apiVersion: 1 }, __validated: true, __enabled: enabled, __git: true }
        if (enabled) m.__sourceDir = dir + id
        return m
    }
    function installed(git, problems) {
        var manifests = ({})
        manifests[timerId] = manifest(timerId, true)
        manifests["example.hello"] = manifest("example.hello", false)
        return Extensions.installed(manifests, function(id) { return id === timerId }, git || {}, problems || [])
    }
    function line(parts) { return parts.join("\t") + "\n" }
    function ranked(rows, q) {
        var out = []
        for (var i = 0; i < rows.length; i++) {
            var r = rows[i]
            if (typeof r.score !== "number") r.score = Match.match(q, r.title, r.keywords || "", r.path || "", r.description || "")
            if (!q || r.score > 0) out.push(r)
        }
        return Match.rank(out, null)
    }
    function titles(rows) { return rows.map(function(r) { return r.title }) }
    function row(rows, id) { return rows.filter(function(r) { return r.id === id })[0] }

    function test_urls_allow_only_https_and_explicit_local_development() {
        var good = ["https://github.com/evindor/keystroke-timer.git", "https://codeberg.org/x/y", "file:///home/me/probe.git", "file:///tmp/repo%20space.git"]
        for (var i = 0; i < good.length; i++) compare(Extensions.gitUrl(good[i]), good[i])
        compare(Extensions.gitUrl("  evindor/keystroke-timer.git "), "https://github.com/evindor/keystroke-timer.git")
        var bad = ["file://relative/path", "file:///home/me/../etc", "file:///tmp/%2e%2e/etc", "/home/me/probe.git", "--upload-pack=x",
                   "-oProxyCommand=x", "http://github.com/x/y", "ext::sh -c x", "git@github.com:x/y", "ssh://-oProxyCommand=x/a",
                   "https://user:pass@github.com/x/y", "https://github.com/x/y?z", "https://github.com/x/y#z", "https://x/a%00b",
                   "https://x/a\nb", "file:///tmp/a\\b", "timer 10m", "chrome"]
        for (i = 0; i < bad.length; i++) compare(Extensions.gitUrl(bad[i]), "", bad[i])
        compare(Extensions.repoSlug("https://github.com/Evindor/Keystroke-Timer.git"), "evindor/keystroke-timer")
        verify(Extensions.validId(timerId))
        verify(!Extensions.validId("extensions"))
        verify(!Extensions.validId("__proto__"))
        verify(!Extensions.validId("../escape"))
    }

    function test_index_is_defensive_and_deduplicated() {
        compare(Extensions.INDEX_URL, "")
        compare(Extensions.parseIndex("not json"), [])
        compare(Extensions.parseIndex(JSON.stringify({ version: 2, extensions: [] })), [])
        var idx = Extensions.parseIndex(JSON.stringify({ version: 1, extensions: [
            { id: "IO.GitHub.Evindor.Keystroke-Timer", name: "Timer", repo: "evindor/keystroke-timer", tags: ["timer", 3] },
            { id: "bad.no-repo" }, { id: "evil.url", repo: "--upload-pack=x" }, { id: "../escape", repo: "x/y" },
            { id: "extensions", repo: "x/y" }, "junk"
        ] }))
        compare(idx.length, 1)
        compare(idx[0].id, timerId)
        compare(idx[0].tags, ["timer", "3"])
        compare(idx[0].source, "index")
        var extra = Extensions.parseIndex(JSON.stringify({ version: 1, extensions: [
            { id: timerId, name: "Duplicate ID", repo: "other/repo" },
            { id: "other.timer", name: "Duplicate repo", repo: "https://github.com/Evindor/Keystroke-Timer.git" },
            { id: "other.hello", name: "Hello", repo: "other/hello" }
        ] }))
        compare(Extensions.discover(idx.concat(extra)).map(function(e) { return e.name }), ["Timer", "Hello"])
    }

    function test_scan_only_enabled_validated_paths_are_loadable() {
        compare(Extensions.scanArgv(rootDir), ["luajit", rootDir + "/helpers/extensions.lua", "scan", "--enabled-json", "[]"])
        compare(Extensions.enabledIds({ providers: { "example.on": { enabled: true }, "example.off": { enabled: false }, "example.default": {}, "example.string": { enabled: "true" }, "../escape": { enabled: true } } }), ["example.on"])
        var raw = ({})
        raw[timerId] = manifest(timerId, true)
        raw["example.hello"] = manifest("example.hello", false)
        raw["example.hello"].__sourceDir = "/forged"
        var found = Extensions.parseScan(JSON.stringify({ manifests: raw, problems: [{ pluginId: "broken.plugin", message: "bad manifest" }] }))
        compare(Object.keys(found.manifests).length, 2)
        compare(found.problems[0].message, "bad manifest")
        compare(Extensions.serviceUrl(found.manifests[timerId]), "file://" + dir + timerId + "/Service.qml")
        verify(!("__sourceDir" in found.manifests["example.hello"]))
        compare(Extensions.serviceUrl(found.manifests["example.hello"]), "")
        compare(Object.keys(Extensions.parseScan("garbage").manifests).length, 0)
        verify(Extensions.parseScan("garbage").problems.length > 0)
        compare(Extensions.parseScan('{"manifests": {}, "problems": []}'), { manifests: {}, problems: [] })
        var m = manifest(timerId, true)
        var bad = ["../other/Service.qml", "/etc/Service.qml", "sub/../../Service.qml", "sub//Main.qml", "sub/./Main.qml", "Main.qml#x", "Main.qml%00"]
        for (var i = 0; i < bad.length; i++) { m.entryPoints.service = bad[i]; compare(Extensions.serviceUrl(m), "", bad[i]) }
        m.entryPoints.service = "sub/Main.qml"
        verify(Extensions.serviceUrl(m).indexOf("sub/Main.qml") > 0)
        m.__sourceDir = "/tmp/not-managed/" + timerId
        compare(Extensions.serviceUrl(m), "")
        m.__sourceDir = "/tmp/has space/keystroke/extensions/" + timerId
        verify(Extensions.serviceUrl(m).indexOf("has%20space") > 0)
        m.__enabled = false
        compare(Extensions.serviceUrl(m), "")
        m.__enabled = true; m.__validated = false
        compare(Extensions.serviceUrl(m), "")
        raw[timerId] = m
        verify(!Extensions.parseScan(JSON.stringify({ manifests: raw })).manifests[timerId])
        var pub = Extensions.publicManifest(found.manifests[timerId])
        compare(pub.id, timerId)
        verify(!("__sourceDir" in pub)); verify(!("__enabled" in pub)); verify(!("__validated" in pub))
    }

    function test_installed_defaults_off_and_reports_git_problems() {
        var raw = ({}); raw[timerId] = manifest(timerId, false)
        verify(!Extensions.installed(raw, null, {}, [])[0].enabled)
        var list = installed()
        compare(list.map(function(e) { return e.name }), ["Hello", "Timer"])
        verify(!list[0].enabled); verify(list[1].enabled)
        verify(list[1].git); verify(!list[1].checked)
        var sick = installed({}, [{ pluginId: timerId, message: "Syntax error" }, { pluginId: timerId, message: "later" }])
        compare(sick[1].problem, "Syntax error")
        var state = Extensions.parseCheck(line([timerId, "aaaa", "bbbb", "https://github.com/x/y"]) + line(["example.hello", "", "", ""]) + "garbage\n")
        var checked = installed(state)
        verify(checked[1].updateAvailable); verify(checked[1].checked); verify(!checked[0].git)
        verify(!installed(Extensions.parseCheck(line([timerId, "aaaa", "aaaa", "url"])))[1].updateAvailable)
    }

    function test_commands_use_literal_native_helper_argv() {
        var helper = ["luajit", rootDir + "/helpers/extensions.lua"]
        compare(Extensions.pluginsDir("/home/me"), dir.slice(0, -1))
        compare(Extensions.pluginsDir("/home/me", "/data"), "/data/keystroke/extensions")
        compare(Extensions.installArgv(rootDir, "https://x/y", timerId), helper.concat(["install", "--id", timerId, "--", "https://x/y"]))
        compare(Extensions.updateArgv(rootDir, "a.b"), helper.concat(["update", "--", "a.b"]))
        compare(Extensions.removeArgv(rootDir, "../escape"), helper.concat(["remove", "--", "../escape"]))
        compare(Extensions.checkArgv(rootDir, ["a.b", "c.d; rm -rf /"]), helper.concat(["check", "--", "a.b", "c.d; rm -rf /"]))
        verify(Extensions.updatedText("Timer").indexOf("restart the launcher shell") > 0)
        var job = { kind: "install", label: "Installing Timer", startedAt: 5 }
        var argv = Extensions.installArgv(rootDir, "https://x/y")
        compare(Extensions.jobArgv("/run/keystroke/extensions", job, rootDir, argv), helper.concat(["job", "/run/keystroke/extensions", JSON.stringify(job), "--"], argv.slice(2)))
        compare(Extensions.ackArgv(rootDir, 5), helper.concat(["ack", "5"]))
        compare(Extensions.parseAdded("Added " + timerId + " into /data/keystroke/extensions/" + timerId), timerId)
        compare(Extensions.parseAdded("Added ../escape into /tmp/evil"), "")
        compare(Extensions.parseResult("junk"), null)
        compare(Extensions.parseResult('{"job":{},"code":0}'), null)
        compare(Extensions.parseResult(JSON.stringify({ job: job, code: 1, output: "boom" })), { job: job, code: 1, output: "boom" })
        compare(Extensions.fetchArgv("https://x/y.json").slice(-2), ["--", "https://x/y.json"])
        compare(Extensions.fetchArgv("file:///tmp/fixture%20index.json").slice(-2), ["--", "file:///tmp/fixture%20index.json"])
    }

    function test_screens_keep_confirmation_jobs_actions_and_search() {
        var disc = Extensions.parseIndex(JSON.stringify({ version: 1, extensions: [{ id: "example.spotify", name: "Spotify", repo: "x/spotify", tags: ["media"] }] }))
        var state = { installed: installed(), discover: disc, checked: "", job: null }
        var rows = ranked(Extensions.screenRows("", state), "")
        compare(titles(rows), ["Hello", "Timer", "Check for updates", "Refresh catalog", "Spotify"])
        compare(rows[0].accessory, "Off"); compare(rows[1].accessory, "On")
        verify(rows[0].altConfirm.indexOf("unsandboxed") > 0)
        compare(rows[1].altConfirm, "")
        compare(rows[0].altAction, Extensions.enableEffect("example.hello", true))
        verify(rows[4].confirm.indexOf("Install and enable") === 0)
        verify(rows[4].confirm.indexOf("unsandboxed") > 0)
        compare(rows[4].altAction.type, "url")
        compare(titles(ranked(Extensions.screenRows("spot", state), "spot")), ["Spotify"])
        var url = row(Extensions.screenRows("x/spotify", state), "install-url")
        verify(url.confirm.indexOf("unsandboxed") > 0)
        compare(url.action.url, "https://github.com/x/spotify.git")
        state.installed = installed(Extensions.parseCheck(line([timerId, "a", "b", "https://x/y"])))
        compare(row(Extensions.screenRows("", state), "check").action.op, "update-all")
        state.job = { kind: "install", label: "Installing Spotify" }
        verify(Extensions.screenRows("", state)[0].disabled)
        var detail = ranked(Extensions.detailRows("", state.installed[1], {}), "")
        compare(titles(detail), ["Enabled", "Settings", "Update now", "Open repository", "Remove", "Timer v1.0.0"])
        compare(detail[0].action, Extensions.enableEffect(timerId, false))
        compare(detail[1].action.scope, "settings/" + timerId)
        verify(detail[4].confirm.indexOf("Remove Timer") === 0)
        verify(detail[4].subtitle.indexOf("$XDG_DATA_HOME/keystroke/extensions") > 0)
        var off = Extensions.detailRows("", installed()[0], {})
        verify(off[0].confirm.indexOf("unsandboxed") > 0)
        compare(ranked(Extensions.detailRows("rem", state.installed[1], {}), "rem")[0].title, "Remove")
    }

    function test_provider_icons_patterns_and_scopes_are_preserved() {
        var e = installed()[1]
        Extensions.decorate(e, { icon: "T", iconSource: "file:///timer/icon.svg", color: "#26a269" }, ["timer 10m", "timer 2h tea"])
        var r = Extensions.installedRow(e, true)
        compare(r.icon, "T"); compare(r.iconSource, "file:///timer/icon.svg"); compare(r.tint, "#26a269")
        var detail = Extensions.detailRows("", e, null)
        compare(row(detail, timerId + "/about").iconSource, r.iconSource)
        compare(row(detail, timerId + "/patterns").title, "Answers queries like timer 10m · timer 2h tea")
        compare(Extensions.scopeId(""), null)
        compare(Extensions.scopeId("extensions"), "")
        compare(Extensions.scopeId("extensions/a.b"), "a.b")
        compare(Extensions.scopeId("settings/a"), null)
    }
}
