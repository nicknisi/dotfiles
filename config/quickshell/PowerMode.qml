// PowerMode.qml - drops the panel to 60 Hz on battery, back to 120 Hz on AC.
//
// 120 Hz cost 6.6 W more than 60 Hz when measured with the screen animating,
// roughly 2.8 hours of runtime, and buys nothing while plugged in. The gap is
// smaller on a still screen and unmeasured there. bin/panel-hz holds the
// numbers and the method; this file only decides when to call it.
//
// UPower is the trigger rather than a udev rule because the charger state is
// already on the D-Bus connection Battery.qml holds open, and driving hyprctl
// as the session user needs no root.
//
// panel-hz reads the charger itself, so nothing is passed here: the shell says
// "reconsider", not "use 60". The policy stays in one file, and running
// `panel-hz` by hand behaves identically.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Scope {
    id: root

    // Applied on every transition and once at startup: saving any shell file
    // reloads quickshell while Hyprland keeps the mode it had, and a
    // `hyprctl reload` reverts to hyprland.lua's "preferred", which is 120.
    Component.onCompleted: root.apply()

    Connections {
        target: Battery
        function onChargingChanged() { root.apply() }
    }

    // `hyprctl reload`, or saving any hypr/*.lua, throws the runtime mode away
    // and restores the config's "preferred", which is 120. Hyprland announces
    // that, so re-apply rather than sit at 120 on battery until the next
    // charger event. This is the whole reason the mode is not just written into
    // hyprland.lua: the config cannot see the charger, and this can.
    Connections {
        target: Hyprland
        function onRawEvent(event): void {
            if (event.name === "configreloaded") root.apply();
        }
    }

    function apply(): void {
        proc.command = ["panel-hz"];
        proc.startDetached();
    }

    Process { id: proc }
}
