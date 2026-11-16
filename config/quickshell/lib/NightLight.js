// NightLight.js - the night light's rules (NightLight.qml), plain data in and
// out, so tests/nightlight.cjs pins them under node.
//
// The night light drives the hyprsunset that already runs as a user service:
// on is `hyprctl hyprsunset temperature <K>`, off is `hyprctl hyprsunset
// identity`. What it should be at a moment is effective(state, ms):
//
//   state: { schedule: "off" | "custom", from: "20:00", to: "07:00",
//            manual: bool, override: "" | "on" | "off", until: ms }
//
//   schedule off     on is `manual`, what the last toggle left, or what the
//                    light showed when Off was picked (NightLight.qml
//                    setSchedule); nothing else changes it.
//   schedule custom  on inside [from, to), which may cross midnight (20:00 to
//                    07:00 is on from 20:00 until 07:00 the next morning).
//                    from equal to to is an empty window: never on by the
//                    schedule. A toggle against the schedule is an override,
//                    on or off, that holds until the next schedule edge
//                    (`until`, nextEdge at the toggle), and from then the
//                    schedule decides again. A toggle back to what the
//                    schedule says clears it.
//
// Times are local wall-clock minutes. An edge is built from the date and the
// minute every time (new Date(y, m, d, h, min)), never by adding hours, so a
// daylight-saving night still turns it on at 20:00 by the clock.
//
// hyprsunset's own profiles (config/hypr/hyprsunset.conf: an identity profile
// at 07:00) switch it back by themselves. hyprsunset says so in its journal
// ("Switched to new profile from: 7:0", journalEvent()), and after a resume
// it says so late: 6 to 50 s after the wake on milhouse, not at 07:00.
// parseProfiles() reads them, profileDiffers() says whether one left the
// screen other than it should be, and crossed() says when one was due since
// the last tick (the fallback when no journal line comes).
//
// No .pragma library: node loads this file too.

var MIN_K = 2500;
var MAX_K = 6000;
var STEP_K = 100;
var DEFAULT_K = 4000;
var DEFAULT_FROM = "20:00";
var DEFAULT_TO = "07:00";
var SCHEDULES = ["off", "custom"];
// The From and To steppers move a time by this many minutes.
var TIME_STEP = 30;
var DAY_MIN = 1440;
// hyprsunset's own default and what a profile without a temperature applies.
var NEUTRAL_K = 6000;

function num(v, fallback) {
    var n = Number(v);
    return isFinite(n) ? n : fallback;
}

// "20:00" or "7:05" -> minutes since midnight, -1 for anything else.
function parseTime(s) {
    var m = /^\s*(\d{1,2}):(\d{2})\s*$/.exec(String(s === undefined || s === null ? "" : s));
    if (!m) return -1;
    var h = Number(m[1]), min = Number(m[2]);
    if (h > 23 || min > 59) return -1;
    return h * 60 + min;
}

// Minutes (any integer, wrapped into the day) -> "HH:MM".
function formatTime(minutes) {
    var m = ((Math.round(num(minutes, 0)) % DAY_MIN) + DAY_MIN) % DAY_MIN;
    var h = Math.floor(m / 60), r = m % 60;
    return (h < 10 ? "0" : "") + h + ":" + (r < 10 ? "0" : "") + r;
}

// A valid "HH:MM", or `fallback`.
function time(s, fallback) {
    var m = parseTime(s);
    return m < 0 ? fallback : formatTime(m);
}

// `s` moved by `steps` of TIME_STEP, wrapping at midnight. Never onto `avoid`
// (the other end of the window): it skips one more step instead, so a
// stepper cannot make the window empty.
function stepTime(s, steps, avoid) {
    var m = parseTime(s);
    if (m < 0) return s;
    var n = Math.round(num(steps, 0));
    if (n === 0) return formatTime(m);
    // Snapped to the step first, so 20:10 + 1 is 20:30 and 20:10 - 1 is 20:00.
    var base = n > 0 ? Math.floor(m / TIME_STEP) * TIME_STEP : Math.ceil(m / TIME_STEP) * TIME_STEP;
    var next = base + n * TIME_STEP;
    var other = parseTime(avoid);
    if (other >= 0 && formatTime(next) === formatTime(other)) next += n > 0 ? TIME_STEP : -TIME_STEP;
    return formatTime(next);
}

// Kelvin clamped to MIN_K..MAX_K on STEP_K; DEFAULT_K for junk.
function kelvin(v) {
    var k = num(v, NaN);
    if (!isFinite(k)) return DEFAULT_K;
    return Math.max(MIN_K, Math.min(MAX_K, Math.round(k / STEP_K) * STEP_K));
}

// The warmth slider: 0 at MAX_K (neutral, left), 1 at MIN_K (warmest, right).
function fraction(k) {
    return (MAX_K - kelvin(k)) / (MAX_K - MIN_K);
}
function fromFraction(f) {
    var v = Math.max(0, Math.min(1, num(f, 0)));
    return kelvin(MAX_K - v * (MAX_K - MIN_K));
}
// One STEP_K as a slider step.
var FRACTION_STEP = STEP_K / (MAX_K - MIN_K);

function schedule(s) {
    return SCHEDULES.indexOf(s) >= 0 ? s : "off";
}

// Local minute of the day at ms.
function minuteOf(ms) {
    var d = new Date(num(ms, 0));
    return d.getHours() * 60 + d.getMinutes();
}

// ms of `minute` on the local day of `ms`, `days` later (may be negative).
function atMinute(ms, minute, days) {
    var d = new Date(num(ms, 0));
    return new Date(d.getFullYear(), d.getMonth(), d.getDate() + (days || 0), Math.floor(minute / 60), minute % 60, 0, 0).getTime();
}

// Inside [from, to) at `minute` (all minutes of the day).
function inWindow(minute, from, to) {
    if (from < 0 || to < 0 || from === to) return false;
    if (from < to) return minute >= from && minute < to;
    return minute >= from || minute < to;
}

// The schedule's verdict at ms (false when there is no schedule).
function scheduled(state, ms) {
    var s = state || {};
    if (schedule(s.schedule) !== "custom") return false;
    return inWindow(minuteOf(ms), parseTime(s.from), parseTime(s.to));
}

// The first schedule edge (a `from` or a `to`) strictly after ms; 0 when the
// window is empty or the times are junk.
function nextEdge(ms, from, to) {
    var f = parseTime(from), t = parseTime(to);
    if (f < 0 || t < 0 || f === t) return 0;
    var best = 0;
    for (var day = 0; day <= 2; day++) {
        [f, t].forEach(function (m) {
            var at = atMinute(ms, m, day);
            if (at > ms && (best === 0 || at < best)) best = at;
        });
        if (best !== 0) break;
    }
    return best;
}

function overrideActive(state, ms) {
    var s = state || {};
    return schedule(s.schedule) === "custom" && (s.override === "on" || s.override === "off") && num(s.until, 0) > num(ms, 0);
}

function onAt(state, ms) {
    var s = state || {};
    if (schedule(s.schedule) !== "custom") return s.manual === true;
    if (overrideActive(s, ms)) return s.override === "on";
    return scheduled(s, ms);
}

// { on, scheduled, overridden, changesAt }: changesAt is the next moment `on`
// flips (an override running out into the same state is no flip), 0 for
// none ahead (no schedule, or an empty window).
function effective(state, ms) {
    var s = state || {};
    var t = num(ms, 0);
    var on = onAt(s, t);
    var out = { on: on, scheduled: scheduled(s, t), overridden: overrideActive(s, t), changesAt: 0 };
    if (schedule(s.schedule) !== "custom") return out;
    var at = t;
    // An override holds at most to the next edge, so two edges always decide.
    for (var i = 0; i < 4; i++) {
        var e = nextEdge(at, s.from, s.to);
        if (e === 0) break;
        if (onAt(s, e) !== on) {
            out.changesAt = e;
            break;
        }
        at = e;
    }
    return out;
}

// What turning it on (or off) at ms writes: { manual } without a schedule,
// else { override, until } (cleared when the schedule already agrees).
function setOn(state, ms, on) {
    var s = state || {};
    var want = on === true;
    if (schedule(s.schedule) !== "custom") return { manual: want, override: "", until: 0 };
    if (scheduled(s, ms) === want) return { override: "", until: 0 };
    return { override: want ? "on" : "off", until: nextEdge(ms, s.from, s.to) };
}
function toggle(state, ms) {
    return setOn(state, ms, !onAt(state, ms));
}

// hyprctl's answer: { ok, kind, value, message }. kind: "ok" (a setter),
// "value" (a query: the number), "stopped" (no hyprsunset socket, exit 3:
// "Couldn't connect to .../.hyprsunset.sock. (3)"), "error" (anything else:
// hyprsunset's "invalid command", an invalid temperature, which exit 0).
function reply(code, text) {
    var t = String(text === undefined || text === null ? "" : text).trim();
    if (/couldn'?t connect/i.test(t)) return { ok: false, kind: "stopped", value: 0, message: "hyprsunset is not running" };
    if (num(code, 1) !== 0) return { ok: false, kind: "error", value: 0, message: t || "hyprctl failed (" + code + ")" };
    if (t === "ok") return { ok: true, kind: "ok", value: 0, message: "" };
    if (/^\d+$/.test(t)) return { ok: true, kind: "value", value: Number(t), message: "" };
    return { ok: false, kind: "error", value: 0, message: t || "no answer from hyprsunset" };
}

// The argv that puts `want` ({ on, temperature }) on the screen.
function command(want) {
    var w = want || {};
    return w.on ? ["hyprctl", "hyprsunset", "temperature", String(kelvin(w.temperature))] : ["hyprctl", "hyprsunset", "identity"];
}
var QUERY = ["hyprctl", "hyprsunset", "temperature"];

// hyprsunset.conf's profiles: [{ minute, identity, temperature }], in file
// order. `profile { time = 07:00 \n identity = true }`; # starts a comment.
// A profile without a valid time is skipped, as hyprsunset skips it.
function parseProfiles(text) {
    var src = String(text === undefined || text === null ? "" : text).replace(/#[^\n]*/g, "");
    var out = [];
    var re = /profile\s*\{([^}]*)\}/g;
    var m;
    while ((m = re.exec(src)) !== null) {
        var body = m[1];
        var get = function (key) {
            var r = new RegExp("(?:^|[\\s;])" + key + "\\s*=\\s*([^\\n;]+)").exec(body);
            return r ? r[1].trim() : "";
        };
        var minute = parseTime(get("time"));
        if (minute < 0) continue;
        var raw = get("temperature");
        var k = raw === "" ? NaN : num(raw, NaN);
        out.push({ minute: minute, identity: /^(true|1|yes|on)$/i.test(get("identity")), temperature: isFinite(k) ? k : NEUTRAL_K });
    }
    return out;
}

// The profile that fired in (fromMs, toMs] (its latest firing wins), or null.
function crossed(profiles, fromMs, toMs) {
    var best = null, bestAt = 0;
    (profiles || []).forEach(function (p) {
        var at = atMinute(toMs, p.minute, 0);
        if (at > toMs) at = atMinute(toMs, p.minute, -1);
        if (at > fromMs && at <= toMs && at >= bestAt) {
            best = p;
            bestAt = at;
        }
    });
    return best;
}

// Whether a fired profile left the screen other than `want` shows it.
function profileDiffers(profile, want) {
    if (!profile) return false;
    var w = want || {};
    if (!w.on) return !profile.identity;
    return profile.identity || kelvin(profile.temperature) !== kelvin(w.temperature);
}

// A line of the journal NightLight.qml follows (USER_UNIT, the user
// manager's lines about the unit, plus _SYSTEMD_USER_UNIT, hyprsunset's own
// output, with --output=cat):
//   { kind: "lifecycle", started }  "Started ...", "Stopping ...", "Stopped
//                                   ...", "Failed ...", or "<unit>: ..." (a
//                                   crash: "Main process exited", "Failed
//                                   with result"); hyprsunset's own lines
//                                   start with box drawing, never like these
//   { kind: "profile", minute }     hyprsunset's "┣ Switched to new profile
//                                   from: 7:0" (minute -1 when unreadable)
//   null                            anything else: its banner, and the CTM
//                                   lines it logs for every request
function journalEvent(line, unit) {
    var t = String(line === undefined || line === null ? "" : line).trim();
    var m = /^(Started|Stopping|Stopped|Failed)\b/.exec(t);
    if (m) return { kind: "lifecycle", started: m[1] === "Started" };
    var u = String(unit || "");
    if (u !== "" && t.indexOf(u + ":") === 0) return { kind: "lifecycle", started: false };
    m = /Switched to new profile from:\s*(\d{1,2}):(\d{1,2})\b/.exec(t);
    if (m) {
        var h = Number(m[1]), min = Number(m[2]);
        return { kind: "profile", minute: h < 24 && min < 60 ? h * 60 + min : -1 };
    }
    if (/Switched to new profile/.test(t)) return { kind: "profile", minute: -1 };
    return null;
}

// The profile at `minute` (journalEvent's), or null.
function profileAt(profiles, minute) {
    var list = profiles || [];
    for (var i = 0; i < list.length; i++)
        if (list[i].minute === minute) return list[i];
    return null;
}

// "HH:MM" of ms (local), "" for 0.
function clock(ms) {
    return num(ms, 0) > 0 ? formatTime(minuteOf(ms)) : "";
}

if (typeof module !== "undefined")
    module.exports = {
        MIN_K: MIN_K, MAX_K: MAX_K, STEP_K: STEP_K, DEFAULT_K: DEFAULT_K, DEFAULT_FROM: DEFAULT_FROM, DEFAULT_TO: DEFAULT_TO,
        SCHEDULES: SCHEDULES, TIME_STEP: TIME_STEP, NEUTRAL_K: NEUTRAL_K, FRACTION_STEP: FRACTION_STEP, QUERY: QUERY,
        parseTime: parseTime, formatTime: formatTime, time: time, stepTime: stepTime, kelvin: kelvin, fraction: fraction,
        fromFraction: fromFraction, schedule: schedule, minuteOf: minuteOf, atMinute: atMinute, inWindow: inWindow,
        scheduled: scheduled, nextEdge: nextEdge, overrideActive: overrideActive, onAt: onAt, effective: effective,
        setOn: setOn, toggle: toggle, reply: reply, command: command, parseProfiles: parseProfiles, crossed: crossed,
        profileDiffers: profileDiffers, journalEvent: journalEvent, profileAt: profileAt, clock: clock
    };
