import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.Commons
import qs.Ui

Scope {
    id: test
    property int activated: 0
    property int confirmed: 0
    property int canceled: 0
    property int dismissed: 0
    property bool activationConfirmed: false
    property bool started: false
    property int serviceStep: 0
    readonly property bool shimsOnly: Quickshell.env("LAUNCHER_TEST_SHIMS_ONLY") === "1"
    function check(condition, message) {
        if (!condition) throw new Error(message)
    }
    function key(code, repeat) { return { key: code, modifiers: Qt.NoModifier, isAutoRepeat: !!repeat, accepted: false } }
    Item {
        id: surface
        width: 640; height: 540
        BorderSurface { id: border; borderSpec: Border.controlSpec("focus", Color.menu.text, Color.accent) }
        Button { id: button; text: "<b>plain</b>"; focusable: true }
        TextField { id: field; text: "<b>typed</b>" }
        ConfirmDialog {
            id: confirmation
            anchors.fill: parent
            message: "<b>Literal confirmation</b>"
            onConfirmed: test.confirmed++
            onCanceled: test.canceled++
        }
        PointerMoveGate { id: gate; referenceItem: surface }
    }
    Component {
        id: testView
        Item {
            property var host: null
            function focusInput() { forceActiveFocus() }
            function dismiss() { test.dismissed++ }
        }
    }
    Loader {
        id: launcher
        active: !test.shimsOnly
        source: active ? Qt.resolvedUrl("Launcher.qml") : ""
        onStatusChanged: if (status === Loader.Error) { console.error("HOST_TEST_FAIL: Launcher failed to load"); Qt.callLater(Qt.quit) }
    }
    function shims() {
        check(Style.font.menuFamily === Theme.font, "prose font")
        check(Style.font.iconFamily === "Symbols Nerd Font", "icon font")
        check(border.borderTop === 2 && border.borderLeft === 2, "border insets")
        check(button.contentItem.textFormat === Text.PlainText, "button literal text")
        check(field.text === "<b>typed</b>", "textfield literal text")
        check(Util.fileUrl("/tmp/a #b.svg") === "file:///tmp/a%20%23b.svg", "file URL encoding")
        check(!gate.moved(surface, {x: 1, y: 1}), "ignore initial pointer")
        check(!gate.moved(surface, {x: 1, y: 1}), "ignore stationary pointer")
        check(gate.moved(surface, {x: 4, y: 1}), "accept pointer motion")
        gate.reset()
        check(!gate.moved(surface, {x: 4, y: 1}), "reset pointer gate")
        confirmation.opened = true
        confirmation.handleKey(key(Qt.Key_Return, true))
        check(!confirmed && !canceled, "confirmation ignores repeated activation")
        confirmation.handleKey(key(Qt.Key_Return))
        check(canceled === 1 && confirmed === 0, "confirmation defaults to cancel")
        confirmation.handleKey(key(Qt.Key_Right))
        confirmation.handleKey(key(Qt.Key_Return))
        check(confirmed === 1, "confirmation selects accept")
        confirmation.handleKey(key(Qt.Key_Escape))
        check(canceled === 2, "confirmation escape")
        confirmation.opened = false
    }
    function hostChecks() {
        const wrapper = launcher.item, host = wrapper.launcherHost
        check(host.configKnown && host.matchingSettings.mode === "off", "isolated matching config")
        check(!host.registry.services["local.host-test"], "disabled extension never loads")
        check(host.registryEntry("local.host-test") !== null, "disabled extension remains manageable")
        check(!host.providerEnabled(host.registryEntry("local.host-test")), "community providers default off")
        check(host.rootDir.charAt(0) === "/" && host.rootDir.endsWith("/launcher"), "absolute launcher root")
        check(host.configPath === Quickshell.env("XDG_CONFIG_HOME") + "/quickshell-launcher.json", "XDG config path")
        check(host.usagePath === Quickshell.env("XDG_STATE_HOME") + "/keystroke/usage.json", "XDG state path")
        check(host.bindingsPath === Quickshell.env("HOME") + "/.config/hypr/launcher-voice.lua", "dedicated voice bindings")
        wrapper.open()
        check(host.opened, "wrapper open")
        check(host.registry.bundled[0].provider.id === "system", "system first")
        check(host.registry.bundled[1].provider.id === "applications", "applications second")
        check(host.appLibrary !== null, "native application library")
        check(host.registryEntry("timer") !== null, "resident timer provider")
        check(!host.registryEntry("calculator"), "calculator excluded")
        check(JSON.parse(host.inspect()).modelCount === host.rows.length, "stable result model")
        wrapper.query("emoji")
        host.runQuery()
        check(host.rows.some(row => row.providerKey === "emoji"), "global emoji search offers the picker")
        check(!host.rows.some(row => row.providerKey === "settings"), "global emoji search excludes feature settings")
        const settingsCatalog = host.catalogFor("", "", "").rows.filter(row => row.providerKey === "settings")
        check(settingsCatalog.length === 1 && settingsCatalog[0].action.scope === "settings", "global semantic catalog only offers Settings")
        wrapper.route("settings")
        wrapper.query("emoji")
        host.runQuery()
        check(host.rows.some(row => row.action.scope === "settings/emoji"), "emoji settings remain searchable inside Settings")
        for (const entry of host.registry.entries) {
            if (entry.key === "system") continue
            wrapper.route(entry.key)
            check(host.scope === entry.key, "direct scope " + entry.key)
        }
        wrapper.route("settings/palette")
        check(host.scope === "settings/palette", "nested direct scope")
        wrapper.route("system")
        check(host.scope === "system", "direct system scope")
        wrapper.route("system/root")
        check(host.scope === "system/root", "system root scope")
        wrapper.route("system/session")
        check(host.scope === "system/session", "system scope")
        wrapper.route("reboot")
        check(host.opened && host.scope === "system/session", "destructive route navigates, never executes")
        host.activate()
        check(host.confirmPending !== null, "routed destructive selection confirms")
        host.goBack()
        wrapper.route("root")
        host.activateRoute({kind: "action", id: "action-reboot", action: {type: "noop"}})
        check(host.confirmPending !== null, "action routes use canonical confirmation")
        host.goBack()
        host.activateRoute({kind: "action", id: "missing-action", action: {type: "exec", argv: ["false"]}})
        check(host.confirmPending === null && host.opened && host.errorMessage === "Route action is unavailable", "unknown route effects stay inert")
        host.showProviderView("codex")
        check(host.providerViewActive, "conversation view opens without a request")
        host.goBack()
        check(!host.providerViewActive, "conversation view back")
        const provider = {
            apiVersion: 1, id: "host-test", name: "Host test", settings: [], view: testView,
            query: function(ctx) { return [
                { id: "one", title: "<b>First</b>", preview: "<b>preview</b>", score: 10, remember: true,
                  confirm: "Confirm test action?", action: { type: "noop" } },
                { id: "two", title: "Second", score: 5, action: { type: "noop" } }
            ] },
            activate: function(row, ctx) { test.activated++; test.activationConfirmed = ctx.confirmed === true; return { type: "noop" } }
        }
        const entry = host.registry.entry("host-test", provider, "bundled", "", "Host test", [])
        host.registry.entries = host.registry.entries.concat([entry])
        host.navigate("host-test", "Host test")
        check(host.rows.length === 2 && host.previewVisible, "provider results and preview")
        host.select(1)
        check(host.selected === 1, "next row")
        host.select(1)
        check(host.selected === 0, "selection wraps")
        host.activateAt(7)
        check(activated === 0, "out of range shortcut inert")
        host.activateAt(0)
        check(host.confirmPending !== null && activated === 0, "confirm before provider activate")
        host.goBack()
        check(host.confirmPending === null && activated === 0, "cancel confirmation")
        host.activate()
        const run = host.confirmPending.run
        host.confirmPending = null
        run()
        check(activated === 1 && activationConfirmed, "confirmed action context")
        host.activateRow({ providerKey: "host-test", id: "alternate", uid: "host-test/alternate", action: {type: "noop"},
                           altAction: {type: "noop"}, altConfirm: "Enable unsandboxed extension?" }, true)
        check(host.confirmPending !== null && activated === 1, "alternate action has its own trust confirmation")
        host.goBack()
        check(activated === 1, "canceling alternate action prevents provider activation")
        host.showProviderView("host-test")
        check(host.providerViewActive, "community-compatible view opens")
        host.goBack()
        check(!host.providerViewActive && dismissed === 1, "provider view dismiss lifecycle")
        const queuedWrites = host.writeQueue.length
        host.installVoiceBindings()
        check(host.confirmPending !== null && host.writeQueue.length === queuedWrites, "bindings require confirmation before writing")
        host.goBack()
        check(host.writeQueue.length === queuedWrites, "canceled bindings do not write")
        host.installVoiceBindings()
        const installBindings = host.confirmPending.run
        host.confirmPending = null
        installBindings()
        wrapper.close()
        check(!host.opened, "explicit close cancels")
        wrapper.toggle()
        check(host.opened, "closed toggle opens")
        wrapper.toggle()
        check(!host.opened, "open toggle closes without voice")
        wrapper.query("literal <b>query</b>")
        check(JSON.parse(host.inspect()).query === "literal <b>query</b>", "query IPC opens and sets text")
        const nextConfig = JSON.parse(JSON.stringify(host.config))
        nextConfig.hostTest = true
        nextConfig.providers["local.host-test"] = { enabled: true }
        host.saveConfig(nextConfig)
        let busySaveRejected = false
        try { host.saveConfig(host.config) } catch (e) { busySaveRejected = String(e).indexOf("still saving") >= 0 }
        check(busySaveRejected, "overlapping stale config snapshot cannot overwrite a pending save")
        check(!host.registry.services["local.host-test"], "extension waits for config persistence")
        wrapper.close()
        check(!host.openDmenu({mode: "input", selectionFile: host.home + "/outside", doneFile: host.home + "/outside-done"}), "reject picker paths outside runtime")
        const dir = Quickshell.env("XDG_RUNTIME_DIR") + "/quickshell-launcher/request"
        wrapper.summon(JSON.stringify({mode: "select", prompt: "<b>Choose</b>", options: ["icon\tFirst\tDetail", "Second"], selectionFile: dir + "/selection", doneFile: dir + "/done"}))
        check(host.dmenuActive && host.rows.length === 2, "generic select picker")
        wrapper.query("Second")
        host.runQuery()
        check(host.rows.length === 1 && host.current.title === "Second", "picker filtering")
        host.activate()
        check(!host.opened && !host.requestActive, "picker completes")
        JSON.parse(host.inspectConversation())
    }
    Timer {
        interval: 150
        repeat: true
        running: true
        onTriggered: {
            try {
                if (!test.started) {
                    if (!test.shimsOnly && (launcher.status !== Loader.Ready || !launcher.item.launcherHost.configKnown || !launcher.item.launcherHost.registry.manifests["local.host-test"])) return
                    test.started = true
                    test.shims()
                    if (!test.shimsOnly) test.hostChecks()
                }
                if (!test.shimsOnly) {
                    const host = launcher.item.launcherHost
                    if (host.writing || host.writeQueue.length) return
                    if (test.serviceStep === 0) {
                        const service = host.registry.services["local.host-test"]
                        if (!service) return
                        test.check(service.instance.host === host, "community host injection")
                        test.check(service.instance.manifest.id === "local.host-test", "community manifest injection")
                        const next = JSON.parse(JSON.stringify(host.config))
                        next.providers["local.host-test"].enabled = false
                        host.saveConfig(next)
                        test.serviceStep = 1
                        return
                    }
                    if (host.registry.services["local.host-test"]) return
                    test.check(!host.providerEnabled(host.registryEntry("local.host-test")), "disabled service unloads")
                }
                console.log(test.shimsOnly ? "HOST_SHIMS_PASS" : "HOST_TEST_PASS")
                stop()
                Qt.quit()
            } catch (e) { console.error("HOST_TEST_FAIL:", e); stop(); Qt.quit() }
        }
    }
}
