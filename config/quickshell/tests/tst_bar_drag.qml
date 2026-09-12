import QtQuick
import QtTest

TestCase {
    id: test
    name: "BarDrag"
    when: windowShown
    visible: true
    width: 1920
    height: 1080
    BarDragFixture { id: bar }
    function init() {
        Prefs.translucent = false;
        bar.suppressClicks = false;
        bar.clicks = 0;
        bar.scrolls = 0;
    }
    function test_layout_data() {
        const cases = [];
        for (const mode of ["pill", "full", "rail"])
            for (const edge of ["top", "bottom", "left", "right"])
                cases.push({tag: mode + "/" + edge, mode, edge});
        return cases;
    }
    function test_layout(data) {
        Prefs.barMode = data.mode;
        Prefs.edge = data.edge;
        const vertical = data.edge === "left" || data.edge === "right";
        const along = vertical ? 1080 : 1920;
        const expected = data.mode === "full" ? along : data.mode === "rail" ? along * 0.8 : 518;
        compare(vertical ? bar.surface.height : bar.surface.width, expected);
        compare(vertical ? bar.surface.width : bar.surface.height, 40);
        compare(vertical ? bar.width : bar.height, data.mode === "full" ? 40 : 56);
        compare(vertical ? bar.surface.y : bar.surface.x, (along - expected) / 2);
    }
    function test_doubleTapTransparency_data() { return test_layout_data(); }
    function test_doubleTapTransparency(data) {
        Prefs.barMode = data.mode;
        Prefs.edge = data.edge;
        Prefs.translucent = data.mode === "full";
        const before = Prefs.translucent;
        const x = bar.vertical ? 16 : 100;
        const y = bar.vertical ? 100 : 16;
        wait(Qt.styleHints.mouseDoubleClickInterval + 20);
        // QtTest inserts 500ms between mouse clicks, exceeding the platform's
        // 400ms threshold. Touch events exercise the same TapHandler without it.
        const touch = touchEvent(bar.surface);
        touch.press(0, bar.surface, x, y).commit();
        touch.release(0, bar.surface, x, y).commit();
        touch.press(0, bar.surface, x, y).commit();
        touch.release(0, bar.surface, x, y).commit();
        tryCompare(Prefs, "translucent", !before, 500, "double-tap toggles background transparency");
        fuzzyCompare(bar.background.color.a, Prefs.translucent ? 0.62 : 1, 0.01);
        mouseDoubleClickSequence(bar.button, 16, 16, Qt.LeftButton, Qt.NoModifier, 10);
        compare(Prefs.translucent, !before, "button double-clicks do not change transparency");
        compare(bar.clicks, 2, "button clicks retain their own actions");
    }
    function test_dragAfterTap() {
        Prefs.barMode = "pill";
        Prefs.edge = "top";
        wait(Qt.styleHints.mouseDoubleClickInterval + 20);
        const touch = touchEvent(bar.surface);
        touch.press(0, bar.surface, 100, 16).commit();
        touch.release(0, bar.surface, 100, 16).commit();
        touch.press(0, bar.surface, 100, 16).commit();
        touch.move(0, bar.surface, 160, 16).commit();
        touch.move(0, bar.surface, 180, 16).commit();
        tryVerify(() => bar.handler.active, 500);
        touch.release(0, bar.surface, 180, 16).commit();
        verify(!Prefs.translucent, "drag cancels a possible double-click");
        tryVerify(() => !bar.suppressClicks, 500);
    }
    function test_drag_data() {
        const cases = [];
        for (const mode of ["pill", "full", "rail"])
            for (const from of ["top", "bottom", "left", "right"])
                for (const to of ["top", "bottom", "left", "right"])
                    for (const button of [false, true])
                        cases.push({tag: mode + "/" + from + "->" + to + "/" + (button ? "button" : "bar"), mode, from, to, button});
        return cases;
    }
    function test_drag(data) {
        Prefs.barMode = data.mode;
        Prefs.edge = data.from;
        const originX = data.from === "right" ? bar.screen.width - bar.width : 0;
        const originY = data.from === "bottom" ? bar.screen.height - bar.height : 0;
        const targets = {top: [960, 5], bottom: [960, 1075], left: [5, 540], right: [1915, 540]};
        const target = targets[data.to];
        const subject = data.button ? bar.button : bar.surface;
        const px = data.button || bar.vertical ? 16 : 100;
        const py = data.button || !bar.vertical ? 16 : 100;
        mousePress(subject, px, py, Qt.LeftButton);
        mouseMove(subject, px + 30, py + 30, 20);
        tryVerify(() => bar.handler.active, 500, "drag starts over " + (data.button ? "button" : "background"));
        mouseMove(test, target[0] - originX, target[1] - originY, 20);
        mouseRelease(test, target[0] - originX, target[1] - originY, Qt.LeftButton);
        compare(Prefs.edge, data.to, "drop chooses monitor edge");
        verify(!bar.handler.active);
        compare(bar.clicks, 0, "drag never activates a button");
        verify(!Prefs.translucent, "drag never toggles transparency");
        tryVerify(() => !bar.suppressClicks, 500, "release suppression expires");
        mouseClick(bar.button, 16, 16);
        compare(bar.clicks, 1, "ordinary clicks work after dragging");
    }
    function test_clickAndWheel() {
        Prefs.edge = "top";
        Prefs.barMode = "pill";
        mousePress(bar.button, 16, 16);
        mouseMove(bar.button, 18, 18, 20);
        verify(!bar.handler.active, "small pointer jitter stays a click");
        mouseRelease(bar.button, 18, 18);
        compare(bar.clicks, 1);
        verify(!bar.handler.active);
        bar.suppressClicks = true;
        mouseClick(bar.button, 16, 16);
        compare(bar.clicks, 1, "the release guard consumes a stray click");
        mouseWheel(bar.button, 16, 16, 0, 120);
        compare(bar.scrolls, 1, "wheel reaches the button");
        compare(Prefs.edge, "top", "wheel does not move the bar");
        mouseClick(bar.surface, 100, 16);
        verify(!Prefs.translucent, "a single background click does not toggle transparency");
    }
}
