// The real Tailscale service with mock executables supplied by
// tailscale.sh, through the control center's Tailscale sheet (M10:
// TailscaleMenu is gone, the sheet is the one surface left). The old menu's
// sections are the sheet's pages and groups: Machines (copy, Taildrop), the
// exit-node list (sheet.page "exits"), Accounts.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Dialogs
import qs
import qs.Panels.Sheets

ShellRoot {
    id: test
    property int stage: 0
    property int ticks: 0
    property string failure: ""
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 728
        implicitHeight: 650
        TailscaleSheet { id: menu; width: 728; height: 650; shown: true }
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
    function group(label) {
        return menu.sheetData.groups.find(g => g.label === label) ?? null;
    }
    // The old menu's machine rows: the Machines group's, without its note.
    function machines() {
        return (test.group("Machines")?.rows ?? []).filter(r => r.action === "copy");
    }
    function toggle() {
        menu.switchToggled(!menu.sheetData.switchOn);
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
                    test.check(test.machines().length === 1, "machine list rendered");
                    menu.activate(test.machines()[0]);
                    test.check(Quickshell.clipboardText === "100.64.0.2", "machine copy uses clipboard");
                    test.check(menu.sheetData.footerEnabled && menu.sheetData.footer !== "", "eligible peer can send");
                    menu.page = "exits";
                    test.check(menu.sheetData.groups[0].rows.length === 3, "direct, tailnet and Mullvad routes");
                    menu.activate(menu.sheetData.groups[0].rows[2]);
                    test.check(Tailscale.busy, "route action serialized");
                    test.next(); break;
                case 1:
                    if (Tailscale.busy || Tailscale.refreshing) return;
                    test.check(Tailscale.regions[0].selected, "Mullvad route selected");
                    menu.page = "exits";
                    menu.activate(menu.sheetData.groups[0].rows[0]);
                    test.next(); break;
                case 2:
                    if (Tailscale.busy || Tailscale.refreshing) return;
                    test.check(Tailscale.exitName === "", "direct clears route");
                    test.check(menu.page === "", "a route steps back out of the exit-node list");
                    menu.activate(test.group("Accounts").rows.find(r => r.account === "work"));
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
                    test.toggle();
                    test.next(); break;
                case 5:
                    if (Tailscale.busy || Tailscale.refreshing) return;
                    test.check(!Tailscale.running && !Tailscale.receiving, "disconnect stops receiver");
                    test.check(test.machines().length === 0 && test.group("Machines") === null, "disconnected peers hidden");
                    test.toggle();
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
                    test.check(menu.sheetData.groups[0].rows.some(r => r.key === "login" && r.action === "login" && r.title === "Log in"), "login action labelled");
                    test.scenario("broken");
                    test.next(); break;
                case 9:
                    if (control.running) return;
                    Tailscale.refresh();
                    test.next(); break;
                case 10:
                    if (Tailscale.refreshing) return;
                    test.check(!!Tailscale.statusError && !Tailscale.running, "daemon error never shows connected");
                    test.check(!menu.sheetData.switchEnabled && !test.child(menu, "sheetSwitch").enabled, "unavailable toggle disabled");
                    Theme.palette = { accent: "#a53b62", foreground: "#202020", background: "#f7f3e8", lighter_background: "#e8e0d0", mode: "light" };
                    test.scenario("Running");
                    test.next(); break;
                case 11:
                    if (control.running) return;
                    Tailscale.refresh();
                    test.next(); break;
                case 12: {
                    if (Tailscale.refreshing || !Tailscale.running) return;
                    const picker = Tailscale.filePicker;
                    test.check(picker !== null, "file picker exists");
                    picker.options = FileDialog.DontUseNativeDialog;
                    picker.currentFolder = "file://" + Quickshell.env("TAILSCALE_TEST_DIR");
                    // The non-native dialog needs a window to show in; the
                    // real one (the portal's) has its own.
                    picker.parentWindow = menu.Window.window;
                    menu.send(test.machines()[0]);
                    test.next(); break;
                }
                case 13: {
                    const picker = Tailscale.filePicker;
                    if (!picker.visible) return;
                    picker.reject();
                    test.check(!Tailscale.sending, "picker cancellation sends nothing");
                    picker.selectedFile = "file://" + Quickshell.env("TAILSCALE_TEST_DIR") + "/pick-me.txt";
                    menu.send(test.machines()[0]);
                    test.next(); break;
                }
                case 14: {
                    const picker = Tailscale.filePicker;
                    if (!picker.visible) return;
                    picker.accept();
                    test.check(Tailscale.sending, "accepted picker sends its selected files: " + Tailscale.error);
                    test.next(); break;
                }
                case 15:
                    if (Tailscale.sending) return;
                    test.check(!Tailscale.actionError, "picker transfer succeeds");
                    test.check(menu.sheetData.switchOn && Tokens.p.mode === "light" && Tokens.hex(Tokens.accent) === "#a53b62", "the connected switch follows the light palette: " + Tokens.hex(Tokens.accent));
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
