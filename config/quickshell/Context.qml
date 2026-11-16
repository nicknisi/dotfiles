pragma Singleton
// Context.qml - what you are doing, read off the focused window.
//
// This is the lane no other shell has. A bar tells you about the machine; this
// tells you about the work. The focused toplevel's app_id decides what kind of
// thing you are looking at, and its title carries the specifics: the shell
// writes its directory there, Claude Code writes a spinner and a session name,
// a browser writes the page. When the title is a directory, git is asked
// about it, so a terminal parked in a repo shows the branch and how far off
// clean it is.
//
// The lane (PLAN M3, island-modes 5.4, 5.5, 7.3): `lane` is what the island
// draws, short by rule: an app or repo name, the branch and how many files
// differ. A browser shows its app's name, never the page's title [GUESS:
// island-modes 5.5 leaves the browser's source as NEEDS CHECK and the
// Island board draws the page's domain; the title can say anything, and the
// domain is not in it]. To get there the focused window is resolved to a
// directory, once per window and title (debounced, cached):
//   - in tmux (every Ghostty window here: the title is tmux's "#T - #W"),
//     `tmux list-clients` names the client whose title it is, so its pane
//     and the pane's directory; an agent in that pane (Crew, from fleet)
//     gives its product name and fleet's `project` as the directory;
//   - an agent outside tmux: walk /proc up from each agent pid the Crew
//     scan knows to the window's pid (one Ghostty process owns every
//     window, so this only settles it when one agent descends from it) and
//     read that agent's cwd;
//   - a bare shell names the window after its directory.
// Then `git rev-parse --show-toplevel` and `git status` run for that
// directory, cached per directory, at most once per 5 s while it is in
// front, only in island mode (nothing else draws the lane), and only while
// an island is drawing it with the session awake (watch(): rest or hover,
// not idle; M3 review), always with --no-optional-locks. The poll reuses the
// cached toplevel, so it is one `git status`, and skips a directory known
// to be outside a repo. A Hyprland event or a spinner turning never spawns
// anything by itself.
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "lib/CrewModel.js" as CrewModel

Singleton {
    id: root

    readonly property var toplevel: ToplevelManager.activeToplevel
    readonly property string app: root.toplevel?.appId ?? ""
    readonly property string title: root.toplevel?.title ?? ""

    readonly property var agentMatch: root.agentParts(root.title)
    readonly property bool isAgent: root.agentMatch !== null
    readonly property bool isPath: root.looksLikePath(root.title)

    // "" | "agent" | "terminal" | "browser" | "editor" | "music" | "other"
    readonly property string kind: root.classify(root.app, root.isAgent)

    readonly property bool active: root.kind !== "" && root.text !== ""

    // ---- the reading, as functions so tests/check.qml can drive them --------

    function classify(app: string, agent: bool): string {
        if (app === "") return "";
        const a = app.toLowerCase();
        if (/ghostty|wezterm|kitty|alacritty|foot|terminal/.test(a)) return agent ? "agent" : "terminal";
        if (/chrom|helium|brave|vivaldi|firefox|zen|librewolf|floorp|epiphany/.test(a)) return "browser";
        if (/code|vscodium|zed|neovide/.test(a)) return "editor";
        if (/spotify|rhythmbox|music|mpv|vlc/.test(a)) return "music";
        return "other";
    }

    // Claude Code and its cousins prefix the title with a spinner glyph while
    // they work and a still one while they wait. The glyph is what gives them
    // away, and it is also worth showing: it turns as the agent thinks.
    function agentParts(title: string): var {
        return title.match(/^([◐-◓✳✱✻✽✶✢·∗*])\s+(.*)$/);
    }

    // A shell sitting in a directory names the window after it.
    function looksLikePath(title: string): bool {
        return /^(\/|~)/.test(title);
    }

    // "Page title - Helium", "Page — Mozilla Firefox": the suffix is the app,
    // which the glyph already says.
    function pageTitle(title: string): string {
        return title.replace(/\s+[-–—]\s+[^-–—]+$/, "");
    }

    function shortPath(p: string): string {
        const home = Quickshell.env("HOME");
        if (p === home) return "~";
        return p.indexOf(home + "/") === 0 ? "~" + p.slice(home.length) : p;
    }

    // ---- the lane, as pure functions (tests/check.qml) ----------------------

    // The title without an agent's spinner, so a glyph turning is no change.
    function stableTitle(title: string): string {
        return root.agentParts(title)?.[2] ?? title;
    }

    // "/home/nick/Developer/dotfiles" -> "dotfiles"; home itself -> "~".
    function baseName(path: string): string {
        const home = Quickshell.env("HOME");
        const p = String(path ?? "").replace(/\/+$/, "");
        if (p === "") return "";
        if (p === home || p === "~") return "~";
        return p.slice(p.lastIndexOf("/") + 1);
    }

    // "~/x" -> "$HOME/x"
    function expand(path: string): string {
        const p = String(path ?? "");
        return p === "~" || p.indexOf("~/") === 0 ? Quickshell.env("HOME") + p.slice(1) : p;
    }

    // A desktop entry's name, else the app id made readable:
    // "com.mitchellh.ghostty" -> "Ghostty", "brave-origin" -> "Brave Origin".
    function appName(app: string, entryName: string): string {
        if (entryName) return entryName;
        const last = String(app ?? "").split(".").pop();
        return last.split(/[-_ ]+/).filter(w => w !== "").map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(" ");
    }

    // tmux clients, one per line: pane id, pane directory, the title tmux
    // gives the terminal ("#T - #W"). The one whose title this is, or null.
    function clientFor(title: string, lines: var): var {
        const want = root.stableTitle(title);
        for (const line of lines || []) {
            const f = String(line).split("\t");
            if (f.length >= 3 && root.stableTitle(f.slice(2).join("\t")) === want) return { pane: f[0], path: f[1] };
        }
        return null;
    }

    // The Crew agent a window shows: the one in `pane`, else a tmux agent
    // whose label and window name the title carries (fleet may cut a long
    // label with "…"). null when none or several.
    function agentFor(title: string, pane: string, agents: var): var {
        const list = agents || [];
        if (pane) {
            const byPane = list.find(a => a.pane === pane);
            if (byPane) return byPane;
        }
        const t = root.stableTitle(title);
        const hits = list.filter(a => {
            if (a.host !== "tmux" || !a.label) return false;
            const label = String(a.label).replace(/…$/, "");
            const tail = a.window ? " - " + a.window : "";
            return t.indexOf(label) >= 0 && (tail === "" || t.slice(-tail.length) === tail);
        });
        return hits.length === 1 ? hits[0] : null;
    }

    // "main +2": the branch and how many files differ from HEAD (staged,
    // unstaged and untracked), the count left out when clean.
    function branchText(branch: string, dirty: int): string {
        if (!branch) return "";
        return dirty > 0 ? `${branch} +${dirty}` : branch;
    }

    // What the lane draws, from what was resolved. `w`:
    //   kind      classify()
    //   title     the window title
    //   appName   appName()
    //   agent     the Crew record for it, or null
    //   cwd, top  the directory and its git toplevel ("" outside a repo)
    //   branch, dirty
    //   track     the playing track's title, for a music app
    // Returns { kind, icon, text, extra, working, who, where, detail }:
    // `extra` is the rest pill's ("main +2" for a terminal, island-modes 5.5),
    // who/where/detail the hover's Context line (7.3).
    function laneFor(w: var): var {
        const kind = w?.kind ?? "";
        if (kind === "") return { kind: "", icon: "", text: "", extra: "", working: false, who: "", where: "", detail: "" };
        const app = w.appName || "";
        const where = w.top ? root.baseName(w.top) : w.cwd ? root.baseName(w.cwd) : "";
        const detail = w.top ? root.branchText(w.branch ?? "", w.dirty ?? 0) : "";
        if (kind === "agent") {
            const glyph = root.agentParts(w.title ?? "")?.[1] ?? "";
            const mood = w.agent?.mood ?? "";
            const who = w.agent ? CrewModel.kindName(w.agent.kind) : "Agent";
            return {
                kind: kind, icon: "sparkle", text: where || who, extra: "",
                // The feed's word when it has one, else the glyph: ✳ is the still one.
                working: mood !== "" ? mood === "working" : glyph !== "" && glyph !== "✳",
                who: who, where: where, detail: detail
            };
        }
        if (kind === "terminal") {
            // A program the shell runs names the window ("nvim notes.md"):
            // its first word, when no directory is known.
            const command = root.stableTitle(w.title ?? "").split(/\s+/)[0] || app;
            return { kind: kind, icon: "terminal", text: where || command, extra: detail, working: false, who: app, where: where, detail: detail };
        }
        if (kind === "music") {
            const text = w.track || app;
            return { kind: kind, icon: "music", text: text, extra: "", working: false, who: app, where: w.track ? text : "", detail: "" };
        }
        // Browsers, editors, anything else: the app's name. A browser's title
        // is the page, which can say anything [GUESS, see the header: the
        // board draws the domain, which the title does not carry].
        return { kind: kind, icon: kind === "browser" ? "globe" : "window", text: app, extra: "", working: false, who: app, where: "", detail: "" };
    }

    function describe(kind: string, title: string, nowPlaying: string): string {
        switch (kind) {
        case "agent":    return root.agentParts(title)?.[2] ?? title;
        case "terminal": return root.looksLikePath(title) ? root.shortPath(title) : title;
        case "browser":  return root.pageTitle(title);
        case "music":    return nowPlaying !== "" ? nowPlaying : title;
        default:         return title;
        }
    }

    // ---- what the lane draws -----------------------------------------------
    // The agent's glyph comes from the title and is set in the text font; every
    // other kind gets the same Nerd Font glyph the workspace pills use.
    readonly property string glyph: root.isAgent ? root.agentMatch[1] : Icons.forClass(root.app)

    readonly property string nowPlaying: {
        const p = Media.player;
        if (!p?.isPlaying || !p.trackTitle) return "";
        return p.trackArtist ? `${p.trackArtist} – ${p.trackTitle}` : p.trackTitle;
    }

    readonly property string text: root.describe(root.kind, root.title, root.nowPlaying)

    // The branch, and how far off clean, when a terminal is parked in a repo.
    readonly property string detail: {
        if (root.branch === "") return "";
        const bits = [root.branch];
        if (root.dirty > 0) bits.push(`±${root.dirty}`);
        if (root.ahead > 0) bits.push(`↑${root.ahead}`);
        if (root.behind > 0) bits.push(`↓${root.behind}`);
        return bits.join(" ");
    }

    // ---- resolving the window to a directory ---------------------------------

    // Only the island draws the lane.
    readonly property bool wanted: Prefs.barMode === "island"
    // The islands drawing it now (rest or hover, the session not idle):
    // IslandView calls watch(). The git poll runs only while one does.
    property var watchers: []
    readonly property bool watched: root.watchers.length > 0
    function watch(owner, on: bool): void {
        const has = root.watchers.indexOf(owner) >= 0;
        if (on === has) return;
        root.watchers = on ? root.watchers.concat([owner]) : root.watchers.filter(o => o !== owner);
    }
    // Back from idle (or from a panel): a fresh look if the cache is stale.
    onWatchedChanged: if (root.watched && root.wanted && root.cwd !== "") root.askGit(false)
    // The focused window's pid (Hyprland), for the /proc walk.
    readonly property int pid: Hyprland.activeToplevel?.lastIpcObject?.pid ?? 0
    readonly property string appLabel: root.appName(root.app, root.app !== "" ? (DesktopEntries.heuristicLookup(root.app)?.name ?? "") : "")
    // What a lookup is keyed on: a spinner turning is not a new window.
    readonly property string windowKey: root.app + "\n" + root.stableTitle(root.title)

    // What the last lookup found for windowKey.
    property string resolvedKey: ""
    property string cwd: ""
    property var agent: null
    property string top: ""

    // The legacy reading: a terminal whose title is its directory.
    readonly property string repoDir: root.kind === "terminal" && root.isPath
        ? root.title.replace(/^~/, Quickshell.env("HOME")) : ""

    // While a terminal or agent window is being looked up (the 350 ms
    // settle, tmux, then git's first answer for a new directory), the lane
    // keeps what it last showed, so a focus change does not flash the
    // shell's name or the folder's before the repo's.
    readonly property bool resolving: (root.kind === "terminal" || root.kind === "agent")
        && (root.resolvedKey !== root.windowKey || (root.cwd !== "" && root.gitSeen[root.cwd] === undefined))
    property var heldLane: null
    readonly property var lane: root.resolving && root.heldLane !== null ? root.heldLane : root.liveLane
    onLiveLaneChanged: if (!root.resolving) root.heldLane = root.liveLane
    readonly property var liveLane: root.laneFor({
        kind: root.kind,
        title: root.title,
        appName: root.appLabel,
        agent: root.resolvedKey === root.windowKey ? root.agent : null,
        cwd: root.resolvedKey === root.windowKey ? root.cwd : "",
        top: root.resolvedKey === root.windowKey ? root.top : "",
        branch: root.branch,
        dirty: root.dirty,
        track: Media.player?.trackTitle ?? ""
    })

    // A window seen in the last few seconds resolves from the cache at once.
    onWindowKeyChanged: {
        if (!root.wanted) return;
        const hit = root.seen[root.windowKey];
        if (hit && Date.now() - hit.at < root.seenFor) {
            settle.stop();
            root.resolve();
        } else {
            settle.restart();
        }
    }
    onWantedChanged: if (root.wanted) settle.restart()
    // A focus change, then a title change as the shell redraws: one lookup.
    Timer {
        id: settle
        interval: 350
        onTriggered: root.resolve()
    }

    // window key -> { cwd, agentId, at } (ms), so flicking between windows
    // does not ask tmux again.
    property var seen: ({})
    readonly property int seenFor: 10000

    // Hyprland fills lastIpcObject (the pid) on a refresh; one is asked for
    // when an agent outside tmux needs it.
    property bool refreshed: false
    function resolve(): void {
        const key = root.windowKey;
        if (root.kind !== "terminal" && root.kind !== "agent") return root.found(key, "", null);
        const hit = root.seen[key];
        if (hit && Date.now() - hit.at < root.seenFor) return root.found(key, hit.cwd, CrewModel.find({ agents: Crew.agents }, hit.agentId) ?? null);
        if (/ - /.test(root.title)) {
            tmux.key = key;
            tmux.lines = [];
            tmux.running = true;
            return;
        }
        root.untmuxed(key);
    }

    // Outside tmux: a shell's directory title, or the /proc walk for an agent.
    function untmuxed(key: string): void {
        if (root.isPath) return root.found(key, root.expand(root.title), null);
        const pids = Crew.agents.filter(a => a.host !== "tmux" && Number(a.pid) > 0).map(a => String(a.pid));
        if (root.kind === "agent" && root.pid <= 0 && pids.length > 0 && !root.refreshed) {
            root.refreshed = true;
            Hyprland.refreshToplevels();
            settle.restart();
            return;
        }
        root.refreshed = false;
        if (root.kind === "agent" && root.pid > 0 && pids.length > 0) {
            walk.key = key;
            walk.lines = [];
            walk.command = ["sh", "-c", root.walkScript, "walk", String(root.pid)].concat(pids);
            walk.running = true;
            return;
        }
        root.found(key, "", null);
    }

    function found(key: string, dir: string, agent: var): void {
        if (key !== root.windowKey) return;
        // Only terminals and agents are looked up, so only they are cached,
        // and entries past seenFor go as the next one is written (M3 review:
        // the map grew by every window and page title seen).
        if (root.kind === "terminal" || root.kind === "agent") {
            const now = Date.now();
            const next = {};
            for (const k in root.seen)
                if (now - root.seen[k].at < root.seenFor) next[k] = root.seen[k];
            next[key] = { cwd: dir, agentId: agent?.id ?? "", at: now };
            root.seen = next;
        }
        root.agent = agent;
        root.resolvedKey = key;
        if (root.cwd !== dir) {
            root.cwd = dir;
            root.askGit(false);
        }
    }

    Process {
        id: tmux
        property string key: ""
        property var lines: []
        command: ["tmux", "list-clients", "-F", "#{pane_id}\t#{pane_current_path}\t#{pane_title} - #{window_name}"]
        stdout: SplitParser {
            onRead: line => tmux.lines.push(line)
        }
        onExited: (code, status) => {
            const client = code === 0 ? root.clientFor(root.title, tmux.lines) : null;
            if (!client) return root.untmuxed(tmux.key);
            const agent = root.agentFor(root.title, client.pane, Crew.agents);
            // fleet's project for a tmux agent; the pane's directory otherwise.
            root.found(tmux.key, agent?.project ? root.expand(agent.project) : client.path, agent);
        }
    }

    // argv: the window's pid, then candidate agent pids. Prints "pid<TAB>cwd"
    // for each agent whose ancestors include the window's process. The ppid is
    // /proc/<pid>/stat's 4th field, read after the last ") " because the
    // command name in field 2 may hold spaces.
    readonly property string walkScript: 'top=$1; shift; for p in "$@"; do q=$p; while [ "${q:-0}" -gt 1 ]; do '
        + 'if [ "$q" = "$top" ]; then printf "%s\\t%s\\n" "$p" "$(readlink "/proc/$p/cwd")"; break; fi; '
        + 'q=$(sed "s/.*) //" "/proc/$q/stat" 2>/dev/null | cut -d" " -f2); done; done'
    Process {
        id: walk
        property string key: ""
        property var lines: []
        stdout: SplitParser {
            onRead: line => walk.lines.push(line)
        }
        onExited: (code, status) => {
            // One agent under the window settles it; several (one Ghostty
            // process owns every window) do not.
            if (walk.lines.length !== 1) return root.found(walk.key, "", null);
            const f = String(walk.lines[0]).split("\t");
            const agent = Crew.agents.find(a => String(a.pid) === f[0]) ?? null;
            root.found(walk.key, f[1] ?? "", agent);
        }
    }

    // ---- git ---------------------------------------------------------------
    property string branch: ""
    property int dirty: 0
    property int ahead: 0
    property int behind: 0

    // directory -> { top, branch, dirty, ahead, behind, at } (ms).
    property var gitSeen: ({})
    readonly property int gitFor: 5000

    // A commit or a save does not change the title, so ask again on a slow
    // clock while a directory is in front.
    Timer {
        id: gitPoll
        interval: root.gitFor
        repeat: true
        running: root.wanted && root.watched && root.cwd !== ""
        onTriggered: root.askGit(true)
    }
    readonly property alias polling: gitPoll.running

    function show(r: var): void {
        root.top = r?.top ?? "";
        root.branch = r?.branch ?? "";
        root.dirty = r?.dirty ?? 0;
        root.ahead = r?.ahead ?? 0;
        root.behind = r?.behind ?? 0;
    }

    // From the cache when it is fresh, else one git run (never two at once:
    // the poll skips a beat while one is out, and a directory change waits
    // for it to finish).
    function askGit(poll): void {
        const dir = root.cwd;
        if (dir === "") return root.show(null);
        const hit = root.gitSeen[dir];
        if (hit) root.show(hit);
        else if (!poll) root.show(null);
        if (hit && !poll && Date.now() - hit.at < root.gitFor) return;
        // Outside a repo the poll has nothing to watch; the next look comes
        // with the next window (or once the cache is stale).
        if (poll && hit && hit.top === "") return;
        if (git.running) {
            git.again = true;
            return;
        }
        git.dir = dir;
        git.command = root.gitCommand(dir, hit?.top ?? "");
        git.pending = { top: hit?.top ?? "", branch: "", dirty: 0, ahead: 0, behind: 0, at: 0 };
        git.running = true;
    }

    // `rev-parse --show-toplevel` names the repo (exit 3 outside one), then
    // `status` reads it; with the toplevel already known, `status` alone.
    // --no-optional-locks: a plain `git status` refreshes .git/index under
    // index.lock, and a poll every 5 s would collide with git run by hand.
    function gitCommand(dir: string, top: string): var {
        const status = ["--no-optional-locks", "-C", top, "status", "--porcelain=v2", "--branch"];
        if (top !== "") return ["git"].concat(status);
        return ["sh", "-c", 'top=$(git -C "$1" rev-parse --show-toplevel 2>/dev/null) || exit 3; printf "# top %s\\n" "$top"; '
            + 'exec git --no-optional-locks -C "$top" status --porcelain=v2 --branch', "git", dir];
    }

    Process {
        id: git
        property string dir: ""
        property var pending: ({})
        property bool again: false

        // gitCommand(): set by askGit() for each run.

        // Porcelain v2: header lines start with "# ", every other line is one
        // path that differs from HEAD in some way.
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("# top ") === 0) {
                    git.pending.top = line.slice(6);
                } else if (line.indexOf("# branch.head ") === 0) {
                    git.pending.branch = line.slice(14);
                } else if (line.indexOf("# branch.ab ") === 0) {
                    const m = line.match(/\+(\d+) -(\d+)/);
                    if (m) { git.pending.ahead = parseInt(m[1]); git.pending.behind = parseInt(m[2]); }
                } else if (line !== "" && line[0] !== "#") {
                    git.pending.dirty += 1;
                }
            }
        }

        onExited: (code, status) => {
            const r = code === 0 ? git.pending : { top: "", branch: "", dirty: 0, ahead: 0, behind: 0 };
            if (r.branch === "(detached)") r.branch = "detached";
            r.at = Date.now();
            // Directories not seen for a minute go, the current one stays.
            const next = {};
            for (const d in root.gitSeen)
                if (d === root.cwd || r.at - root.gitSeen[d].at < 12 * root.gitFor) next[d] = root.gitSeen[d];
            next[git.dir] = r;
            root.gitSeen = next;
            if (git.dir === root.cwd) root.show(r);
            if (git.again || git.dir !== root.cwd) {
                git.again = false;
                Qt.callLater(() => root.askGit(false));
            }
        }
    }
}
