pragma Singleton
// Net.qml - the wifi radio and whatever it is attached to.
//
// Quickshell 0.3.1 ships a Networking module that talks to NetworkManager over
// D-Bus, so none of this shells out to nmcli. DeviceType is None=0, Wifi=1,
// Wired=2; `connected` on a Network is the honest signal, so state enums are
// left alone.
import Quickshell
import Quickshell.Networking

Singleton {
    id: root

    readonly property var device: {
        const devices = Networking.devices?.values ?? [];
        for (const d of devices) {
            if (d.type === DeviceType.Wifi) return d;
        }
        return null;
    }

    readonly property var network: {
        const networks = root.device?.networks?.values ?? [];
        for (const n of networks) {
            if (n.connected) return n;
        }
        return null;
    }

    readonly property bool radioOn: Networking.wifiEnabled
    readonly property bool connected: network !== null
    readonly property string ssid: network?.name ?? ""

    // signalStrength is reported 0..100 by NetworkManager, but normalise in case
    // a backend hands back a 0..1 fraction.
    readonly property real strength: {
        const s = root.network?.signalStrength ?? 0;
        return s > 1 ? s / 100 : s;
    }

    // Four bars, so the glyph does not jitter on every dBm wobble.
    readonly property int bars: {
        if (!root.connected) return 0;
        const s = root.strength;
        if (s >= 0.75) return 4;
        if (s >= 0.5) return 3;
        if (s >= 0.25) return 2;
        return 1;
    }
}
