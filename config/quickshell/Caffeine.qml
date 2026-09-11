pragma Singleton
// Session-only idle inhibition. Choosing a duration starts it immediately;
// restarting Quickshell always restores normal idle behavior.
import Quickshell
import QtQuick

Singleton {
    id: root

    property bool active: false
    property int selectedMinutes: 60
    property double endsAt: 0

    readonly property string status: !root.active ? "off"
        : root.endsAt > 0 ? `until ${Qt.formatDateTime(new Date(root.endsAt), "HH:mm")}`
        : "until turned off"

    function durationLabel(minutes: int): string {
        if (minutes < 0) return "Until turned off";
        if (minutes < 60) return `${minutes} minutes`;
        return minutes === 60 ? "1 hour" : `${minutes / 60} hours`;
    }

    function start(minutes: int): void {
        expiry.stop();
        root.selectedMinutes = minutes;
        root.active = true;
        root.endsAt = minutes < 0 ? 0 : Date.now() + minutes * 60000;
        if (minutes > 0) {
            expiry.interval = minutes * 60000;
            expiry.restart();
        }
    }

    function stop(): void {
        expiry.stop();
        root.active = false;
        root.endsAt = 0;
    }

    Timer {
        id: expiry
        onTriggered: root.stop()
    }
}
