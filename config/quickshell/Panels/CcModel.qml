import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.SystemTray
import QtQuick
import qs
import "../lib/CcData.js" as CcData

// CcModel.qml - the live side of the control center (PLAN M6): gathers the
// services into lib/CcData.js's plain shape (or takes a fixture's `cc`) and
// does what ControlCenter's action(name, arg) asks.
//
// What each press does (control-lock 2.3 to 2.8):
//   tile wifi      Networking.wifiEnabled
//   tile bt        Bt.adapter.enabled (not while it settles)
//   tile ts        Tailscale.toggle() (opens the login page when it needs one)
//   tile dnd       NotificationState.dnd, the flag the toasts, the server and
//                  the island read (persisted through Prefs.dnd)
//   level volume   Audio.setVolume(Audio.sink, v); its icon mutes
//   level light    brightnessctl set N% (N >= 1), 80 ms debounce (HudHome)
//   media          Media.player previous / togglePlaying / next, seek, cycle
//   mini awake     Caffeine.start(selected) / stop()
//   mini theme     the host's openThemes() when it has one (the island: the
//                  themes picker in place, M7); else closes, then
//                  `theme picker themes`
//   mini record    closes, then `capture record region` (Stop while recording)
//   mini clipboard the host's openClipboard() when it has one (the island: the
//                  palette's clipboard scope, from cc straight to the launcher
//                  state); else closes, then the clipboard IPC's open (as
//                  Super+V does)
//   notes          NotificationState.clear(); a row focuses its sender and
//                  closes when that worked
//   battery        hands off to the old Hud's battery page (the charge-limit
//                  top-up has nowhere else to live until M10)
//   lock           closes, then `loginctl lock-session`
//   power          the island's power state
//   tray           left: activate (or the menu of a menu-only item), right:
//                  its menu as the Tray sheet, middle: secondary, wheel: scroll
//
// `dryRun` (the sandbox, SHELL_DRY_RUN=1, or a fixture's `cc`) keeps every
// press from reaching a service or a process: the press is logged in `last`
// and only what happens to the island (close, power, a sheet) goes ahead.
//
// Signals for the host: close() (back to rest), power(), handOff(page) (an
// old Hud page) and sheet(name, props).
//
// Only while the cc state shows (`active`) does any of this follow the
// services: closed, `live`, `media` and `home` read nothing, and `home` keeps
// the last picture it drew (so the layer fading out does not change under
// it). A volume key, a battery tick or a rescan costs the closed control
// center nothing (M6 review).
Item {
    id: model

    // The cc state is showing.
    property bool active: false
    property var monitor: null
    property date now: new Date()
    readonly property var fixture: Fixture.data.cc
    property bool dryRun: Fixture.dryRun || model.fixture !== undefined
    // The last press, as "name arg", for tests and the sandbox.
    property string last: ""
    // The host's way to the launcher's clipboard scope, or null (CcLayer).
    property var openClipboard: null
    // The host's way to the themes picker in place, or null (CcLayer).
    property var openThemes: null

    signal close
    signal power
    signal handOff(string page)
    signal sheet(string name, var props)

    readonly property string screenName: String(model.monitor?.name ?? "")

    // ---- data -----------------------------------------------------------------

    // Polled while the card shows: MPRIS does not notify position.
    property int mediaTick: 0
    Timer {
        interval: 1000
        repeat: true
        running: model.active && (Media.player?.isPlaying ?? false) && Fixture.data.media === undefined
        onTriggered: model.mediaTick++
    }
    readonly property var media: {
        if (!model.active) return null;
        if (Fixture.data.media !== undefined) return Fixture.data.media;
        void model.mediaTick;
        const p = Media.player;
        if (!p) return null;
        return {
            title: p.trackTitle || p.identity || "",
            artist: p.trackArtist || "",
            playing: p.isPlaying === true,
            canPrevious: p.canGoPrevious !== false,
            canNext: p.canGoNext !== false,
            canSeek: p.canSeek === true && p.positionSupported === true,
            position: p.positionSupported ? p.position : 0,
            length: p.lengthSupported ? p.length : 0,
            artUrl: p.trackArtUrl || ""
        };
    }

    // The panel's rate and scale, from `display-mode json` each time it opens.
    property var display: ({})
    onActiveChanged: if (active && !model.fixture) displayQuery.refresh()
    Process {
        id: displayQuery
        stdout: StdioCollector { id: displayOut }
        function refresh() {
            if (running || model.screenName === "") return;
            command = ["display-mode", "json", model.screenName];
            running = true;
        }
        onExited: code => {
            if (code !== 0) return;
            try {
                model.display = JSON.parse(displayOut.text.trim());
            } catch (e) {
                model.display = {};
            }
        }
    }

    readonly property var tray: SystemTray.items.values

    readonly property var live: {
        if (!model.active) return null;
        const sink = Audio.sink;
        const history = [];
        const list = NotificationState.history;
        for (let i = 0; i < Math.min(2, list.count); i++) {
            const n = list.get(i);
            history.push({ summary: n.summary, appName: n.appName, body: n.body, created: n.created, critical: n.critical });
        }
        return {
            wifi: { present: Net.device !== null, radioOn: Net.radioOn, connected: Net.connected, ssid: Net.ssid, busy: Net.network ? Net.busy(Net.network) === true : false },
            bt: { present: Bt.present, enabled: Bt.enabled, settling: Bt.settling, device: Bt.primary ? Bt.labelFor(Bt.primary) : "" },
            tailscale: { installed: Tailscale.installed, running: Tailscale.running, needsLogin: Tailscale.needsLogin, busy: Tailscale.busy, state: Tailscale.stateText },
            dnd: NotificationState.dnd,
            volume: { value: Audio.volume, muted: Audio.muted, present: sink !== null, device: sink ? CcData.outputName({ name: sink.name, description: Audio.labelFor(sink), props: sink.properties }) : "No output" },
            brightness: { value: Backlight.fraction, present: Backlight.max > 1 },
            awake: { active: Caffeine.active, label: Caffeine.durationLabel(Caffeine.selectedMinutes) },
            hz: Number(model.display.current?.hz) || 0,
            scale: Number(model.display.current?.scale) || 0,
            theme: Theme.name,
            recording: Capture.recording,
            notifications: history,
            count: NotificationState.count,
            user: Quickshell.env("USER") || "",
            battery: { present: Battery.present, percent: Battery.percent, charging: Battery.charging, pluggedIn: Battery.pluggedIn, low: Battery.low },
            tray: model.tray.map(t => ({ id: t.id, title: t.tooltipTitle || t.title || t.id, icon: t.icon, passive: t.status === Status.Passive }))
        };
    }
    // A fixture's `cc` stands in for the services (its `now` for the clock the
    // notification times count from); the theme stays the pack being shot.
    // The last picture drawn, for while it is closed.
    property var lastHome: CcData.home({}, 0, null)
    readonly property var home: model.active ? CcData.home(model.fixture ? Object.assign({ theme: Theme.name }, model.fixture) : model.live, Number(model.fixture?.now) || model.now.getTime(), model.media) : model.lastHome
    onHomeChanged: if (model.active) model.lastHome = model.home

    // ---- actions ----------------------------------------------------------------

    function exec(argv) {
        if (model.dryRun) return;
        Quickshell.execDetached(argv);
    }

    function run(name: string, arg): string {
        model.last = name + (arg === null || arg === undefined ? "" : " " + JSON.stringify(arg));
        switch (name) {
        case "tile": return model.toggleTile(arg.key, arg.on === true);
        case "level": return model.setLevel(arg.key, Number(arg.value) || 0);
        case "mute":
            if (arg === "volume" && !model.dryRun && Audio.sink?.audio) Audio.sink.audio.muted = !Audio.muted;
            return "ok";
        case "media": return model.mediaAction(String(arg));
        case "seek": {
            const p = Media.player;
            if (!model.dryRun && p && p.canSeek && p.lengthSupported) p.position = Math.max(0, Math.min(1, Number(arg) || 0)) * p.length;
            return "ok";
        }
        case "cycle":
            if (!model.dryRun) Media.selectNext();
            return "ok";
        case "mini": return model.miniAction(String(arg));
        case "clearNotes":
            if (!model.dryRun) NotificationState.clear();
            return "ok";
        case "openNote": {
            const n = NotificationState.history.count > arg ? NotificationState.history.get(arg) : null;
            if (!model.dryRun && n && NotificationState.focusSource(n.appName, n.desktopEntry)) model.close();
            return "ok";
        }
        case "battery":
            model.handOff("battery");
            return "ok";
        case "lock":
            model.close();
            model.exec(["loginctl", "lock-session"]);
            return "ok";
        case "power":
            model.power();
            return "ok";
        case "tray": return model.trayAction(arg.index, arg.button);
        case "trayScroll": {
            const item = model.tray[arg.index];
            if (!model.dryRun && item) item.scroll(Math.round((Number(arg.delta) || 0) / 120), false);
            return "ok";
        }
        }
        return "error: unknown action " + name;
    }

    function toggleTile(key: string, on: bool): string {
        if (model.dryRun) return "ok";
        if (key === "wifi") {
            if (Net.device) Networking.wifiEnabled = on;
        } else if (key === "bt") {
            if (Bt.adapter && !Bt.settling) Bt.adapter.enabled = on;
        } else if (key === "ts") {
            if (!Tailscale.busy) Tailscale.toggle();
        } else if (key === "dnd") {
            NotificationState.dnd = on;
        }
        return "ok";
    }

    // Brightness waits 80 ms for the drag to settle (HudHome's pattern).
    property int pendingBrightness: -1
    Timer {
        id: brightnessLater
        interval: 80
        onTriggered: {
            if (model.pendingBrightness < 1) return;
            model.exec(["brightnessctl", "set", model.pendingBrightness + "%"]);
            model.pendingBrightness = -1;
        }
    }
    function setLevel(key: string, value: real): string {
        if (key === "volume") {
            if (!model.dryRun) Audio.setVolume(Audio.sink, value);
        } else if (key === "brightness") {
            model.pendingBrightness = Math.max(1, Math.round(value * 100));
            brightnessLater.restart();
        }
        return "ok";
    }

    function mediaAction(action: string): string {
        const p = Media.player;
        if (model.dryRun || Fixture.data.media !== undefined || !p) return "ok";
        if (action === "previous" && p.canGoPrevious) p.previous();
        else if (action === "next" && p.canGoNext) p.next();
        else if (action === "toggle") p.togglePlaying();
        return "ok";
    }

    function miniAction(key: string): string {
        if (key === "awake") {
            if (!model.dryRun) Caffeine.active ? Caffeine.stop() : Caffeine.start(Caffeine.selectedMinutes);
        } else if (key === "theme") {
            // Only the island changes (the picker writes nothing until Enter).
            if (typeof model.openThemes === "function" && model.openThemes()) return "ok";
            model.close();
            model.exec(["theme", "picker", "themes"]);
        } else if (key === "record") {
            model.close();
            if (model.dryRun) return "ok";
            if (Capture.recording) Capture.stop();
            else model.exec(["capture", "record", "region"]);
        } else if (key === "clipboard") {
            // Only the island changes, so a dry run goes ahead too.
            if (typeof model.openClipboard === "function" && model.openClipboard()) return "ok";
            model.close();
            // What Super+V runs (hyprland.lua), so whichever surface owns the
            // clipboard (the picker today, the launcher scope after M5) opens.
            model.exec(["qs", "ipc", "call", "clipboard", "open", model.screenName]);
        }
        return "ok";
    }

    function trayAction(index: int, button: string): string {
        const item = model.tray[index];
        if (!item) return "error: no tray item " + index;
        if (button === "right" || (button === "left" && item.onlyMenu)) {
            if (item.hasMenu) model.sheet("tray", { item: item });
            return "ok";
        }
        if (model.dryRun) return "ok";
        if (button === "middle") {
            item.secondaryActivate();
        } else {
            item.activate();
            if (NotificationState.focusApp([item.title, item.tooltipTitle, item.id])) model.close();
        }
        return "ok";
    }
}
