pragma Singleton
// Crew.qml - the agent feed behind the island's bots (PLAN M2, personal-looks 2.3).
// (pragma Singleton stays above every brace, comments included: see Icons.qml.)
//
// Two polls, both read-only and cheap, and nothing per frame:
//   - `fleet list --json` every 5 s: the tmux agents with their status and
//     needsAttention. `fleet` is resolved to its binary once per polling run
//     (`mise which fleet`): through the mise shim each call cost about 130 ms
//     of CPU against 50 for the binary (M2 review);
//   - `bin/omniwm-agents --print --crew` every 15 s: one /proc scan for every
//     agent wherever it runs (tmux, Riker, Rex, a bare terminal), with pid
//     and age, and today's spend (the script refreshes that from `sessions
//     report` at most every 10 min, in the background, into
//     ~/.cache/omniwm-agents). --crew skips the script's own `fleet list`
//     (this file already has it) and its `riker jobs` lookup (about 1 s of
//     CPU, and the panel shows the job id from the path).
// lib/CrewModel.js merges them into `agents` and the counts below. They poll
// only while the island is the bar mode, since nothing else draws the crew.
//
// Fakes: `qs ipc call crew fake '<json>'` (or a fixture's `crew` key, or, in
// the sandbox, `crew fake <fixture-name>`) replaces the feed with a payload of
// the same shape, { fleet, scan, now?, fresh? }, until `crew live`. The
// screenshot sandbox never polls (its tmux socket is the real one) and never
// jumps; SHELL_CREW=off does the same for tests/check.sh.
//
// Moments: every new model is compared with the last (CrewModel.edges). An
// agent starting to need you emits hailed(agent); the last one handled emits
// vibes(). The first model after startup, after polling resumes (back to
// island mode) and after `crew live` is only a baseline, so a mode switch
// never raises a stale hail or vibes.
//
//   qs ipc call crew inspect        JSON: the model, the feed's state, the last jump
//   qs ipc call crew fake JSON      use this payload instead of the feed
//   qs ipc call crew live           back to the feed
//   qs ipc call crew jump ID        bin/crew-jump for that agent (tmux pane or pid)
import Quickshell
import Quickshell.Io
import QtQuick
import "lib/CrewModel.js" as CrewModel

Singleton {
    id: root

    readonly property bool sandbox: Fixture.sandbox
    // Real processes: the feed and the jumps. Off in the sandbox and for SHELL_CREW=off.
    readonly property bool live: !root.sandbox && Quickshell.env("SHELL_CREW") !== "off"
    // Nothing but the island draws the crew today.
    readonly property bool wanted: Prefs.barMode === "island"
    // The payload in use instead of the feed, null for the feed.
    property var fake: null
    readonly property bool polling: root.live && root.wanted && root.fake === null

    readonly property string scanBin: Quickshell.shellDir + "/../../bin/omniwm-agents"
    // `fleet` itself, or the binary `mise which fleet` named.
    property string fleetBin: "fleet"
    readonly property string jumpBin: Quickshell.shellDir + "/../../bin/crew-jump"

    // The feed's last good answers and when they came, epoch seconds.
    property var fleetData: null
    property var scanData: null
    property real fleetAt: 0
    property real scanAt: 0
    // Polls in a row that failed, either source.
    property int failures: 0
    property real now: Date.now() / 1000

    property var model: CrewModel.empty()
    readonly property int total: root.model.total
    readonly property int attention: root.model.attention
    readonly property var spendToday: root.model.spendToday
    readonly property var agents: root.model.agents
    readonly property real lastGood: Math.max(root.fleetAt, root.scanAt)
    // A good read in the last two minutes (OmniWM STALE).
    readonly property bool fresh: root.fake !== null ? root.fake.fresh !== false : root.lastGood > 0 && root.now - root.lastGood < CrewModel.STALE_AFTER
    // The "?" bot: a feed that answered once and went quiet, or one that has
    // failed three polls in a row without ever answering.
    readonly property bool stale: root.fake !== null ? root.fake.fresh === false : root.polling && !root.fresh && (root.lastGood > 0 || root.failures >= 3)

    property bool primed: false
    // crew-jump's argv and answer, for inspect.
    property var lastJump: []
    property string lastJumpResult: ""

    signal hailed(var agent)
    signal vibes

    function rebuild() {
        let input, t;
        if (root.fake !== null) {
            input = root.fake;
            t = Number(root.fake.now) > 0 ? Number(root.fake.now) : root.now;
        } else {
            // A fleet answer older than a minute is not trusted over the scan.
            input = { fleet: root.now - root.fleetAt < 60 ? root.fleetData : null, scan: root.scanData };
            t = root.now;
        }
        const next = CrewModel.build(input, t);
        if (JSON.stringify(next) === JSON.stringify(root.model) && root.primed) return;
        const e = CrewModel.edges(root.primed ? root.model : null, next);
        root.model = next;
        root.primed = true;
        if (e.hails.length > 0) root.hailed(CrewModel.find(next, e.hails[0]));
        if (e.vibes) root.vibes();
    }

    function parse(text) {
        try {
            const v = JSON.parse(text);
            return v && typeof v === "object" ? v : null;
        } catch (e) {
            return null;
        }
    }

    // A payload, or a fixture-shaped object holding one under `crew`.
    function useFake(payload): string {
        const p = payload && typeof payload === "object" && payload.crew !== undefined ? payload.crew : payload;
        if (!p || typeof p !== "object" || Array.isArray(p)) return "error: a crew payload is an object { fleet, scan, now?, fresh? }";
        root.fake = p;
        root.rebuild();
        return "ok " + root.total + " agents, " + root.attention + " need you";
    }

    function useLive(): string {
        root.fake = null;
        root.primed = false;
        root.now = Date.now() / 1000;
        root.rebuild();
        return root.live ? "ok live" : "ok (no live feed here: " + (root.sandbox ? "sandbox" : "SHELL_CREW=off") + ")";
    }

    // "ok ..." or "error: ...". The sandbox and SHELL_CREW=off record the argv and run nothing.
    function jump(id: string): string {
        const agent = CrewModel.find(root.model, id);
        if (!agent) return "error: no agent " + id;
        const args = CrewModel.jumpArgs(agent);
        if (args.length === 0) return "error: " + agent.name + " has no window to jump to";
        root.lastJump = args;
        if (!root.live) {
            root.lastJumpResult = "not run";
            return "ok (not run here): crew-jump " + args.join(" ");
        }
        if (jumper.running) return "error: a jump is already running";
        root.lastJumpResult = "";
        jumper.command = [root.jumpBin].concat(args);
        jumper.running = true;
        return "ok crew-jump " + args.join(" ");
    }

    function inspect() {
        return {
            live: root.live,
            polling: root.polling,
            fake: root.fake !== null,
            fresh: root.fresh,
            stale: root.stale,
            fleetAt: root.fleetAt,
            scanAt: root.scanAt,
            failures: root.failures,
            total: root.total,
            attention: root.attention,
            spendToday: root.spendToday,
            lastJump: root.lastJump,
            lastJumpResult: root.lastJumpResult,
            agents: root.agents
        };
    }

    onPollingChanged: {
        root.failures = 0;
        // Back from pill mode (or a fake): the first answer is a new baseline.
        if (polling) {
            root.primed = false;
            if (!whichFleet.running) whichFleet.running = true;
        }
    }

    // A fixture with a `crew` key drives the feed in the sandbox. Loading one
    // is a fresh start (a baseline, no hail or vibes), so a shot shows the
    // fixture as written; `crew fake` afterwards is what raises the moments.
    // A fixture without one hands the feed back.
    property bool fakeFromFixture: false
    Connections {
        target: Fixture
        function onDataChanged() {
            if (Fixture.data.crew !== undefined) {
                root.primed = false;
                root.fakeFromFixture = true;
                root.useFake(Fixture.data.crew);
            } else if (root.fakeFromFixture) {
                root.fakeFromFixture = false;
                root.primed = false;
                root.useLive();
            }
        }
    }

    // The fleet binary behind the mise shim, looked up once per polling run
    // (and again after three failed polls, in case an upgrade moved it).
    Process {
        id: whichFleet
        command: ["sh", "-c", "mise which fleet 2>/dev/null"]
        stdout: StdioCollector {
            id: whichOut
        }
        onExited: code => {
            const path = whichOut.text.trim().split("\n")[0];
            root.fleetBin = code === 0 && path.startsWith("/") ? path : "fleet";
        }
    }

    Process {
        id: fleetProc
        command: ["timeout", "10", root.fleetBin, "list", "--json"]
        stdout: StdioCollector {
            id: fleetOut
        }
        onExited: code => {
            const v = code === 0 ? root.parse(fleetOut.text) : null;
            root.now = Date.now() / 1000;
            if (v && Array.isArray(v.agents)) {
                root.fleetData = v;
                root.fleetAt = root.now;
                root.failures = 0;
            } else {
                root.failures++;
                if (root.failures === 3 && root.fleetBin !== "fleet") {
                    root.fleetBin = "fleet";
                    if (!whichFleet.running) whichFleet.running = true;
                }
            }
            if (root.polling) root.rebuild();
        }
    }

    Process {
        id: scanProc
        command: ["timeout", "20", root.scanBin, "--print", "--crew"]
        stdout: StdioCollector {
            id: scanOut
        }
        onExited: code => {
            const v = code === 0 ? root.parse(scanOut.text) : null;
            root.now = Date.now() / 1000;
            if (v && Array.isArray(v.agents)) {
                root.scanData = v;
                root.scanAt = root.now;
                root.failures = 0;
            } else {
                root.failures++;
            }
            if (root.polling) root.rebuild();
        }
    }

    Process {
        id: jumper
        stdout: StdioCollector {
            id: jumpOut
        }
        stderr: StdioCollector {
            id: jumpErr
        }
        onExited: code => root.lastJumpResult = "exit " + code + ": " + (jumpOut.text + jumpErr.text).trim()
    }

    Timer {
        interval: 5000
        repeat: true
        triggeredOnStart: true
        running: root.polling
        onTriggered: if (!fleetProc.running) fleetProc.running = true
    }
    Timer {
        interval: 15000
        repeat: true
        triggeredOnStart: true
        running: root.polling
        onTriggered: if (!scanProc.running) scanProc.running = true
    }
    // Ages the feed for `fresh`, so a dead feed turns into "?" without a new answer.
    Timer {
        interval: 10000
        repeat: true
        running: root.polling
        onTriggered: root.now = Date.now() / 1000
    }

    // For `crew fake <name>` in the sandbox: a fixture file read synchronously.
    FileView {
        id: reader
        blockLoading: true
        printErrors: false
        watchChanges: false
    }

    IpcHandler {
        target: "crew"

        function inspect(): string {
            return JSON.stringify(root.inspect());
        }
        // A JSON payload, or in the sandbox the name of a tests/fixtures file
        // with a `crew` key (crew-hail, crew-calm, ...).
        function fake(json: string): string {
            // A fixture may be named with or without .json (PLAN: `crew fake hail.json`).
            const text = json.trim().replace(/\.json$/, "");
            if (text.startsWith("{")) {
                const v = root.parse(text);
                return v ? root.useFake(v) : "error: not JSON";
            }
            if (!root.sandbox) return "error: fixture names work only under SHELL_SANDBOX=1; pass JSON";
            if (!/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(text) || text.includes("..")) return "error: bad fixture name \"" + text + "\"";
            // Clearing the path first makes text() read again (see Fixture.load).
            reader.path = "";
            reader.path = Fixture.dir + "/" + text + ".json";
            // text() is what runs the blocking read; loaded is only true after it.
            const body = reader.text();
            const v = reader.loaded && body !== "" ? root.parse(body) : null;
            if (!v) return "error: no fixture " + text;
            if (v.crew === undefined) return "error: " + text + ".json has no crew key";
            return root.useFake(v);
        }
        function live(): string {
            return root.useLive();
        }
        function jump(id: string): string {
            return root.jump(id);
        }
    }
}
