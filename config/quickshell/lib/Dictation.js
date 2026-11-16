// Dictation.js - which surface shows the voxtype daemon's dictation (PLAN M3).
//
// One rule for both: VoxtypeOsd.qml (the bottom popup, classic bar modes) and
// the island's dict state (island mode). A session the launcher owns has its
// own UI (voice.active), and a --no-osd recording asks for none
// (voice.osdSuppressed); otherwise the daemon recording or streaming is
// "listening" and transcribing is "transcribing".
//
// No .pragma library: tests/voxtype-osd.qml and node can load it alike.

// "" (nothing to show), "listening" or "transcribing".
function phase(voice) {
    if (!voice || voice.active || voice.osdSuppressed) return "";
    if (voice.daemonListening) return "listening";
    if (voice.daemonState === "transcribing") return "transcribing";
    return "";
}

// "osd", "island" or "" for a phase in a bar mode.
function surface(p, barMode) {
    if (!p) return "";
    return barMode === "island" ? "island" : "osd";
}

// m:ss for a duration in ms.
function clock(ms) {
    var s = Math.max(0, Math.floor((Number(ms) || 0) / 1000));
    var r = s % 60;
    return Math.floor(s / 60) + ":" + (r < 10 ? "0" : "") + r;
}

if (typeof module !== "undefined") module.exports = { phase: phase, surface: surface, clock: clock };
