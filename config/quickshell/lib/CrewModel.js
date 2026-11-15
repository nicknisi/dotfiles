// CrewModel.js - the Crew's data rules, as pure functions (PLAN M2, personal-looks 2.3).
//
// Crew.qml feeds this two raw payloads and draws nothing itself:
//
//   fleet  `fleet list --json` (fleet.observe/v1): the tmux agents, with
//          status, needsAttention, pane, session and windowId. Polled every 5 s.
//   scan   `omniwm-agents --print`: every agent process, wherever it runs
//          (tmux, Riker, Rex, a bare terminal), with pid and process age, and
//          today's spend. Polled every 15 s.
//
// build() merges them into the one model the island reads:
//
//   { total, attention, spendToday, agents: [record] }
//   record = { id, kind, host, name, where, mood, state, age, pane, session,
//              windowId, window, project, pid, riker, job, repo, reason,
//              jumpable, attention }
//
// While fleet answers, it owns the tmux agents (fresher, and it sees status)
// and the scan adds their pid and age by pane; every agent outside tmux comes
// from the scan. Without fleet, the scan's tmux rows stand in.
//
// edges() compares two models for the island's two moments: a hail when an
// agent goes from not needing you to needing you, and vibes when the last one
// that needed you is handled (OmniWM's easter egg).
//
// Every string the panel shows is built here so tests/crew-model.cjs can pin
// it. Python's omniwm-agents and this file agree on one sort: needs you first,
// then working, then by host, then by label. No .pragma library: node loads
// this file too (tests/crew-model.cjs), and nothing here keeps state.

// The mock's pixel bots (Personal board `bots`), '#' filled. 8 x 8 each.
var SPRITES = {
    awake: ["....#...", "..####..", ".######.", ".#.##.#.", ".######.", "..####..", ".#.##.#.", ".#....#."],
    hat: ["..####..", "########", ".######.", ".#.##.#.", ".######.", "..####..", ".#.##.#.", ".#....#."],
    sleep: ["........", "..####..", ".######.", ".######.", ".#.##.#.", "..####..", ".#.##.#.", ".#....#."],
    wave: ["#...#...", "#.####..", "#######.", ".#.##.#.", ".######.", "..####..", "...##.#.", ".#....#."]
};

// The board's hop: 0 / -2 / -4 / -2 px over 500 ms (CSS steps(2) on a
// 0 / 50 / 100% keyframe pair is four equal frames).
var HOP = [0, -2, -4, -2];
var HOP_PERIOD = 500;

// personal-looks 2.3 mood table. color and wordColor name Tokens properties.
//   frames  y offsets in logical px, equal frames over `period`. Kit/PixelSprite
//           snaps them to device pixels, halves away from zero, so the bob
//           stays symmetric at 1.5 (0 / -2 / -3 / -2 device px).
//   period  ms per loop.
// The motion budget (M2 review: one timer per bot redrew the whole island
// window at about 23 fps for crew-4). A group of bots shares one step clock
// (Kit/CrewClock, clockStep below) and changes on one tick:
//   needs    hops twice (1 s), then holds still for 3 s: OmniWM's waving bot
//            moves for the first 0.9 s of every 4 s, and today's behaviour
//            wins over the board's endless hop. The hail card, on screen for
//            5 s, hops without the pause (HOP, HOP_PERIOD).
//   working  bobs over 1000 ms, not the board's 900, so its 250 ms frames land
//            on every second 125 ms hop tick.
var MOODS = {
    needs: { sprite: "wave", color: "accent", word: "needs you", wordColor: "accent", period: 4000,
        frames: HOP.concat(HOP, [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]) },
    working: { sprite: "awake", color: "fg", word: "working", wordColor: "inkDim", period: 1000, frames: [0, -1, -2, -1] },
    asleep: { sprite: "sleep", color: "inkDim", word: "asleep", wordColor: "inkDim", period: 0, frames: [0] }
};
var MOOD_ORDER = ["needs", "working", "asleep"];

// The vibes bot bobs a little faster than a working one (Personal board: bob 0.8s).
var VIBES_PERIOD = 800;

// Kind (process or fleet agentType) to the name the panel shows.
var KIND_NAMES = { claude: "Claude Code", pi: "Pi", codex: "Codex", opencode: "OpenCode" };

// Hosts with no window to jump to.
var NO_WINDOW = ["riker", "rex"];

// How many bots the rest pill draws before "+N" (OmniWM MAX_CREW), and how
// many rows the panel lists before "+N more". Seven rows is what fits the
// island's 560 px ceiling: 16 + 30 + 7 x 52 + 8 x 8 gaps + the more line,
// the footer's spacer gap and the footer + 16 = 536 (panelHeight).
var MAX_BOTS = 8;
var MAX_ROWS = 7;

// The panel's box (personal-looks 3.5), logical px.
var PANEL = { width: 460, padding: 16, gap: 8, header: 30, row: 52, more: 16, footer: 14 };

// A feed older than this reads as stale (OmniWM STALE), seconds.
var STALE_AFTER = 120;

function str(v) {
    return v === undefined || v === null ? "" : String(v);
}

function basename(path) {
    var p = str(path).replace(/\/+$/, "");
    if (p === "" || p === "~") return p;
    var i = p.lastIndexOf("/");
    return i < 0 ? p : p.slice(i + 1);
}

// "~/Developer/dotfiles/.riker/worktrees/12" -> { job: "12", repo: "dotfiles" }
function rikerPath(path) {
    var m = /^(.*?)\/\.riker\/worktrees\/(\d+)/.exec(str(path));
    return m ? { job: m[2], repo: basename(m[1]) } : null;
}

function kindName(kind) {
    var k = str(kind).toLowerCase();
    if (KIND_NAMES[k]) return KIND_NAMES[k];
    return k === "" ? "Agent" : k.charAt(0).toUpperCase() + k.slice(1);
}

function displayName(a) {
    if (a.host === "riker") return "Riker · worker";
    if (a.host === "rex") return "Rex";
    return kindName(a.kind);
}

// One fleet.observe/v1 agent to a feed row.
function fromFleet(a) {
    var since = null;
    if (a.timestampKind === "state_change" && Number(a.ts) > 0) since = Number(a.ts);
    else if (Number(a.hookTs) > 0) since = Number(a.hookTs);
    var project = str(a.project);
    var root = a.git && a.git.worktreeRoot ? a.git.worktreeRoot : project;
    return {
        id: str(a.pane),
        kind: str(a.agentType).toLowerCase(),
        host: "tmux",
        label: str(a.label || a.windowLabel || a.window),
        window: str(a.window || a.windowLabel),
        project: project,
        repo: basename(root),
        status: str(a.status).toUpperCase(),
        attention: a.needsAttention === true,
        since: since,
        pane: str(a.pane),
        session: str(a.session),
        windowId: str(a.windowId),
        pid: null,
        age: ""
    };
}

// One omniwm-agents agent to a feed row. Rows without a pane are keyed by pid.
function fromScan(a, index) {
    var pid = Number(a.pid) > 0 ? Number(a.pid) : null;
    var pane = str(a.pane);
    var where = str(a.where);
    var riker = rikerPath(where);
    var label = str(a.label);
    return {
        id: pane !== "" ? pane : pid !== null ? "pid:" + pid : "scan:" + index,
        kind: str(a.kind).toLowerCase(),
        host: str(a.host) || "other",
        label: label,
        window: "",
        project: where,
        repo: riker ? riker.repo : basename(where),
        job: riker ? riker.job : "",
        status: str(a.state || "running").toUpperCase(),
        attention: a.attention === true,
        since: null,
        pane: pane,
        session: str(a.session),
        windowId: str(a.windowId),
        pid: pid,
        age: str(a.age)
    };
}

function agentsOf(payload) {
    return payload && Array.isArray(payload.agents) ? payload.agents : [];
}

// fleet null means it did not answer: the scan's own tmux rows stand in.
function merge(fleet, scan) {
    var scanned = agentsOf(scan).map(fromScan);
    if (fleet === null || fleet === undefined) return scanned;
    var byPane = {};
    scanned.forEach(function (s) {
        if (s.pane !== "") byPane[s.pane] = s;
    });
    var tmux = agentsOf(fleet).filter(function (f) {
        return f && f.pane;
    }).map(function (f) {
        var row = fromFleet(f);
        var s = byPane[row.pane];
        if (s) {
            row.pid = s.pid;
            row.age = s.age;
            if (!row.project) {
                row.project = s.project;
                row.repo = s.repo;
            }
        }
        return row;
    });
    return tmux.concat(scanned.filter(function (s) {
        return s.host !== "tmux";
    }));
}

function moodOf(row) {
    if (row.attention) return "needs";
    return ["BUSY", "RUNNING", "WORKING"].indexOf(row.status) >= 0 ? "working" : "asleep";
}

// Why an agent needs you, lower case (personal-looks 2.3 [GUESS]).
function reasonOf(row) {
    if (row.status === "DONE") return "done, waiting for you";
    if (["QUESTION", "WAITING", "ASKING"].indexOf(row.status) >= 0) return "waiting for approval";
    return "waiting for you";
}

// 12 min, 3 h, 2 d. Never "0 min".
function duration(seconds) {
    var s = Math.max(0, Number(seconds) || 0);
    if (s < 3600) return Math.max(1, Math.round(s / 60)) + " min";
    if (s < 86400) return Math.round(s / 3600) + " h";
    return Math.round(s / 86400) + " d";
}

function workingWhere(row) {
    if (row.host === "riker") return "Riker job" + (row.job ? " #" + row.job : "") + (row.repo ? " · " + row.repo : "");
    if (row.host === "tmux") return [row.repo, row.label].filter(Boolean).join(" · ");
    return [row.repo, row.host === "other" ? "" : row.host].filter(Boolean).join(" · ");
}

function whereOf(row, mood, now) {
    if (mood === "needs") return row.host + " · " + reasonOf(row);
    if (mood === "asleep" && row.since !== null && now > 0) return "idle " + duration(now - row.since);
    return workingWhere(row);
}

function jumpable(row) {
    if (NO_WINDOW.indexOf(row.host) >= 0) return false;
    return row.pane !== "" || row.pid !== null;
}

// A feed row to the record the island draws. now is epoch seconds.
function record(row, now) {
    var mood = moodOf(row);
    return {
        id: row.id,
        kind: row.kind,
        host: row.host,
        name: displayName(row),
        label: row.label,
        where: whereOf(row, mood, now),
        mood: mood,
        state: MOODS[mood].word,
        attention: mood === "needs",
        reason: mood === "needs" ? reasonOf(row) : "",
        repo: row.repo,
        job: row.job || "",
        riker: row.host === "riker",
        age: row.age,
        pane: row.pane,
        session: row.session,
        windowId: row.windowId,
        // The tmux window's name and the agent's directory ("~/..."), for
        // Context's lane (M3): which window shows it, and where it works.
        window: row.window || "",
        project: row.project || "",
        pid: row.pid,
        jumpable: jumpable(row)
    };
}

// Needs you, then working, then host, then label (omniwm-agents order), then id.
function compare(a, b) {
    var m = MOOD_ORDER.indexOf(a.mood) - MOOD_ORDER.indexOf(b.mood);
    if (m !== 0) return m;
    if (a.host !== b.host) return a.host < b.host ? -1 : 1;
    if (a.label !== b.label) return a.label < b.label ? -1 : 1;
    return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
}

function sort(records) {
    return records.slice().sort(compare);
}

function empty() {
    return { total: 0, attention: 0, spendToday: null, agents: [] };
}

// input = { fleet, scan } (either may be null); now = epoch seconds.
function build(input, now) {
    var src = input || {};
    var records = sort(merge(src.fleet === undefined ? null : src.fleet, src.scan || null).map(function (r) {
        return record(r, now);
    }));
    var spend = src.scan && src.scan.spend && typeof src.scan.spend.today === "number" ? src.scan.spend.today : null;
    return {
        total: records.length,
        attention: records.filter(function (r) {
            return r.attention;
        }).length,
        spendToday: spend,
        agents: records
    };
}

function find(model, id) {
    var list = model && model.agents ? model.agents : [];
    for (var i = 0; i < list.length; i++)
        if (list[i].id === id) return list[i];
    return null;
}

// What changed between two models. prev null (the first read) is a baseline:
// nothing that was already true when the shell started counts as news.
//   hails  ids now needing you that did not before (a new agent counts), in sort order
//   vibes  someone needed you, and now nobody does
function edges(prev, next) {
    if (!prev || !next) return { hails: [], vibes: false };
    var hails = next.agents.filter(function (a) {
        if (!a.attention) return false;
        var before = find(prev, a.id);
        return !before || !before.attention;
    }).map(function (a) {
        return a.id;
    });
    return { hails: hails, vibes: prev.attention > 0 && next.attention === 0 };
}

// $12 from ten dollars up, $4.37 below, "" without a value.
function money(value) {
    if (value === null || value === undefined || isNaN(Number(value))) return "";
    var v = Number(value);
    return v >= 10 ? "$" + Math.round(v) : "$" + v.toFixed(2);
}

// The rest pill's bots: the first max, and how many more.
function strip(agents, max) {
    var list = agents || [];
    var n = max === undefined ? MAX_BOTS : max;
    return { shown: list.slice(0, n), more: Math.max(0, list.length - n) };
}

// The panel's rows: the first max, and how many more.
function rows(agents, max) {
    return strip(agents, max === undefined ? MAX_ROWS : max);
}

// The panel's height for n agents: header, rows, the "+N more" line, footer.
// The board's flex column puts a spacer before the footer, so the footer sits
// two gaps below the last row (Personal board DOM: rows end 686, footer 702).
function panelHeight(count) {
    var p = PANEL;
    var shown = Math.min(count, MAX_ROWS);
    var body = shown > 0 ? shown * p.row + (shown - 1) * p.gap : p.row;
    var more = count > MAX_ROWS ? p.gap + p.more : 0;
    return p.padding + p.header + p.gap + body + more + p.gap + p.gap + p.footer + p.padding;
}

// The step a group of bots' shared clock ticks at, ms: the shortest frame
// among the moods given (125 with a needs bot, 250 with only working ones),
// 0 when none of them moves.
function clockStep(moods) {
    var step = 0;
    (moods || []).forEach(function (m) {
        var spec = MOODS[m];
        if (!spec || !(spec.period > 0) || spec.frames.length < 2) return;
        var frame = spec.period / spec.frames.length;
        if (step === 0 || frame < step) step = frame;
    });
    return step;
}

// The hail card's two lines and button, for the agent and how many others also need you.
function hail(agent, others) {
    if (!agent) return { title: "", subtitle: "", button: "" };
    var reason = agent.reason || "waiting for you";
    var subtitle = reason.charAt(0).toUpperCase() + reason.slice(1) + " in " + agent.host + (agent.repo ? " · " + agent.repo : "");
    if (others > 0) subtitle += " · +" + others + " more";
    return { title: agent.name + " needs you", subtitle: subtitle, button: agent.host === "tmux" ? "Go to pane" : "Go to window" };
}

// The first agent that needs you, preferring `id`.
function hailTarget(model, id) {
    var a = id ? find(model, id) : null;
    if (a && a.attention) return a;
    var list = model && model.agents ? model.agents : [];
    for (var i = 0; i < list.length; i++)
        if (list[i].attention) return list[i];
    return null;
}

// "Crew: 4 agents, 1 needs you" (personal-looks 6).
function summary(model) {
    var m = model || empty();
    var s = "Crew: " + m.total + (m.total === 1 ? " agent" : " agents");
    if (m.attention > 0) s += ", " + m.attention + (m.attention === 1 ? " needs you" : " need you");
    return s;
}

// crew-jump's argv for a record, [] when there is nowhere to go.
function jumpArgs(agent) {
    if (!agent || !agent.jumpable) return [];
    if (agent.pane) {
        var args = ["--pane", agent.pane];
        if (agent.session) args.push("--session", agent.session);
        if (agent.windowId) args.push("--window", agent.windowId);
        return args;
    }
    return agent.pid ? ["--pid", String(agent.pid)] : [];
}

if (typeof module !== "undefined")
    module.exports = {
        SPRITES: SPRITES, HOP: HOP, HOP_PERIOD: HOP_PERIOD, MOODS: MOODS, MOOD_ORDER: MOOD_ORDER, KIND_NAMES: KIND_NAMES, MAX_BOTS: MAX_BOTS,
        MAX_ROWS: MAX_ROWS, PANEL: PANEL, STALE_AFTER: STALE_AFTER, VIBES_PERIOD: VIBES_PERIOD,
        basename: basename, rikerPath: rikerPath, kindName: kindName, fromFleet: fromFleet, fromScan: fromScan,
        merge: merge, moodOf: moodOf, reasonOf: reasonOf, duration: duration, record: record, compare: compare,
        sort: sort, empty: empty, build: build, find: find, edges: edges, money: money, strip: strip, rows: rows,
        panelHeight: panelHeight, clockStep: clockStep, hail: hail, hailTarget: hailTarget, summary: summary, jumpArgs: jumpArgs
    };
