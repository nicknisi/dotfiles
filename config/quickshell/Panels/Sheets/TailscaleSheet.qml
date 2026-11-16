import QtQuick
import qs
import "../../lib/CcData.js" as CcData

// TailscaleSheet.qml - machines, the exit node and Taildrop (control-lock
// 3.5, Control board): the Tailscale tile's chevron, and the launcher's
// System > Tailscale page in place of TailscaleMenu.qml.
//
// This machine (a press copies its IP), the exit node (a press opens the
// exit-node list in the same frame: Direct, the tailnet's exit nodes, Mullvad;
// back steps out of it first [GUESS]), Machines: online peers, then the ones
// that are away with "Last seen 2 h ago" (TailscaleModel's offline list, M6),
// and Accounts when there is more than one (a press is `tailscale switch`,
// TailscaleMenu's Accounts). A press on a machine copies its IP
// (TailscaleMenu's activate) and selects it. The footer sends files with
// Taildrop [GUESS, control-lock 3.5]: to the selected machine when it takes
// them, else it opens the machines that do, in the same frame, as the exit
// nodes do; it shows whenever one does. Errors, operator access and login
// show as rows above, with TailscaleMenu's Start service and health lines.
// The header switch is Tailscale.toggle().
//
// The file chooser is Tailscale's own (Tailscale.chooseFiles): the sheet
// closes its host first, and the chooser outlives it.
//
// Not here (control-lock 3.7; lost with TailscaleMenu in M10, SWITCHOVER.md
// lists them): search, the IPv6 / DNS / name chips, the admin console link,
// the Taildrop inbox and TailscaleMenu's letter keys.
//
// A fixture's `sheets.tailscale` stands in for Tailscale, and then, as under
// Fixture.dryRun, nothing runs.
SheetFrame {
    id: sheet

    readonly property var fixture: Fixture.data.sheets?.tailscale
    readonly property bool dry: Fixture.dryRun || sheet.fixture !== undefined
    // "" for the main page, "exits" for the exit-node list, "send" for the
    // machines Taildrop can send to.
    property string page: ""
    // The machine the last Taildrop send went to (under a dry run, the one it
    // would have): tests and the sandbox.
    property string sentTo: ""
    property date now: new Date()

    readonly property var routes: [{ id: "direct", name: "Direct connection", target: "", selected: Tailscale.exitName === "", detail: "No exit node" }]
        .concat(Tailscale.exitNodes.map(n => ({ id: n.id, name: n.name, target: n.ipv4 || n.dns || n.ipv6, selected: n.exitNode, detail: n.online ? "Your tailnet" : "Selected, offline" })))
        .concat(Tailscale.regions.map(n => ({ id: n.id, name: n.name, target: n.target, selected: n.selected, detail: "Mullvad" })))
    readonly property var live: ({
            installed: Tailscale.installed,
            running: Tailscale.running,
            busy: Tailscale.busy,
            needsLogin: Tailscale.needsLogin,
            state: Tailscale.stateText,
            error: Tailscale.error,
            statusError: Tailscale.statusError !== "",
            accessDenied: Tailscale.accessDenied,
            health: Tailscale.status.health ?? [],
            self: { name: Tailscale.self.name ?? "", ipv4: Tailscale.self.ipv4 ?? "" },
            exitName: Tailscale.exitName,
            peers: Tailscale.peers,
            offline: Tailscale.offlinePeers,
            accounts: Tailscale.accounts,
            routes: sheet.routes
        })
    readonly property var source: sheet.fixture ?? sheet.live
    // From the source alone: whether the footer can send is CcData's to say
    // (some online machine takes files), never the keyboard's row, which
    // comes from this very data (the M6 review's binding loop).
    readonly property var model: CcData.tailscale(sheet.source, (Number(sheet.fixture?.now) || sheet.now.getTime()), sheet.page)

    objectName: "ccSheet-tailscale"
    title: sheet.page === "exits" ? "Exit node" : sheet.page === "send" ? "Send with Taildrop" : "Tailscale"
    sheetData: sheet.model
    backHandler: function () {
        if (sheet.page === "") return false;
        sheet.page = "";
        return true;
    }

    onShownChanged: {
        sheet.page = "";
        sheet.now = new Date();
        if (sheet.shown && !sheet.dry) Tailscale.refresh();
    }

    function peer(key) {
        return Tailscale.peers.concat(Tailscale.offlinePeers).find(p => p.id === key) ?? null;
    }
    // Taildrop to this row's machine: the chooser opens (Tailscale's own),
    // then the host closes. Under a dry run only `sentTo` changes.
    function send(row) {
        if (!row?.canSend) return;
        sheet.sentTo = row.key;
        if (sheet.dry) {
            sheet.page = "";
            return;
        }
        if (Tailscale.chooseFiles(row.key, "Send to " + row.title)) sheet.dismissed();
    }

    onSwitchToggled: on => {
        if (!sheet.dry && !Tailscale.busy) Tailscale.toggle();
    }
    onActivated: row => {
        if (row.action === "exits") {
            sheet.page = "exits";
            return;
        }
        if (row.action === "send") {
            sheet.send(row);
            return;
        }
        if (sheet.dry) {
            if (row.action === "route") sheet.page = "";
            return;
        }
        if (row.action === "copySelf") {
            Tailscale.copy(Tailscale.self.ipv4 || Tailscale.self.ipv6, "your IP");
        } else if (row.action === "copy") {
            const p = sheet.peer(row.key);
            if (p) Tailscale.copy(p.ipv4 || p.ipv6, "machine IP");
        } else if (row.action === "route") {
            const r = sheet.routes.find(x => x.id === row.key);
            if (r && !Tailscale.busy && (r.id === "direct" || r.target)) Tailscale.setExitNode(r.target);
            sheet.page = "";
        } else if (row.action === "authorize") {
            Tailscale.authorize();
        } else if (row.action === "login") {
            Tailscale.toggle();
        } else if (row.action === "account") {
            Tailscale.switchAccount(row.account);
        } else if (row.action === "startService") {
            Tailscale.startService();
        }
    }
    onFooterClicked: {
        if (!sheet.sheetData.footerEnabled) return;
        const row = sheet.currentRow;
        if (row?.canSend === true) sheet.send(row);
        else sheet.page = "send";
    }
}
