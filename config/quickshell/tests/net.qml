// The real Net service's captive-portal rules, with a mock Networking module
// supplied by net.sh, through the control center's Wi-Fi sheet (M10: NetMenu
// is gone, the sheet is the one surface left). `portalRow()` stands for the
// old menu's sign-in button: the connected row while a portal is reported
// (its sub "Sign-in required", the prominent case), or the manual "Open Wi-Fi
// sign-in page" row on Limited or Unknown connectivity. Activating either
// runs Net.openPortal().
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
        WifiSheet { id: menu; width: 728; height: 528; onDismissed: test.dismissals++ }
    }
    function check(condition, message) {
        if (!condition) throw new Error(message);
    }
    // The row that opens the sign-in page, as { visible, enabled,
    // highlighted, text, click() }; visible false when there is none.
    function portalRow() {
        const rows = [];
        for (const g of menu.sheetData.groups) for (const r of g.rows) rows.push(r);
        const r = rows.find(x => x.action === "portal") ?? null;
        return {
            visible: r !== null,
            enabled: r !== null && !r.inert,
            highlighted: r !== null && r.key !== "sign-in",
            text: r === null ? "" : r.key === "sign-in" ? r.title : r.sub,
            click: () => { if (r) menu.activate(r); }
        };
    }
    Timer {
        id: autoCheck
        interval: 40
        repeat: true
        property int step: 0
        onTriggered: {
            try {
                const button = test.portalRow();
                switch (step++) {
                case 0:
                    test.check(!Net.portalAttempted, "radio off resets automatic sign-in");
                    Networking.connectivity = NetworkConnectivity.Full;
                    Networking.wifiEnabled = true;
                    break;
                case 1:
                    test.check(!Net.portalAttempted && !button.visible, "full internet neither opens nor offers sign-in");
                    Networking.connectivity = NetworkConnectivity.Limited;
                    break;
                case 2:
                    test.check(!Net.portalAttempted && button.visible, "limited internet offers manual sign-in without opening");
                    Networking.connectivity = NetworkConnectivity.Portal;
                    break;
                case 3:
                    test.check(Net.portalAttempted && button.visible, "detected portal opens automatically and keeps retry visible");
                    Networking.connectivity = NetworkConnectivity.Full;
                    break;
                case 4:
                    test.check(Net.portalAttempted && !button.visible, "successful sign-in hides button without resetting guard");
                    Networking.connectivity = NetworkConnectivity.Portal;
                    break;
                case 5:
                    test.check(Net.portalAttempted && button.visible, "portal returning restores button without another automatic tab");
                    Networking.hotel.connected = false;
                    break;
                case 6:
                    test.check(!Net.portalAttempted, "disconnect resets automatic sign-in");
                    Networking.hotel.connected = true;
                    break;
                case 7:
                    test.check(Net.portalAttempted, "reconnect allows one new automatic attempt");
                    button.click();
                    Networking.wifiEnabled = false;
                    Networking.connectivity = NetworkConnectivity.Unknown;
                    Networking.wifiEnabled = true;
                    break;
                case 8:
                    test.check(!Net.portalAttempted && button.visible, "unknown connectivity offers manual sign-in without opening");
                    button.click();
                    Networking.connectivity = NetworkConnectivity.Portal;
                    break;
                case 9:
                    test.check(Net.portalAttempted && button.visible, "manual attempt prevents a later duplicate automatic tab");
                    console.log("NETWORK_TEST_PASS");
                    Qt.quit();
                }
            } catch (error) {
                console.error("NETWORK_TEST_FAIL: auto step " + step + ": " + error.message);
                Qt.quit();
            }
        }
    }
    Timer {
        interval: 200
        running: true
        onTriggered: {
            try {
                test.check(Networking.mock === true, "never run against the real network");
                let button = test.portalRow();
                test.check(Net.connected && Net.portal, "Wi-Fi association is distinct from internet access");
                test.check(Net.portalAttempted, "portal present on shell startup opens once");
                test.check(button.visible && button.enabled && button.highlighted, "portal action is prominent");
                test.check(button.text === "Sign-in required" && Net.statusText === "sign-in required", "portal is labelled");
                test.check(Networking.checks > 0, "connection triggers a connectivity check");
                const checks = Networking.checks;
                menu.shown = true;
                test.check(Networking.checks === checks + 1, "opening menu refreshes connectivity");
                button.click();
                test.check(menu.portalError !== "" && test.dismissals === 0, "browser failure is visible and keeps menu open");

                for (const [state, label] of [
                    [NetworkConnectivity.Full, "internet connected"],
                    [NetworkConnectivity.Limited, "limited internet access"],
                    [NetworkConnectivity.None, "no internet access"],
                    [NetworkConnectivity.Unknown, "internet access not checked"]
                ]) {
                    Networking.connectivity = state;
                    button = test.portalRow();
                    test.check(!Net.portal && Net.statusText === label, "status: " + label);
                    const available = state !== NetworkConnectivity.Full;
                    test.check(button.visible === available && button.enabled === available && !button.highlighted, "manual sign-in follows incomplete internet access");
                    test.check(!available || button.text === "Open Wi-Fi sign-in page", "manual action is labelled");
                }
                Networking.connectivity = NetworkConnectivity.Portal;
                Networking.connectivityCheckEnabled = false;
                const disabledChecks = Networking.checks;
                Net.checkConnectivity();
                button = test.portalRow();
                test.check(Networking.checks === disabledChecks && !Net.portal, "disabled checks are respected");
                test.check(button.visible && Net.statusText === "internet access not checked", "disabled detection keeps fallback");
                Networking.connectivityCheckEnabled = true;
                Networking.canCheckConnectivity = false;
                Net.checkConnectivity();
                test.check(Networking.checks === disabledChecks && !Net.portal, "unsupported checks are respected");
                Networking.canCheckConnectivity = true;

                Networking.hotel.connected = false;
                button = test.portalRow();
                test.check(!Net.portal && !button.visible && !button.enabled, "disconnect clears portal and disables sign-in");
                test.check(Net.statusText === "not connected" && !Net.openPortal(), "disconnected network cannot open browser");
                Net.checkConnectivity();
                test.check(Networking.checks === disabledChecks, "disconnected network is not probed");
                Networking.hotel.connected = true;
                test.check(Networking.checks === disabledChecks + 1 && Net.portal, "reconnect checks again");
                Networking.wifiEnabled = false;
                button = test.portalRow();
                test.check(!Net.portal && !button.visible && !button.enabled && !Net.openPortal(), "radio off cannot open sign-in");
                test.check(Net.statusText === "wifi off", "radio off label");
                autoCheck.start();
            } catch (error) {
                console.error("NETWORK_TEST_FAIL: " + error.message);
                Qt.quit();
            }
        }
    }
}
