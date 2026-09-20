import QtQuick
import QtQuick.Layouts
import QtTest

// TrayMenuEntry against stand-ins for QsMenuEntry: a click triggers a plain
// item and leaves the menu, a disabled item ignores the click, and check and
// separator rows draw as such. Unfolding a submenu is not exercised here:
// it loads a real QsMenuOpener, which wants a D-Bus menu handle.
TestCase {
    id: test
    name: "TrayMenu"
    when: windowShown
    visible: true
    width: 320
    height: 400

    component FakeEntry: QtObject {
        property bool isSeparator: false
        property bool enabled: true
        property string text: ""
        property string icon: ""
        property int checkState: Qt.Unchecked
        property bool hasChildren: false
        property int triggers: 0
        signal triggered()
        signal opened()
        signal closed()
        onTriggered: triggers++
    }
    Component {
        id: fakeComponent
        FakeEntry {}
    }
    Component {
        id: entryComponent
        TrayMenuEntry {}
    }
    ColumnLayout {
        id: column
        width: 300
    }

    function make(props, rowProps) {
        const entry = fakeComponent.createObject(test, props);
        const row = entryComponent.createObject(column, Object.assign({ modelData: entry }, rowProps || {}));
        const t = { entry: entry, row: row, button: findChild(row, "trayEntryButton"), left: 0 };
        row.activated.connect(() => t.left++);
        waitForRendering(row);
        return t;
    }

    function test_plainEntryTriggersAndLeaves() {
        const t = make({ text: "Show window" });
        verify(t.button.visible, "a plain entry is a button");
        mouseClick(t.button);
        compare(t.entry.triggers, 1, "the entry is triggered");
        compare(t.left, 1, "and the menu is dismissed");
        compare(t.row.expanded, false);
    }

    function test_disabledEntryIgnoresClicks() {
        const t = make({ text: "Unavailable", enabled: false });
        mouseClick(t.button);
        compare(t.entry.triggers, 0);
        compare(t.left, 0);
    }

    function test_checkAndRadioGlyphs() {
        const check = make({ text: "Start at login", checkState: Qt.Checked }, { checkable: true });
        const radio = make({ text: "Balanced" }, { checkable: true, radio: true });
        const plain = make({ text: "About" });
        compare(findChild(check.row, "trayEntryCheck").text, "\u{f0132}", "checked box");
        compare(findChild(radio.row, "trayEntryCheck").text, "\u{f043d}", "unselected radio");
        verify(!findChild(plain.row, "trayEntryCheck").visible, "no glyph on a plain item");
    }

    function test_separatorAndSubmenuRows() {
        const rule = make({ isSeparator: true });
        verify(!rule.button.visible, "a separator has no button");
        const sub = make({ text: "Devices", hasChildren: true });
        verify(findChild(sub.row, "trayEntryChevron").visible, "a submenu row shows its chevron");
        compare(sub.row.expanded, false);
    }
}
