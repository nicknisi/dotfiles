pragma Singleton
// Battery.qml - UPower's display device, which is the laptop battery here.
//
// UPower reports percentage as 0..100 over D-Bus but some bindings normalise to
// 0..1, so this clamps either shape into a whole percent rather than guessing.
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick

Singleton {
    id: root

    readonly property UPowerDevice device: UPower.displayDevice
    readonly property bool present: device?.isPresent ?? false
    readonly property bool pluggedIn: !UPower.onBattery
    readonly property bool charging: device?.state === UPowerDeviceState.Charging
    readonly property string statusText: charging ? "Charging" : pluggedIn ? "Plugged in" : "Battery"
    property var care: ({ supported: false, target: 0, recovery: false })
    property string error: ""
    property bool controlsVisible: false
    readonly property bool busy: action.running
    readonly property string helper: decodeURIComponent(Qt.resolvedUrl("battery-top-up.py").toString().replace(/^file:\/\//, ""))

    function refresh(): void {
        if (!query.running) query.running = true;
    }
    function topUp(target: int): void {
        if (busy || !care.supported || care.mode !== "Custom" || care.target || !pluggedIn || percent >= target || ![80, 100].includes(target)) return;
        if (target === 80 && (care.end !== 80 || percent >= 75)) return;
        run(["start", String(target)]);
    }
    function stopTopUp(): void {
        if (!busy && care.target) run(["stop"]);
    }
    function run(args): void {
        error = "";
        action.command = ["pkexec", "/usr/bin/python3", "-I", helper].concat(args);
        action.running = true;
    }

    onControlsVisibleChanged: if (controlsVisible) refresh()
    Component.onCompleted: refresh()
    Timer {
        interval: 5000
        repeat: true
        running: root.controlsVisible || root.care.target > 0
        onTriggered: root.refresh()
    }
    Process {
        id: query
        command: ["/usr/bin/python3", "-I", root.helper, "status"]
        stdout: StdioCollector { id: queryOutput }
        onExited: (code, status) => {
            if (code !== 0) { root.error = "Could not read battery controls"; return; }
            try { root.care = JSON.parse(queryOutput.text); }
            catch (e) { root.error = "Could not read battery controls"; }
        }
    }
    Process {
        id: action
        stderr: StdioCollector { id: actionError }
        onExited: (code, status) => {
            if (code !== 0) root.error = code === 126 ? "Authorization cancelled" : actionError.text.trim() || "Battery action failed";
            root.refresh();
        }
    }

    readonly property int percent: {
        const p = root.device?.percentage ?? 0;
        return Math.round(p <= 1 ? p * 100 : p);
    }

    readonly property bool low: percent <= 20 && !pluggedIn

    // Seconds; 0 when UPower has not worked out a rate yet.
    readonly property int secondsLeft: {
        const d = root.device;
        if (!d) return 0;
        return Math.round(root.charging ? (d.timeToFull ?? 0) : root.pluggedIn ? 0 : (d.timeToEmpty ?? 0));
    }

    readonly property string timeText: {
        const s = root.secondsLeft;
        if (s <= 0) return "";
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        return h > 0 ? `${h}h ${m}m` : `${m}m`;
    }
}
