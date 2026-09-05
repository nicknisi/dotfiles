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

    // ---- everything the network menu picks from ---------------------------
    // Connected first, then remembered, then by signal. Anything without an SSID
    // is a hidden network the picker cannot do anything useful with.
    readonly property var networks: {
        const list = (root.device?.networks?.values ?? []).filter(n => n.name !== "");
        list.sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            if (a.known !== b.known) return a.known ? -1 : 1;
            return (b.signalStrength ?? 0) - (a.signalStrength ?? 0);
        });
        return list;
    }

    readonly property bool scanning: root.device?.scannerEnabled ?? false

    // Open and Owe need no passphrase; everything else does, and Unknown is
    // treated as needing one because guessing wrong the other way fails silently
    // at connect time.
    readonly property var secured: function (network) {
        const s = network?.security;
        return s !== WifiSecurityType.Open && s !== WifiSecurityType.Owe;
    }

    readonly property var barsFor: function (network) {
        const raw = network?.signalStrength ?? 0;
        const s = raw > 1 ? raw / 100 : raw;
        if (s >= 0.75) return 4;
        if (s >= 0.5) return 3;
        if (s >= 0.25) return 2;
        return 1;
    }

    readonly property var busy: function (network) {
        return network?.stateChanging
            || network?.state === ConnectionState.Connecting
            || network?.state === ConnectionState.Disconnecting;
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
