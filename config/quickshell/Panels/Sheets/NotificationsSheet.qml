import QtQuick
import qs
import "../../lib/CcData.js" as CcData

// NotificationsSheet.qml - the whole notification history (control-lock 3.6;
// not drawn): the Do not disturb tile's chevron and the notifications card's
// header. The switch is Do not disturb (NotificationState.dnd, the flag the
// toasts and the island read); a row focuses its sender (and the host closes
// when that worked); the footer clears the history.
//
// A fixture's `sheets.notifications` ({ dnd, items: [{ summary, appName,
// body, created, critical }] }) stands in, and then, as under
// Fixture.dryRun, nothing changes.
SheetFrame {
    id: sheet

    readonly property var fixture: Fixture.data.sheets?.notifications
    readonly property bool dry: Fixture.dryRun || sheet.fixture !== undefined
    property date now: new Date()

    readonly property var live: {
        const items = [];
        const list = NotificationState.history;
        for (let i = 0; i < list.count; i++) {
            const n = list.get(i);
            items.push({ summary: n.summary, appName: n.appName, body: n.body, created: n.created, critical: n.critical });
        }
        return { dnd: NotificationState.dnd, items: items };
    }

    objectName: "ccSheet-notifications"
    title: "Notifications"
    switchLabel: "Do not disturb"
    sheetData: CcData.notifications(sheet.fixture ?? sheet.live, Number(sheet.fixture?.now) || sheet.now.getTime())

    onShownChanged: sheet.now = new Date()
    Timer {
        interval: 30000
        repeat: true
        running: sheet.shown
        onTriggered: sheet.now = new Date()
    }

    onSwitchToggled: on => {
        if (!sheet.dry) NotificationState.dnd = on;
    }
    onActivated: row => {
        if (sheet.dry || row.action !== "open") return;
        const n = NotificationState.history.count > row.index ? NotificationState.history.get(row.index) : null;
        if (n && NotificationState.focusSource(n.appName, n.desktopEntry)) sheet.dismissed();
    }
    onFooterClicked: {
        if (!sheet.dry) NotificationState.clear();
    }
}
