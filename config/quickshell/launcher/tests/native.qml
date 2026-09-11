import QtQuick
import QtQuick as Quick
import Quickshell
import "../core" as Core
import "../providers" as Providers

Scope {
    id: suite
    property int failures: 0
    property int checks: 0
    property bool started: false
    property int phase: 0
    QtObject {
        id: testHost
        property bool opened: false
        property string scope: ""
        property var current: ({})
        property var appLibrary: library.library
        property string statusMessage: ""
        function requery(options) {}
        function goBack() {}
        function cancel() { opened = false }
    }
    Core.ApplicationLibrary { id: library }
    Providers.Applications { id: applications; host: testHost }
    Providers.System { id: desktop; host: testHost }
    Providers.Clipboard { id: clipboard; host: testHost }
    Providers.Hotkeys { id: hotkeys; host: testHost }
    Providers.Timer { id: countdown; host: testHost }

    function check(condition, message) {
        suite.checks++
        if (!condition) { suite.failures++; console.error("NATIVE_FAIL: " + message) }
    }
    function equal(actual, expected, message) { check(JSON.stringify(actual) === JSON.stringify(expected), message) }
    function run() {
        if (suite.started) return
        suite.started = true
        check(library.library === library && library.sharedLibrary === null, "native library identity")
        var entry = DesktopEntries.byId("native-fixture")
        check(!!entry, "native desktop entry loaded")
        if (entry) {
            var context = library.launchContext(entry)
            equal(context.command, ["uwsm-app", "--", "ghostty", "-e", "printf", "--fixture", "a b", "literal;value"], "desktop argv and terminal prefix")
            equal(context.workingDirectory, Quickshell.env("HOME") + "/work dir", "desktop working directory")
            check(!!library.iconFor(entry), "native desktop icon")
            var rows = applications.query({ scope: "applications", query: "Native Fixture" })
            check(rows.length === 1 && rows[0].appId === "native-fixture", "application query contract")
            check(rows.length === 1 && rows[0].iconSource === library.iconFor(entry), "application preserves icon")
        }
        check(!library.sortedEntries("").some(function(row) { return row.entry.id === "native-hidden" }), "NoDisplay entry filtered")
        var sorted = library.sortedEntries("").map(function(row) { return library.entryName(row.entry) })
        equal(sorted, sorted.slice().sort(function(a, b) { return a.localeCompare(b) }), "applications sorted")

        var rows = desktop.catalog({ settings: {} })
        equal(rows.filter(function(row) { return row.id.indexOf("action-") === 0 }).length, 13, "all original session and capture actions")
        equal(rows.filter(function(row) { return !!row.confirm }).length, 3, "logout reboot poweroff confirmation")
        check(rows.filter(function(row) { return row.id.indexOf("action-record-") === 0 }).every(function(row) {
            return row.intentFamily === (row.id === "action-record-stop" ? "record-stop" : "record-start")
        }), "record start and stop semantic families")
        equal(desktop.routeFor("themes").scope, "system/theme", "singular theme route")
        equal(desktop.routeFor("applications").kind, "apps", "application route")
        check(desktop.routeFor("reboot").kind === "menu", "IPC cannot bypass reboot confirmation")
        desktop.themes = [{ name: "fixture name;literal", label: "Fixture", image: "", tagline: "fixture" }]
        desktop.backgrounds = [{ name: "/tmp/fixture name.png", label: "Fixture wallpaper" }]
        desktop.themesLoaded = true
        desktop.backgroundsLoaded = true
        rows = desktop.catalog({ settings: {} })
        equal(rows.find(function(row) { return row.title === "Theme: Fixture" }).action.argv, ["theme", "fixture name;literal"], "theme argv is literal")
        equal(rows.find(function(row) { return row.title === "Wallpaper: Fixture wallpaper" }).action.argv, ["theme", "bg", "/tmp/fixture name.png"], "wallpaper argv is literal")
        equal(desktop.activate(desktop.navRow(desktop.menus[4], 4)), { type: "provider-view", provider: "system" }, "native provider view contract")
        equal(desktop.activePage, "audio", "audio menu selected")
        equal(desktop.query({ scope: "files", query: "", settings: {} }), [], "system scope isolation")
        check(desktop.query({ scope: "system/bar", sub: "bar", query: "", settings: {} }).length >= 6, "bar preferences searchable")
        check(desktop.query({ scope: "", query: "reboot", settings: {} }).some(function(row) { return row.id === "action-reboot" && row.confirm }), "root session search retains confirmation")
        for (var name of ["AudioMenu", "NetMenu", "BtMenu", "DisplayMenu", "TailscaleMenu", "ThemeMenu"]) {
            var component = Qt.createComponent(Qt.resolvedUrl("../../" + name + ".qml"))
            check(component.status === Component.Ready, name + " compiles: " + component.errorString())
        }
        for (var providerName of ["Converter", "Files"]) {
            var providerComponent = Qt.createComponent(Qt.resolvedUrl("../providers/" + providerName + ".qml"))
            check(providerComponent.status === Component.Ready, providerName + " QtQuick.Timer remains unambiguous: " + providerComponent.errorString())
        }
        desktop.activePage = ""
        var view = desktop.view.createObject(suite, { host: testHost })
        check(!!view && typeof view.focusInput === "function", "provider view instantiates")
        if (view) view.destroy()

        clipboard.entries = [
            { id: "42", kind: "text", preview: "fixture text", extension: "bin", mime: "" },
            { id: "43", kind: "image", preview: "[[ binary data png ]]", extension: "png", mime: "image/png" },
            { id: "44", kind: "video", preview: "[[ binary data video/mp4 ]]", extension: "mp4", mime: "video/mp4" }
        ]
        clipboard.loaded = true
        equal(clipboard.query({ scope: "", query: "fixture", settings: {} }), [], "history never in global search")
        equal(clipboard.provider.catalog({}).length, 1, "clipboard catalog contains navigation only")
        rows = clipboard.query({ scope: "clipboard", query: "", settings: {} })
        equal(rows.length, 3, "clipboard keeps text image video")
        check(rows.every(function(row) { return !row.remember }), "clipboard never remembered")
        equal(rows[0].action.argv.slice(-3), ["copy", "42", "text"], "Enter copies")
        equal(rows[0].altAction.argv, ["clipboard-paste", "42", "", ""], "Ctrl+Enter pastes")
        equal(rows[2].altAction.argv.slice(0, 3), ["clipboard-paste", "44", "video/mp4"], "video MIME preserved")
        equal(hotkeys.activate({ action: { type: "hotkey", dispatcher: "__lua", argv: ["invalid"] } }), { type: "noop" }, "opaque callback activation disabled")

        equal(countdown.parse("timer 10m tea"), { duration: 600000, label: "tea" }, "timer syntax")
        equal(countdown.parse("1h30m long tea"), { duration: 5400000, label: "long tea" }, "compound duration")
        for (var invalid of ["1+2", "0s", "-1m", "8d", "10", "10mystery"])
            equal(countdown.parse(invalid), null, "invalid timer duration")
        var timer = countdown.start(5000, "fixture", 1000)
        equal(countdown.remaining(timer, 2000), "0:04", "countdown display")
        equal(countdown.expire(5999).length, 0, "timer not early")
        equal(countdown.expire(6000).length, 1, "timer expires once")
        equal(countdown.expire(7000).length, 0, "timer notification not repeated")
        countdown.start(5000, "fixture", Date.now())
        rows = countdown.query({ scope: "", query: "timer list" })
        equal(rows.length, 1, "timer list")
        countdown.activate(rows[0])
        equal(countdown.timers.length, 0, "stop timer")
        check(countdown.query({ scope: "", query: "timer 10m tea" })[0].action.type === "timer-start", "root countdown command")
        clipboard.loaded = false
        clipboard.entries = []
        suite.phase = 1
        testHost.scope = "clipboard"
        testHost.opened = true
    }
    Quick.Timer { interval: 300; running: true; onTriggered: suite.run() }
    Quick.Timer {
        interval: 100
        repeat: true
        running: suite.phase > 0 && suite.phase < 4
        onTriggered: {
            if (suite.phase === 1 && clipboard.loaded) {
                suite.equal(clipboard.entries.length, 3, "existing clipboard-list loaded fixtures")
                suite.equal(clipboard.entries.map(function(row) { return row.kind }), ["text", "image", "video"], "ClipboardModel preserves media metadata")
                var row = clipboard.query({ scope: "clipboard", query: "", settings: {} })[0]
                row.providerKey = "clipboard"
                testHost.current = row
                suite.phase = 2
            } else if (suite.phase === 2 && clipboard.previewResult.id === "42") {
                suite.equal(clipboard.previewResult.text, "fixture selection body\nline two", "selected preview decodes actual fixture text")
                var row = clipboard.query({ scope: "clipboard", query: "", settings: {} })[1]
                row.providerKey = "clipboard"
                testHost.current = row
                suite.phase = 3
            } else if (suite.phase === 3 && clipboard.previewResult.id === "43") {
                suite.check(!!clipboard.previewResult.image, "selected image decoded into private thumbnail")
                testHost.opened = false
                testHost.scope = ""
                suite.equal(clipboard.entries, [], "closing clears scoped clipboard data")
                suite.equal(clipboard.previewResult, {}, "closing clears preview data")
                suite.phase = 4
                countdown.start(1000, "native expiry fixture", Date.now())
                finish.start()
            }
        }
    }
    Quick.Timer {
        interval: 10000
        running: true
        onTriggered: { console.error("NATIVE_FAIL: asynchronous fixture timeout"); Qt.quit() }
    }
    Quick.Timer {
        id: finish
        interval: 1600
        onTriggered: {
            suite.check(countdown.timers.length === 0, "countdown expires while palette is closed")
            console.log(suite.failures ? "NATIVE_FAILED" : "NATIVE_PASS: " + suite.checks + " checks")
            Qt.quit()
        }
    }
}
