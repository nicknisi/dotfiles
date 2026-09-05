// Battery.qml - UPower's display device, which is the laptop battery here.
//
// UPower reports percentage as 0..100 over D-Bus but some bindings normalise to
// 0..1, so this clamps either shape into a whole percent rather than guessing.
pragma Singleton
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root

    readonly property UPowerDevice device: UPower.displayDevice
    readonly property bool present: device?.isPresent ?? false
    readonly property bool charging: !UPower.onBattery

    readonly property int percent: {
        const p = root.device?.percentage ?? 0;
        return Math.round(p <= 1 ? p * 100 : p);
    }

    readonly property bool low: percent <= 20 && !charging

    // Seconds; 0 when UPower has not worked out a rate yet.
    readonly property int secondsLeft: {
        const d = root.device;
        if (!d) return 0;
        return Math.round(root.charging ? (d.timeToFull ?? 0) : (d.timeToEmpty ?? 0));
    }

    readonly property string timeText: {
        const s = root.secondsLeft;
        if (s <= 0) return "";
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        return h > 0 ? `${h}h ${m}m` : `${m}m`;
    }
}
