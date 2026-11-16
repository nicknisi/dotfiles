import QtQuick
import qs
import "../../lib/CcData.js" as CcData

// KeepAwakeSheet.qml - keep awake's durations (control-lock 3.6, not drawn;
// CaffeineMenu's list): a right click or long press on the Keep awake mini.
// A row starts it for that long (Caffeine.start); the switch starts the last
// duration or stops it.
//
// A fixture's `sheets.awake` ({ active, selected, status }) stands in, and
// then, as under Fixture.dryRun, nothing changes.
SheetFrame {
    id: sheet

    readonly property var fixture: Fixture.data.sheets?.awake
    readonly property bool dry: Fixture.dryRun || sheet.fixture !== undefined
    readonly property var durations: [30, 60, 120, 240, -1]

    readonly property var live: ({
            active: Caffeine.active,
            selected: Caffeine.selectedMinutes,
            status: Caffeine.active ? (Caffeine.endsAt > 0 ? "On for " + Caffeine.durationLabel(Caffeine.selectedMinutes) : "On until turned off") : "Off"
        })
    readonly property var source: Object.assign({}, sheet.fixture ?? sheet.live, {
        options: sheet.durations.map(m => ({ minutes: m, label: m < 0 ? "Until turned off" : Caffeine.durationLabel(m) }))
    })

    objectName: "ccSheet-awake"
    title: "Keep awake"
    sheetData: CcData.awake(sheet.source)

    onSwitchToggled: on => {
        if (sheet.dry) return;
        if (on) Caffeine.start(Caffeine.selectedMinutes);
        else Caffeine.stop();
    }
    onActivated: row => {
        if (!sheet.dry && row.action === "start") Caffeine.start(Number(row.key));
    }
}
