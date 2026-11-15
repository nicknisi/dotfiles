import QtQuick
import qs
import "../../lib/CcData.js" as CcData

// BluetoothSheet.qml - the Bluetooth sheet (control-lock 3.6; not drawn on
// the board, so it follows the frame's rules): the Bluetooth tile's chevron,
// and the launcher's System > Bluetooth page in place of BtMenu.qml.
//
// Connected, Paired, Available from Bt; the sub is Bt.statusOf, the trail
// the battery when the device reports one. A press does Bt.activate's one
// obvious thing (connect, disconnect, pair, cancel); the trash forgets a
// paired one. The switch is the adapter's power, the footer starts and stops
// discovery. BtMenu's two rules hold: Bt.pickerOpen follows `shown` (it keeps
// the bluetoothctl agent up for pairing), and discovery stops when the sheet
// hides.
//
// A fixture's `sheets.bt` stands in for Bt, and then, as under
// Fixture.dryRun, nothing reaches BlueZ.
SheetFrame {
    id: sheet

    readonly property var fixture: Fixture.data.sheets?.bt
    readonly property bool dry: Fixture.dryRun || sheet.fixture !== undefined

    function device(d) {
        return { key: d.address, name: Bt.labelFor(d), status: Bt.statusOf(d), battery: Bt.batteryOf(d), icon: d.icon ?? "", paired: d.paired === true || d.bonded === true };
    }
    readonly property var live: ({
            present: Bt.present,
            enabled: Bt.enabled,
            settling: Bt.settling,
            discovering: Bt.scanning,
            connected: Bt.connected.map(d => sheet.device(d)),
            known: Bt.known.map(d => sheet.device(d)),
            nearby: Bt.nearby.map(d => sheet.device(d))
        })

    objectName: "ccSheet-bt"
    title: "Bluetooth"
    sheetData: CcData.bluetooth(sheet.fixture ?? sheet.live)

    function find(key) {
        return Bt.devices.find(d => d.address === key) ?? null;
    }

    onShownChanged: {
        if (sheet.dry) return;
        Bt.pickerOpen = sheet.shown;
        if (!sheet.shown && Bt.adapter) Bt.adapter.discovering = false;
    }
    Component.onDestruction: {
        if (sheet.dry || !sheet.shown) return;
        Bt.pickerOpen = false;
        if (Bt.adapter) Bt.adapter.discovering = false;
    }

    onSwitchToggled: on => {
        if (!sheet.dry && Bt.adapter && !Bt.settling) Bt.adapter.enabled = on;
    }
    onActivated: row => {
        if (!sheet.dry && row.action === "activate") Bt.activate(sheet.find(row.key));
    }
    onForgot: row => {
        const d = sheet.dry ? null : sheet.find(row.key);
        if (d && (d.paired || d.bonded)) d.forget();
    }
    onFooterClicked: {
        if (!sheet.dry && Bt.adapter) Bt.adapter.discovering = !Bt.scanning;
    }
}
