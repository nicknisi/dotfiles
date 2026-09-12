import QtQuick
import QtTest

TestCase {
    id: test
    name: "ShellMotion"
    when: windowShown
    visible: true
    width: 400
    height: 300
    property int clicks: 0

    PopupSurface {
        id: popup
        shown: false
        edge: "top"
        x: 32; y: 48; width: 200; height: 120
    }
    BarModule {
        id: button
        x: 32; y: 220; width: 100; height: 32
        text: "Press"
        onClicked: test.clicks++
        Text { text: "Press" }
    }
    function test_popup_data() {
        return ["top", "bottom", "left", "right"].map(edge => ({tag: edge, edge}));
    }
    function test_popup(data) {
        popup.shown = false;
        popup.edge = data.edge;
        compare(popup.reveal, 0);
        compare(popup.opacity, 0);
        const shift = popup.transform[0];
        compare(shift.x, data.edge === "left" ? -6 : data.edge === "right" ? 6 : 0);
        compare(shift.y, data.edge === "top" ? -6 : data.edge === "bottom" ? 6 : 0);
        popup.shown = true;
        wait(40);
        verify(popup.reveal > 0 && popup.reveal < 1, "entrance animates rather than snapping");
        compare(popup.x, 32, "layout position never moves");
        compare(popup.y, 48);
        compare(popup.width, 200);
        compare(popup.height, 120);
        popup.shown = false;
        compare(popup.reveal, 0, "closing interrupts and resets the entrance");
        popup.shown = true;
        tryCompare(popup, "reveal", 1, 500);
        compare(popup.opacity, 1);
        compare(shift.x, 0, "settled panel keeps its exact anchor alignment");
        compare(shift.y, 0);
        wait(200);
        compare(popup.reveal, 1, "no idle animation");
        popup.shown = false;
    }
    function test_button() {
        clicks = 0;
        mousePress(button, 50, 16);
        wait(200);
        compare(button.contentItem.scale, 1, "pressed glyphs are never scaled");
        compare(button.width, 100, "press never shrinks the hit area");
        compare(button.height, 32);
        compare(button.scale, 1);
        mouseRelease(button, 50, 16);
        compare(clicks, 1, "press feedback does not delay activation");
        tryCompare(button.contentItem, "scale", 1, 500);
        button.forceActiveFocus();
        keyPress(Qt.Key_Space);
        wait(200);
        compare(button.contentItem.scale, 1, "keyboard presses also keep glyphs still");
        keyRelease(Qt.Key_Space);
        compare(clicks, 2, "keyboard activation keeps its feedback");
        tryCompare(button.contentItem, "scale", 1, 500);
        wait(200);
        compare(button.contentItem.scale, 1, "released button stays still");
    }
}
