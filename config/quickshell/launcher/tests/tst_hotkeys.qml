import QtQuick
import QtTest
import "../core/Hotkeys.js" as Hotkeys

TestCase {
    name: "Hotkeys"
    property var settings: ({ limit: 10, keyboardOnly: true })
    property string records: JSON.stringify([
        { combo: "SUPER + RETURN", label: "Terminal", dispatcher: "exec", arg: "ghostty", argv: ["uwsm-app", "--", "ghostty"] },
        { combo: "SUPER SHIFT + RETURN", label: "Browser", dispatcher: "exec", arg: "firefox --new-window", argv: ["uwsm-app", "--", "firefox", "--new-window"] },
        { combo: "SUPER SHIFT + B", label: "Browser", dispatcher: "exec", arg: "firefox --new-window", argv: ["uwsm-app", "--", "firefox", "--new-window"] },
        { combo: "SUPER + F", label: "Full screen", dispatcher: "fullscreen", arg: "0", argv: ["hyprctl", "dispatch", "hl.dsp.window.fullscreen({ mode = \"fullscreen\" })"] },
        { combo: "SUPER + Q", label: "Close window", dispatcher: "__lua", arg: "42", argv: [], labelHint: true },
        { combo: "PRINT", label: "Screenshot", dispatcher: "exec", arg: "capture shot region", argv: ["uwsm-app", "--", "capture", "shot", "region"] },
        { combo: "SUPER + Q", label: "Close window", dispatcher: "__lua", arg: "43", argv: [], submap: "resize" }
    ])

    function test_parse_merges_only_identical_actions() {
        var binds = Hotkeys.parse(records)
        compare(binds.length, 6)
        compare(binds[1].combos, ["SUPER SHIFT + RETURN", "SUPER SHIFT + B"])
        compare(binds[5].id, "close-window-2")
        compare(binds[5].submap, "resize")
        compare(Hotkeys.parse("bad JSON").length, 0)
        compare(Hotkeys.parse("{}").length, 0)
    }
    function test_keys_are_readable() {
        compare(Hotkeys.keys("SUPER SHIFT CTRL + SPACE"), "Super + Shift + Ctrl + Space")
        compare(Hotkeys.keys("SUPER + RETURN"), "Super + ↵")
        compare(Hotkeys.keys("CTRL ALT + DELETE"), "Ctrl + Alt + Del")
        compare(Hotkeys.keys("SUPER + LEFT"), "Super + ←")
        compare(Hotkeys.keys("XF86AudioRaiseVolume"), "Audio Raise Volume")
        compare(Hotkeys.keys("SUPER + code:20"), "Super + code:20")
    }
    function test_argv_is_literal() {
        compare(Hotkeys.loadArgv("/tmp/with space/hotkeys.lua"), ["luajit", "/tmp/with space/hotkeys.lua"])
        var argv = ["uwsm-app", "--", "printf", "%s", "a b", "$(not-expanded)", "x;y"]
        compare(Hotkeys.dispatchArgv({ argv: argv }), argv)
        compare(Hotkeys.dispatchArgv({ argv: ["bad\u0000arg"] }), [])
        compare(Hotkeys.dispatchArgv({ argv: [1] }), [])
    }
    function test_opaque_callbacks_stay_disabled() {
        var binds = Hotkeys.parse(records), rows = Hotkeys.rows("", binds, settings, true)
        compare(rows.length, binds.length)
        compare(rows[3].disabled, true)
        compare(rows[3].remember, false)
        compare(rows[3].action, { type: "noop" })
        verify(rows[3].subtitle.indexOf("__lua 42") >= 0)
        verify(rows[3].previewDetail.indexOf("Label hint") >= 0)
        compare(Hotkeys.runnable({ dispatcher: "__lua", argv: ["hyprctl", "dispatch", "42"] }), false)
        compare(Hotkeys.rows("", binds, { keyboardOnly: false }, true).length, 4)
        compare(Hotkeys.rows("", binds, settings, false).length, 0)
    }
    function registeredRecord(generation, id) {
        return { combo: "SUPER + Q", label: "Close window", dispatcher: "__lua", arg: "42",
                 registration: { generation: generation, id: id },
                 argv: ["hyprctl", "dispatch", '_G.launcher_bindings.resolve("' + generation + '", ' + id + ')'] }
    }
    function test_registered_callback_rows_and_activation_argv() {
        var record = registeredRecord("0123456789abcdef0123456789abcdef", 1)
        var binds = Hotkeys.parse(JSON.stringify([record]))
        verify(Hotkeys.runnable(binds[0]))
        var rows = Hotkeys.rows("", binds, { keyboardOnly: false }, true)
        compare(rows.length, 1)
        compare(rows[0].disabled, false)
        compare(rows[0].remember, true)
        compare(rows[0].verb, "Run")
        verify(rows[0].confirm.indexOf("Unsaved work") >= 0, "destructive registered callbacks retain confirmation")
        compare(rows[0].subtitle, "Registered Hyprland binding")
        compare(rows[0].action.type, "hotkey")
        compare(rows[0].action.registration, record.registration)
        compare(Hotkeys.dispatchArgv(rows[0].action), record.argv)
        // A cached action retains its generation, not just the recycled native
        // callback arg. The Lua fixture proves it fails after a config reload.
        var changed = registeredRecord("abcdef0123456789abcdef0123456789", 1)
        compare(Hotkeys.parse(JSON.stringify([record, changed])).length, 2)
        verify(Hotkeys.dispatchArgv(changed)[2] !== Hotkeys.dispatchArgv(record)[2])
    }
    function test_registered_identity_cannot_be_replaced_by_arbitrary_argv() {
        var generation = "0123456789abcdef0123456789abcdef"
        var record = registeredRecord(generation, 1)
        record.argv = ["hyprctl", "dispatch", "42"]
        compare(Hotkeys.dispatchArgv(record), [])
        record = registeredRecord(generation, 1)
        record.registration.id = 2
        compare(Hotkeys.dispatchArgv(record), [])
        record = registeredRecord(generation, 1)
        record.registration.generation = "abcdef0123456789abcdef0123456789"
        compare(Hotkeys.dispatchArgv(record), [])
        for (var i = 0, ids = [0, -1, 1.5, "1", 1025, "1); injected()"]; i < ids.length; i++)
            compare(Hotkeys.dispatchArgv(registeredRecord(generation, ids[i])), [])
        compare(Hotkeys.dispatchArgv(registeredRecord('x"); injected()', 1)), [])
        compare(Hotkeys.dispatchArgv(registeredRecord("a", 1)), [])
    }
    function test_registered_trigger_modes_stay_disabled_and_distinct() {
        var record = registeredRecord("0123456789abcdef0123456789abcdef", 1)
        var records = [record]
        var flags = [{ release: true }, { longPress: true }, { mouse: true }, { submap: "resize" }, { catch_all: true }, { enabled: false }]
        for (var i = 0; i < flags.length; i++) {
            var copy = JSON.parse(JSON.stringify(record))
            for (var field in flags[i]) copy[field] = flags[i][field]
            records.push(copy)
            compare(Hotkeys.dispatchArgv(copy), [])
        }
        var binds = Hotkeys.parse(JSON.stringify(records))
        compare(binds.length, records.length)
        compare(Hotkeys.rows("", binds, { keyboardOnly: false }, true).length, 1)
        var rows = Hotkeys.rows("", binds, settings, true)
        for (i = 1; i < rows.length; i++) compare(rows[i].action, { type: "noop" })
        verify(rows[2].previewDetail.indexOf("Long press") >= 0)
        verify(rows[3].previewDetail.indexOf("Mouse trigger") >= 0)
        record.repeat = true
        verify(Hotkeys.runnable(record)) // repeatable media keys can run once
    }
    function test_matches_names_combos_and_commands() {
        var binds = Hotkeys.parse(records)
        function titles(query) { return Hotkeys.rows(query, binds, settings, false).map(function(row) { return row.title }) }
        compare(titles("flcrn")[0], "Full screen")
        compare(titles("super f")[0], "Full screen")
        compare(titles("SUPER + SHIFT + B")[0], "Browser")
        compare(titles("capture")[0], "Screenshot")
        compare(titles("close win")[0], "Close window")
        compare(titles("zzzz").length, 0)
        compare(Hotkeys.rows("r", binds, { limit: 1 }, false).length, 1)
    }
}
