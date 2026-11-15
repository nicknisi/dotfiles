// The control center's Wi-Fi sheet (PLAN M6) on the real Net service, with
// net.sh's mock Networking module: a captive portal shows on the connected
// row as "Sign-in required", pressing that row opens the portal once (and
// never disconnects), the scanner runs only while the sheet shows, and the
// row goes back to its plain sub once the portal clears.
import Quickshell
import Quickshell.Networking
import QtQuick
import qs
import qs.Panels.Sheets

ShellRoot {
    id: test
    property int dismissals: 0
    FloatingWindow {
        visible: true
        implicitWidth: 728
        implicitHeight: 528
        WifiSheet {
            id: sheet
            width: 728
            height: 528
            onDismissed: test.dismissals++
        }
    }
    function check(condition, message) {
        if (!condition) throw new Error(message);
    }
    Timer {
        interval: 200
        repeat: true
        running: true
        property int step: 0
        onTriggered: {
            try {
                const rows = () => sheet.sheetData.groups[0].rows;
                if (step === 0) {
                    test.check(Networking.mock === true, "never run against the real network");
                    test.check(!sheet.dry, "no fixture, no dry run: the sheet talks to (mock) NetworkManager");
                    test.check(Net.portal && Net.portalAttempted, "the startup attempt already opened the portal once");
                    test.check(!Networking.wifi.scannerEnabled, "no scan before the sheet shows");
                    const checks = Networking.checks;
                    sheet.shown = true;
                    test.check(Networking.wifi.scannerEnabled, "the scanner runs while the sheet shows");
                    test.check(Networking.checks === checks + 1, "showing rechecks connectivity");
                    test.check(sheet.sheetData.groups[0].label === "Connected" && rows()[0].title === "Test Hotel", "the hotel is the connected row");
                    test.check(rows()[0].sub === "Sign-in required" && rows()[0].action === "portal", "the portal shows on the connected row");
                    const item = sheet.rowItem("Test Hotel");
                    test.check(item && item.subText.text === "Sign-in required" && String(item.subText.color) === String(Tokens.inkDim), "in inkDim, not a warning colour");
                    sheet.activate(rows()[0]);
                    test.check(Networking.hotel.disconnects === 0, "pressing it never disconnects");
                    test.check(test.dismissals === 0 && sheet.sheetData.status === "Could not open the browser", "a browser that will not open keeps the sheet up and says so");
                } else if (step === 1) {
                    Networking.connectivity = NetworkConnectivity.Full;
                } else if (step === 2) {
                    test.check(rows()[0].sub === "Open" && rows()[0].action === "disconnect", "the portal gone, the row is plain again and disconnects");
                    sheet.activate(rows()[0]);
                    test.check(Networking.hotel.disconnects === 1, "and now a press disconnects");
                    sheet.shown = false;
                    test.check(!Networking.wifi.scannerEnabled, "hiding stops the scanner");
                    console.log("NETWORK_SHEET_TEST_PASS");
                    Qt.quit();
                }
                step++;
            } catch (error) {
                console.error("NETWORK_SHEET_TEST_FAIL: " + error.message);
                Qt.quit();
            }
        }
    }
}
