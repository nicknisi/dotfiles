import QtQuick
import QtTest

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
            BarModule { id: first; text: "First"; onClicked: test.clicks++ }
            BarModule { visible: false; text: "Hidden" }
            BarModule { enabled: false; text: "Disabled" }
            MenuAction { id: legacy; width: 200; height: 30; Accessible.name: "Legacy action"; onClicked: test.clicks++ }
            MenuSlider { id: level; width: 200; label: "Volume"; value: 0.5 }
            TextInput { id: input; width: 200; height: 28; activeFocusOnTab: true; text: "" }
            Flickable {
                id: scroll
                width: 280; height: 55
                contentWidth: width; contentHeight: 220
                clip: true
                BarModule { id: offscreen; y: 170; text: "Offscreen action"; onClicked: test.clicks++ }
            }
            ListView {
                id: list
                width: 280; height: 45
                activeFocusOnTab: true
                model: 20
                delegate: Item { width: 280; height: 25 }
            }
            BarModule { id: last; text: "Last" }
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
        const slider = level.children[0];
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
