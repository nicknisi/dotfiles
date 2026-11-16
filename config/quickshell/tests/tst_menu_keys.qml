import QtQuick
import QtQuick.Controls
import QtTest

// MenuNavigation over a BarMenu of plain Qt controls (M10: the old BarModule,
// MenuAction and MenuSlider went with the old menus): Down and Up (Ctrl+J
// and Ctrl+K) walk the focus chain, skipping hidden and disabled controls,
// a slider keeps Left and Right, a text input keeps plain letters, focused
// controls scroll into view, a ListView is walked through its model, and the
// walk wraps inside the menu.

TestCase {
    id: test
    name: "MenuKeys"
    when: windowShown
    visible: true
    width: 400
    height: 340
    property int clicks: 0

    Item {
        id: frame
        anchors.fill: parent
        Keys.onEscapePressed: test.clicks++
        MenuNavigation { scope: frame }
        BarMenu {
            id: page
            width: 320
            Button { id: first; text: "First"; onClicked: test.clicks++ }
            Button { visible: false; text: "Hidden" }
            Button { enabled: false; text: "Disabled" }
            Button { id: legacy; width: 200; height: 30; text: "Second action"; onClicked: test.clicks++ }
            Slider { id: level; width: 200; from: 0; to: 1; value: 0.5; stepSize: 0.05 }
            TextInput { id: input; width: 200; height: 28; activeFocusOnTab: true; text: "" }
            Flickable {
                id: scroll
                width: 280; height: 55
                contentWidth: width; contentHeight: 220
                clip: true
                Button { id: offscreen; y: 170; text: "Offscreen action"; onClicked: test.clicks++ }
            }
            ListView {
                id: list
                width: 280; height: 45
                activeFocusOnTab: true
                model: 20
                delegate: Item { width: 280; height: 25 }
            }
            Button { id: last; text: "Last" }
        }
    }
    function init() {
        clicks = 0;
        input.text = "";
        scroll.contentY = 0;
        list.currentIndex = 0;
        frame.forceActiveFocus(Qt.TabFocusReason);
    }
    function test_arrowsAndControlKeys() {
        keyClick(Qt.Key_Down);
        verify(first.activeFocus, "Down focuses the first menu control");
        keyClick(Qt.Key_Down);
        verify(legacy.activeFocus, "skip hidden and disabled controls");
        keyClick(Qt.Key_K, Qt.ControlModifier);
        verify(first.activeFocus, "Ctrl-K moves up");
        keyClick(Qt.Key_J, Qt.ControlModifier);
        verify(legacy.activeFocus, "Ctrl-J moves down");
    }
    function test_sliderAndTextInput() {
        legacy.forceActiveFocus(Qt.TabFocusReason);
        keyClick(Qt.Key_Down);
        const slider = level;
        verify(slider.activeFocus, "slider participates in navigation");
        const before = slider.value;
        keyClick(Qt.Key_Right);
        verify(slider.value > before, "Left/Right retain slider behavior");
        keyClick(Qt.Key_Down);
        verify(input.activeFocus, "Down leaves the slider");
        keyClick(Qt.Key_J);
        compare(input.text, "j", "plain letters still type");
        keyClick(Qt.Key_K, Qt.ControlModifier);
        verify(slider.activeFocus, "Ctrl-K navigates out of text input");
    }
    function test_activationAndScroll() {
        legacy.forceActiveFocus(Qt.TabFocusReason);
        keyClick(Qt.Key_Return);
        compare(clicks, 1);
        keyClick(Qt.Key_Space);
        compare(clicks, 2);
        first.forceActiveFocus(Qt.TabFocusReason);
        keyClick(Qt.Key_Return);
        compare(clicks, 3);
        offscreen.forceActiveFocus(Qt.TabFocusReason);
        tryVerify(() => scroll.contentY > 0, 500, "focused controls scroll into view");
    }
    function test_virtualListAndWrap() {
        list.forceActiveFocus(Qt.TabFocusReason);
        keyClick(Qt.Key_Down);
        compare(list.currentIndex, 1);
        list.currentIndex = 19;
        keyClick(Qt.Key_Down);
        verify(last.activeFocus, "leave the list at its end");
        keyClick(Qt.Key_Down);
        verify(first.activeFocus, "focus stays inside the menu and wraps");
        keyClick(Qt.Key_Escape);
        compare(clicks, 1, "Escape still reaches the popup");
    }
}
