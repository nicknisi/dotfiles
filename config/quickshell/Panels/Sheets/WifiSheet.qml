import Quickshell
import Quickshell.Networking
import QtQuick
import qs
import "../../lib/CcData.js" as CcData

// WifiSheet.qml - the Wi-Fi sheet (control-lock 3.3, Control board): the
// control center's Wi-Fi chevron, and the launcher's System > Network page in
// place of NetMenu.qml.
//
// Groups from Net.networks (connected, known, the rest; lib/CcData.js wifi()).
// Presses keep NetMenu's rules: the connected row disconnects, a known or open
// one connects, a secured unknown one asks for its passphrase in the row
// (connectWithPsk on Enter), the trash forgets a known one. While NetworkManager
// reports a captive portal the connected row says "Sign-in required" and opens
// the portal instead (Net.openPortal, the one guarded call NetMenu used), then
// the sheet's host closes. The header switch is the radio. While the sheet
// shows the scanner runs (Net.device.scannerEnabled = shown) and connectivity
// is rechecked. On Limited or Unknown connectivity with no portal reported, a
// row under it opens the sign-in page by hand (NetMenu's "Open Wi-Fi sign-in
// page"). Footer: nmtui in a terminal ([GUESS]; no other settings app is
// installed).
//
// A fixture's `sheets.wifi` ({ present, radioOn, portal, networks: [{ ssid,
// connected, known, secured, bars, busy }] }) stands in for Net, and then, as
// under Fixture.dryRun, nothing reaches NetworkManager.
SheetFrame {
    id: sheet

    readonly property var fixture: Fixture.data.sheets?.wifi
    readonly property bool dry: Fixture.dryRun || sheet.fixture !== undefined
    // The browser could not be opened for the portal.
    property string portalError: ""

    readonly property var live: ({
            present: Net.device !== null,
            radioOn: Net.radioOn,
            portal: Net.portal,
            signIn: Net.signInAvailable,
            networks: Net.networks.map(n => ({
                        key: n.name,
                        ssid: n.name,
                        connected: n.connected === true,
                        known: n.known === true,
                        secured: Net.secured(n),
                        bars: Net.barsFor(n),
                        busy: Net.busy(n) === true
                    }))
        })
    readonly property var model: {
        const m = CcData.wifi(sheet.fixture ?? sheet.live);
        if (sheet.portalError !== "") m.status = sheet.portalError;
        return m;
    }

    objectName: "ccSheet-wifi"
    title: "Wi-Fi"
    sheetData: sheet.model

    function network(key) {
        return Net.networks.find(n => n.name === key) ?? null;
    }

    onShownChanged: {
        sheet.portalError = "";
        if (sheet.dry) return;
        // NetworkManager only rescans on its own schedule otherwise (NetMenu).
        if (Net.device) Net.device.scannerEnabled = sheet.shown;
        if (sheet.shown) Net.checkConnectivity();
    }
    Component.onDestruction: if (!sheet.dry && sheet.shown && Net.device) Net.device.scannerEnabled = false

    onSwitchToggled: on => {
        if (!sheet.dry && Net.device) Networking.wifiEnabled = on;
    }
    onActivated: row => {
        if (row.action === "passphrase") {
            sheet.expandedKey = row.key;
            return;
        }
        if (sheet.dry) return;
        // The manual sign-in row (Limited or Unknown connectivity) has no
        // network of its own.
        const n = row.key === "sign-in" ? Net.network : sheet.network(row.key);
        if (!n) return;
        if (row.action === "portal") {
            if (Net.openPortal()) sheet.dismissed();
            else sheet.portalError = "Could not open the browser";
        } else if (row.action === "disconnect") {
            n.disconnect();
        } else if (row.action === "connect") {
            n.connect();
        }
    }
    onSubmitted: (row, text) => {
        const n = sheet.dry ? null : sheet.network(row.key);
        if (n) n.connectWithPsk(text);
    }
    onForgot: row => {
        const n = sheet.dry ? null : sheet.network(row.key);
        if (n && n.known) n.forget();
    }
    onFooterClicked: {
        if (!sheet.dry) Quickshell.execDetached(["ghostty", "-e", "nmtui"]);
        sheet.dismissed();
    }
}
