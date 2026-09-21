import QtQuick
import QtTest
import "../core/UserHotkeys.js" as UserHotkeys

TestCase {
    name: "UserHotkeys"
    property var live: [
        { combos: ["SUPER + RETURN"], label: "Terminal", submap: "" },
        { combos: ["SUPER SHIFT + RETURN", "SUPER SHIFT + B"], label: "Browser", submap: "" },
        { combos: ["SUPER + code:10"], label: "Workspace 1", submap: "" },
        { combos: ["SUPER + R"], label: "Resize", submap: "resize" },
        { combos: ["SUPER + F"], label: "Firefox", submap: "" }
    ]
    property var entries: [
        { combo: "SUPER + F", route: "applications/firefox.desktop", label: "Firefox" },
        { combo: "SUPER + CTRL + T", route: "system/action-theme", label: "Theme" }
    ]
    property string userFile: "-- keep me\nhl.bind(\"SUPER + SHIFT + R\", hl.dsp.exec_cmd(\"ghostty -e ssh box\"))\n"

    function test_combos_parse_from_every_spelling() {
        compare(UserHotkeys.canonical("SUPER + SHIFT + B"), "SUPER SHIFT B")
        compare(UserHotkeys.canonical("shift super + b"), "SUPER SHIFT B")
        compare(UserHotkeys.canonical("SUPER SHIFT + B"), "SUPER SHIFT B")
        compare(UserHotkeys.canonical("SUPER + Code:19"), "SUPER code:19")
        compare(UserHotkeys.canonical("XF86AudioPlay"), "XF86AudioPlay")
        compare(UserHotkeys.canonical(""), "")
        compare(UserHotkeys.canonical("SUPER +"), "")
        compare(UserHotkeys.combo(UserHotkeys.parseCombo("ctrl super b")), "SUPER + CTRL + B")
        compare(UserHotkeys.display("SUPER + SHIFT + RETURN"), "Super + Shift + ↵")
        compare(UserHotkeys.display("F13"), "F13")
        compare(UserHotkeys.displayPartial("SUPER + SHIFT"), "Super + Shift + …")
        compare(UserHotkeys.displayPartial("CTRL"), "Ctrl + …")
    }
    function test_chords_come_from_qt_key_events() {
        compare(UserHotkeys.chord(Qt.Key_B, Qt.MetaModifier | Qt.ShiftModifier, "B"), { combo: "SUPER + SHIFT + B" })
        compare(UserHotkeys.chord(Qt.Key_1, Qt.MetaModifier, "1"), { combo: "SUPER + code:10" })
        compare(UserHotkeys.chord(Qt.Key_Exclam, Qt.MetaModifier | Qt.ShiftModifier, "!"), { combo: "SUPER + SHIFT + code:10" })
        compare(UserHotkeys.chord(Qt.Key_0, Qt.ControlModifier | Qt.AltModifier, "0"), { combo: "CTRL + ALT + code:19" })
        compare(UserHotkeys.chord(Qt.Key_Return, Qt.MetaModifier, "\r"), { combo: "SUPER + RETURN" })
        compare(UserHotkeys.chord(Qt.Key_Comma, Qt.MetaModifier, ","), { combo: "SUPER + COMMA" })
        compare(UserHotkeys.chord(Qt.Key_Less, Qt.MetaModifier | Qt.ShiftModifier, "<"), { combo: "SUPER + SHIFT + COMMA" })
        compare(UserHotkeys.chord(Qt.Key_F5, Qt.NoModifier, ""), { combo: "F5" })
        compare(UserHotkeys.chord(Qt.Key_MediaPlay, Qt.NoModifier, ""), { combo: "XF86AudioPlay" })
        compare(UserHotkeys.chord(Qt.Key_Meta, Qt.MetaModifier, ""), { partial: "SUPER" })
        compare(UserHotkeys.chord(Qt.Key_Shift, Qt.MetaModifier | Qt.ShiftModifier, ""), { partial: "SUPER + SHIFT" })
        compare(UserHotkeys.chord(Qt.Key_B, Qt.NoModifier, "b").error, "Add Super, Ctrl or Alt")
        compare(UserHotkeys.chord(Qt.Key_B, Qt.ShiftModifier, "B").error, "Add Super, Ctrl or Alt")
        compare(UserHotkeys.chord(Qt.Key_Escape, Qt.MetaModifier, "").error, "Escape is reserved")
        compare(UserHotkeys.chord(Qt.Key_Yen, Qt.MetaModifier, "¥").error, "That key can't be bound")
    }
    function test_routes_are_restricted_to_argv_safe_ids() {
        verify(UserHotkeys.validRoute("applications/org.mozilla.firefox.desktop"))
        verify(UserHotkeys.validRoute("hotkeys/close-window-2"))
        verify(UserHotkeys.validRoute("system/action-reboot"))
        verify(!UserHotkeys.validRoute("emoji/😀"))
        verify(!UserHotkeys.validRoute("files/~/notes with space.md"))
        verify(!UserHotkeys.validRoute("applications"))
        verify(!UserHotkeys.validRoute("a/b;c"))
        verify(!UserHotkeys.validRoute("a/b/c"))
    }
    function test_lines_round_trip_and_foreign_lines_survive() {
        var text = UserHotkeys.apply(userFile, entries, [])
        verify(text.indexOf(userFile) === 0)
        var lines = UserHotkeys.find(text).body.split("\n")
        compare(lines.length, 4)
        compare(lines[1], "hl.bind(\"SUPER + F\", hl.dsp.exec_cmd(\"qs ipc call launcher run applications/firefox.desktop\"), { description = \"Firefox\" })")
        var parsed = UserHotkeys.parse(text)
        compare(parsed.entries, entries)
        compare(parsed.foreign, [])
        compare(UserHotkeys.parse(userFile).found, false)
        var edited = text.replace(UserHotkeys.END, "hl.bind(\"SUPER + Z\", hl.dsp.exec_cmd(\"true\"))\n" + UserHotkeys.END)
        parsed = UserHotkeys.parse(edited)
        compare(parsed.entries.length, 2)
        compare(parsed.foreign, ["hl.bind(\"SUPER + Z\", hl.dsp.exec_cmd(\"true\"))"])
        compare(UserHotkeys.apply(edited, parsed.entries, parsed.foreign), edited)
        var quoted = UserHotkeys.apply("", [{ combo: "SUPER + Q", route: "system/x", label: "Say \"hi\"\\n" }], [])
        compare(UserHotkeys.parse(quoted).entries[0].label, "Say \"hi\"\\n")
        var hostile = text.replace("applications/firefox.desktop", "applications/firefox.desktop; rm -rf x")
        compare(UserHotkeys.parse(hostile).entries.length, 1)
        compare(UserHotkeys.parse(hostile).foreign.length, 1)
    }
    function test_one_chord_per_row_and_one_row_per_chord() {
        var next = UserHotkeys.withBinding(entries, "super f", "applications/chromium.desktop", "Chromium")
        compare(next.length, 2)
        compare(next[1], { combo: "SUPER + F", route: "applications/chromium.desktop", label: "Chromium" })
        next = UserHotkeys.withBinding(entries, "SUPER + SHIFT + F", "applications/firefox.desktop", "Firefox")
        compare(next.map(function(e) { return e.route }), ["system/action-theme", "applications/firefox.desktop"])
        compare(next[1].combo, "SUPER + SHIFT + F")
        compare(UserHotkeys.withoutRoute(entries, "system/action-theme").length, 1)
        compare(UserHotkeys.byRoute(entries)["system/action-theme"].combo, "SUPER + CTRL + T")
    }
    function test_check_reports_conflicts_against_live_binds_and_our_own() {
        compare(UserHotkeys.check("SUPER + B", "applications/chromium.desktop", entries, live).state, "available")
        compare(UserHotkeys.check("SUPER + RETURN", "applications/chromium.desktop", entries, live), { state: "taken", message: "Taken by Terminal in your Hyprland config" })
        compare(UserHotkeys.check("SUPER SHIFT + B", "applications/chromium.desktop", entries, live).state, "taken")
        compare(UserHotkeys.check("SUPER + 1", "applications/chromium.desktop", entries, live).state, "available")
        compare(UserHotkeys.check("SUPER + code:10", "applications/chromium.desktop", entries, live).state, "taken")
        compare(UserHotkeys.check("SUPER + R", "applications/chromium.desktop", entries, live).state, "available")
        compare(UserHotkeys.check("SUPER + F", "applications/firefox.desktop", entries, live).state, "same")
        compare(UserHotkeys.check("SUPER + F", "applications/chromium.desktop", entries, live), { state: "replace", message: "Replaces Firefox's hotkey" })
        compare(UserHotkeys.check("SUPER + F", "system/action-theme", entries, live).message, "Replaces Firefox's hotkey · moves from Super + Ctrl + T")
        compare(UserHotkeys.check("SUPER + B", "system/action-theme", entries, live), { state: "move", message: "Moves from Super + Ctrl + T" })
        compare(UserHotkeys.check("B", "system/action-theme", entries, live), { state: "invalid", message: "Add Super, Ctrl or Alt" })
        compare(UserHotkeys.check("", "system/action-theme", entries, live), { state: "invalid", message: "Press a key combination" })
    }
}
