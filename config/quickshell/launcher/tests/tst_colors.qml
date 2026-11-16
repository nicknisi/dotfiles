import QtQuick
import QtTest
import "../core/Colors.js" as Colors

// The Colors answer (launcher-pickers 5.3): the "On bg" contrast row and its
// WCAG labels, and the swatch caption.
TestCase {
    name: "ColorsAnswer"

    function test_contrast_row_on_hackerman_bg() {
        var a = Colors.answer("#82fb9c", "#0b0c16")
        compare(a.values.length, 3)
        compare(a.contrast.label, "On bg")
        // 15.048: the mock's "15.1" rounds the spec's 15.05 a second time; one rounding gives 15.0.
        fuzzyCompare(a.contrast.ratio, 15.048, 0.001)
        compare(a.contrast.text, "15.0 : 1")
        compare(a.contrast.level, "AAA")
        compare(a.values[2].text, "hsl(133, 94%, 75%)")
    }
    function test_levels_at_their_thresholds() {
        compare(Colors.level(21), "AAA")
        compare(Colors.level(7), "AAA")
        compare(Colors.level(6.99), "AA")
        compare(Colors.level(4.5), "AA")
        compare(Colors.level(4.49), "AA large")
        compare(Colors.level(3), "AA large")
        compare(Colors.level(2.99), "Fail")
        compare(Colors.level(1), "Fail")
    }
    function test_ratio_text() {
        compare(Colors.ratioText(21), "21.0 : 1")
        compare(Colors.ratioText(4.46), "4.5 : 1")
        compare(Colors.ratioText(1), "1.0 : 1")
        // Black on white is the WCAG maximum; a colour on itself the minimum.
        fuzzyCompare(Colors.contrast("#000000", "#ffffff"), 21, 1e-9)
        compare(Colors.contrast("#fa8", "#ffaa88"), 1)
    }
    function test_low_contrast_fails() {
        var a = Colors.answer("#1a1b26", "#0b0c16")
        compare(a.contrast.level, "Fail")
        verify(a.contrast.ratio < 1.5)
    }
    function test_caption_names_a_pack_colour() {
        var palette = { name: "hackerman", accent: "#82FB9C", background: "#0b0c16" }
        compare(Colors.caption("#82fb9c", palette, "hackerman"), "hackerman accent")
        compare(Colors.caption("#0B0C16", palette, "hackerman"), "hackerman background")
        compare(Colors.caption("#123456", palette, "hackerman"), "#123456")
        compare(Colors.caption("#abcdef", null, ""), "#ABCDEF")
    }
    function test_not_a_colour() {
        compare(Colors.answer("123456", "#000000"), null)
        compare(Colors.answer("hello", "#000000"), null)
    }
}
