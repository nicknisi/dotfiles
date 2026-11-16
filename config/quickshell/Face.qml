pragma Singleton
// Face.qml - the profile picture: which file to draw, and setting it.
// (pragma Singleton stays above every brace, comments included: see Icons.qml.)
//
// Read by every place that draws the user's circle: the lock card
// (lock.qml, its own process), the control center's footer and the polkit
// prompt. lib/FaceModel.js has the rules: ~/.face, then
// /var/lib/AccountsService/icons/$USER, then the initial.
//
//   refresh()   one `sh` that checks the candidates are readable regular
//               files of 1 byte to 32 MiB (no FIFO, device, directory or
//               symlink loop reaches the image reader). Its answer is
//               `sources`/`urls`, the files to try in order;
//               Kit/FacePicture.qml decodes them asynchronously and falls
//               back to the initial. The main shell refreshes at startup,
//               after every set or clear, and when the control center or the
//               profile picture sheet opens; the lock once, when it starts.
//   probing     the main shell only (ShellServices): a hidden Image decodes
//               the sources too, so `kind` (face, system or "") says what
//               the circles show, for `face get` and the sheet. The lock
//               never probes: its card's own Image is the only decode there.
//   set(path)   checks the file the same way, decodes it, then copies it to
//               ~/.face atomically (lib/FaceModel.js setCommand) and
//               refreshes. Answers at once; `busy` and `error` follow it.
//   clear()     removes ~/.face and refreshes.
//
// The `face` IPC target (set PATH, clear, get) lives in ShellServices, so
// the lock instance, which loads this file too, registers none.
//
// Writes happen only outside a dry run: never under SHELL_DRY_RUN=1
// (tests/check.sh runs on the real home), and under SHELL_SANDBOX=1 only
// inside the sandbox guard with SHELL_FACE_HOME pointing at a scratch home
// (the shots). The sandbox guard also lets SHELL_FACE_HOME,
// SHELL_FACE_ICONS and SHELL_FACE_PICTURES stand in for the home, the
// AccountsService icons and ~/Pictures.
import Quickshell
import Quickshell.Io
import QtQuick
import "lib/FaceModel.js" as FaceModel

Singleton {
    id: root

    function env(name: string): string {
        const v = Quickshell.env(name);
        return v === undefined || v === null ? "" : String(v);
    }

    // lock.qml's guard: SHELL_SANDBOX=1 and SBX_RUNTIME equal to
    // XDG_RUNTIME_DIR (.shell-rebuild/tmp/sandbox.sh sets both).
    readonly property bool sandbox: env("SHELL_SANDBOX") === "1" && env("SBX_RUNTIME") !== "" && env("SBX_RUNTIME") === env("XDG_RUNTIME_DIR")
    readonly property string home: root.sandbox && env("SHELL_FACE_HOME") !== "" ? env("SHELL_FACE_HOME") : env("HOME")
    readonly property string iconsDir: root.sandbox && env("SHELL_FACE_ICONS") !== "" ? env("SHELL_FACE_ICONS") : "/var/lib/AccountsService/icons"
    readonly property string picturesDir: root.sandbox && env("SHELL_FACE_PICTURES") !== "" ? env("SHELL_FACE_PICTURES") : root.home + "/Pictures"
    readonly property string user: env("USER") || env("LOGNAME")
    readonly property string path: FaceModel.facePath(root.home)
    readonly property bool writable: env("SHELL_DRY_RUN") !== "1" && (env("SHELL_SANDBOX") !== "1" || (root.sandbox && env("SHELL_FACE_HOME") !== ""))

    readonly property var candidates: FaceModel.candidates(root.home, root.user, root.iconsDir)
    // The check's rows, [{ path, ok, why, size, mtime }].
    property var checked: []
    property bool checkedOnce: false
    // [{ kind, path, url }] that passed the check, in order; `urls` for
    // FacePicture's `sources`.
    readonly property var sources: FaceModel.sources(root.candidates, root.checked)
    readonly property var urls: root.sources.map(s => s.url)

    // ---- the probe (main shell) ---------------------------------------------------
    property bool probing: false
    property int probeIndex: 0
    // What the circles show once decoded: "face", "system" or "" (the
    // initial); "" while unknown.
    readonly property string kind: root.probing && probe.status === Image.Ready ? (root.sources[root.probeIndex]?.kind ?? "") : ""
    readonly property string shownPath: root.probing && probe.status === Image.Ready ? (root.sources[root.probeIndex]?.path ?? "") : ""
    onSourcesChanged: root.probeIndex = 0
    Image {
        id: probe
        visible: false
        asynchronous: true
        cache: false
        sourceSize: Qt.size(88, 88)
        source: root.probing && root.probeIndex < root.sources.length ? root.sources[root.probeIndex].url : ""
        onStatusChanged: if (status === Image.Error) root.probeIndex++
    }

    // ---- checking ---------------------------------------------------------------------
    property bool recheck: false
    function refresh(): void {
        if (check.running) {
            root.recheck = true;
            return;
        }
        check.command = FaceModel.checkCommand(root.candidates.map(c => c.path), FaceModel.MAX_BYTES);
        check.running = true;
    }
    Process {
        id: check
        stdout: StdioCollector {
            onStreamFinished: {
                // Only a real change reaches the circles: a refresh that finds
                // the same files leaves `sources` (and every decode) alone.
                const rows = FaceModel.parseCheck(text);
                if (JSON.stringify(rows) !== JSON.stringify(root.checked)) root.checked = rows;
                root.checkedOnce = true;
            }
        }
        onExited: {
            if (!root.recheck) return;
            root.recheck = false;
            root.refresh();
        }
    }

    // ---- setting ----------------------------------------------------------------------
    property bool busy: false
    property string error: ""
    // The last write asked for, "set PATH" or "clear", for tests and the
    // sandbox (also under a dry run, which writes nothing).
    property string lastRun: ""
    property string pending: ""

    function fail(why: string): void {
        root.error = why;
        root.busy = false;
        root.pending = "";
        setProbe.source = "";
        console.warn("face: " + why);
    }

    function set(src: string): string {
        const why = FaceModel.setError(src, root.home);
        if (why !== "") return "error: " + why;
        if (root.busy) return "error: busy";
        root.error = "";
        root.lastRun = "set " + src;
        if (!root.writable) return "ok: dry run, nothing written";
        root.busy = true;
        root.pending = FaceModel.cleanPath(src);
        setCheck.command = FaceModel.checkCommand([root.pending], FaceModel.MAX_BYTES);
        setCheck.running = true;
        return "ok: setting " + root.pending;
    }
    function clear(): string {
        if (root.busy) return "error: busy";
        root.error = "";
        root.lastRun = "clear";
        if (!root.writable) return "ok: dry run, nothing removed";
        if (root.path === "") return "error: no home directory";
        root.busy = true;
        remover.command = FaceModel.clearCommand(root.home);
        remover.running = true;
        return "ok";
    }
    function report(): var {
        const r = FaceModel.report({ kind: root.kind, path: root.shownPath, busy: root.busy, error: root.error, checked: root.checked });
        r.checking = check.running || (root.probing && probe.status === Image.Loading);
        r.writable = root.writable;
        r.lastRun = root.lastRun;
        // The picker's last listing (names only, newest first), once listed.
        r.pictures = root.picturesLoaded ? (root.pictures ?? []).map(p => p.name) : null;
        return r;
    }

    // 1. The same file checks as the lock's.
    Process {
        id: setCheck
        stdout: StdioCollector {
            onStreamFinished: {
                const row = FaceModel.parseCheck(text)[0];
                if (!row) return root.fail("could not check " + root.pending);
                if (!row.ok) return root.fail(row.path + ": " + ({ missing: "no such file", type: "not a regular file", unreadable: "not readable", empty: "empty", large: "larger than 32 MiB" }[row.why] ?? row.why));
                setProbe.source = FaceModel.fileUrl(row.path, row.mtime + "-" + row.size);
            }
        }
    }
    // 2. It decodes as an image.
    Image {
        id: setProbe
        visible: false
        asynchronous: true
        cache: false
        sourceSize: Qt.size(88, 88)
        onStatusChanged: {
            if (!root.busy || source == "") return;
            if (status === Image.Error) {
                root.fail(root.pending + ": not an image");
            } else if (status === Image.Ready) {
                setProbe.source = "";
                copier.command = FaceModel.setCommand(root.pending, root.home);
                copier.running = true;
            }
        }
    }
    // 3. The atomic copy.
    Process {
        id: copier
        stderr: StdioCollector {
            id: copierErr
        }
        onExited: code => {
            if (code !== 0) return root.fail(copierErr.text.trim() || "copy failed (" + code + ")");
            root.busy = false;
            root.pending = "";
            root.refresh();
        }
    }
    Process {
        id: remover
        stderr: StdioCollector {
            id: removerErr
        }
        onExited: code => {
            if (code !== 0) return root.fail(removerErr.text.trim() || "remove failed (" + code + ")");
            root.busy = false;
            root.refresh();
        }
    }

    // ---- the picker's listing -------------------------------------------------------------
    // ~/Pictures' images, newest first (FaceModel.parseList), read when the
    // sheet shows.
    property var pictures: []
    property bool picturesLoaded: false
    function listPictures(): void {
        if (lister.running) return;
        lister.command = FaceModel.listCommand(root.picturesDir);
        lister.running = true;
    }
    Process {
        id: lister
        stdout: StdioCollector {
            onStreamFinished: {
                root.pictures = FaceModel.parseList(text, root.picturesDir, FaceModel.LIST_LIMIT);
                root.picturesLoaded = true;
            }
        }
    }
}
