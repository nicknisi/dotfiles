// CcData.js - what the control center and its sheets draw, from plain data
// (PLAN M6, control-lock 2 and 3).
//
// Panels/CcModel.qml and each live sheet gather their services into the plain
// shapes below (or read a fixture's, `Fixture.data.cc` and
// `Fixture.data.sheets.<name>`), and these functions turn them into the rows
// and labels the leaf components draw. No Qt here, so tests/cc-data.cjs pins
// every rule the spec gives (and every [GUESS] it fills in).
//
// home(src, now, media) -> { tiles, media, levels, minis, notes, footer }
//   src: { wifi: { present, radioOn, connected, ssid, busy },
//          bt: { present, enabled, settling, device },
//          tailscale: { installed, running, needsLogin, busy, state },
//          dnd, volume: { value, muted, device }, brightness: { value, present },
//          awake: { active, label }, hz, scale, theme, recording,
//          nightlight: { available, reason, on, temperature, schedule, from,
//                        to, until, overridden, message } (NightLight.qml),
//          notifications: [{ id, summary, appName, body, created, critical }],
//          count, user, battery: { present, percent, charging, pluggedIn, low },
//          tray: [{ id, title, icon, glyph, passive }] }
//   media: { title, artist, playing, position, length, canPrevious, canNext,
//            canSeek } or null (IslandView.media's shape plus the times).
//
// Sheets: each returns { status, switchOn, switchEnabled, hasSwitch, groups,
// footer, footerEnabled }. A group is { label, rows }; a row is
// { key, title, sub, icon, on, dim, bad, slider, trail, forget, inert, action,
// wrap, lines } (Panels/Sheets/SheetFrame.qml draws them; `action` says what
// a press does, and the sheet runs it against the live object behind `key`;
// `wrap` lets the sub run to `lines` lines, four when unset, instead of
// eliding on one).

var DAY = 86400000;

function text(v) {
    return v === undefined || v === null ? "" : String(v);
}
function num(v, fallback) {
    var n = Number(v);
    return isFinite(n) ? n : fallback;
}
function clamp01(v) {
    return Math.max(0, Math.min(1, num(v, 0)));
}

// "now", "2m", "3h", "1d" since `created` (ms) [GUESS, control-lock 2.7].
function ago(created, now) {
    var t = num(created, 0);
    if (!(t > 0)) return "";
    var m = Math.floor(Math.max(0, num(now, 0) - t) / 60000);
    if (m < 1) return "now";
    if (m < 60) return m + "m";
    var h = Math.floor(m / 60);
    if (h < 24) return h + "h";
    return Math.floor(h / 24) + "d";
}

// A notification body is StyledText: one plain line for a row's sub.
function plain(body) {
    return text(body).replace(/<[^>]*>/g, " ").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
        .replace(/&quot;/g, "\"").replace(/&#39;/g, "'").replace(/\s+/g, " ").trim();
}

// The Main board draws sparkle for Claude Code and record for capture; any
// other app gets the bell [GUESS].
function noteIcon(app) {
    var a = text(app).toLowerCase();
    if (/claude|codex|agent/.test(a)) return "sparkle";
    if (/capture|record|screen/.test(a)) return "record";
    if (/spotify|music|player/.test(a)) return "music";
    return "bell";
}

// m:ss for the media times.
function clock(seconds) {
    var s = Math.max(0, Math.floor(num(seconds, 0)));
    var m = Math.floor(s / 60);
    var r = s % 60;
    return m + ":" + (r < 10 ? "0" : "") + r;
}

// 1.5 -> "1.5×", 2 -> "2×".
function scaleText(scale) {
    var s = num(scale, 0);
    if (!(s > 0)) return "";
    return (Math.round(s * 100) / 100) + "×";
}

function tiles(src) {
    var wifi = src.wifi || {};
    var bt = src.bt || {};
    var ts = src.tailscale || {};
    var wifiPresent = wifi.present !== false;
    var btPresent = bt.present !== false;
    var tsInstalled = ts.installed !== false;
    var dnd = src.dnd === true;
    return [
        {
            key: "wifi", label: "Wi-Fi",
            icon: wifiPresent && wifi.radioOn ? "wifi" : "wifiOff",
            on: wifiPresent && wifi.radioOn === true,
            enabled: wifiPresent,
            busy: wifi.busy === true,
            sub: !wifiPresent ? "No adapter" : !wifi.radioOn ? "Off" : wifi.busy ? "Connecting…" : wifi.connected && text(wifi.ssid) !== "" ? text(wifi.ssid) : "Not connected"
        },
        {
            key: "bt", label: "Bluetooth",
            icon: btPresent && bt.enabled ? "bt" : "btOff",
            on: btPresent && bt.enabled === true,
            enabled: btPresent && bt.settling !== true,
            busy: bt.settling === true,
            sub: !btPresent ? "No adapter" : !bt.enabled ? "Off" : text(bt.device) !== "" ? text(bt.device) : "On"
        },
        {
            key: "ts", label: "Tailscale",
            icon: "tailscale",
            on: tsInstalled && ts.running === true,
            enabled: tsInstalled && ts.busy !== true,
            busy: ts.busy === true,
            sub: !tsInstalled ? "Not installed" : ts.needsLogin ? "Needs login" : ts.running ? (text(ts.state) || "Connected") : "Off"
        },
        {
            key: "dnd", label: "Do not disturb",
            icon: "moon",
            on: dnd, enabled: true, busy: false,
            sub: dnd ? "On" : "Off"
        }
    ];
}

function levels(src) {
    var vol = src.volume || {};
    var light = src.brightness || {};
    var muted = vol.muted === true;
    return [
        { key: "volume", icon: muted ? "volMute" : "vol", label: "Volume", value: clamp01(vol.value), muted: muted, device: text(vol.device) || "Output", enabled: vol.present !== false },
        { key: "brightness", icon: "sun", label: "Brightness", value: clamp01(light.value), muted: false, device: "Built-in", enabled: light.present !== false }
    ];
}

// The night light mini's line: when it next changes, else its warmth or Off.
function nightSub(n) {
    if (n.available !== true) return "Unavailable";
    if (n.on === true) return text(n.until) !== "" ? "Until " + text(n.until) : num(n.temperature, NIGHT_DEFAULT_K) + " K";
    return text(n.until) !== "" ? "From " + text(n.until) : "Off";
}

// `sheet`: the sheet the mini also opens (its chevron, a right click, a long
// press, Alt+Right); `opens`: a press opens it too, instead of the toggle.
function minis(src) {
    var awake = src.awake || {};
    var hz = num(src.hz, 0);
    var scale = scaleText(src.scale);
    var recording = src.recording === true;
    var night = src.nightlight || {};
    // The Display mini carries the panel's rate (panel-hz switches it on the
    // charger) since the night light took the Power mode mini's place.
    var display = scale !== "" ? (hz > 0 ? scale + " · " + Math.round(hz) + " Hz" : scale + " scale") : (hz > 0 ? Math.round(hz) + " Hz" : "Built-in");
    return [
        { key: "awake", icon: "coffee", label: "Keep awake", sub: awake.active ? (text(awake.label) || "On") : "Off", on: awake.active === true, sheet: "awake" },
        { key: "nightlight", icon: "sunset", label: "Night light", sub: nightSub(night), on: night.available === true && night.on === true, sheet: "nightlight", opens: night.available !== true },
        { key: "display", icon: "monitor", label: "Display", sub: display, on: false },
        { key: "theme", icon: "palette", label: "Theme", sub: text(src.theme) || "Theme", on: false },
        { key: "record", icon: "record", label: "Record", sub: recording ? "Stop" : "Region", on: recording },
        { key: "clipboard", icon: "clip", label: "Clipboard", sub: "History", on: false }
    ];
}

function notes(src, now) {
    var list = Array.isArray(src.notifications) ? src.notifications : [];
    var rows = [];
    for (var i = 0; i < list.length && rows.length < 2; i++) {
        var n = list[i] || {};
        var app = text(n.appName);
        var body = plain(n.body);
        rows.push({
            index: i,
            title: text(n.summary) || app || "Notification",
            sub: app !== "" && body !== "" ? app + " · " + body : app || body,
            time: ago(n.created, now),
            icon: noteIcon(app),
            critical: n.critical === true
        });
    }
    return { count: num(src.count, list.length), rows: rows };
}

// Lucide's battery by level, as the board's carries a level mark: charging,
// then low up to 30 % (or when UPower says low), medium up to 70, else full.
function batteryIcon(b) {
    var p = num(b.percent, 0);
    if (b.charging) return "batteryCharging";
    if (b.low || p <= 30) return "batteryLow";
    return p <= 70 ? "batteryMedium" : "batteryFull";
}

function footer(src) {
    var b = src.battery || {};
    var user = text(src.user) || "you";
    var state = b.charging ? "charging" : b.pluggedIn ? "plugged in" : "on battery";
    return {
        user: user,
        letter: user.charAt(0).toUpperCase(),
        battery: {
            visible: b.present === true,
            text: Math.round(num(b.percent, 0)) + "% · " + state,
            icon: batteryIcon(b),
            low: b.low === true
        },
        tray: (Array.isArray(src.tray) ? src.tray : []).map(function (t, i) {
            return { index: i, title: text(t.title) || text(t.id), icon: text(t.icon), glyph: text(t.glyph), passive: t.passive === true };
        })
    };
}

function mediaCard(media) {
    if (!media) return { present: false, title: "Ready when you are", artist: "Start something in your favourite player.", playing: false, progress: 0, elapsed: "", total: "", canPrevious: false, canNext: false, canSeek: false, length: 0, art: "" };
    var length = num(media.length, 0);
    var position = Math.max(0, Math.min(length > 0 ? length : Infinity, num(media.position, 0)));
    return {
        present: true,
        title: text(media.title) || "Unknown track",
        artist: text(media.artist),
        playing: media.playing === true,
        progress: length > 0 ? position / length : 0,
        elapsed: length > 0 ? clock(position) : "",
        total: length > 0 ? clock(length) : "",
        canPrevious: media.canPrevious !== false,
        canNext: media.canNext !== false,
        canSeek: media.canSeek === true && length > 0,
        length: length,
        // The player's cover (MPRIS trackArtUrl, M10): a file, http(s) or
        // data URL, else "" (M9's filter).
        art: /^(file|https?|data):/.test(text(media.art)) ? text(media.art) : ""
    };
}

function home(src, now, media) {
    var s = src || {};
    return {
        tiles: tiles(s),
        media: mediaCard(media),
        levels: levels(s),
        minis: minis(s),
        notes: notes(s, now),
        footer: footer(s)
    };
}

// ---- sheets -------------------------------------------------------------------

function sheet(fields) {
    var out = { status: "", switchOn: false, switchEnabled: true, hasSwitch: true, groups: [], footer: "", footerEnabled: true };
    for (var k in fields) out[k] = fields[k];
    return out;
}
function note(key, title, sub) {
    return { key: key, title: title, sub: sub || "", icon: "", dim: true, inert: true };
}

// control-lock 3.3: 4 bars wifi, 3 wifi2, 1 or 2 wifi1.
function wifiIcon(bars) {
    var b = num(bars, 0);
    return b >= 4 ? "wifi" : b === 3 ? "wifi2" : "wifi1";
}

// src: { present, radioOn, portal, signIn, networks: [{ key, ssid, connected,
// known, secured, bars, busy }] } in Net.networks order (connected, known,
// signal). `signIn` (Net.signInAvailable: connected on Limited or Unknown
// connectivity, no portal reported) adds NetMenu's manual "Open Wi-Fi
// sign-in page" under the connected row.
// The band ("5 GHz") is dropped [GUESS, PLAN risk 22]: Quickshell's
// WifiNetwork has no frequency.
function wifi(src) {
    var s = src || {};
    var present = s.present !== false;
    var on = present && s.radioOn === true;
    var nets = Array.isArray(s.networks) ? s.networks : [];
    var groups = [];
    if (!present) groups.push({ label: "", rows: [note("none", "No Wi-Fi adapter")] });
    else if (!on) groups.push({ label: "", rows: [note("off", "Wi-Fi is off")] });
    else {
        var connected = [], known = [], other = [];
        nets.forEach(function (n) {
            var security = n.secured ? "Secured" : "Open";
            var row = { key: text(n.key || n.ssid), title: text(n.ssid), icon: wifiIcon(n.bars), on: false, dim: false, trail: "" };
            if (n.connected) {
                // [DEVIATION] control-lock 3.3: NetworkManager learns of a portal
                // only once connected, so the sign-in shows on this row, in
                // inkDim, and pressing it opens the portal instead of
                // disconnecting.
                row.on = true;
                row.sub = n.busy ? "Disconnecting…" : s.portal ? "Sign-in required" : security;
                row.action = s.portal ? "portal" : "disconnect";
                row.forget = n.known === true;
                connected.push(row);
            } else if (n.known) {
                row.sub = n.busy ? "Connecting…" : security;
                row.action = "connect";
                row.forget = true;
                known.push(row);
            } else {
                row.dim = true;
                row.sub = n.busy ? "Connecting…" : security;
                row.action = n.secured ? "passphrase" : "connect";
                other.push(row);
            }
        });
        if (connected.length && s.signIn === true && !s.portal)
            connected.push({ key: "sign-in", title: "Open Wi-Fi sign-in page", sub: "For a network that asks you to sign in", icon: "globe", trail: "↗", action: "portal" });
        if (connected.length) groups.push({ label: "Connected", rows: connected });
        if (known.length) groups.push({ label: "Known", rows: known });
        if (other.length) groups.push({ label: "Other networks", rows: other });
        if (!groups.length) groups.push({ label: "", rows: [note("empty", "No networks in range")] });
    }
    return sheet({
        status: !present ? "No adapter" : on ? "On" : "Off",
        switchOn: on,
        switchEnabled: present,
        groups: groups,
        footer: "Network settings"
    });
}

// "Built-in", "Bluetooth", "HDMI", "USB" from a node's properties [GUESS].
function transport(props) {
    var p = props || {};
    var api = text(p["device.api"]).toLowerCase();
    var bus = text(p["device.bus"]).toLowerCase();
    var name = (text(p["node.name"]) + " " + text(p["device.profile.name"]) + " " + text(p["node.description"])).toLowerCase();
    if (api === "bluez5" || /bluez/.test(name)) return "Bluetooth";
    if (/hdmi|displayport/.test(name)) return "HDMI";
    if (bus === "usb" || /usb/.test(name)) return "USB";
    return "Built-in";
}

// A sink's short name: a Bluetooth device by its own name, else
// "Headphones", "HDMI" or "Speakers" [GUESS, control-lock 2.5], read from the
// same properties AudioOutput.icon() classifies. node: { name, description,
// props }.
function outputKind(node) {
    var n = node || {};
    var p = n.props || {};
    if (text(p["device.api"]) === "bluez5" || text(p["device.bus"]) === "bluetooth" || /^bluez_output\./.test(text(n.name))) return "bluetooth";
    var kind = [p["device.form-factor"], p["device.icon-name"], p["device.profile.name"], n.name, n.description].map(text).join(" ").toLowerCase();
    if (/headset|hands.free|headphone/.test(kind)) return "headphones";
    if (/hdmi|displayport/.test(kind)) return "hdmi";
    return "speakers";
}
function outputName(node) {
    var k = outputKind(node);
    if (k === "bluetooth") return text((node || {}).description) || "Bluetooth";
    return k === "headphones" ? "Headphones" : k === "hdmi" ? "HDMI" : "Speakers";
}

// Browsers globe, meeting apps video, anything else music [GUESS].
function appIcon(app) {
    var a = text(app).toLowerCase();
    if (/firefox|chrom|brave|zen|browser|vivaldi|edge|epiphany|safari/.test(a)) return "globe";
    if (/zoom|meet|teams|slack|discord|webex|jitsi/.test(a)) return "video";
    return "music";
}

// src: { sink, muted, volume, micVolume, micMuted, sinks: [{ key, name,
// transport, isDefault, headphones }], sources: [{ key, name, transport,
// isDefault }], recorders: [names], streams: [{ key, app, volume }] }.
//
// The default output and the default input carry their levels (a 110 px
// slider and the value), and a press on either mutes it: AudioMenu's output
// and input faders, which the board leaves out [GUESS, control-lock 3.7].
function sound(src) {
    var s = src || {};
    var groups = [];
    var muted = s.muted === true;
    var micMuted = s.micMuted === true;
    function level(row, value, isMuted, mutedIcon) {
        var v = clamp01(value);
        row.slider = v;
        row.trail = String(Math.round(v * 100));
        if (isMuted) {
            row.sub = "Muted";
            row.icon = mutedIcon;
        }
        return row;
    }
    var sinks = (s.sinks || []).map(function (n) {
        var row = { key: text(n.key), title: text(n.name), sub: text(n.transport) || "Built-in", icon: n.headphones ? "headphones" : "speaker", on: n.isDefault === true, action: "sink" };
        if (!n.isDefault) return row;
        row.action = "outputMute";
        return level(row, s.volume, muted, "volMute");
    });
    var recorders = (s.recorders || []).filter(function (r) { return text(r) !== ""; });
    var sources = (s.sources || []).map(function (n) {
        var inUse = n.isDefault && recorders.length > 0;
        var row = { key: text(n.key), title: text(n.name), sub: inUse ? "In use by " + recorders.join(", ") : (text(n.transport) || "Built-in"), icon: "mic", on: n.isDefault === true, action: "source" };
        if (!n.isDefault) return row;
        row.action = "micMute";
        return level(row, s.micVolume, micMuted, "micOff");
    });
    var streams = (s.streams || []).map(function (n) {
        var v = clamp01(n.volume);
        return { key: text(n.key), title: text(n.app) || "App", icon: appIcon(n.app), slider: v, trail: String(Math.round(v * 100)), action: "" };
    });
    // Unlike AudioMenu, the Output group shows even with one sink (the board does).
    groups.push({ label: "Output", rows: sinks.length ? sinks : [note("no-output", "No outputs")] });
    groups.push({ label: "Input", rows: sources.length ? sources : [note("no-input", "No inputs")] });
    if (streams.length) groups.push({ label: "Apps", rows: streams });
    return sheet({
        status: text(s.sink) || "No output",
        // [GUESS] control-lock 3.4: the header switch is output sound on
        // (mute inverted).
        switchOn: !muted && sinks.length > 0,
        switchEnabled: sinks.length > 0,
        groups: groups,
        // [NEEDS CHECK] no mixer app is installed (no pavucontrol,
        // pwvucontrol, wiremix): no footer.
        footer: ""
    });
}

// "Last seen 2 h ago" (TailscaleModel.lastSeenText's rule, repeated here so
// this file has no imports).
function lastSeen(seen, now) {
    var t = num(seen, 0);
    if (!(t > 0)) return "Offline";
    var m = Math.floor(Math.max(0, num(now, 0) - t) / 60000);
    if (m < 1) return "Last seen just now";
    if (m < 60) return "Last seen " + m + " min ago";
    var h = Math.floor(m / 60);
    if (h < 48) return "Last seen " + h + " h ago";
    return "Last seen " + Math.floor(h / 24) + " d ago";
}
// macOS and Windows laptop, Linux server, iOS and Android phone [GUESS].
function osIcon(os) {
    var o = text(os).toLowerCase();
    if (/ios|android/.test(o)) return "phone";
    if (/linux/.test(o)) return "server";
    return "laptop";
}

// src: { installed, running, busy, needsLogin, state, error, statusError, accessDenied,
// health: [lines], self: { name, ipv4 }, exitName, peers: [...], offline: [...], accounts:
// [{ id, label, account, selected }], routes: [{ id, name, target, selected,
// detail }] }. page "exits" is the nested exit-node list, "send" the machines
// Taildrop can send to [GUESS, control-lock 3.5]. The footer (Taildrop) is
// enabled whenever an online machine takes files and nothing is running.
function tailscale(src, now, page) {
    var s = src || {};
    var installed = s.installed !== false;
    var running = installed && s.running === true;
    var groups = [];
    var alerts = [];
    if (s.accessDenied) alerts.push({ key: "authorize", title: "Authorize operator", sub: "Let your user run tailscale", icon: "shield", action: "authorize" });
    else if (text(s.error) !== "") alerts.push({ key: "error", title: "Tailscale", sub: text(s.error), icon: "shield", bad: true, inert: true });
    // TailscaleMenu's Start service (the daemon unreachable) and health lines.
    if (installed && s.statusError === true && !s.accessDenied)
        alerts.push({ key: "start", title: "Start Tailscale", sub: "Starts tailscaled; asks for your password", icon: "power", action: "startService" });
    (Array.isArray(s.health) ? s.health : []).forEach(function (h, i) {
        if (text(h) !== "") alerts.push({ key: "health-" + i, title: "Health", sub: text(h), icon: "shield", inert: true });
    });
    if (s.needsLogin) alerts.push({ key: "login", title: "Log in", sub: "Opens the login page", icon: "globe", action: "login" });
    if (page === "exits") {
        var routes = (s.routes || []).map(function (r) {
            return { key: text(r.id), title: text(r.name), sub: text(r.detail), icon: r.id === "direct" ? "globe" : "exit", on: r.selected === true, action: "route" };
        });
        groups.push({ label: "Exit node", rows: routes.length ? routes : [note("no-routes", "No exit nodes")] });
        return sheet({ status: text(s.exitName) || "None", hasSwitch: false, groups: groups, footer: "" });
    }
    var senders = running ? (s.peers || []).filter(function (p) { return p.canSend === true; }) : [];
    if (page === "send") {
        var targets = senders.map(function (p) {
            return { key: text(p.id), title: text(p.name), sub: "Online", icon: osIcon(p.os), action: "send", canSend: true };
        });
        groups.push({ label: "Send to", rows: targets.length ? targets : [note("no-targets", "No machine takes files right now")] });
        return sheet({ status: "Taildrop", hasSwitch: false, groups: groups, footer: "" });
    }
    if (alerts.length) groups.push({ label: "", rows: alerts });
    if (!installed) groups.push({ label: "", rows: [note("missing", "Tailscale is not installed")] });
    else if (!running) groups.push({ label: "", rows: [note("off", "Tailscale is off")] });
    else {
        var self = s.self || {};
        groups.push({ label: "This machine", rows: [{ key: "self", title: text(self.name) || "This device", sub: (text(self.ipv4) !== "" ? text(self.ipv4) + " · " : "") + "this device", icon: "laptop", on: true, action: "copySelf" }] });
        var exit = text(s.exitName);
        groups.push({ label: "Exit node", rows: [{ key: "exit", title: exit || "None", sub: exit ? "Traffic leaves from " + exit : "Traffic leaves from this network", icon: "exit", trail: "›", action: "exits" }] });
        var machines = (s.peers || []).map(function (p) {
            return { key: text(p.id), title: text(p.name), sub: "Online", icon: osIcon(p.os), trail: "●", action: "copy", canSend: p.canSend === true };
        }).concat((s.offline || []).map(function (p) {
            return { key: text(p.id), title: text(p.name), sub: lastSeen(p.lastSeen, now), icon: osIcon(p.os), dim: true, action: "copy", canSend: false };
        }));
        groups.push({ label: "Machines", rows: machines.length ? machines : [note("alone", "No other machines")] });
    }
    // TailscaleMenu's Accounts, when there is a choice: `tailscale switch`.
    var accounts = Array.isArray(s.accounts) ? s.accounts : [];
    if (installed && accounts.length > 1)
        groups.push({ label: "Accounts", rows: accounts.map(function (a) {
            var label = text(a.label) || text(a.account) || text(a.id);
            var login = text(a.account);
            return { key: "account:" + text(a.id), account: text(a.id), title: label, sub: a.selected ? "In use" : (login !== label ? login : ""), icon: "user", on: a.selected === true, action: "account" };
        }) });
    return sheet({
        status: text(s.state) || (running ? "Connected" : "Off"),
        switchOn: running,
        switchEnabled: installed && s.busy !== true && s.statusError !== true,
        groups: groups,
        footer: running ? "Send a file with Taildrop" : "",
        footerEnabled: senders.length > 0 && s.busy !== true
    });
}

// Bluetooth device icons by the BlueZ `icon` hint [GUESS].
function btIcon(hint) {
    var h = text(hint).toLowerCase();
    if (/headset|headphone|audio/.test(h)) return "headphones";
    if (/keyboard/.test(h)) return "keyboard";
    if (/mouse|tablet/.test(h)) return "mouse";
    if (/gaming|joystick/.test(h)) return "gamepad";
    if (/phone/.test(h)) return "phone";
    if (/computer/.test(h)) return "laptop";
    return "bt";
}
function capital(t) {
    var s = text(t);
    return s.charAt(0).toUpperCase() + s.slice(1);
}

// src: { present, enabled, settling, discovering, connected, known, nearby },
// each device { key, name, status, battery, icon } (control-lock 3.6).
function bluetooth(src) {
    var s = src || {};
    var present = s.present !== false;
    var on = present && s.enabled === true;
    function row(d, connected) {
        var b = num(d.battery, -1);
        return { key: text(d.key), title: text(d.name), sub: capital(d.status) || (connected ? "Connected" : "Not paired"), icon: btIcon(d.icon), on: connected, trail: b >= 0 ? b + "%" : "", action: "activate", forget: !connected && d.paired !== false && d.group !== "nearby" };
    }
    var groups = [];
    if (!present) groups.push({ label: "", rows: [note("none", "No Bluetooth adapter")] });
    else if (!on) groups.push({ label: "", rows: [note("off", "Bluetooth is off")] });
    else {
        var connected = (s.connected || []).map(function (d) { return row(d, true); });
        var known = (s.known || []).map(function (d) { return row(d, false); });
        var nearby = (s.nearby || []).map(function (d) { var r = row(d, false); r.forget = false; r.dim = true; return r; });
        if (connected.length) groups.push({ label: "Connected", rows: connected });
        if (known.length) groups.push({ label: "Paired", rows: known });
        if (nearby.length) groups.push({ label: "Available", rows: nearby });
        // BtMenu's hint while scanning: Quickshell gives no agent callbacks,
        // so there is nowhere to type a passkey.
        if (s.discovering) groups.push({ label: "", rows: [note("passkey", "A device that asks for a typed passkey", "Pair it with bluetoothctl in a terminal")] });
        if (!connected.length && !known.length && !nearby.length) groups.unshift({ label: "", rows: [note("empty", s.discovering ? "Looking for devices…" : "No devices yet")] });
    }
    return sheet({
        status: !present ? "No adapter" : !on ? "Off" : s.discovering ? "Scanning" : "On",
        switchOn: on,
        switchEnabled: present && s.settling !== true,
        groups: groups,
        footer: on ? (s.discovering ? "Stop scanning" : "Scan for devices") : ""
    });
}

// src: { dnd, items: [{ summary, appName, body, created, critical }] }.
// The body wraps to six lines, as the old NotificationCenter showed it (the
// classic cards cut it at four, the island at one).
function notifications(src, now) {
    var s = src || {};
    var items = Array.isArray(s.items) ? s.items : [];
    var rows = items.map(function (n, i) {
        var app = text(n.appName);
        var body = plain(n.body);
        return { key: String(i), index: i, title: text(n.summary) || app || "Notification", sub: app !== "" && body !== "" ? app + " · " + body : app || body, icon: noteIcon(app), trail: ago(n.created, now), bad: false, critical: n.critical === true, action: "open", wrap: true, lines: 6 };
    });
    return sheet({
        status: s.dnd ? "Do not disturb" : items.length + (items.length === 1 ? " notification" : " notifications"),
        switchOn: s.dnd === true,
        groups: [{ label: "Recent", rows: rows.length ? rows : [note("empty", "No notifications")] }],
        footer: rows.length ? "Clear all" : ""
    });
}

var BAR_MODES = [
    { key: "island", title: "Island", sub: "Floats at the top centre" },
    { key: "pill", title: "Pill", sub: "Floating bar on one edge" },
    { key: "full", title: "Full", sub: "Edge to edge" },
    { key: "rail", title: "Rail", sub: "Narrow strip on the side" }
];

// src: { brightness: { value, present }, output, current: { width, height, hz,
// scale }, modes: [{ mode, label, current }], scales: [{ value, label,
// current }], barMode, error }. Brightness, the Bar mode (PLAN 1.6: the
// Display mini switches it [GUESS where]), then DisplayMenu's modes and scales.
// With `looks` ([{ key, title, sub }], Look.qml's) also the island's form
// (`islandForm`: float or notch) and its look (`look`), after the Bar (M9:
// no board draws a picker for either; this is the settings home PLAN M9
// asks for).
var ISLAND_FORMS = [
    { key: "float", title: "Float", sub: "8 below the top edge" },
    { key: "notch", title: "Notch", sub: "Flush with the top edge" }
];
function display(src) {
    var s = src || {};
    var light = s.brightness || {};
    var groups = [];
    if (light.present !== false) {
        var v = clamp01(light.value);
        groups.push({ label: "Brightness", rows: [{ key: "brightness", title: "Built-in", icon: "sun", slider: v, trail: String(Math.round(v * 100)), action: "" }] });
    }
    groups.push({ label: "Bar", rows: BAR_MODES.map(function (m) {
        return { key: m.key, title: m.title, sub: m.sub, icon: m.key === "island" ? "sparkle" : "window", on: s.barMode === m.key, action: "bar" };
    }) });
    if (Array.isArray(s.looks) && s.looks.length) {
        groups.push({ label: "Island form", rows: ISLAND_FORMS.map(function (f) {
            return { key: f.key, title: f.title, sub: f.sub, icon: "sparkle", on: (text(s.islandForm) || "float") === f.key, action: "form" };
        }) });
        groups.push({ label: "Look", rows: s.looks.map(function (l) {
            return { key: text(l.key), title: text(l.title) || text(l.key), sub: text(l.sub), icon: "sparkle", on: (text(s.look) || "crew") === text(l.key), action: "look" };
        }) });
    }
    var modes = (s.modes || []).map(function (m) {
        return { key: text(m.mode), title: text(m.label) || text(m.mode), icon: "monitor", on: m.current === true, action: "mode" };
    });
    var scales = (s.scales || []).map(function (m) {
        return { key: String(m.value), title: text(m.label) || scaleText(m.value), icon: "sliders", on: m.current === true, action: "scale" };
    });
    if (text(s.error) !== "") groups.push({ label: "", rows: [{ key: "error", title: "Display", sub: text(s.error), icon: "monitor", bad: true, inert: true }] });
    if (modes.length) groups.push({ label: "Mode", rows: modes });
    if (scales.length) groups.push({ label: "Scale", rows: scales });
    var cur = s.current || {};
    var res = num(cur.width, 0) > 0 ? cur.width + "×" + cur.height : "";
    var hz = num(cur.hz, 0) > 0 ? Math.round(cur.hz) + " Hz" : "";
    return sheet({
        status: [res, hz, scaleText(cur.scale)].filter(function (x) { return x !== ""; }).join(" · "),
        hasSwitch: false,
        groups: groups,
        footer: ""
    });
}

// src: { active, selected, status, options: [{ minutes, label }] }
// (CaffeineMenu's durations).
function awake(src) {
    var s = src || {};
    var on = s.active === true;
    var rows = (s.options || []).map(function (o) {
        return { key: String(o.minutes), title: text(o.label), icon: o.minutes < 0 ? "coffee" : "sun", on: on && num(s.selected, 0) === o.minutes, action: "start" };
    });
    return sheet({
        status: on ? (text(s.status) || "On") : "Off",
        switchOn: on,
        groups: [{ label: "Keep the screen on for", rows: rows }],
        footer: ""
    });
}

// src: { present, percent, statusText, timeText, pluggedIn, busy, error,
// care: { supported, mode, start, end, target, recovery } } (Battery.qml's).
// The charge limit's top-up (M10: BatteryMenu.qml's page, now a sheet, the
// control center footer's battery). The two top-ups can run only when
// Battery.topUp would run them (Custom charging mode, plugged in, below the
// target, nothing running; the 80 % one also needs the 80 % cap and under
// 75 %); while one runs, Cancel or Restore takes their place. Then
// BatteryMenu's hints as dim rows and its error in `bad`. A row that cannot
// run is dim and inert. No switch, no footer.
function battery(src) {
    var s = src || {};
    var care = s.care || {};
    // Battery.topUp compares the raw level; the status shows it rounded.
    var level = num(s.percent, 0);
    var pct = Math.round(level);
    var target = num(care.target, 0);
    var custom = care.supported === true && care.mode === "Custom";
    var busy = s.busy === true;
    var status = (text(s.statusText) || "Battery") + " · " + pct + "%" + (text(s.timeText) !== "" ? " · " + text(s.timeText) : "");
    var hint = target > 0
        ? (care.recovery ? "Top-up was interrupted. Restore battery care below." : "Topping up to " + target + "%. Your usual limits return at the target or when you unplug.")
        : care.supported === true ? "Battery care: start below " + num(care.start, 0) + "%, stop at " + num(care.end, 0) + "%."
            : "Top-up controls are not supported on this battery.";
    var rows = [];
    if (target > 0) {
        var restore = care.recovery === true;
        rows.push({ key: "stop", title: restore ? "Restore battery care" : "Cancel top-up", sub: hint, icon: restore ? "shield" : "x", action: busy ? "" : "stop", inert: busy, dim: busy });
    } else {
        [80, 100].forEach(function (t) {
            var ok = custom && s.pluggedIn === true && level < t && !busy && (t !== 80 || (num(care.end, 0) === 80 && level < 75));
            rows.push({ key: String(t), title: t === 80 ? "Top up to 80%" : "Charge to 100%", sub: "Then back to your usual limits", icon: t === 80 ? "batteryMedium" : "batteryFull", action: ok ? "topUp" : "", inert: !ok, dim: !ok });
        });
    }
    // BatteryMenu's hints wrap (a row's sub is one line otherwise).
    var notes = [];
    if (target === 0) notes.push({ key: "care", title: "Battery care", sub: hint, icon: "", dim: true, inert: true, wrap: true });
    notes.push({ key: "how", title: busy ? "Waiting for authorization" : "Top-up", icon: "", dim: true, inert: true, wrap: true,
        sub: busy ? "Authorize in the system dialog…"
            : s.pluggedIn !== true ? "Connect a charger to top up."
                : care.supported === true && care.mode !== "Custom" && target === 0 ? "Select Custom charging mode in BIOS to enable battery care."
                    : "Requires administrator authorization. Usual settings return automatically. The 80% top-up is available below 75% with an 80% cap." });
    if (text(s.error) !== "") notes.push({ key: "error", title: "Battery", sub: text(s.error), icon: "shield", bad: true, inert: true, wrap: true });
    var groups = s.present === false ? [{ label: "", rows: [note("missing", "No battery")] }]
        : [{ label: "Charge limit", rows: rows }, { label: "", rows: notes }];
    return sheet({ status: status, hasSwitch: false, groups: groups, footer: "" });
}

// The night light's warmth range (lib/NightLight.js MIN_K and MAX_K;
// tests/cc-data.cjs checks they agree). The slider runs neutral at the left,
// warmest at the right.
var NIGHT_MIN_K = 2500;
var NIGHT_MAX_K = 6000;
var NIGHT_DEFAULT_K = 4000;
function nightFraction(k) {
    var v = Math.max(NIGHT_MIN_K, Math.min(NIGHT_MAX_K, num(k, NIGHT_DEFAULT_K)));
    return (NIGHT_MAX_K - v) / (NIGHT_MAX_K - NIGHT_MIN_K);
}

// src: NightLight.qml's { available, reason, message, on, temperature,
// schedule, from, to, until, overridden }.
// Its state ("On until 07:00", "Off until 20:00", "Unavailable"), the switch
// (refused while hyprsunset is not answering), then why it is unavailable
// with the one way the shell starts hyprsunset (`start`, only when it is
// simply not running), the warmth (a slider, 100 K a key step) and the
// schedule: Off, or From and To on 30-minute steppers. No sunset to sunrise:
// nothing on the machine stores a location (NightLight.qml).
function nightlight(src) {
    var s = src || {};
    var available = s.available === true;
    var on = s.on === true;
    var until = text(s.until);
    var k = Math.round(Math.max(NIGHT_MIN_K, Math.min(NIGHT_MAX_K, num(s.temperature, NIGHT_DEFAULT_K))) / 100) * 100;
    var custom = s.schedule === "custom";
    var from = text(s.from) || "20:00";
    var to = text(s.to) || "07:00";
    var groups = [];
    if (!available) {
        var reason = text(s.reason);
        groups.push({ label: "", rows: [
            reason === "stopped" ? { key: "start", title: "Start hyprsunset", sub: text(s.message) || "hyprsunset is not running", icon: "power", action: "start" }
                : note(reason || "unavailable", reason === "dry" ? "Dry run" : reason === "session" ? "No Hyprland session" : reason === "checking" ? "Asking hyprsunset" : "hyprsunset",
                    reason === "dry" ? "The screen is left alone here" : reason === "session" ? "hyprctl has no session to talk to" : reason === "checking" ? "Waiting for its answer" : text(s.message) || "No answer")
        ] });
    }
    groups.push({ label: "Warmth", rows: [{ key: "warmth", title: "Temperature", sub: "Warmer to the right", icon: "thermometer", slider: nightFraction(k), step: 100 / (NIGHT_MAX_K - NIGHT_MIN_K), trail: k + " K", action: "" }] });
    var rows = [
        { key: "off", title: "Off", sub: "On and off by hand", icon: "timerOff", on: !custom, action: "schedule" },
        { key: "custom", title: "Custom times", sub: "From " + from + " to " + to, icon: "clock", on: custom, action: "schedule" }
    ];
    if (custom) {
        rows.push({ key: "from", title: "From", icon: "sunset", trail: from, stepper: true, action: "" });
        rows.push({ key: "to", title: "To", icon: "sunrise", trail: to, stepper: true, action: "" });
    }
    groups.push({ label: "Schedule", rows: rows });
    return sheet({
        status: !available ? "Unavailable" : (on ? "On" : "Off") + (until !== "" ? " until " + until : ""),
        switchOn: available && on,
        switchEnabled: available,
        groups: groups,
        footer: ""
    });
}

// What a sheet name is called when it opens (control-lock 3; the launcher's
// System pages use audio and net for sound and wifi).
var SHEETS = ["wifi", "sound", "tailscale", "bt", "notifications", "display", "awake", "tray", "battery", "nightlight"];
var ALIASES = { net: "wifi", audio: "sound", bluetooth: "bt", ts: "tailscale", dnd: "notifications", caffeine: "awake", brightness: "display", volume: "sound", power: "display", charge: "battery", night: "nightlight", sunset: "nightlight", hyprsunset: "nightlight" };
function sheetName(name) {
    var n = text(name);
    if (ALIASES[n]) n = ALIASES[n];
    return SHEETS.indexOf(n) >= 0 ? n : "";
}

// The power menu's commands (launcher/providers/System.qml's), for every host
// that shows it: the island (IslandView) and the classic bars' anchored host.
var POWER_COMMANDS = {
    lock: ["loginctl", "lock-session"],
    suspend: ["systemctl", "suspend"],
    logout: ["uwsm", "stop"],
    reboot: ["systemctl", "reboot"],
    shutdown: ["systemctl", "poweroff"]
};

if (typeof module !== "undefined")
    module.exports = {
        home: home, tiles: tiles, levels: levels, minis: minis, notes: notes, footer: footer, mediaCard: mediaCard,
        wifi: wifi, sound: sound, tailscale: tailscale, bluetooth: bluetooth, notifications: notifications, display: display, awake: awake, battery: battery, nightlight: nightlight,
        nightSub: nightSub, nightFraction: nightFraction, NIGHT_MIN_K: NIGHT_MIN_K, NIGHT_MAX_K: NIGHT_MAX_K,
        batteryIcon: batteryIcon, outputKind: outputKind, outputName: outputName, ago: ago, plain: plain, clock: clock, scaleText: scaleText, transport: transport, appIcon: appIcon, osIcon: osIcon, btIcon: btIcon,
        lastSeen: lastSeen, wifiIcon: wifiIcon, sheetName: sheetName, SHEETS: SHEETS, ALIASES: ALIASES, BAR_MODES: BAR_MODES, ISLAND_FORMS: ISLAND_FORMS, POWER_COMMANDS: POWER_COMMANDS
    };
