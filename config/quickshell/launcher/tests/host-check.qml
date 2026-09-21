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
    property int hotkeyStep: 0
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
        const panel = Array.from(host.data).find(item => item.contentItem && item.color !== undefined)
        check(panel && panel.color.a === 0, "launcher window stays transparent")
        const dismiss = Array.from(panel.contentItem.children).find(item => item.objectName === "launcher-dismiss-area")
        check(dismiss && dismiss.color === undefined, "outside-click area does not paint a dimming layer")
        dismiss.clicked(null)
        check(!host.opened, "outside click still dismisses the launcher")
        wrapper.open()
        check(host.registry.bundled[0].provider.id === "system", "system first")
        check(host.registry.bundled[1].provider.id === "applications", "applications second")
        check(host.appLibrary !== null, "native application library")
        check(!host.usefulPreview(null), "empty selection has no preview")
        check(!host.usefulPreview({providerKey: "applications", preview: "Application", previewImage: "icon.png"}), "apps never repeat their icon or details in a preview")
        check(!host.usefulPreview({title: "Same", preview: "Same"}), "duplicate titles do not get a preview")
        check(!host.usefulPreview({subtitle: "Same", preview: "Same"}), "duplicate subtitles do not get a preview")
        check(!host.usefulPreview({providerKey: "hotkeys", preview: "Launch app"}), "hotkey metadata does not get a preview")
        check(host.usefulPreview({providerKey: "files", preview: "Document content", title: "notes.md"}), "file content retains its preview")
        check(host.usefulPreview({previewImage: "image.png"}) && host.usefulPreview({swatch: "#ff0000"}), "images and color swatches retain previews")
        check(host.registryEntry("timer") !== null, "resident timer provider")
        check(host.registryEntry("calculator") !== null, "resident calculator provider")
        wrapper.query("12*34")
        host.runQuery()
        check(host.rows.some(row => row.providerKey === "calculator" && row.title === "408"), "arithmetic answers at the root")
        wrapper.query("slack")
        host.runQuery()
        check(!host.rows.some(row => row.providerKey === "calculator"), "a plain word is not arithmetic")
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
        // Palette hotkeys: a chord recorded for a catalog row becomes a native bind.
        check(host.hotkeysPath === Quickshell.env("HOME") + "/.config/hypr/launcher-hotkeys.lua", "dedicated hotkeys file")
        check(host.hotkeysKnown && host.hotkeys.entries.length === 0, "absent hotkeys file is safe to write")
        check(!host.bindable(host.rows[0]), "rows without a catalog cannot be bound")
        // The catalog fixture is an enabled extension on disk, so it survives the registry rebuild on every open.
        check(host.providerEnabled(host.registryEntry("local.host-catalog")), "catalog fixture enabled")
        host.navigate("local.host-catalog", "Host catalog")
        check(host.rows.length === 3 && !host.bindable(host.rows[0]) && host.bindable(host.rows[1]), "only rows with an action to run can be bound")
        const pick = function(id) { host.selectionTouched = true; host.selected = host.rows.findIndex(function(r) { return r.id === id }); return host.current.id === id }
        check(pick("runs") && host.hotkeyHint, "footer offers ctrl B for a bindable row")
        check(!host.capturing && host.beginCapture() && host.capturing && host.captureRow.uid === "local.host-catalog/runs", "capture starts")
        const press = function(key, modifiers, text) { host.captureKey({ key: key, modifiers: modifiers, text: text || "", isAutoRepeat: false }) }
        press(Qt.Key_Meta, Qt.MetaModifier)
        check(host.capturePartial === "SUPER" && host.captureChord === "", "held modifier is shown, not recorded")
        press(Qt.Key_Return, Qt.NoModifier, "\r")
        check(host.capturing && host.confirmPending === null, "enter without a chord does nothing")
        press(Qt.Key_B, Qt.NoModifier, "b")
        check(host.captureChord === "B" && host.captureCheck.state === "invalid" && !host.captureReady, "bare letters are refused")
        press(Qt.Key_B, Qt.MetaModifier, "b")
        check(host.captureChord === "SUPER + B" && host.captureCheck.state === "available" && host.captureReady, "chord is available")
        press(Qt.Key_Escape, Qt.NoModifier)
        check(!host.capturing && host.confirmPending === null, "escape cancels the recorder")
        host.beginCapture()
        press(Qt.Key_B, Qt.MetaModifier, "b")
        const hotkeyWrites = host.writeQueue.length
        press(Qt.Key_Return, Qt.NoModifier, "\r")
        check(!host.capturing && host.confirmPending !== null && host.confirmPending.confirmText === "Bind", "a chord confirms before writing")
        check(host.writeQueue.length === hotkeyWrites, "nothing is written before confirmation")
        const bindHotkey = host.confirmPending.run
        host.confirmPending = null
        bindHotkey()
        check(host.writing !== null || host.writeQueue.length > hotkeyWrites, "confirmed hotkey is queued for writing")
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
                    if (!test.shimsOnly && (launcher.status !== Loader.Ready || !launcher.item.launcherHost.configKnown || !launcher.item.launcherHost.registry.manifests["local.host-test"]
                                            || !launcher.item.launcherHost.registry.services["local.host-catalog"] || !launcher.item.launcherHost.hotkeysKnown)) return
                    test.started = true
                    test.shims()
                    if (!test.shimsOnly) test.hostChecks()
                }
                if (!test.shimsOnly) {
                    const host = launcher.item.launcherHost
                    if (host.writing || host.writeQueue.length) return
                    const wrapper = launcher.item
                    const pick = function(id) { host.selectionTouched = true; host.selected = host.rows.findIndex(function(r) { return r.id === id }); return host.current.id === id }
                    if (test.hotkeyStep === 0) {
                        const catalog = host.registry.services["local.host-catalog"].instance
                        const press = function(key, modifiers, text) { host.captureKey({ key: key, modifiers: modifiers, text: text || "", isAutoRepeat: false }) }
                        test.check(host.hotkeys.entries.length === 1 && host.hotkeys.entries[0].route === "local.host-catalog/runs" && host.hotkeys.entries[0].combo === "SUPER + B", "hotkey parsed back from the file")
                        test.check(host.hotkeysByRoute["local.host-catalog/runs"].label === "Runs headless", "bound row is known by route")
                        test.check(wrapper.run("local.host-catalog/runs") === "ok" && catalog.ran.indexOf("runs") >= 0 && !host.opened, "a hotkey runs its row without the palette")
                        test.check(wrapper.run("local.host-catalog/asks") === "ok" && host.opened && host.confirmPending !== null && catalog.ran.indexOf("asks") < 0, "a confirming row opens the palette and asks")
                        host.goBack()
                        const missing = wrapper.run("local.host-catalog/missing"), bogus = wrapper.run("bogus"), disabled = wrapper.run("local.host-test/one")
                        test.check(missing === "pending", "a row its provider does not list retries once")
                        test.check(bogus === "unavailable", "a malformed route never runs")
                        test.check(disabled === "unavailable", "a provider without a catalog never runs")
                        wrapper.route("local.host-catalog")
                        test.check(host.rows[1].accessory === "Super + B" && host.rows[0].accessory === "", "a bound row shows its chord")
                        test.check(pick("asks") && host.beginCapture(), "capture for a second row")
                        press(Qt.Key_B, Qt.MetaModifier, "b")
                        test.check(host.captureCheck.state === "replace" && host.captureCheck.message === "Replaces Runs headless's hotkey", "a chord in use by the palette can be taken over")
                        press(Qt.Key_B, Qt.MetaModifier | Qt.ShiftModifier, "B")
                        test.check(host.captureChord === "SUPER + SHIFT + B" && host.captureCheck.state === "available", "shifted chord")
                        press(Qt.Key_Return, Qt.NoModifier, "\r")
                        const bindSecond = host.confirmPending.run
                        host.confirmPending = null
                        bindSecond()
                        test.hotkeyStep = 1
                        return
                    }
                    if (test.hotkeyStep === 1) {
                        test.check(host.hotkeys.entries.length === 2 && host.hotkeysByRoute["local.host-catalog/asks"].combo === "SUPER + SHIFT + B", "second hotkey written")
                        test.check(pick("asks") && host.beginCapture() && host.captureCurrent !== null && host.captureCurrent.combo === "SUPER + SHIFT + B", "recorder shows the current chord")
                        host.captureKey({ key: Qt.Key_Backspace, modifiers: Qt.NoModifier, text: "", isAutoRepeat: false })
                        test.check(!host.capturing && host.confirmPending !== null && host.confirmPending.confirmText === "Remove", "backspace offers removal")
                        const remove = host.confirmPending.run
                        host.confirmPending = null
                        remove()
                        test.hotkeyStep = 2
                        return
                    }
                    if (test.hotkeyStep === 2) {
                        test.check(host.hotkeys.entries.length === 1 && host.hotkeys.entries[0].route === "local.host-catalog/runs", "removed hotkey leaves the other")
                        test.check(host.removeHotkey("local.host-catalog/asks", "Asks first", "") === undefined && host.confirmPending === null && host.errorMessage.indexOf("No palette hotkey") === 0, "removing a missing hotkey reports it")
                        host.errorMessage = ""
                        wrapper.close()
                        test.hotkeyStep = 3
                    }
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
