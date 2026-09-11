import QtQuick
import QtTest
import "../core/Motion.js" as Motion

TestCase {
    name: "Motion"

    function test_off_disables_every_transition() {
        var m = Motion.profile("off")
        compare(m.level, 0)
        compare(m.slide + m.selection + m.flashRise + m.flashFall + m.window, 0)
    }
    function test_snappy_is_a_couple_of_frames_and_fluid_eases() {
        var snappy = Motion.profile("snappy"), fluid = Motion.profile("fluid")
        compare(snappy.level, 1)
        compare(fluid.level, 2)
        var keys = ["slide", "selection", "window"]
        for (var i = 0; i < keys.length; i++) {
            verify(snappy[keys[i]] >= 25 && snappy[keys[i]] <= 40, keys[i] + " snappy in 25–40 ms")
            verify(fluid[keys[i]] >= 80 && fluid[keys[i]] <= 100, keys[i] + " fluid in 80–100 ms")
        }
        // The flash is faster than the transitions it sits between.
        verify(snappy.flashRise + snappy.flashFall <= snappy.window + snappy.flashRise)
        verify(fluid.flashRise + fluid.flashFall < fluid.window)
        verify(snappy.flashRise < snappy.flashFall)
    }
    function test_unknown_or_missing_tier_falls_back_to_the_default() {
        compare(Motion.profile(undefined), Motion.profile(Motion.DEFAULT_TIER))
        compare(Motion.profile("bouncy"), Motion.profile(Motion.DEFAULT_TIER))
        compare(Motion.profile(""), Motion.profile("snappy"))
    }
    function test_level_offset_enters_from_the_side_it_lives_on() {
        compare(Motion.levelOffset(1, 28), 28)
        compare(Motion.levelOffset(-1, 28), -28)
        compare(Motion.levelOffset(0, 28), 0)
        compare(Motion.levelOffset("nope", 28), 0)
    }
}
