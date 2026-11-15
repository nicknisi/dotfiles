import Quickshell
import QtQuick
import qs

// TraySheet.qml - a tray icon's menu as a sheet (DECISION 5: the tray lives
// in the control center footer; a right click, or a left click on a
// menu-only item, opens this). The rows are the item's menu entries
// (QsMenuOpener, as TrayMenuEntries.qml reads them): a press triggers one and
// the host closes; an entry with children opens them in the same frame, and
// back steps out of them first. Separators are left out; disabled entries
// show dim and do nothing. Checkable entries are on when checked.
//
// `item` is the SystemTrayItem (CcModel passes it when the sheet opens).
SheetFrame {
    id: sheet

    property var item: null
    // The submenus opened, outermost first.
    property var stack: []
    readonly property var menu: sheet.stack.length > 0 ? sheet.stack[sheet.stack.length - 1] : (sheet.item?.menu ?? null)

    QsMenuOpener {
        id: opener
        menu: sheet.menu
    }

    readonly property var entries: (opener.children?.values ?? []).filter(e => !e.isSeparator)

    objectName: "ccSheet-tray"
    title: sheet.stack.length > 0 ? (sheet.stack[sheet.stack.length - 1].text || "Menu") : (sheet.item?.tooltipTitle || sheet.item?.title || sheet.item?.id || "Tray")
    sheetData: ({
            status: "",
            hasSwitch: false,
            footer: "",
            groups: [{
                    label: "",
                    rows: sheet.entries.length ? sheet.entries.map((e, i) => ({
                                key: String(i),
                                title: e.text,
                                image: e.icon ?? "",
                                on: e.checkState === Qt.Checked,
                                dim: !e.enabled,
                                inert: !e.enabled,
                                trail: e.hasChildren ? "›" : "",
                                action: e.hasChildren ? "open" : "trigger"
                            })) : [{ key: "empty", title: "No menu", dim: true, inert: true }]
                }]
        })
    backHandler: function () {
        if (sheet.stack.length === 0) return false;
        sheet.stack = sheet.stack.slice(0, -1);
        return true;
    }

    onActivated: row => {
        const entry = sheet.entries[Number(row.key)];
        if (!entry) return;
        if (row.action === "open") {
            entry.opened();
            sheet.stack = sheet.stack.concat([entry]);
            return;
        }
        if (Fixture.dryRun) return;
        entry.triggered();
        sheet.dismissed();
    }
}
