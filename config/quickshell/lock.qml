// lock.qml - the lock screen, a Quickshell instance of its own (PLAN M8,
// control-lock 4).
//
//   qs -n -p ~/.config/quickshell/lock.qml       (bin/shell-lock runs it)
//
// It is not part of shell.qml: the main shell hot-reloads on every save and a
// bar crash should not take the lock with it. This instance never reloads
// (settings.watchFiles false) and reads the same singletons by file path
// (Theme, Tokens, Motion, Media, Net).
//
// Security rules (tests/lock-machine.cjs, tests/lock-load.sh and
// .shell-rebuild/specs/shots/M8/lock-test.sh check them):
//   - One way to unlock: PAM answering Success to a conversation this lock
//     started (Lock/LockAuth.qml, lib/LockMachine.js). No IPC verb, signal or
//     environment variable unlocks, in or out of the sandbox. The `lock` IPC
//     target answers `secure` and `inspect` only.
//   - The session stays locked whatever else happens: Failed, MaxTries and
//     Error go back to the field; a crash, `qs kill`, SIGTERM or SIGKILL
//     leaves the compositor's lock in place (ext-session-lock-v1: a lock
//     client that dies without unlocking leaves the outputs locked). Nothing
//     here unlocks on destruction.
//   - Every output gets a surface, outputs added while locked included
//     (WlSessionLock builds one per screen, as screens come and go).
//   - No input reaches windows underneath: the compositor sends input only
//     to lock surfaces while locked.
//   - No screenshot: the surfaces draw the wallpaper file, the scrim and the
//     UI, nothing captured.
//   - The password lives in LockAuth's record only, is drawn as bullets, is
//     cleared on every way out of an attempt and is never logged.
//
// If the lock dies anyway, Hyprland shows its "lockscreen crashed" screen
// and the session stays locked. bin/shell-lock's watcher then starts a new
// lock, which takes the dead one over (misc:allow_session_lock_restore =
// true, PLAN DECISION 4); it tells a death from the unlock by SHELL_LOCK_DONE,
// a file this lock creates right after the one unlock (markUnlocked). If the
// crash screen stays, recover from a TTY: bin/shell-lock --help has the steps
// (relaunch the lock, or hl.clear_crashed_lockscreen()).
//
// Sandbox mode, for tests and shots only: SHELL_SANDBOX=1 and SBX_RUNTIME
// equal to XDG_RUNTIME_DIR (.shell-rebuild/tmp/sandbox.sh sets both; the real
// session sets neither). It changes three things:
//   - SHELL_LOCK_PAM_DIR and SHELL_LOCK_PAM_CONFIG may point PamContext at a
//     test PAM stack (pam_exec against a fixed test password), so the sandbox
//     test unlocks by typing, never with the real password or a verb;
//   - the `lockpose` IPC target can change what the card and pills draw (a
//     media fixture, a held shake frame) for screenshots. It moves no state
//     the unlock reads;
//   - Suspend, Reboot and Shut down log instead of running (also under
//     SHELL_DRY_RUN=1).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
import qs
import qs.Lock
import "lib/CcData.js" as CcData
import "lib/LockMachine.js" as LockMachine

ShellRoot {
    id: root

    settings.watchFiles: false

    function env(name: string): string {
        const v = Quickshell.env(name);
        return v === undefined || v === null ? "" : String(v);
    }

    readonly property bool sandbox: env("SHELL_SANDBOX") === "1" && env("SBX_RUNTIME") !== "" && env("SBX_RUNTIME") === env("XDG_RUNTIME_DIR")
    readonly property bool dryRun: root.sandbox || env("SHELL_DRY_RUN") === "1"

    // ---- who -------------------------------------------------------------------

    readonly property string user: env("USER") || env("LOGNAME")
    property string gecosName: ""
    property string gitName: ""
    // control-lock 4.5: GECOS is empty on milhouse, so git's user.name, then
    // the login name.
    readonly property string displayName: root.gecosName || root.gitName || root.user
    property string host: ""
    readonly property string sub: root.host !== "" ? root.user + " on " + root.host : root.user

    // ---- the main shell's bar --------------------------------------------------
    // The capsule springs from the island's rest pill only when the main shell
    // shows one (LockSurface.fromIsland, M10). Its Prefs keep the bar mode in
    // capsule.json, in the state dir Quickshell names after the shell's path:
    // the md5 of <this dir>/shell.qml, beside this instance's own. Read once,
    // before the first frame (blockLoading), so the capsule starts where it
    // will move from. No file, or no mode in it: the island's spring, as
    // before M10.
    readonly property string shellPrefs: Quickshell.stateDir.replace(/[^\/]*$/, Qt.md5(Quickshell.shellDir + "/shell.qml")) + "/capsule.json"
    FileView {
        id: shellPrefsFile
        path: root.shellPrefs
        blockLoading: true
        printErrors: false
    }
    readonly property string barMode: {
        try {
            const mode = JSON.parse(shellPrefsFile.text() || "{}").barMode;
            return typeof mode === "string" ? mode : "";
        } catch (e) {
            return "";
        }
    }

    FileView {
        path: "/etc/passwd"
        onLoaded: {
            const lines = text().split("\n");
            for (const line of lines) {
                const f = line.split(":");
                if (f.length >= 5 && f[0] === root.user) {
                    root.gecosName = f[4].split(",")[0].trim();
                    break;
                }
            }
        }
    }
    Process {
        running: true
        command: ["git", "config", "--includes", "--global", "--get", "user.name"]
        stdout: StdioCollector {
            onStreamFinished: root.gitName = text.trim().split("\n")[0] ?? ""
        }
    }
    Process {
        running: true
        command: ["cat", "/proc/sys/kernel/hostname"]
        stdout: StdioCollector {
            onStreamFinished: root.host = text.trim()
        }
    }

    // ---- what the surfaces draw ----------------------------------------------------

    SystemClock {
        id: systemClock
        precision: SystemClock.Minutes
    }

    // The wallpaper hyprpaper shows: the `background` link beside colors.json
    // (~/.local/state/theme/current/background; a shot's private copy in the
    // sandbox).
    readonly property url wallpaper: {
        const p = Theme.colorsPath;
        const dir = p.slice(0, Math.max(0, p.lastIndexOf("/")));
        return dir !== "" ? "file://" + dir + "/background" : "";
    }

    readonly property var media: {
        if (root.pose?.media !== undefined) return CcData.mediaCard(root.pose.media);
        const p = Media.player;
        if (!p) return CcData.mediaCard(null);
        return CcData.mediaCard({
            title: p.trackTitle || p.identity || "",
            artist: p.trackArtist || "",
            playing: p.isPlaying === true,
            canPrevious: p.canGoPrevious !== false,
            canNext: p.canGoNext !== false
        });
    }

    readonly property var status: {
        if (root.pose?.status !== undefined) return root.pose.status;
        const b = UPower.displayDevice;
        const pct = b?.percentage ?? 0;
        const percent = Math.round(pct <= 1 ? pct * 100 : pct);
        const charging = b?.state === UPowerDeviceState.Charging;
        return {
            wifi: { present: Net.device !== null, radioOn: Net.radioOn, icon: Net.connected ? CcData.wifiIcon(Net.bars) : "wifiOff" },
            battery: { present: (b?.isPresent ?? false) && (b?.isLaptopBattery ?? true), percent: percent, icon: CcData.batteryIcon({ percent: percent, charging: charging, low: percent <= 20 && UPower.onBattery }) }
        };
    }

    // ---- which screen has the card -----------------------------------------------

    // The screen whose lock surface last took keyboard focus, and the focused
    // monitor when the lock started (the cursor's, in practice).
    property string focusedName: ""
    property string startName: ""
    readonly property string primaryName: {
        const names = Quickshell.screens.map(s => s.name);
        for (const n of [root.focusedName, root.startName, "eDP-1"]) {
            if (n !== "" && names.indexOf(n) >= 0) return n;
        }
        return names.length > 0 ? names[0] : "";
    }
    Component.onCompleted: root.startName = String(Hyprland.focusedMonitor?.name ?? "")

    // ---- the lock ---------------------------------------------------------------------

    // Not `auth` or `clock`: LockSurface has properties by those names, and
    // inside it they would shadow these ids.
    LockAuth {
        id: lockAuth
        config: root.sandbox && root.env("SHELL_LOCK_PAM_CONFIG") !== "" ? root.env("SHELL_LOCK_PAM_CONFIG") : "hyprlock"
        configDirectory: root.sandbox && root.env("SHELL_LOCK_PAM_DIR") !== "" ? root.env("SHELL_LOCK_PAM_DIR") : "/etc/pam.d"
    }

    // The content is in. False at first, so every surface paints its start
    // state (`darker`, the capsule at the island's 360) into the frame the
    // compositor commits the lock with; true once the lock is secure, which
    // runs the lock-in motion (control-lock 4.8: the wallpaper fades in, the
    // capsule springs 360 -> 96, the clock, card and pills arrive). False
    // again once PAM said Success, for the leave motion. A surface built
    // while shown is already true (an output added while locked) shows at
    // once. Never declare it true: Kit/Layer shows a layer that is current
    // at creation without the enter rule (M8 review).
    property bool shown: false
    function arrive() {
        if (!lockAuth.unlocking) root.shown = true;
    }
    // A compositor slow to confirm still gets the content (offscreen, where
    // it never confirms, too); bin/shell-lock stops a lock that is not
    // secure after 2 s anyway.
    Timer {
        interval: 1000
        running: true
        onTriggered: root.arrive()
    }
    // Every screen's LockSurface, for inspect(). Kept by identity, with the
    // screen's name read when asked: a surface can be built before its screen
    // is set, and an old one can go after its replacement came.
    property var views: []
    function register(view) {
        if (root.views.indexOf(view) < 0) root.views = root.views.concat([view]);
    }
    function unregister(view) {
        root.views = root.views.filter(v => v !== view);
    }
    property string lastAction: ""

    Connections {
        target: lockAuth
        function onUnlockingChanged() {
            if (!lockAuth.unlocking) return;
            root.shown = false;
            leave.restart();
        }
    }

    // The leave rule's longest part (the capsule's spring back to 360), then
    // the one unlock.
    Timer {
        id: leave
        interval: Math.max(Motion.exitFade, Motion.spatial)
        onTriggered: {
            if (!lockAuth.unlocking) return;
            lock.locked = false;
            lockAuth.wipe();
            root.markUnlocked();
            quit.start();
        }
    }

    WlSessionLock {
        id: lock
        locked: true

        // `locked` notifies through lockStateChanged (onLockedChanged never
        // runs). Unlocked for any reason: the buffer goes. A lock the
        // compositor never granted (no ext-session-lock, as offscreen) stays
        // up for bin/shell-lock's timeout to end it.
        onLockStateChanged: {
            if (!lock.locked)
                lockAuth.wipe();
        }
        // Every output shows a lock surface's first frame: the content comes in.
        onSecureStateChanged: if (lock.secure) root.arrive()

        WlSessionLockSurface {
            id: surface
            color: Tokens.darker

            LockSurface {
                id: view
                anchors.fill: parent
                primary: screenName === root.primaryName
                wallpaper: root.wallpaper
                now: systemClock.date
                name: root.displayName
                sub: root.sub
                auth: root.pose?.auth !== undefined ? Object.assign(LockMachine.initial(), root.pose.auth) : lockAuth.m
                media: root.media
                status: root.status
                shown: root.shown
                fromIsland: root.barMode === "island" || root.barMode === ""
                shakeHold: root.pose?.shakeHold !== undefined ? Number(root.pose.shakeHold) : -1

                onWindowActiveChanged: if (windowActive && screenName !== "") root.focusedName = screenName
                onTyped: text => lockAuth.type(text)
                onErased: lockAuth.erase()
                onCleared: lockAuth.clear()
                onSubmitted: lockAuth.submit()
                onEscaped: lockAuth.clear()
                onMediaAction: name => root.mediaAction(name)
                onSuspendRequested: root.power("suspend")
                onPowerRun: id => root.power(id)

                readonly property string screenName: String(surface.screen?.name ?? "")
                Component.onCompleted: {
                    focusField();
                    root.register(view);
                }
                Component.onDestruction: root.unregister(view)
            }
        }
    }

    // bin/shell-lock's watcher relaunches a lock whose instance ends without
    // this file (it died locked). Created only here, after the one unlock.
    function markUnlocked() {
        const f = root.env("SHELL_LOCK_DONE");
        if (f !== "") Quickshell.execDetached(["touch", "--", f]);
    }

    // A short wait so the unlock reaches the compositor, then this instance
    // ends (bin/shell-lock starts a fresh one for the next lock, and its
    // `qs -n` would refuse while this one lingers). Qt.quit() does not end a
    // Quickshell instance; `qs kill` on its own pid does. Never while locked:
    // a lock instance that dies locked leaves the compositor's crash screen.
    Timer {
        id: quit
        interval: 200
        onTriggered: {
            if (lock.locked) return;
            Quickshell.execDetached(["qs", "kill", "--pid", String(Quickshell.processId)]);
        }
    }

    function mediaAction(name: string) {
        root.lastAction = "media " + name;
        if (root.dryRun || root.pose?.media !== undefined) return;
        const p = Media.player;
        if (!p) return;
        if (name === "previous" && p.canGoPrevious) p.previous();
        else if (name === "next" && p.canGoNext) p.next();
        else if (name === "toggle") p.togglePlaying();
    }

    // The lock's power menu: Suspend, Reboot and Shut down, nothing else.
    readonly property var commands: ({
        suspend: ["systemctl", "suspend"],
        reboot: ["systemctl", "reboot"],
        shutdown: ["systemctl", "poweroff"]
    })
    function power(id: string) {
        const cmd = root.commands[id];
        if (!cmd) return;
        root.lastAction = "power " + id;
        if (root.dryRun) {
            console.log("lock: dry run:", cmd.join(" "));
            return;
        }
        Quickshell.execDetached(cmd);
    }

    // ---- IPC ----------------------------------------------------------------------------

    // bin/shell-lock asks `secure` until the compositor has committed the lock.
    // Nothing here changes the lock.
    IpcHandler {
        target: "lock"
        function secure(): bool {
            return lock.secure;
        }
        function inspect(): string {
            return JSON.stringify({
                locked: lock.locked,
                secure: lock.secure,
                sandbox: root.sandbox,
                phase: lockAuth.m.phase,
                attempts: lockAuth.m.attempts,
                screens: Quickshell.screens.map(s => s.name),
                primary: root.primaryName,
                pam: { config: lockAuth.config, sandboxDir: root.sandbox && lockAuth.configDirectory !== "/etc/pam.d" },
                // How many characters are typed, for the sandbox test only.
                typed: root.sandbox ? lockAuth.m.buffer.length : -1,
                last: root.lastAction,
                // Where the parts sit on the primary screen, logical px, for
                // the sandbox shots only: they include the bullet count.
                parts: root.sandbox ? root.parts() : null,
                // The main shell's bar mode (M10: the capsule springs from
                // the island only in island mode).
                barMode: root.barMode,
                surfaces: root.views.map(v => ({ screen: v.screenName, primary: v.primary, width: v.width, height: v.height, fromIsland: v.fromIsland }))
            });
        }
    }

    function box(item, view) {
        if (!item || !item.visible) return null;
        const p = item.mapToItem(view, 0, 0);
        return { x: Math.round(p.x * 100) / 100, y: Math.round(p.y * 100) / 100, width: item.width, height: item.height };
    }
    function parts() {
        const v = root.views.find(w => w.primary);
        if (!v) return null;
        return {
            card: box(v.card, v),
            field: box(v.card.field, v),
            unlock: box(v.card.unlockButton, v),
            hint: box(v.card.hintText, v),
            capsule: box(v.capsule, v),
            clock: box(v.clock, v),
            media: box(v.mediaPill, v),
            play: box(v.mediaPill.playButton, v),
            status: box(v.statusPill, v),
            suspend: box(v.statusPill.suspendButton, v),
            power: v.powerOpen ? box(v.powerMenu, v) : null,
            shake: v.card.shakeOffset,
            fieldRing: String(v.card.field.border.color),
            fieldFocus: v.card.field.activeFocus,
            fieldKeyboard: v.card.field.keyboardHere,
            hintText: v.card.hintText.text,
            bullets: v.card.field.length,
            // The lock-in motion, for the sandbox test's samples.
            shown: v.shown,
            cardOpacity: v.card.parent.opacity,
            wallOpacity: v.wall.opacity,
            // M10: outside island mode the capsule fades in place.
            capsuleOpacity: v.capsule.opacity
        };
    }

    // Display overrides for sandbox screenshots: { auth: {...}, media: {...},
    // status: {...}, shakeHold: n }. What the surfaces draw only: the unlock
    // reads lockAuth.unlocking, which this never touches.
    property var pose: null
    IpcHandler {
        target: "lockpose"
        enabled: root.sandbox
        function pose(json: string): string {
            if (!root.sandbox) return "error: sandbox only";
            try {
                const p = JSON.parse(json);
                root.pose = p && typeof p === "object" ? p : null;
                return "ok";
            } catch (e) {
                return "error: " + e;
            }
        }
        function clear(): void {
            root.pose = null;
        }
    }
}
