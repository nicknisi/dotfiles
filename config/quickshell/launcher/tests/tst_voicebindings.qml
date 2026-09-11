import QtQuick
import QtTest
import "../core/VoiceBindings.js" as VoiceBindings

TestCase {
    name: "VoiceBindings"
    property string userFile: "-- my bindings\nhl.bind(\"SUPER + SHIFT + R\", hl.dsp.exec_cmd(\"ghostty -e ssh box\"))\n"

    function test_block_has_a_long_press_and_a_release_bind_per_hotkey() {
        var b = VoiceBindings.block("SUPER + SPACE, SUPER + SHIFT + code:201")
        var lines = b.split("\n")
        compare(lines.length, 10)
        verify(lines[0].indexOf("-- >>> keystroke voice") === 0)
        compare(lines[1], "hl.bind(\"SUPER + SPACE\", hl.dsp.exec_cmd(\"qs ipc call launcher voiceHold\"), { long_press = true })")
        verify(lines[2].indexOf("\"SUPER + SHIFT + code:201\"") > 0 && lines[2].indexOf("long_press") > 0)
        verify(lines[3].indexOf('hl.bind("SPACE"') === 0)
        verify(lines[4].indexOf('hl.bind("Super_L"') === 0)
        verify(lines[5].indexOf('hl.bind("Super_R"') === 0)
        verify(lines[6].indexOf('hl.bind("code:201"') === 0)
        for (var i = 3; i < 9; i++) {
            verify(lines[i].indexOf("release = true, ignore_mods = true, submap_universal = true, non_consuming = true") > 0)
            verify(lines[i].indexOf("qs ipc call launcher voiceRelease") > 0)
        }
        compare(lines[9], "-- <<< keystroke voice")
    }
    function test_keys_are_trimmed_deduplicated_and_escaped() {
        compare(VoiceBindings.parseKeys("  SUPER +  SPACE ,, super + space,SUPER + SPACE, "), ["SUPER + SPACE", "super + space"])
        compare(VoiceBindings.parseKeys(""), [])
        verify(VoiceBindings.block("SUPER + \"X\\").indexOf("\"SUPER + \\\"X\\\\\"") > 0)
        compare(VoiceBindings.block("").split("\n").length, 2)     // markers only
    }
    function test_status_and_apply_leave_the_rest_of_the_file_alone() {
        compare(VoiceBindings.status(userFile, "SUPER + SPACE"), "missing")
        var once = VoiceBindings.apply(userFile, "SUPER + SPACE")
        verify(once.indexOf(userFile) === 0)
        compare(VoiceBindings.status(once, "SUPER + SPACE"), "installed")
        compare(VoiceBindings.status(once, "SUPER + SPACE, F13"), "outdated")
        var twice = VoiceBindings.apply(once, "SUPER + SPACE")
        compare(twice, once)                                        // idempotent
        var updated = VoiceBindings.apply(once + "-- trailing user line\n", "F13")
        compare(VoiceBindings.status(updated, "F13"), "installed")
        verify(updated.indexOf("-- trailing user line") > 0)
        verify(updated.indexOf("SUPER + SPACE") < 0)
        compare(updated.split("keystroke voice").length, 3)        // one begin, one end
        compare(VoiceBindings.remove(updated), userFile + "-- trailing user line\n")
        compare(VoiceBindings.apply("", "F13").indexOf("-- >>>"), 0)
    }
    function test_a_block_missing_its_end_marker_is_replaced_to_the_end() {
        var broken = userFile + "\n-- >>> keystroke voice: hold the palette hotkey to dictate (written by Keystroke Settings › Voice)\no.bind(\"X\", nil, \"y\", {})\n"
        compare(VoiceBindings.status(broken, "X"), "outdated")
        var fixed = VoiceBindings.apply(broken, "X")
        compare(VoiceBindings.status(fixed, "X"), "installed")
        verify(fixed.indexOf("o.bind(\"X\", nil, \"y\"") < 0)
    }
}
