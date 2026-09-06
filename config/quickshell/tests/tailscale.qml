// Real service and controls with mock executables supplied by tailscale.sh.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Dialogs

ShellRoot {
    id: test
    property int stage: 0
    property int ticks: 0
    property string failure: ""
    FloatingWindow {
        visible: true
        implicitWidth: 392
        implicitHeight: 650
        TailscaleMenu { id: menu; width: 392 }
        NetMenu { id: network; width: 392; visible: false }
    }
    Process { id: control }
    function check(condition, message) {
        if (!condition) throw new Error(message);
    }
    function child(item, name) {
        if (item.objectName === name) return item;
        for (const c of (item.data ?? item.children ?? [])) {
            const found = child(c, name);
            if (found) return found;
        }
        return null;
    }
    function scenario(state) {
        control.command = ["tailscale", "test", state];
        control.running = true;
    }
    function next() { stage++; ticks = 0; }
    Timer {
        interval: 40
        running: true
        repeat: true
        onTriggered: {
            try {
                if (++test.ticks > 100) throw new Error("Timed out at stage " + test.stage + ": " + Tailscale.error);
                switch (test.stage) {
                case 0:
                    if (Tailscale.regions.length !== 1 || Tailscale.refreshing || !Tailscale.downloads) return;
                    test.check(Tailscale.running && Tailscale.accountId === "home", "initial status/account");
                    test.check(Tailscale.receiving, "receiver starts once connected");
                    test.check(menu.rows.length === 1, "machine list rendered");
                    menu.activate(0);
                    test.check(Quickshell.clipboardText === "100.64.0.2", "machine copy uses clipboard");
                    test.check(test.child(menu, "tailscaleSend").enabled, "eligible peer can send");
                    menu.section = "Routes";
                    test.check(menu.rows.length === 3, "direct, tailnet and Mullvad routes");
                    menu.activate(2);
                    test.check(Tailscale.busy, "route action serialized");
                    test.next(); break;
                case 1:
                    if (Tailscale.busy || Tailscale.refreshing) return;
                    test.check(Tailscale.regions[0].selected, "Mullvad route selected");
                    menu.activate(0);
                    test.next(); break;
                case 2:
                    if (Tailscale.busy || Tailscale.refreshing) return;
                    test.check(Tailscale.exitName === "", "direct clears route");
                    menu.section = "Accounts";
                    menu.activate(1);
                    test.next(); break;
                case 3:
                    if (Tailscale.busy || Tailscale.refreshing) return;
                    test.check(Tailscale.accountId === "work" && Tailscale.peers[0].id === "work", "consistent switched profile and peers");
                    test.check(!Tailscale.actionError, "receiver stopped before account change");
                    Tailscale.sendFiles("work", "home", ["file:///tmp/test.txt"]);
                    test.check(!Tailscale.sending && !!Tailscale.actionError, "stale picker cannot send under new account");
                    Tailscale.sendFiles("work", "work", ["https://example.com/test.txt"]);
                    test.check(!Tailscale.sending && !!Tailscale.actionError, "nonlocal files cannot send");
                    Tailscale.sendFiles("work", "work", ["file:///tmp/test%20file.txt"]);
                    test.check(Tailscale.sending && Tailscale.busy, "send runs asynchronously: " + Tailscale.error + ", busy=" + Tailscale.busy + ", sending=" + Tailscale.sending);
                    Tailscale.switchAccount("home");
                    test.next(); break;
                case 4:
                    if (Tailscale.busy) return;
                    test.check(Tailscale.accountId === "work", "account cannot change during send");
                    menu.section = "Machines";
                    test.child(menu, "tailscaleToggle").click();
                    test.next(); break;
                case 5:
                    if (Tailscale.busy || Tailscale.refreshing) return;
                    test.check(!Tailscale.running && !Tailscale.receiving, "disconnect stops receiver");
                    test.check(menu.rows.length === 0, "disconnected peers hidden");
                    test.child(menu, "tailscaleToggle").click();
                    test.next(); break;
                case 6:
                    if (Tailscale.busy || Tailscale.refreshing) return;
                    test.check(Tailscale.running, "reconnect through control");
                    test.scenario("NeedsLogin");
                    test.next(); break;
                case 7:
                    if (control.running) return;
                    Tailscale.refresh();
                    test.next(); break;
                case 8:
                    if (Tailscale.refreshing || Tailscale.receiving) return;
                    test.check(Tailscale.needsLogin && !Tailscale.receiving, "login state stops receive");
                    test.check(test.child(menu, "tailscaleToggle").text === "Sign in to Tailscale", "login action labelled");
                    test.scenario("broken");
                    test.next(); break;
                case 9:
                    if (control.running) return;
                    Tailscale.refresh();
                    test.next(); break;
                case 10:
                    if (Tailscale.refreshing) return;
                    test.check(!!Tailscale.statusError && !Tailscale.running, "daemon error never shows connected");
                    test.check(!test.child(menu, "tailscaleToggle").enabled, "unavailable toggle disabled");
                    Theme.palette = { accent: "#a53b62", foreground: "#202020", background: "#f7f3e8", lighter_background: "#e8e0d0", mode: "light" };
                    test.scenario("Running");
                    test.next(); break;
                case 11:
                    if (control.running) return;
                    Tailscale.refresh();
                    test.next(); break;
                case 12: {
                    if (Tailscale.refreshing || !Tailscale.running) return;
                    const picker = test.child(menu, "taildropFiles");
                    test.check(picker !== null, "file picker exists");
                    picker.options = FileDialog.DontUseNativeDialog;
                    picker.currentFolder = "file://" + Quickshell.env("TAILSCALE_TEST_DIR");
                    menu.send();
                    test.next(); break;
                }
                case 13: {
                    const picker = test.child(menu, "taildropFiles");
                    if (!picker.visible) return;
                    picker.reject();
                    test.check(!Tailscale.sending, "picker cancellation sends nothing");
                    picker.selectedFile = "file://" + Quickshell.env("TAILSCALE_TEST_DIR") + "/pick-me.txt";
                    menu.send();
                    test.next(); break;
                }
                case 14: {
                    const picker = test.child(menu, "taildropFiles");
                    if (!picker.visible) return;
                    picker.accept();
                    test.check(Tailscale.sending, "accepted picker sends its selected files: " + Tailscale.error);
                    test.next(); break;
                }
                case 15:
                    if (Tailscale.sending) return;
                    test.check(!Tailscale.actionError, "picker transfer succeeds");
                    test.check(String(test.child(menu, "tailscaleToggle").background.color) === String(Theme.glowFill), "connected control follows light palette");
                    console.log("TAILSCALE_UI_PASS");
                    Qt.quit();
                }
            } catch (error) {
                console.error("TAILSCALE_UI_FAIL: stage " + test.stage + ": " + error.message);
                Qt.quit();
            }
        }
    }
}
