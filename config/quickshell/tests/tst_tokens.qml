import QtQuick
import QtTest

// Tokens.qml + lib/TokenMath.js against the 8 vectors in
// .shell-rebuild/specs/main-tokens.md section 1.4, exact. Runs in qmltestrunner
// beside Tokens.qml, lib/TokenMath.js and stub Theme/Motion singletons:
//   Theme.qml   pragma Singleton; QtObject { property var palette: ({}) }
//   Motion.qml  pragma Singleton; QtObject { property int effects: 0;
//               property var spring: [0.30, 0.553, 0.06, 1.0, 1, 1] }
//   qmldir      singleton Theme 1.0 Theme.qml / Motion / Tokens likewise
TestCase {
    id: test
    name: "Tokens"
    when: windowShown
    visible: true
    width: 100
    height: 100

    // The mock's embedded palettes (Tokens.dc.html palettes()), colour keys only.
    readonly property var palettes: ({
        "hackerman": {"background": "#0b0c16", "foreground": "#ddf7ff", "accent": "#82fb9c", "muted": "#2d3450", "red": "#50f872", "yellow": "#50f7d4", "cyan": "#7cf8f7", "blue": "#829dd4", "magenta": "#86a7df", "bright_magenta": "#cddbf4", "darker_background": "#06060c", "dark_foreground": "#6a6e95", "mode": "dark", "tagline": "green phosphor, no mercy"},
        "tokyo-night": {"background": "#1a1b26", "foreground": "#a9b1d6", "accent": "#7aa2f7", "muted": "#414868", "red": "#f7768e", "yellow": "#e0af68", "cyan": "#449dab", "blue": "#7aa2f7", "magenta": "#ad8ee6", "bright_magenta": "#bb9af7", "darker_background": "#0e0e14", "dark_foreground": "#565f89", "mode": "dark", "tagline": "neon rain over the sumida"},
        "gruvbox-material": {"background": "#342f2c", "foreground": "#dcceb3", "accent": "#ce8d6b", "muted": "#776f62", "red": "#d28f7b", "yellow": "#dcceb3", "cyan": "#8fb8ab", "blue": "#92a8b8", "magenta": "#c197b4", "bright_magenta": "#dac0d0", "darker_background": null, "dark_foreground": "#776f62", "mode": "dark", "tagline": "same groove, softer edges"},
        "nord": {"background": "#2e3440", "foreground": "#d8dee9", "accent": "#81a1c1", "muted": "#4c566a", "red": "#bf616a", "yellow": "#ebcb8b", "cyan": "#88c0d0", "blue": "#81a1c1", "magenta": "#b48ead", "bright_magenta": "#b48ead", "darker_background": "#191c23", "dark_foreground": "#667080", "mode": "dark", "tagline": "cold light on the fjord"},
        "retro-82": {"background": "#05182e", "foreground": "#f6dcac", "accent": "#faa968", "muted": "#2a6b78", "red": "#f85525", "yellow": "#e97b3c", "cyan": "#8cbfb8", "blue": "#3f8f8a", "magenta": "#3f8f8a", "bright_magenta": "#3f8f8a", "darker_background": "#020c17", "dark_foreground": "#3f8f8a", "mode": "dark", "tagline": "tape hiss and neon grids"},
        "lumon": {"background": "#16242d", "foreground": "#d6e2ee", "accent": "#8bc9eb", "muted": "#304860", "red": "#4d86b0", "yellow": "#6fa4c9", "cyan": "#b4e4f6", "blue": "#6fb8e3", "magenta": "#8bc9eb", "bright_magenta": "#b1d8ee", "darker_background": "#0b1216", "dark_foreground": "#4d86b0", "mode": "dark", "tagline": "please enjoy each color equally"},
        "catppuccin-latte": {"background": "#eff1f5", "foreground": "#4c4f69", "accent": "#1e66f5", "muted": "#acb0be", "red": "#d20f39", "yellow": "#df8e1d", "cyan": "#179299", "blue": "#1e66f5", "magenta": "#ea76cb", "bright_magenta": "#ea76cb", "darker_background": "#d7d8dc", "dark_foreground": "#9ca0b0", "mode": "light", "tagline": "the same pastel, morning light"},
        "rose-pine": {"background": "#faf4ed", "foreground": "#575279", "accent": "#56949f", "muted": "#cecacd", "red": "#b4637a", "yellow": "#ea9d34", "cyan": "#d7827e", "blue": "#56949f", "magenta": "#907aa9", "bright_magenta": "#907aa9", "darker_background": "#e1dbd5", "dark_foreground": "#9893a5", "mode": "light", "tagline": "soho vibes, faux fur"}
    })

    // main-tokens.md section 1.4, verbatim.
    readonly property var vectors: ({"hackerman":{"mode":"dark","surface":"#13151f","raised":"#1c1f29","overlay":"#242832","hairline":"#2f353e","fillLow":"#1f232c","fillHigh":"#2d323c","inkDim":"#8d9ea6","k":0.62,"inkMid":"#78868f","faint":"#5a646d","accentTint":"#253a33","onAccent":"#0b0c16","bad":"#ff6b6b","redNearAccent":true,"darker":"#06060c","ratios":{"fg":16.3,"inkDim":6.6,"onAccent":15.0}},
    "tokyo-night":{"mode":"dark","surface":"#20212d","raised":"#252734","overlay":"#2b2d3b","hairline":"#333545","fillLow":"#282a37","fillHigh":"#323443","inkDim":"#8187a5","k":0.72,"inkMid":"#737893","faint":"#505368","accentTint":"#2e364d","onAccent":"#1a1b26","bad":"#f7768e","redNearAccent":false,"darker":"#0e0e14","ratios":{"fg":7.6,"inkDim":4.5,"onAccent":6.8}},
    "gruvbox-material":{"mode":"dark","surface":"#3b3531","raised":"#413c37","overlay":"#48423c","hairline":"#524a43","fillLow":"#453e39","fillHigh":"#504942","inkDim":"#aa9e8b","k":0.70,"inkMid":"#998e7d","faint":"#736b5f","accentTint":"#53433a","onAccent":"#342f2c","bad":"#ff6b6b","redNearAccent":true,"darker":"#24211f","ratios":{"fg":7.8,"inkDim":4.6,"onAccent":4.8}},
    "nord":{"mode":"dark","surface":"#353b47","raised":"#3c424e","overlay":"#424854","hairline":"#4c525e","fillLow":"#3f4551","fillHigh":"#4a505c","inkDim":"#a2a8b3","k":0.68,"inkMid":"#9197a2","faint":"#6e747f","accentTint":"#414b5b","onAccent":"#2e3440","bad":"#bf616a","redNearAccent":false,"darker":"#191c23","ratios":{"fg":8.3,"inkDim":4.7,"onAccent":4.6}},
    "retro-82":{"mode":"dark","surface":"#0f2033","raised":"#182838","overlay":"#22303d","hairline":"#2f3a44","fillLow":"#1d2b3a","fillHigh":"#2d3843","inkDim":"#9a927c","k":0.62,"inkMid":"#827e70","faint":"#5f625d","accentTint":"#35363b","onAccent":"#05182e","bad":"#ff6b6b","redNearAccent":true,"darker":"#020c17","ratios":{"fg":12.4,"inkDim":5.3,"onAccent":9.3}},
    "lumon":{"mode":"dark","surface":"#1e2c35","raised":"#25333c","overlay":"#2d3b44","hairline":"#38454f","fillLow":"#293740","fillHigh":"#36444d","inkDim":"#8d9aa5","k":0.62,"inkMid":"#7a8791","faint":"#5e6b75","accentTint":"#2f4552","onAccent":"#16242d","bad":"#ff6b6b","redNearAccent":true,"darker":"#0b1216","ratios":{"fg":10.9,"inkDim":5.0,"onAccent":8.8}},
    "catppuccin-latte":{"mode":"light","surface":"#e8ebef","raised":"#e2e4ea","overlay":"#dbdee4","hairline":"#d2d5dc","fillLow":"#dfe2e7","fillHigh":"#d4d7de","inkDim":"#66697f","k":0.84,"inkMid":"#76798d","faint":"#b2b4c1","accentTint":"#ccd8f0","onAccent":"#ffffff","bad":"#d20f39","redNearAccent":false,"darker":"#d7d8dc","ratios":{"fg":6.7,"inkDim":4.5,"onAccent":4.9}},
    "rose-pine":{"mode":"light","surface":"#f3eee8","raised":"#ede7e4","overlay":"#e6e1df","hairline":"#ddd8d8","fillLow":"#eae5e1","fillHigh":"#dfdada","inkDim":"#6e6989","k":0.86,"inkMid":"#7e7995","faint":"#bdb7c2","accentTint":"#dde1de","onAccent":"#000000","bad":"#b4637a","redNearAccent":false,"darker":"#e1dbd5","ratios":{"fg":6.3,"inkDim":4.5,"onAccent":6.1}}})

    // PLAN.md 1.4 contrast fix: `bad` steps toward fg until 4.5:1 on surface.
    // The vector's `bad` is the hue pick before that step (d.badBase); these
    // three are under 4.5:1 there (4.35, 2.75, 3.64) and move.
    readonly property var steppedBad: ({"gruvbox-material": "#fc7371", "nord": "#ca98a2", "rose-pine": "#8f5c7a"})

    readonly property var colorKeys: ["surface", "raised", "overlay", "hairline", "fillLow", "fillHigh",
        "inkDim", "inkMid", "faint", "accentTint", "onAccent", "darker"]

    function show(palette) {
        Tokens.animate = false; // values land at once; test_cross_fade covers the Behaviors
        Tokens.previewPalette = palette;
    }

    function cleanup() {
        Motion.effects = 0;
        Tokens.animate = false;
        Tokens.previewPalette = null;
        Theme.palette = ({});
    }

    function test_vectors_data() {
        return Object.keys(vectors).map(name => ({tag: name, name: name}));
    }
    function test_vectors(data) {
        const v = vectors[data.name];
        show(palettes[data.name]);
        compare(Tokens.mode, v.mode);
        compare(Tokens.dark, v.mode === "dark");
        for (const key of colorKeys)
            compare(String(Tokens[key]), v[key], key);
        fuzzyCompare(Tokens.d.k, v.k, 1e-9, "k");
        compare(Tokens.d.redNearAccent, v.redNearAccent, "redNearAccent");
        compare(Tokens.d.badBase, v.bad, "bad before the contrast step");
        compare(String(Tokens.bad), steppedBad[data.name] ?? v.bad, "bad");
        compare(Number(Tokens.contrast(Tokens.fg, Tokens.surface).toFixed(1)), v.ratios.fg, "ratio fg");
        compare(Number(Tokens.contrast(Tokens.inkDim, Tokens.surface).toFixed(1)), v.ratios.inkDim, "ratio inkDim");
        compare(Number(Tokens.contrast(Tokens.onAccent, Tokens.accent).toFixed(1)), v.ratios.onAccent, "ratio onAccent");
    }

    function test_contrast_fixes_data() {
        return Object.keys(vectors).map(name => ({tag: name, name: name}));
    }
    function test_contrast_fixes(data) {
        const p = palettes[data.name];
        show(p);
        verify(Tokens.contrast(Tokens.bad, Tokens.surface) >= 4.5,
               "bad " + Tokens.bad + " reads at 4.5:1 on surface");
        if (!steppedBad[data.name])
            compare(String(Tokens.bad), Tokens.d.badBase, "no step when the hue pick already reads");
        // the play icon on an fg fill is bg (PLAN.md 1.4); rose-pine is the tightest at 6.66:1
        compare(String(Tokens.onFg), p.background, "onFg");
        verify(Tokens.contrast(Tokens.onFg, Tokens.fg) >= 6.6, "onFg on fg " + Tokens.contrast(Tokens.onFg, Tokens.fg));
    }

    function test_passthrough() {
        const p = palettes["hackerman"];
        show(p);
        compare(String(Tokens.bg), p.background);
        compare(String(Tokens.fg), p.foreground);
        compare(String(Tokens.ink), p.foreground);
        compare(String(Tokens.accent), p.accent);
        compare(String(Tokens.red), p.red);
        compare(String(Tokens.cyan), p.cyan);
        compare(String(Tokens.magenta), p.magenta);
        compare(String(Tokens.magentaBright), p.bright_magenta);
        compare(String(Tokens.muted), p.muted);
        compare(String(Tokens.darkFg), p.dark_foreground);
        compare(String(Tokens.slate), "#1a1c26", "slate (personal-looks 1.1)");
        compare(Tokens.tagline, p.tagline);
        show(palettes["rose-pine"]);
        compare(String(Tokens.slate), "#faf4ed", "light slate is bg");
        compare(String(Tokens.magentaBright), "#907aa9");
    }

    function fuzzyColor(actual, r, g, b, a, msg) {
        fuzzyCompare(actual.r * 255, r, 0.01, msg + " r");
        fuzzyCompare(actual.g * 255, g, 0.01, msg + " g");
        fuzzyCompare(actual.b * 255, b, 0.01, msg + " b");
        fuzzyCompare(actual.a, a, 0.001, msg + " a");
    }

    function test_alpha_tokens() {
        show(palettes["hackerman"]);
        fuzzyColor(Tokens.shadow, 0, 0, 0, 0.45, "shadow dark");
        fuzzyColor(Tokens.shadow2, 0, 0, 0, 0.5, "shadow2 dark");
        fuzzyColor(Tokens.scrim, 0x0b, 0x0c, 0x16, 0.56, "scrim");
        fuzzyColor(Tokens.darkerA72, 0x06, 0x06, 0x0c, 0.72, "darkerA72");
        fuzzyColor(Tokens.accentA35, 0x82, 0xfb, 0x9c, 0.35, "accentA35");
        fuzzyColor(Tokens.accentA5, 0x82, 0xfb, 0x9c, 0.05, "accentA5");
        fuzzyColor(Tokens.cyanA55, 0x7c, 0xf8, 0xf7, 0.55, "cyanA55");
        fuzzyColor(Tokens.magentaA60, 0x86, 0xa7, 0xdf, 0.60, "magentaA60");
        fuzzyColor(Tokens.fgA50, 0xdd, 0xf7, 0xff, 0.50, "fgA50");
        fuzzyColor(Tokens.alpha("#ff0000", 0.25), 255, 0, 0, 0.25, "alpha()");
        show(palettes["catppuccin-latte"]);
        fuzzyColor(Tokens.shadow, 0, 0, 0, 0.14, "shadow light");
        fuzzyColor(Tokens.shadow2, 0, 0, 0, 0.18, "shadow2 light");
    }

    // p = previewPalette ?? Theme.palette; colors.json tokens win over derive()
    function test_palette_precedence() {
        show(null);
        Theme.palette = ({});
        compare(String(Tokens.bg), "#1a1b26", "no colors.json yet: Theme.qml's Tokyo Night look");
        compare(String(Tokens.surface), vectors["tokyo-night"].surface);
        compare(String(Tokens.inkDim), vectors["tokyo-night"].inkDim);

        const live = Object.assign({}, palettes["nord"], {surface: "#123456", bad: "#ee0000", darker: "#010203", shadow_alpha: "0.3"});
        Theme.palette = live;
        compare(String(Tokens.surface), "#123456", "colors.json surface wins");
        compare(String(Tokens.hairline), mixHex("#123456", live.foreground, 0.14), "and derive() builds on it");
        compare(String(Tokens.bad), "#ee0000", "colors.json bad wins");
        compare(String(Tokens.darker), "#010203", "colors.json darker wins over darker_background");
        fuzzyCompare(Tokens.shadowAlpha, 0.3, 1e-9, "shadow_alpha string is read as a number");
        compare(String(Tokens.raised), vectors["nord"].raised, "missing tokens fall back to derive()");

        Tokens.animate = false;
        Tokens.previewPalette = palettes["hackerman"];
        compare(String(Tokens.surface), vectors["hackerman"].surface, "preview wins over the live palette");
        Tokens.animate = false;
        Tokens.previewPalette = null;
        compare(String(Tokens.surface), "#123456", "clearing the preview restores the live palette");
    }

    // per-channel JS Math.round mix, the rule TokenMath uses
    function mixHex(a, b, t) {
        const x = [1, 3, 5].map(i => parseInt(a.slice(i, i + 2), 16));
        const y = [1, 3, 5].map(i => parseInt(b.slice(i, i + 2), 16));
        return "#" + x.map((v, i) => Math.floor(v + (y[i] - v) * t + 0.5).toString(16).padStart(2, "0")).join("");
    }

    function test_first_palette_snaps_then_fades() {
        show(null);
        Theme.palette = ({});
        Tokens.animate = false;
        Motion.effects = 400;
        Tokens.previewPalette = palettes["hackerman"];
        compare(String(Tokens.surface), vectors["hackerman"].surface, "first palette lands without a fade");
        tryCompare(Tokens, "animate", true, 1000, "animations switch on after the first palette");
    }

    // every colour token that carries a Behavior
    readonly property var fadedKeys: ["bg", "fg", "accent", "surface", "raised", "overlay", "hairline",
        "fillLow", "fillHigh", "inkDim", "inkMid", "faint", "accentTint", "inkOnAccent", "inkOnFg",
        "bad", "darker", "slate", "muted", "darkFg", "red", "green", "yellow", "blue", "cyan",
        "magenta", "magentaBright"]

    function test_cross_fade() {
        show(palettes["catppuccin-latte"]);
        const end = {};
        for (const key of fadedKeys) end[key] = Tokens.hex(Tokens[key]);
        show(palettes["hackerman"]);
        const start = {};
        for (const key of fadedKeys) start[key] = Tokens.hex(Tokens[key]);
        tryCompare(Tokens, "animate", true, 1000);
        Motion.effects = 400;
        Tokens.previewPalette = palettes["catppuccin-latte"];
        wait(100);
        const mid = Tokens.hex(Tokens.surface);
        verify(mid !== start.surface && mid !== end.surface, "surface is mid-fade at 100 of 400 ms: " + mid);
        for (const key of fadedKeys)
            if (start[key] !== end[key])
                verify(Tokens.hex(Tokens[key]) !== end[key], key + " fades rather than snapping");
        compare(Tokens.hex(Tokens.onAccent), Tokens.hex(Tokens.inkOnAccent), "onAccent follows the fade");
        compare(Tokens.hex(Tokens.onFg), Tokens.hex(Tokens.inkOnFg), "onFg follows the fade");
        verify(Tokens.shadowAlpha < 0.45 && Tokens.shadowAlpha > 0.14, "shadowAlpha fades too: " + Tokens.shadowAlpha);
        tryVerify(() => fadedKeys.every(key => Tokens.hex(Tokens[key]) === end[key]), 2000, "fade lands on the target");
        tryVerify(() => Math.abs(Tokens.shadowAlpha - 0.14) < 1e-9, 2000);
        compare(String(Tokens.onAccent), vectors["catppuccin-latte"].onAccent);
    }
}
