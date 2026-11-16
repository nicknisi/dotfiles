import QtQuick
import qs
import "../../lib/CcData.js" as CcData
import "../../lib/NightLight.js" as Rules

// NightLightSheet.qml - the night light (NightLight.qml, on hyprsunset): the
// Night light mini's chevron, right click or long press, its press while
// hyprsunset is not answering, and the launcher's System > Night Light page.
//
// The switch turns it on or off (against a schedule, until the next edge).
// Warmth: a slider, neutral at the left and warmest at the right, 2500 to
// 6000 K on 100 (NightLight applies it once a drag settles). Schedule: Off,
// or Custom times with From and To on 30-minute steppers (Left and Right on
// the row). While hyprsunset is not running, "Start hyprsunset" runs
// `systemctl --user start hyprsunset.service`, the one place the shell
// starts it.
//
// A fixture's `sheets.nightlight` stands in, and then, as under
// Fixture.dryRun, nothing changes.
SheetFrame {
    id: sheet

    readonly property var fixture: Fixture.data.sheets?.nightlight
    readonly property bool dry: Fixture.dryRun || sheet.fixture !== undefined

    readonly property var live: ({
            available: NightLight.available,
            reason: NightLight.reason,
            message: NightLight.message,
            on: NightLight.on,
            temperature: NightLight.temperature,
            schedule: NightLight.schedule,
            from: NightLight.from,
            to: NightLight.to,
            until: NightLight.until,
            overridden: NightLight.overridden
        })

    objectName: "ccSheet-nightlight"
    title: "Night light"
    sheetData: CcData.nightlight(sheet.fixture ?? sheet.live)

    onShownChanged: if (sheet.shown && !sheet.dry) NightLight.refresh()

    onSwitchToggled: on => {
        if (!sheet.dry) NightLight.setOn(on);
    }
    onActivated: row => {
        if (sheet.dry) return;
        if (row.action === "start") NightLight.startDaemon();
        else if (row.action === "schedule") NightLight.setSchedule(row.key, "", "");
    }
    onSlid: (row, value) => {
        if (!sheet.dry && row.key === "warmth") NightLight.setTemperature(Rules.fromFraction(value));
    }
    onStepped: (row, delta) => {
        if (!sheet.dry) NightLight.stepTime(row.key, delta);
    }
}
