import QtQuick
import qs
import qs.Kit
import qs.Panels
// Installs qs.Panels.Sheets: Quickshell only resolves a directory's types
// once some file it scans from shell.qml imports that directory, and the
// sheets (loaded by URL, here and from the launcher's System view, in every
// bar mode) find SheetFrame through it.
import qs.Panels.Sheets
import "../lib/CcData.js" as CcData

// CcLayer.qml - the island's `cc` state (PLAN M6, control-lock 2): the
// control center (Panels/ControlCenter.qml, 760 x 560) on the island's own
// choreography (Kit/Layer), fed and run by Panels/CcModel.qml.
//
// The sheets are the live ones under Panels/Sheets; `island open cc/<name>`
// reaches them through openSheet(). What the control center asks of the
// island (close, the power state) goes out as signals for IslandView.
Layer {
    id: layer

    property var monitor: null
    property bool animated: true
    // What the Clipboard mini calls instead of the `clipboard` IPC: the
    // island's palette, opened in place (IslandView.openClipboard); null for
    // none.
    property var openClipboard: null
    // What the Theme mini calls instead of `theme picker themes`: the themes
    // picker in place (IslandView.openThemes); null for none.
    property var openThemes: null

    signal close
    signal power

    readonly property alias content: cc
    readonly property alias model: ccModel
    readonly property var files: ({ wifi: "WifiSheet", sound: "SoundSheet", tailscale: "TailscaleSheet", bt: "BluetoothSheet", notifications: "NotificationsSheet", display: "DisplaySheet", awake: "KeepAwakeSheet", tray: "TraySheet", battery: "BatterySheet", face: "FaceSheet" })

    width: 760
    height: 560

    // A sheet by any of its names (net, audio, ...); false for none. byKey:
    // its first row draws the focus ring (ControlCenter.openSheet).
    function openSheet(name: string, props, byKey): bool {
        return cc.openSheet(CcData.sheetName(name), props, byKey === true);
    }

    onCurrentChanged: {
        ccModel.now = new Date();
        if (!current) cc.closeSheet(true);
    }

    ControlCenter {
        id: cc
        anchors.fill: parent
        shown: layer.current
        animated: layer.animated
        monitor: layer.monitor
        focus: true
        model: ccModel.home
        sheetUrl: function (name) {
            const file = layer.files[name];
            return file ? Qt.resolvedUrl("../Panels/Sheets/" + file + ".qml") : "";
        }
        onAction: (name, arg) => ccModel.run(name, arg)
        onCloseRequested: layer.close()
    }

    CcModel {
        id: ccModel
        active: layer.current
        monitor: layer.monitor
        openClipboard: layer.openClipboard
        openThemes: layer.openThemes
        onClose: layer.close()
        onPower: layer.power()
        onSheet: (name, props) => layer.openSheet(name, props, false)
    }

    // Notification times and the media clock move while it shows.
    Timer {
        interval: 30000
        repeat: true
        running: layer.current
        onTriggered: ccModel.now = new Date()
    }
}
