pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "TailscaleModel.js" as Model

Singleton {
    id: root

    property bool installed: false
    property var status: ({})
    property var accounts: []
    property var regions: []
    property string statusError: ""
    property string accountsError: ""
    property string regionsError: ""
    property string actionError: ""
    property string receiveError: ""
    property string message: ""
    property string downloads: ""
    property bool awaitingLogin: false
    property bool openedLogin: false
    property int generation: 0
    property bool settling: false
    property var pendingCommand: []
    readonly property bool running: status.running === true
    readonly property bool needsLogin: status.needsLogin === true
    readonly property bool busy: action.running || sending || settling
    readonly property bool refreshing: query.running
    property bool sending: false
    readonly property bool receiving: receiver.running
    readonly property var self: status.self ?? ({})
    readonly property var peers: running ? (status.peers ?? []) : []
    readonly property var exitNodes: running ? (status.exitNodes ?? []) : []
    readonly property string accountId: accounts.find(a => a.selected)?.id ?? ""
    readonly property string accountName: accounts.find(a => a.selected)?.label ?? status.tailnet ?? ""
    readonly property string exitName: regions.find(r => r.selected)?.name ?? status.exitNode?.name ?? ""
    readonly property bool accessDenied: /access denied|permission denied|sudo tailscale|not permitted/i.test([statusError, accountsError, actionError].join(" "))
    readonly property string stateText: !installed ? "Not installed" : statusError ? "Service unavailable"
        : needsLogin ? "Needs login" : running ? "Connected" : status.backendState === "Stopped" ? "Disconnected" : status.backendState ?? "Checking"
    readonly property string error: actionError || statusError || accountsError || regionsError || receiveError
    readonly property bool wantReceiver: running && status.fileSharing === true && !settling

    function refresh() {
        if (!query.running && !action.running && !sending && !pendingCommand.length) poll(installed ? "status" : "installed");
    }
    function poll(kind) {
        if (action.running || sending || pendingCommand.length) return;
        query.kind = kind;
        query.generation = generation;
        const commands = {
            installed: ["sh", "-c", "command -v tailscale"],
            status: ["tailscale", "status", "--json"],
            accounts: ["tailscale", "switch", "--list", "--json"],
            regions: ["tailscale", "exit-node", "list"]
        };
        query.command = ["timeout", "-k", "2", "12"].concat(commands[kind]);
        query.running = true;
    }
    function result(kind, code, output, error) {
        const failure = code === 124 || code === 137 ? "Tailscale timed out" : error.trim() || "Tailscale command failed";
        let next = "";
        try {
            if (kind === "installed") {
                installed = code === 0;
                if (installed) next = "status";
                else { status = {}; statusError = "Install the tailscale package to get started"; }
            } else if (kind === "status") {
                if (code !== 0) throw new Error(failure);
                status = Model.parseStatus(output);
                statusError = "";
                if (running) awaitingLogin = false;
                next = "accounts";
            } else if (kind === "accounts") {
                accounts = [];
                if (code !== 0) throw new Error(failure);
                accounts = Model.parseAccounts(output);
                accountsError = "";
                next = running ? "regions" : "";
            } else {
                regions = [];
                if (code !== 0) throw new Error(failure);
                regions = Model.parseExitNodes(output);
                regionsError = "";
            }
        } catch (e) {
            if (kind === "status") {
                status = {}; accounts = []; regions = [];
                settling = false;
                accountsError = ""; regionsError = "";
                statusError = e.message;
            } else if (kind === "accounts") {
                accountsError = e.message;
                next = running ? "regions" : "";
            } else regionsError = e.message;
        }
        if (!running) regions = [];
        if (!next) settling = false;
        const epoch = generation;
        if (next) Qt.callLater(() => { if (epoch === generation && !query.running) poll(next); });
    }
    function run(command, label, login) {
        if (busy || !installed) return;
        generation++;
        pendingCommand = ["timeout", "-k", "2", "300"].concat(command);
        actionError = "";
        message = label;
        action.output = "";
        action.login = login === true;
        action.authPrompt = false;
        openedLogin = false;
        // Stop the old account's receiver before changing the daemon's profile.
        settling = true;
        query.running = false;
        if (!receiver.processId) beginAction();
    }
    function beginAction() {
        if (!pendingCommand.length) return;
        action.command = pendingCommand;
        pendingCommand = [];
        action.running = true;
    }
    function openLogin(text) {
        const url = Model.authLink(text);
        if (!url || openedLogin) return;
        openedLogin = true;
        awaitingLogin = true;
        message = "Finish signing in in your browser";
        Qt.openUrlExternally(url);
    }
    function toggle() {
        if (busy || !installed || statusError) return;
        if (running) run(["tailscale", "down"], "Disconnecting", false);
        else if (needsLogin && Model.authLink(status.authUrl)) {
            openedLogin = false;
            openLogin(status.authUrl);
        } else run(["tailscale", "up"], "Connecting", true);
    }
    function switchAccount(id) {
        if (!accounts.some(a => a.id === id) || id === accountId) return;
        run(["tailscale", "switch", id], "Switching account", false);
    }
    function setExitNode(target) {
        if (!running) return;
        // Only select something returned by the daemon. An empty target clears it.
        if (target && !exitNodes.some(n => (n.ipv4 || n.dns || n.ipv6) === target)
                && !regions.some(n => n.target === target)) return;
        run(["tailscale", "set", "--exit-node=" + target], target ? "Selecting exit node" : "Using direct connection", false);
    }
    function authorize() {
        const user = Quickshell.env("USER");
        if (user) run(["pkexec", "tailscale", "set", "--operator=" + user], "Authorize in the system dialog", false);
    }
    function startService() {
        run(["pkexec", "systemctl", "start", "tailscaled.service"], "Starting Tailscale service", false);
    }
    function copy(value, label) {
        if (!value) return;
        Quickshell.clipboardText = value;
        message = "Copied " + label;
        messageTimer.restart();
    }
    function sendFiles(peerId, profile, urls) {
        const peer = peers.find(p => p.id === peerId);
        if (busy || !profile || profile !== accountId || !peer?.canSend) {
            actionError = "The connection changed. Choose the machine again before sending.";
            return;
        }
        const files = urls.map(u => Model.filePath(u));
        if (!files.length || files.some(p => !p)) {
            actionError = "Choose local files to send";
            return;
        }
        actionError = "";
        message = "Sending to " + peer.name;
        sending = true;
        sender.command = ["env", "taildrop", "send", peer.ipv4 || peer.dns || peer.ipv6].concat(files);
        sender.running = true;
    }

    Timer { interval: root.awaitingLogin ? 2000 : root.statusError ? 5000 : 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
    Timer { id: messageTimer; interval: 3000; onTriggered: if (!root.busy) root.message = "" }

    Process {
        id: query
        property string kind: ""
        property int generation: 0
        stdout: StdioCollector { id: queryOut }
        stderr: StdioCollector { id: queryErr }
        onExited: (code) => {
            if (generation === root.generation) root.result(kind, code, queryOut.text, queryErr.text);
        }
    }
    Process {
        id: action
        property bool login: false
        property bool authPrompt: false
        property string output: ""
        function line(text) {
            output += text + "\n";
            if (/To authenticate, visit:|To log in, visit:/i.test(text)) authPrompt = true;
            if (login && authPrompt) root.openLogin(text);
        }
        stdout: SplitParser { onRead: line => action.line(line) }
        stderr: SplitParser { onRead: line => action.line(line) }
        onExited: code => {
            if (code !== 0) {
                root.actionError = code === 124 || code === 137 ? "Tailscale action timed out. Refresh to check its state." : output.trim() || "Tailscale action failed";
                root.awaitingLogin = false;
            }
            root.message = "";
            Qt.callLater(root.refresh);
        }
    }
    Process {
        id: sender
        stderr: StdioCollector { id: sendErr }
        onExited: code => {
            root.sending = false;
            if (code !== 0) root.actionError = sendErr.text.trim() || "Taildrop send failed";
            root.message = code === 0 ? "Files sent" : "";
            messageTimer.restart();
        }
    }
    Timer { id: receiveRetry; interval: 10000 }
    Process {
        id: receiver
        command: ["env", "taildrop", "receive"]
        running: root.wantReceiver && !receiveRetry.running
        stdout: SplitParser {
            onRead: line => {
                try {
                    const event = JSON.parse(line);
                    if (event.event === "ready") { root.downloads = event.directory; root.receiveError = ""; }
                    else if (event.event === "received") root.receiveError = "";
                    else if (event.event === "error") root.receiveError = event.message;
                } catch (e) { root.receiveError = "Could not read Taildrop receiver status"; }
            }
        }
        stderr: StdioCollector { id: receiveErr }
        onExited: code => {
            if (root.pendingCommand.length) Qt.callLater(root.beginAction);
            else if (root.wantReceiver) {
                root.receiveError = receiveErr.text.trim() || "Taildrop receiver stopped";
                receiveRetry.restart();
            }
        }
    }
}
