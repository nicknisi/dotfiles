import Quickshell
import Quickshell.Io
import QtQuick
import qs
import "../../lib/CcData.js" as CcData

// DisplaySheet.qml - brightness, the bar mode, and DisplayMenu's modes and
// scales (control-lock 3.6, not drawn; PLAN 1.6 for the bar mode): the
// Display and Power mode minis and the brightness row's device button, and
// the launcher's System > Displays page in place of DisplayMenu.qml.
//
// Brightness: Backlight's fraction, set with `brightnessctl set N%` (N >= 1)
// after an 80 ms pause (HudHome's debounce). Bar: island, pill, full, rail
// (Prefs.setBarMode; the island closes first, since leaving island mode
// takes it down). Mode and Scale: `display-mode json <output>` when the sheet
// shows, applied with `display-mode set <output> <mode> <scale>`, exactly as
// DisplayMenu does.
//
// A fixture's `sheets.display` stands in, and then, as under Fixture.dryRun,
// nothing runs.
SheetFrame {
    id: sheet

    readonly property var fixture: Fixture.data.sheets?.display
    readonly property bool dry: Fixture.dryRun || sheet.fixture !== undefined
    property var display: ({ current: {}, modes: [], scales: [] })
    property string error: ""
    readonly property string output: String(sheet.monitor?.name ?? "")
    readonly property bool busy: query.running || action.running

    readonly property var live: ({
            brightness: { value: Backlight.fraction, present: Backlight.max > 1 },
            output: sheet.display.output ?? sheet.output,
            current: sheet.display.current ?? {},
            modes: sheet.display.modes ?? [],
            scales: sheet.display.scales ?? [],
            barMode: Prefs.barMode,
            error: sheet.error
        })

    objectName: "ccSheet-display"
    title: "Display"
    sheetData: CcData.display(sheet.fixture ?? sheet.live)

    onShownChanged: {
        sheet.error = "";
        if (sheet.shown) sheet.refresh();
    }
    function refresh(): void {
        if (sheet.dry || !sheet.shown || query.running || sheet.output === "") return;
        query.command = ["display-mode", "json", sheet.output];
        query.running = true;
    }
    function apply(mode: string, scale: real): void {
        const out = sheet.display.output || sheet.output;
        if (sheet.dry || sheet.busy || !out) return;
        sheet.error = "";
        action.command = ["display-mode", "set", out, mode, String(scale)];
        action.running = true;
    }

    property int pendingBrightness: -1
    Timer {
        id: brightnessLater
        interval: 80
        onTriggered: {
            if (sheet.pendingBrightness >= 1 && !sheet.dry) Quickshell.execDetached(["brightnessctl", "set", sheet.pendingBrightness + "%"]);
            sheet.pendingBrightness = -1;
        }
    }

    onSlid: (row, value) => {
        if (row.key !== "brightness") return;
        sheet.pendingBrightness = Math.max(1, Math.round(value * 100));
        brightnessLater.restart();
    }
    onActivated: row => {
        if (sheet.dry) return;
        const cur = sheet.display.current ?? {};
        if (row.action === "bar") {
            if (row.key === Prefs.barMode) return;
            const mode = row.key;
            sheet.dismissed();
            Qt.callLater(() => Prefs.setBarMode(mode));
        } else if (row.action === "mode") {
            sheet.apply(row.key, Number(cur.scale) || 1);
        } else if (row.action === "scale") {
            sheet.apply(String(cur.mode ?? "current"), Number(row.key));
        }
    }

    Process {
        id: query
        stdout: StdioCollector { id: queryOut }
        stderr: StdioCollector { id: queryErr }
        onExited: code => {
            if (!sheet.shown) return;
            if (code !== 0) {
                sheet.error = queryErr.text.trim() || "Could not read display modes";
                return;
            }
            try {
                sheet.display = JSON.parse(queryOut.text.trim());
            } catch (e) {
                sheet.error = "Could not read display modes";
            }
        }
    }
    Process {
        id: action
        stderr: StdioCollector { id: actionErr }
        onExited: code => {
            if (code !== 0) sheet.error = actionErr.text.trim() || "Display change failed";
            refreshLater.restart();
        }
    }
    Timer {
        id: refreshLater
        interval: 500
        onTriggered: sheet.refresh()
    }
}
