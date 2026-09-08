// Real Net service and menu with a mock Networking module supplied by net.sh.
import Quickshell
import Quickshell.Networking
import QtQuick

ShellRoot {
    id: test
    property int dismissals: 0
    FloatingWindow {
        visible: true
        implicitWidth: 392
        implicitHeight: 400
        NetMenu { id: menu; width: 392; onDismissed: test.dismissals++ }
    }
    function check(condition, message) {
        if (!condition) throw new Error(message);
    }
    function child(item, name) {
        if (item.objectName === name) return item;
        for (const c of (item.children ?? [])) {
            const found = child(c, name);
            if (found) return found;
        }
        return null;
    }
    Timer {
        id: autoCheck
        interval: 40
        repeat: true
        property int step: 0
        onTriggered: {
            try {
                const button = test.child(menu, "wifiPortal");
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
                const button = test.child(menu, "wifiPortal");
                test.check(Net.connected && Net.portal, "Wi-Fi association is distinct from internet access");
                test.check(Net.portalAttempted, "portal present on shell startup opens once");
                test.check(button.visible && button.enabled && button.highlighted, "portal action is prominent");
                test.check(button.text === "Sign in to Wi-Fi" && menu.subtitle.includes("sign-in required"), "portal is labelled");
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
                    test.check(!Net.portal && Net.statusText === label, "status: " + label);
                    const available = state !== NetworkConnectivity.Full;
                    test.check(button.visible === available && button.enabled === available && !button.highlighted, "manual sign-in follows incomplete internet access");
                    test.check(button.text === "Open Wi-Fi sign-in page", "manual action is labelled");
                }
                Networking.connectivity = NetworkConnectivity.Portal;
                Networking.connectivityCheckEnabled = false;
                const disabledChecks = Networking.checks;
                Net.checkConnectivity();
                test.check(Networking.checks === disabledChecks && !Net.portal, "disabled checks are respected");
                test.check(button.visible && Net.statusText === "internet access not checked", "disabled detection keeps fallback");
                Networking.connectivityCheckEnabled = true;
                Networking.canCheckConnectivity = false;
                Net.checkConnectivity();
                test.check(Networking.checks === disabledChecks && !Net.portal, "unsupported checks are respected");
                Networking.canCheckConnectivity = true;

                Networking.hotel.connected = false;
                test.check(!Net.portal && !button.visible && !button.enabled, "disconnect clears portal and disables sign-in");
                test.check(Net.statusText === "not connected" && !Net.openPortal(), "disconnected network cannot open browser");
                Net.checkConnectivity();
                test.check(Networking.checks === disabledChecks, "disconnected network is not probed");
                Networking.hotel.connected = true;
                test.check(Networking.checks === disabledChecks + 1 && Net.portal, "reconnect checks again");
                Networking.wifiEnabled = false;
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
