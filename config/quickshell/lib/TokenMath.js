// TokenMath.js: the island shell's colour tokens, derived from a palette.
//
// A port of shell_tokens() in bin/theme-color, which is the canonical rule set
// (itself a port of the design mocks' themeVals()). tests/token-parity.cjs pins
// derive() to `bin/theme-color --json` for every pack, so change both together.
//
// Tokens.qml prefers the token bin/theme-color already wrote into colors.json
// and falls back to derive(). The fallback covers a colors.json written before
// the tokens existed, picker previews built from bare palettes, and
// qmltestrunner, which has no colors.json at all.
//
// Input: a colors.json-shaped object (snake_case keys: background, foreground,
// accent, red, mode, darker_background, ...). Output: camelCase tokens as
// lowercase "#rrggbb" strings, plus a few numbers and flags. Pure functions,
// no QML types, so Node can require() this file too.
//
// Rounding is the point. Every mix rounds each channel like JS Math.round
// (floor(x + 0.5)) before it feeds the next step, and the ink_dim search adds
// 0.02 as a float exactly as theme-color does. Change either and the values
// drift a channel away from Plymouth and the mocks.

// Theme.qml's literals: the look until `theme` has run once on a machine.
var FALLBACK = {
    background: "#1a1b26", foreground: "#a9b1d6", accent: "#7aa2f7", red: "#f7768e",
    yellow: "#e0af68", green: "#9ece6a", cyan: "#0db9d7", blue: "#7aa2f7",
    magenta: "#ad8ee6", muted: "#444b6a", mode: "dark"
};

// colors.json key -> derive() key, for the tokens theme-color writes
var SNAKE = {
    surface: "surface", raised: "raised", overlay: "overlay", hairline: "hairline",
    fill_low: "fillLow", fill_high: "fillHigh", ink_dim: "inkDim", ink_mid: "inkMid",
    faint: "faint", accent_tint: "accentTint", on_accent: "onAccent", on_fg: "onFg",
    bad: "bad", darker: "darker", shadow_alpha: "shadowAlpha"
};

function isHex(v) {
    return typeof v === "string" && /^#?[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(v.trim());
}

// "#RRGGBB", "rrggbb" or "#rrggbbaa" -> "#rrggbb", the way theme-color's norm() reads a pack
function norm(v) {
    var h = v.trim().replace(/^#/, "");
    return "#" + h.slice(0, 6).toLowerCase();
}

function hx(h) {
    var s = norm(h);
    return [parseInt(s.slice(1, 3), 16), parseInt(s.slice(3, 5), 16), parseInt(s.slice(5, 7), 16)];
}

function jsRound(x) {
    return Math.floor(x + 0.5);
}

function toHex(chans) {
    return "#" + chans.map(function (v) {
        var n = jsRound(Math.max(0, Math.min(255, v)));
        return (n < 16 ? "0" : "") + n.toString(16);
    }).join("");
}

// a moved t of the way toward b, per channel, never clamping t (shell_tokens' _mix_js)
function mix(a, b, t) {
    var x = hx(a), y = hx(b);
    return toHex([0, 1, 2].map(function (i) { return x[i] + (y[i] - x[i]) * t; }));
}

// WCAG relative luminance, linearised at 0.03928 like the mocks (not 0.04045)
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

function hue(h) {
    var c = hx(h).map(function (v) { return v / 255; });
    var mx = Math.max(c[0], c[1], c[2]), mn = Math.min(c[0], c[1], c[2]), d = mx - mn;
    if (!d) return 0;
    var H;
    if (mx === c[0]) H = ((c[1] - c[2]) / d) % 6;
    else if (mx === c[1]) H = (c[2] - c[0]) / d + 2;
    else H = (c[0] - c[1]) / d + 4;
    return (H * 60 + 360) % 360;
}

// theme-color's luminance(): the 0..255 weighted sum it guesses a pack's mode from
function brightness(h) {
    var c = hx(h);
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
}

function derive(palette) {
    var p = palette || {};
    // a palette without both ends is not a palette: show Theme.qml's look instead
    var src = isHex(p.background ?? p.bg) && isHex(p.foreground ?? p.fg) ? p : FALLBACK;
    function pick() {
        for (var i = 0; i < arguments.length; i++) {
            var v = src[arguments[i]];
            if (isHex(v)) return norm(v);
        }
        return null;
    }
    var bg = pick("background", "bg");
    var fg = pick("foreground", "fg");
    var accent = pick("accent", "blue") || fg;
    var red = pick("red", "color1") || fg;
    var mode = src.mode || src.theme_type || (brightness(bg) > 128 ? "light" : "dark");
    var dark = mode !== "light";
    var t = { bg: bg, fg: fg, accent: accent, mode: mode, dark: dark };

    t.surface = pick("surface") || mix(bg, fg, 0.04);
    var surface = t.surface;
    var k = 0.62, ink = mix(bg, fg, k);
    while (contrast(ink, surface) < 4.5 && k < 1) { // first step that reads at 4.5:1
        k += 0.02;
        ink = mix(bg, fg, k);
    }
    t.k = k;
    t.inkDim = ink;
    t.inkMid = mix(bg, fg, Math.max(0.5, k - 0.1));
    t.raised = mix(bg, fg, 0.08);
    t.overlay = mix(bg, fg, 0.12);
    t.hairline = mix(surface, fg, 0.14);
    t.fillLow = mix(surface, fg, 0.06);
    t.fillHigh = mix(surface, fg, 0.13);
    t.faint = mix(bg, fg, 0.375);
    t.accentTint = mix(surface, accent, dark ? 0.16 : 0.14);

    var on = contrast(bg, accent) >= contrast(fg, accent) ? bg : fg;
    if (contrast(on, accent) < 4.5)
        on = contrast("#ffffff", accent) >= contrast("#000000", accent) ? "#ffffff" : "#000000";
    t.onAccent = on;
    // ink on an fg fill (the play button): onAccent is picked against accent, bg against fg
    on = bg;
    if (contrast(on, fg) < 4.5)
        on = contrast("#ffffff", fg) >= contrast("#000000", fg) ? "#ffffff" : "#000000";
    t.onFg = on;

    // errors in a red that reads as red (hackerman's "red" is a green, like its accent) ...
    var hd = Math.abs(hue(red) - hue(accent));
    t.redNearAccent = Math.min(hd, 360 - hd) < 40;
    t.badBase = t.redNearAccent ? (dark ? "#ff6b6b" : "#d20f39") : red;
    // ... and at 4.5:1 on surface, stepping toward fg on an integer counter
    var bad = t.badBase;
    for (var n = 0; contrast(bad, surface) < 4.5 && n < 50;) {
        n += 1;
        bad = mix(t.badBase, fg, n / 50);
    }
    t.bad = bad;

    // The pack's own darker_background, else a shallower step than the resolver's
    // 50%. Caveat: colors.json always carries darker_background, because the
    // resolver fills it with mix(bg, black, 50%) for packs without one, and five
    // packs set exactly that value by hand, so the two cannot be told apart here.
    // A colors.json from before the tokens therefore gets the resolver's 50% for
    // those 11 packs; the `darker` theme-color writes now is exact, and wins below.
    var own = pick("darker_background", "darker_bg");
    t.darker = own || mix(bg, "#000000", dark ? 0.3 : 0.06);
    t.shadowAlpha = dark ? 0.45 : 0.14;
    t.shadow2Alpha = dark ? 0.5 : 0.18;
    t.scrimAlpha = 0.56;
    t.slate = dark ? mix(bg, fg, 0.07) : bg;

    t.muted = pick("muted", "color8") || mix(bg, fg, 0.2);
    t.darkFg = pick("dark_foreground", "dark_fg") || mix(bg, fg, 0.45);
    t.red = red;
    t.green = pick("green", "color2") || fg;
    t.yellow = pick("yellow", "color3") || fg;
    t.blue = pick("blue", "color4") || fg;
    t.magenta = pick("magenta", "purple", "color5") || fg;
    t.cyan = pick("cyan", "color6") || fg;
    t.magentaBright = pick("bright_magenta", "bright_purple") || t.magenta;
    t.name = typeof src.name === "string" ? src.name : "";
    t.tagline = typeof src.tagline === "string" ? src.tagline : "";

    // shell_tokens() fills with setdefault: a token already in the palette (a
    // pack's own, or one theme-color wrote into colors.json) wins as output.
    // Only `surface` also feeds the derivation, as it does there.
    Object.keys(SNAKE).forEach(function (key) {
        var v = src[key];
        if (key === "shadow_alpha") {
            if (v !== undefined && v !== null && v !== "" && isFinite(Number(v))) t.shadowAlpha = Number(v);
        } else if (isHex(v)) {
            t[SNAKE[key]] = norm(v);
        }
    });
    return t;
}

if (typeof module !== "undefined")
    module.exports = { derive: derive, mix: mix, contrast: contrast, hue: hue, lum: lum, norm: norm, isHex: isHex, FALLBACK: FALLBACK };
