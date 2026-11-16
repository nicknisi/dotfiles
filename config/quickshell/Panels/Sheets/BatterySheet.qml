import QtQuick
import qs
import "../../lib/CcData.js" as CcData

// BatterySheet.qml - the charge limit (PLAN M10: BatteryMenu.qml's page,
// which the island showed through the old Hud and the classic bars on their
// panel's page frame). The control center footer's battery opens it in both
// hosts, and so do `island open battery` and `bar open battery`.
//
// Top up to 80% and Charge to 100% run Battery.topUp (pkexec, the
// battery-top-up.py helper) when Battery would run them, else they show dim;
// while one runs, Cancel top-up (or Restore battery care after an
// interrupted one) runs Battery.stopTopUp. BatteryMenu's hints follow as dim
// rows that wrap, and its error in `bad`. While the sheet shows,
// Battery.controlsVisible holds, so the helper's status is polled every 5 s
// (BatteryMenu's rule).
//
// A fixture's `sheets.battery` (Battery's shape: present, percent,
// statusText, timeText, pluggedIn, busy, error, care) stands in, and then,
// as under Fixture.dryRun, nothing runs.
SheetFrame {
    id: sheet

    readonly property var fixture: Fixture.data.sheets?.battery
    readonly property bool dry: Fixture.dryRun || sheet.fixture !== undefined
    // What the last press ran (or, under a dry run, would have): "topUp 80",
    // "stop". Tests and the sandbox.
    property string ran: ""

    readonly property var live: ({
            present: Battery.present,
            percent: Battery.percent,
            statusText: Battery.statusText,
            timeText: Battery.timeText,
            pluggedIn: Battery.pluggedIn,
            busy: Battery.busy,
            error: Battery.error,
            care: Battery.care
        })

    objectName: "ccSheet-battery"
    title: "Battery"
    sheetData: CcData.battery(sheet.fixture ?? sheet.live)

    onShownChanged: if (!sheet.fixture) Battery.controlsVisible = sheet.shown
    Component.onDestruction: if (sheet.shown && !sheet.fixture) Battery.controlsVisible = false

    onActivated: row => {
        if (row.action === "topUp") {
            sheet.ran = "topUp " + row.key;
            if (!sheet.dry) Battery.topUp(Number(row.key));
        } else if (row.action === "stop") {
            sheet.ran = "stop";
            if (!sheet.dry) Battery.stopTopUp();
        }
    }
}
