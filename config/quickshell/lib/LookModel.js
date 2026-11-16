// LookModel.js - the island's looks as data (personal-looks 4, PLAN M9).
//
// A look restyles the island's small surfaces, not its data: the rest bar
// and the look's moment line, plus the Crew's two moments (the hail and
// vibes) where the look has no cell of its own. Every look takes the pack's
// colours. "crew" is the plain island, the default (the Looks board's
// "Crew (default, flat)"): nothing changes until a look is picked. "none" is
// another name for it.
//
// What each look draws itself (the Looks board's two lines per frame):
//
//   look      rest bar                                   moment line (kind)
//   phosphor  square tabs, clock + cursor, ASCII crew     "> tagline" + cursor (signoff)
//   bridge    LCARS segments: stardate, letters, team     "{name} hailing | On screen" (hail)
//   arcade    Stage, 1UP + clock, hearts, invaders        HI spend, Crew xN, Player n needs you (hail)
//   liner     handwritten letters + scribble, stamp       the tagline (signoff; the meeting note
//                                                         has no source on Linux and is left out)
//   outrun    three neon tubes: letters, clock, bots      now playing (nowplaying)
//
// The cells a look does not draw (the hail in phosphor, liner and outrun,
// vibes in every look) fall back to the Crew component (Island/HailCard,
// Island/VibesCard) in the look's font and colours (skin()).
//
// Contrast. The boards use the accent or palette hues as ink, which fails on
// light packs (personal-looks 4.2-4.5: accent on darker is 3.45 on
// catppuccin-latte). ink() picks each ink against the ground it sits on: the
// board's colour where it reaches 4.5 (text) or 3 (glyphs, PixelSprite
// shapes), else the pack's fg. Bridge prints black on its segments, or white
// where black falls short (black or white always reaches 4.58). pairs() lists
// every pair ink() produced, and tests/look-contrast.cjs runs it over all 37
// packs: a look whose pairs still fail on light packs after the fallback is
// marked darkOnly and the island draws the plain look there.
//
// Input tokens: camelCase "#rrggbb" strings (Tokens.qml's names: bg, fg,
// accent, surface, hairline, inkDim, inkMid, fillHigh, darker, bad, red,
// yellow, cyan, blue, magenta, magentaBright) and `dark`. Pure functions, no
// QML types, so node can require() this file. The contrast maths matches
// lib/TokenMath.js (WCAG 2, linearised at 0.03928; the test checks).

var LOOKS = ["crew", "phosphor", "bridge", "arcade", "liner", "outrun"];
var ALIASES = { none: "crew", plain: "crew" };

// The settings' words: a label, bin/bar's tagline for the look, and its type.
var META = {
    crew: { label: "Crew", sub: "The plain island", font: "Adwaita Sans", moment: "" },
    phosphor: { label: "Phosphor", sub: "Green screen, no mercy", font: "Monaspace Argon", moment: "signoff" },
    bridge: { label: "Bridge", sub: "Riker's on the bridge", font: "Antonio", moment: "hail" },
    arcade: { label: "Arcade", sub: "Insert coin", font: "Press Start 2P", moment: "hail" },
    liner: { label: "Liner Notes", sub: "Ink on good paper", font: "Monaspace Radon", moment: "signoff" },
    outrun: { label: "Outrun", sub: "Tape hiss and neon grids", font: "Monaspace Argon", moment: "nowplaying" }
};

// The moments a look's moment line covers. A hail look draws the hail in
// its own cell; a signoff or nowplaying look peeks its line on the island's
// `moment` state (a theme or look switch, a new track).
var MOMENT_KINDS = ["signoff", "hail", "nowplaying"];

// Looks the contrast audit could not make pass on light packs. None today:
// the fg fallback covers every pair on all 37 packs (tests/look-contrast.cjs).
var DARK_ONLY = [];

// Text reaches 4.5, glyphs (bots, invaders, hearts, the play triangle) 3;
// a gauge's empty steps only need to show (1.4).
var TEXT_MIN = 4.5;
var GLYPH_MIN = 3;
var SCALE_MIN = 1.4;

function canonical(name) {
    var n = String(name === undefined || name === null ? "" : name).trim().toLowerCase();
    if (ALIASES[n]) n = ALIASES[n];
    return LOOKS.indexOf(n) >= 0 ? n : "";
}

function meta(name) {
    return META[canonical(name)] || META.crew;
}

function momentKind(name) {
    return meta(name).moment;
}

function darkOnly(name) {
    return DARK_ONLY.indexOf(canonical(name)) >= 0;
}

// Whether the look draws on a pack: any look but crew, except a dark-only one on a light pack.
function shows(name, dark) {
    var n = canonical(name);
    return n !== "" && n !== "crew" && (dark !== false || !darkOnly(n));
}

// ---- colour maths (lib/TokenMath.js's) ---------------------------------------

function hx(h) {
    var s = String(h || "#000000").trim().replace(/^#/, "");
    return [parseInt(s.slice(0, 2), 16), parseInt(s.slice(2, 4), 16), parseInt(s.slice(4, 6), 16)];
}
function toHex(chans) {
    return "#" + chans.map(function (v) {
        var n = Math.floor(Math.max(0, Math.min(255, v)) + 0.5);
        return (n < 16 ? "0" : "") + n.toString(16);
    }).join("");
}
function mix(a, b, t) {
    var x = hx(a), y = hx(b);
    return toHex(x.map(function (v, i) {
        return v + (y[i] - v) * t;
    }));
}
function lum(h) {
    var c = hx(h).map(function (v) {
        v = v / 255;
        return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
    });
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
}
function contrast(a, b) {
    var x = lum(a), y = lum(b);
    return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05);
}

// `color` where it reaches `min` on `ground`, else `fallback`.
function pick(color, ground, min, fallback) {
    return contrast(color, ground) >= min ? color : fallback;
}
// `color` faded toward `ground`, mixed at `t` (the board's opacity) or at
// the least step of .05 above it that still reaches `min`; `color` itself
// when none does. One colour, drawn at full opacity.
function fade(color, ground, t, min) {
    for (var k = Math.round(t * 20); k < 20; k++) {
        var c = mix(ground, color, k / 20);
        if (contrast(c, ground) >= min) return c;
    }
    return color;
}
// Black where it reaches 4.5 on `fill`, else white (one of them always does).
function blackOrWhite(fill) {
    return contrast("#000000", fill) >= TEXT_MIN ? "#000000" : "#ffffff";
}

// The live segment (Island/LiveSegment: the recording dot, the elapsed time
// and Stop, the mic, keep awake, DND) in a look's inks: a look restyles the
// segment, it never drops it. text: the elapsed time; dim: the mic's app and
// the time left; accent: the mic, coffee and moon icons; dot: the recording
// dot; divider: the 1 x 16 rule before it; button, buttonInk: Stop; ring: a
// 1 px ring round a Stop filled with the ground ("" for none). buttonPressed
// is Stop held down; radius its corners (the plain pill's 13, Phosphor's and
// Arcade's square ones).
function live(text, dim, accent, dot, divider, button, buttonInk, ring, radius) {
    return { text: text, dim: dim, accent: accent, dot: dot, divider: divider, button: button,
             buttonPressed: mix(button, buttonInk, 0.2), buttonInk: buttonInk, ring: ring,
             radius: typeof radius === "number" ? radius : 13 };
}

// ---- inks ------------------------------------------------------------------

// Every colour a look draws with, resolved for the tokens `t`. Keys per look:
//   ground   the island's fill under the text
//   text     the main ink; dim the quiet one; and the look's own extras
function ink(name, t) {
    var n = canonical(name);
    if (n === "phosphor") {
        var pg = t.darker;
        var p = pick(t.accent, pg, TEXT_MIN, t.fg);
        // The asleep face is the ink at .6 on the board: that colour, mixed
        // and drawn at full opacity, where it reaches 4.5, else the dimmest
        // step above .6 that does (fade()).
        // The focused tab: the ink as fill, its letter in the ground.
        return { ground: pg, text: p, dim: p, accent: p, tabFill: p, tabText: pg, glow: p,
                 asleep: fade(p, pg, 0.6, TEXT_MIN),
                 live: live(p, p, p, pick(t.bad, pg, GLYPH_MIN, p), mix(pg, p, 0.5), p, pg, "", 0) };
    }
    if (n === "bridge") {
        var seg = { cap: t.accent, stardate: t.cyan, clock: t.fg, focused: t.fg, other: t.blue, team: t.magenta, hail: t.accent, screen: t.magentaBright };
        var inks = {};
        for (var k in seg)
            inks[k] = blackOrWhite(seg[k]);
        // On the black body itself (the fallback cards): fg, white on a
        // light pack (its fg is dark), and the dim ink and accent where they
        // read on black.
        var bt = pick(t.fg, "#000000", TEXT_MIN, "#ffffff");
        var bd = pick(t.inkDim, "#000000", TEXT_MIN, bt);
        var ba = pick(t.accent, "#000000", GLYPH_MIN, bt);
        return { ground: "#000000", text: bt, dim: bd, accent: ba, segments: seg, inks: inks,
                 live: live(bt, bd, ba, pick(t.bad, "#000000", GLYPH_MIN, bt), mix("#000000", bt, 0.3), seg.screen, inks.screen, "") };
    }
    if (n === "arcade") {
        var ag = t.darker;
        var at = pick(t.fg, ag, TEXT_MIN, blackOrWhite(ag));
        return {
            ground: ag, text: at, dim: pick(t.inkDim, ag, TEXT_MIN, at),
            accent: pick(t.accent, ag, TEXT_MIN, at),
            bad: pick(t.bad, ag, TEXT_MIN, at),
            heart: pick(t.bad, ag, GLYPH_MIN, at),
            // The empty hearts are the gauge's scale, not a mark of their own:
            // the board's fillHigh where it shows at all (1.4, every dark pack),
            // else the text ink at .3 over the ground (light packs, where
            // fillHigh and darker are one colour).
            heartEmpty: contrast(t.fillHigh, ag) >= SCALE_MIN ? t.fillHigh : mix(ag, at, 0.3),
            invader: pick(t.fg, ag, GLYPH_MIN, at), invaderNeeds: pick(t.accent, ag, GLYPH_MIN, pick(t.bad, ag, GLYPH_MIN, at)),
            invaderAsleep: pick(t.inkDim, ag, GLYPH_MIN, at),
            ring: at, star: t.fg,
            live: live(at, pick(t.inkDim, ag, TEXT_MIN, at), pick(t.accent, ag, GLYPH_MIN, at), pick(t.bad, ag, GLYPH_MIN, at), mix(ag, at, 0.3), ag, at, at, 0)
        };
    }
    if (n === "liner") {
        var lg = t.surface;
        // The board's unfocused letters are fg at .6 opacity: that colour,
        // mixed here and drawn at full opacity (one fade, so what the audit
        // tests is what is on screen), or inkDim where it misses 4.5.
        var faded = mix(lg, t.fg, 0.6);
        var la = pick(t.accent, lg, GLYPH_MIN, t.fg), ls = pick(t.bad, lg, TEXT_MIN, t.fg);
        return {
            ground: lg, text: t.fg, faded: pick(faded, lg, TEXT_MIN, t.inkDim),
            dim: t.inkDim, accent: la, stamp: ls, ring: t.hairline,
            live: live(t.fg, t.inkDim, la, pick(t.bad, lg, GLYPH_MIN, t.fg), t.hairline, t.fillHigh, t.fg, "")
        };
    }
    if (n === "outrun") {
        var og = t.bg;
        var od = pick(t.inkDim, og, TEXT_MIN, pick(t.inkMid, og, TEXT_MIN, t.fg));
        var ot = pick(t.fg, og, TEXT_MIN, blackOrWhite(og)), oc = pick(t.cyan, og, GLYPH_MIN, t.fg);
        return {
            ground: og, text: ot, dim: od,
            cyan: t.cyan, magenta: t.magenta,
            botNeeds: oc, botAsleep: pick(t.inkDim, og, GLYPH_MIN, t.fg),
            play: oc, accent: oc,
            live: live(ot, od, oc, pick(t.bad, og, GLYPH_MIN, ot), t.magenta, og, ot, t.cyan)
        };
    }
    return { ground: t.surface, text: t.fg, dim: t.inkDim, accent: t.accent };
}

// The text and glyph pairs a look puts on screen: [{ what, fg, bg, min }].
function pairs(name, t) {
    var n = canonical(name), i = ink(n, t), out = [];
    function add(what, fg, bg, min) {
        out.push({ what: what, fg: fg, bg: bg, min: min });
    }
    if (n === "phosphor") {
        add("text", i.text, i.ground, TEXT_MIN);
        add("focused tab", i.tabText, i.tabFill, TEXT_MIN);
        add("asleep face", i.asleep, i.ground, TEXT_MIN);
    } else if (n === "bridge") {
        for (var k in i.segments)
            add(k + " segment", i.inks[k], i.segments[k], TEXT_MIN);
        add("text on black", i.text, i.ground, TEXT_MIN);
        add("dim on black", i.dim, i.ground, TEXT_MIN);
        add("bot on black", i.accent, i.ground, GLYPH_MIN);
    } else if (n === "arcade") {
        add("text", i.text, i.ground, TEXT_MIN);
        add("dim", i.dim, i.ground, TEXT_MIN);
        add("stage, crew", i.accent, i.ground, TEXT_MIN);
        add("1UP, needs you", i.bad, i.ground, TEXT_MIN);
        add("heart", i.heart, i.ground, GLYPH_MIN);
        add("empty heart", i.heartEmpty, i.ground, SCALE_MIN);
        add("invader", i.invader, i.ground, GLYPH_MIN);
        add("invader needs", i.invaderNeeds, i.ground, GLYPH_MIN);
        add("invader asleep", i.invaderAsleep, i.ground, GLYPH_MIN);
    } else if (n === "liner") {
        add("text", i.text, i.ground, TEXT_MIN);
        add("letters", i.faded, i.ground, TEXT_MIN);
        add("tagline", i.dim, i.ground, TEXT_MIN);
        add("stamp", i.stamp, i.ground, TEXT_MIN);
        add("scribble", i.accent, i.ground, GLYPH_MIN);
    } else if (n === "outrun") {
        add("text", i.text, i.ground, TEXT_MIN);
        add("letters, artist", i.dim, i.ground, TEXT_MIN);
        add("bot needs", i.botNeeds, i.ground, GLYPH_MIN);
        add("bot asleep", i.botAsleep, i.ground, GLYPH_MIN);
        add("play", i.play, i.ground, GLYPH_MIN);
    }
    // The live segment, wherever a look draws one (every look but crew).
    if (i.live) {
        add("live time", i.live.text, i.ground, TEXT_MIN);
        add("live label", i.live.dim, i.ground, TEXT_MIN);
        add("live icon", i.live.accent, i.ground, GLYPH_MIN);
        add("recording dot", i.live.dot, i.ground, GLYPH_MIN);
        add("Stop", i.live.buttonInk, i.live.button, TEXT_MIN);
    }
    out.forEach(function (p) {
        p.ratio = contrast(p.fg, p.bg);
    });
    return out;
}

// ---- material -----------------------------------------------------------------

// The island body for a look's cell: { height (0: the state's own), radius
// (-1: min(28, h / 2)), fill, ring, ringWidth, glow ("" for none), glowAlpha,
// glowBlur, shadow ("shadow" | "shadow2" | "") }. cell is "rest", the look's
// moment kind, or "card" (a Crew card in the look's skin).
function material(name, cell, t) {
    var n = canonical(name), i = ink(n, t);
    var m = { height: 0, radius: -1, fill: t.surface, ring: t.hairline, ringWidth: 1, glow: "", glowAlpha: 0, glowBlur: 0, shadow: "shadow" };
    if (n === "phosphor")
        return set(m, { height: cell === "card" ? 0 : 36, radius: 4, fill: i.ground, ring: i.text, ringWidth: 1, glow: i.glow, glowAlpha: 0.35, glowBlur: 14, shadow: "" });
    if (n === "bridge")
        return set(m, { height: cell === "card" ? 0 : 32, radius: cell === "card" ? -1 : 16, fill: "#000000", ring: "#000000", ringWidth: 0, shadow: "" });
    if (n === "arcade")
        return set(m, { height: cell === "card" ? 0 : 38, radius: 0, fill: i.ground, ring: i.ring, ringWidth: 2, shadow: "" });
    if (n === "liner")
        return set(m, { height: cell === "card" ? 0 : 40, radius: cell === "card" ? -1 : 20, fill: i.ground, ring: i.ring, ringWidth: 1, shadow: "" });
    if (n === "outrun") {
        if (cell === "nowplaying")
            return set(m, { height: 40, radius: 20, fill: i.ground, ring: t.magenta, ringWidth: 1.5, glow: t.magenta, glowAlpha: 0.6, glowBlur: 12, shadow: "" });
        return set(m, { height: cell === "card" ? 0 : 40, radius: cell === "card" ? -1 : 20, fill: i.ground, ring: i.ground, ringWidth: 0, shadow: "shadow2" });
    }
    return m;
}
function set(m, over) {
    for (var k in over)
        m[k] = over[k];
    return m;
}

// The Crew cards' type and inks in a look (the fallback cells): { font,
// italic, upper, spacing, scale (of the card's sizes), ink, dim, accent,
// button, buttonInk, buttonPressed, voice (vibes' face), ground (the fill
// they sit on) }. A button filled with the ground gets a 1 px ring in its ink.
function skin(name, t) {
    var n = canonical(name), i = ink(n, t);
    var s = { font: "Adwaita Sans", italic: false, upper: false, spacing: 0, scale: 1, ink: t.fg, dim: t.inkDim, accent: t.accent, button: t.fillHigh, buttonInk: t.fg, voice: "Monaspace Radon", ground: i.ground };
    if (n === "phosphor") set(s, { font: "Monaspace Argon", ink: i.text, dim: i.text, accent: i.text, button: i.tabFill, buttonInk: i.tabText, voice: "Monaspace Argon" });
    else if (n === "bridge") set(s, { font: "Antonio", upper: true, spacing: 0.6, ink: i.text, dim: i.dim, accent: i.accent, button: i.segments.screen, buttonInk: i.inks.screen, voice: "Antonio" });
    else if (n === "arcade") set(s, { font: "Press Start 2P", scale: 10 / 13, ink: i.text, dim: i.dim, accent: i.accent, button: i.ground, buttonInk: i.bad, voice: "Press Start 2P" });
    else if (n === "liner") set(s, { font: "Monaspace Radon", italic: true, ink: i.text, dim: i.dim, accent: i.accent, voice: "Monaspace Radon" });
    else if (n === "outrun") set(s, { font: "Monaspace Argon", ink: i.text, dim: i.dim, accent: i.accent, button: i.ground, buttonInk: i.text, voice: "Monaspace Argon" });
    // The button held down: a step toward its ink (the plain card's fillLow
    // for fillHigh, in the look's colours).
    s.buttonPressed = mix(s.button, s.buttonInk, 0.2);
    return s;
}

// ---- the looks' small pure pieces ---------------------------------------------

// Phosphor's crew (the board's faces; OmniWM's [o_o] lost to the mock).
var FACES = { working: "[^_^]", needs: "[O_O]!", asleep: "[-_-]z" };
function face(mood) {
    return FACES[mood] || FACES.asleep;
}

// Arcade's hearts for a battery percent: ceil(percent / 25), 0 to 4. -1
// without a battery (a desktop, no UPower), and the hearts hide.
function hearts(percent) {
    if (percent === null || percent === undefined || percent === "" || isNaN(Number(percent))) return -1;
    var p = Number(percent);
    if (p < 0) return -1;
    return Math.max(0, Math.min(4, Math.ceil(p / 25)));
}

// The vibes line per look (personal-looks 3.7: OmniWM's own lines kept).
function vibesLine(name) {
    var n = canonical(name);
    return n === "bridge" ? "engage" : n === "arcade" ? "STAGE CLEAR" : "vibes: immaculate";
}

// Arcade's status line, left to right: { score, crew, needs } ("" hides a part).
// The board's "HI [spend]" prints OmniWM's "HI %d" (whole dollars); n in
// "Player n needs you" is the 1-based place of the first agent needing you.
function arcadeStatus(agents, total, spend) {
    var list = agents || [];
    var at = -1;
    for (var k = 0; k < list.length; k++)
        if (list[k] && list[k].attention) {
            at = k;
            break;
        }
    var s = spend === null || spend === undefined || isNaN(Number(spend)) ? "" : "HI " + Math.floor(Number(spend));
    return { score: s, crew: "Crew x" + (Number(total) || 0), needs: at >= 0 ? "Player " + (at + 1) + " needs you" : "" };
}

// Bridge's away team segment: "Away team 4", with OmniWM's " · 1 hailing".
function awayTeam(total, attention) {
    var s = "Away team " + (Number(total) || 0);
    return Number(attention) > 0 ? s + " · " + attention + " hailing" : s;
}

// Arcade's stars inside a w x h island: the board's 70 over 656 x 212,
// thinned to the same density (at least 3), each { x, y, alpha }.
function stars(w, h) {
    var W = Math.max(0, Math.floor(w)), H = Math.max(0, Math.floor(h));
    if (W < 4 || H < 4) return [];
    var count = Math.max(3, Math.round(70 * W * H / (656 * 212)));
    var out = [];
    for (var i = 0; i < count; i++)
        out.push({ x: (i * 97) % (W - 2), y: (i * 53 + (i % 7) * 29) % (H - 2), alpha: [0.25, 0.45, 0.7][i % 3] });
    return out;
}

if (typeof module !== "undefined")
    module.exports = {
        LOOKS: LOOKS, ALIASES: ALIASES, META: META, MOMENT_KINDS: MOMENT_KINDS, DARK_ONLY: DARK_ONLY, TEXT_MIN: TEXT_MIN, GLYPH_MIN: GLYPH_MIN,
        canonical: canonical, meta: meta, momentKind: momentKind, darkOnly: darkOnly, shows: shows,
        mix: mix, fade: fade, contrast: contrast, pick: pick, blackOrWhite: blackOrWhite, live: live,
        ink: ink, pairs: pairs, material: material, skin: skin,
        FACES: FACES, face: face, hearts: hearts, vibesLine: vibesLine, arcadeStatus: arcadeStatus, awayTeam: awayTeam, stars: stars
    };
