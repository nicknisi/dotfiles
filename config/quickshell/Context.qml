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
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

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

    // ---- git ---------------------------------------------------------------
    property string branch: ""
    property int dirty: 0
    property int ahead: 0
    property int behind: 0

    readonly property string repoDir: root.kind === "terminal" && root.isPath
        ? root.title.replace(/^~/, Quickshell.env("HOME")) : ""

    onRepoDirChanged: root.askGit()

    // A commit or a save does not change the title, so ask again on a slow
    // clock while a repo is in front.
    Timer {
        interval: 5000
        repeat: true
        running: root.repoDir !== ""
        onTriggered: root.askGit()
    }

    function askGit(): void {
        if (root.repoDir === "") {
            root.branch = ""; root.dirty = 0; root.ahead = 0; root.behind = 0;
            return;
        }
        if (git.running) return;
        git.pendingBranch = ""; git.pendingDirty = 0; git.pendingAhead = 0; git.pendingBehind = 0;
        git.running = true;
    }

    Process {
        id: git
        property string pendingBranch: ""
        property int pendingDirty: 0
        property int pendingAhead: 0
        property int pendingBehind: 0

        command: ["git", "-C", root.repoDir, "status", "--porcelain=v2", "--branch"]

        // Porcelain v2: header lines start with "# ", every other line is one
        // path that differs from HEAD in some way.
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("# branch.head ") === 0) {
                    git.pendingBranch = line.slice(14);
                } else if (line.indexOf("# branch.ab ") === 0) {
                    const m = line.match(/\+(\d+) -(\d+)/);
                    if (m) { git.pendingAhead = parseInt(m[1]); git.pendingBehind = parseInt(m[2]); }
                } else if (line !== "" && line[0] !== "#") {
                    git.pendingDirty += 1;
                }
            }
        }

        onExited: (code, status) => {
            if (code !== 0) { root.branch = ""; root.dirty = 0; root.ahead = 0; root.behind = 0; return; }
            root.branch = git.pendingBranch === "(detached)" ? "detached" : git.pendingBranch;
            root.dirty = git.pendingDirty;
            root.ahead = git.pendingAhead;
            root.behind = git.pendingBehind;
        }
    }
}
