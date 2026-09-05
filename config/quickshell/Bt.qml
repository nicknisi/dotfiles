pragma Singleton
// Bt.qml - the bluetooth adapter and the devices it knows about.
//
// Quickshell 0.3.1 ships a Bluetooth module that talks to BlueZ over D-Bus, so
// like Net.qml nothing here shells out to read state. The one exception is
// pairing: that module implements org.bluez Adapter1/Device1/Battery1 and never
// registers an org.bluez.Agent1, and BlueZ will not complete a pairing when no
// agent is listening. See the Process at the bottom.
//
// Named Bt rather than Bluetooth because Quickshell registers every .qml in this
// directory by filename, and `Bluetooth` is already the singleton that comes in
// with the import below.
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import QtQml          // Connections
import QtQml.Models   // Instantiator

Singleton {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool present: root.adapter !== null
    readonly property bool enabled: root.adapter?.enabled ?? false
    readonly property bool scanning: root.adapter?.discovering ?? false

    // Enabling and Disabling are transient states the radio passes through, so
    // the power toggle can grey itself out instead of looking stuck.
    readonly property bool settling: {
        const s = root.adapter?.state;
        return s === BluetoothAdapterState.Enabling || s === BluetoothAdapterState.Disabling;
    }

    readonly property var devices: root.adapter?.devices?.values ?? []

    // Three buckets, because the picker draws three sections and each one offers
    // a different action: disconnect, connect, pair.
    readonly property var connected: root.sorted(root.devices.filter(d => d.connected))
    readonly property var known: root.sorted(root.devices.filter(d => !d.connected && (d.paired || d.bonded)))

    // A scan turns up a pile of LE beacons that broadcast an address and nothing
    // else. `name` falls back to the address, so `deviceName` is the honest test
    // for whether a human could recognise the thing.
    readonly property var nearby: root.sorted(root.devices.filter(
        d => !d.paired && !d.bonded && d.deviceName !== ""))

    // What the bar shows when the radio is on: the first connected device, or
    // nothing.
    readonly property var primary: root.connected[0] ?? null

    // Declared as properties holding functions rather than as methods. A method
    // declared on a singleton is not reachable from another file here (see the
    // note in Icons.qml); a var property holding a function is.
    readonly property var labelFor: function (device) {
        return device?.name || device?.deviceName || device?.address || "unknown";
    }

    readonly property var sorted: function (list) {
        return list.slice().sort((a, b) => root.labelFor(a).localeCompare(root.labelFor(b)));
    }

    // battery is reported 0..1, but normalise the same way Net.strength does in
    // case a backend hands back a percentage.
    readonly property var batteryOf: function (device) {
        if (!device?.batteryAvailable) return -1;
        const b = device.battery ?? 0;
        return Math.round(b > 1 ? b : b * 100);
    }

    readonly property var statusOf: function (device) {
        if (!device) return "";
        if (device.pairing) return "pairing";
        switch (device.state) {
        case BluetoothDeviceState.Connecting: return "connecting";
        case BluetoothDeviceState.Disconnecting: return "disconnecting";
        case BluetoothDeviceState.Connected: return "connected";
        }
        return device.paired || device.bonded ? "paired" : "";
    }

    // One click does the obvious thing for whatever state the row is in.
    readonly property var activate: function (device) {
        if (!device) return;
        if (device.pairing) {
            device.cancelPair();
        } else if (device.connected || device.state === BluetoothDeviceState.Connecting) {
            device.disconnect();
        } else if (device.paired || device.bonded) {
            device.connect();
        } else {
            root.autoConnect[device.address] = true;
            device.pair();
        }
    }

    // ---- pair, then connect ------------------------------------------------
    // BlueZ treats these as separate operations: pair() bonds the device and
    // stops, so a freshly paired headset just sits there unless something tells
    // it to connect. This watches for the moment a device we asked to pair
    // becomes paired and finishes the job, marking it trusted so it can
    // reconnect on its own next time it powers on.
    //
    // The watch lives here rather than in the popup's row delegate because that
    // delegate is destroyed the instant the device moves from the "available"
    // section to the "paired" one, which is the same instant the signal fires.
    property var autoConnect: ({})

    Instantiator {
        model: root.devices
        delegate: Connections {
            required property var modelData
            target: modelData

            function onPairedChanged() {
                if (!root.autoConnect[modelData.address]) return;
                delete root.autoConnect[modelData.address];
                if (!modelData.paired) return;
                modelData.trusted = true;
                // Plenty of devices connect themselves the instant bonding
                // completes. Calling connect() on top of that is an error at the
                // BlueZ level ("Device is already connected"), so only push the
                // ones that did not.
                if (!modelData.connected && modelData.state !== BluetoothDeviceState.Connecting) {
                    modelData.connect();
                }
            }
        }
    }

    // ---- the pairing agent -------------------------------------------------
    // Nothing on this session registers an org.bluez.Agent1, and BlueZ rejects a
    // pairing when no agent can answer for it. bluetoothctl registers one as a
    // side effect of starting up, so park an instance of it for as long as the
    // picker could plausibly need it and no longer: an always-on agent leaves
    // the controller Pairable forever.
    //
    // stdinEnabled is what keeps it alive. Given a closed stdin, bluetoothctl
    // reads EOF on its first prompt, prints "quit" and exits, taking the agent
    // with it.
    //
    // NoInputNoOutput accepts "just works" pairing without a prompt, which is
    // every headset, speaker, mouse and most keyboards. The one case it cannot
    // serve is a device that insists on a passkey being displayed or typed back,
    // because Quickshell exposes no agent callbacks to draw a prompt from; pair
    // those with `bluetoothctl` directly.
    //
    // Set by BtPopup. Bar.qml is per-monitor so on a multi-head setup the last
    // picker to close clears it for all of them, which is why scanning and
    // in-flight pairings hold the agent up on their own too.
    property bool pickerOpen: false

    readonly property bool agentWanted: root.pickerOpen || root.scanning
        || root.devices.some(d => d.pairing)

    Process {
        running: root.agentWanted
        stdinEnabled: true
        command: ["bluetoothctl", "--agent", "NoInputNoOutput"]
    }
}
