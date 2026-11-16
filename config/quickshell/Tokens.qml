pragma Singleton
// Tokens.qml - the one colour-token singleton every new island file reads.
// (pragma Singleton stays above every brace, comments included: see Icons.qml.)
//
// p is the palette on screen: the picker's preview when one is set, else the
// live colors.json (Theme.palette). d is TokenMath.derive(p), the JS port of
// bin/theme-color's shell_tokens(). Each token prefers the value theme-color
// wrote into colors.json and falls back to d, so a colors.json from before the
// tokens, a bare preview palette and qmltestrunner all get the same colours.
//
// QtQuick only, no Quickshell import: qmltestrunner loads this file with a stub
// Theme and Motion. New code reads colours here, never from Theme.
import QtQuick
import "lib/TokenMath.js" as TokenMath

QtObject {
    id: root

    // A palette to show instead of the live one (theme picker preview); null = live.
    // colors.json shape: background, foreground, accent, red, mode, ... (snake_case).
    property var previewPalette: null
    readonly property var p: previewPalette ?? Theme.palette ?? ({})
    readonly property var d: TokenMath.derive(p)

    readonly property bool dark: d.dark
    readonly property string mode: d.mode
    readonly property string name: d.name
    readonly property string tagline: d.tagline

    // ---- base palette --------------------------------------------------------
    property color bg: p.background ?? d.bg
    property color fg: p.foreground ?? d.fg
    readonly property color ink: fg
    property color accent: p.accent ?? d.accent

    // ---- surfaces, inks, states (shell_tokens) -------------------------------
    property color surface: p.surface ?? d.surface
    property color raised: p.raised ?? d.raised
    property color overlay: p.overlay ?? d.overlay
    property color hairline: p.hairline ?? d.hairline
    property color fillLow: p.fill_low ?? d.fillLow
    property color fillHigh: p.fill_high ?? d.fillHigh
    property color inkDim: p.ink_dim ?? d.inkDim
    property color inkMid: p.ink_mid ?? d.inkMid
    property color faint: p.faint ?? d.faint
    property color accentTint: p.accent_tint ?? d.accentTint
    // ink on accent fills; inkOnFg is ink on an fg fill (the control center's play icon)
    property color inkOnAccent: p.on_accent ?? d.onAccent
    property color inkOnFg: p.on_fg ?? d.onFg
    // The boards' names for those two. With `accent` and `fg` declared beside
    // them, Qt 6.12 silently drops an `onAccent: ...` or `onFg: ...` initializer
    // (the colour stays #000000; on<Name> reads as a handler name), and a
    // Behavior on either segfaults the object creator. So they are bound in
    // Component.onCompleted. Read-only by contract. Do not declare an on<Name>
    // property next to a <name> one in any other file either.
    property color onAccent
    property color onFg
    property color bad: p.bad ?? d.bad
    property color darker: p.darker ?? d.darker
    // The screens going dark before sleep (SleepFade.qml, the lock's own
    // fade): true black in every pack, light ones included, since `darker`
    // is a light grey there.
    readonly property color night: "#000000"
    property real shadowAlpha: Number(p.shadow_alpha ?? d.shadowAlpha)

    // ---- derived here, not in colors.json -------------------------------------
    // The panel's own black around a rounded screen (ScreenCorners.qml): the
    // bezel, whatever the theme.
    readonly property color bezel: "#000000"
    property color slate: d.slate
    property real shadow2Alpha: d.shadow2Alpha

    // ---- palette passthrough ---------------------------------------------------
    property color muted: p.muted ?? d.muted
    property color darkFg: p.dark_foreground ?? d.darkFg
    property color red: p.red ?? d.red
    property color green: p.green ?? d.green
    property color yellow: p.yellow ?? d.yellow
    property color blue: p.blue ?? d.blue
    property color cyan: p.cyan ?? d.cyan
    property color magenta: p.magenta ?? d.magenta
    property color magentaBright: p.bright_magenta ?? d.magentaBright

    // ---- alpha tokens, built from the animated colours above --------------------
    readonly property color shadow: Qt.rgba(0, 0, 0, shadowAlpha)
    readonly property color shadow2: Qt.rgba(0, 0, 0, shadow2Alpha)
    readonly property color scrim: alpha(bg, d.scrimAlpha)
    readonly property color darkerA72: alpha(darker, 0.72)
    readonly property color accentA5: alpha(accent, 0.05)
    readonly property color accentA35: alpha(accent, 0.35)
    readonly property color accentA50: alpha(accent, 0.50)
    readonly property color accentA55: alpha(accent, 0.55)
    readonly property color accentA60: alpha(accent, 0.60)
    readonly property color cyanA5: alpha(cyan, 0.05)
    readonly property color cyanA35: alpha(cyan, 0.35)
    readonly property color cyanA50: alpha(cyan, 0.50)
    readonly property color cyanA55: alpha(cyan, 0.55)
    readonly property color cyanA60: alpha(cyan, 0.60)
    readonly property color magentaA5: alpha(magenta, 0.05)
    readonly property color magentaA35: alpha(magenta, 0.35)
    readonly property color magentaA50: alpha(magenta, 0.50)
    readonly property color magentaA55: alpha(magenta, 0.55)
    readonly property color magentaA60: alpha(magenta, 0.60)
    readonly property color fgA5: alpha(fg, 0.05)
    readonly property color fgA35: alpha(fg, 0.35)
    readonly property color fgA50: alpha(fg, 0.50)
    readonly property color fgA55: alpha(fg, 0.55)
    readonly property color fgA60: alpha(fg, 0.60)

    function alpha(c: color, a: real): color {
        return Qt.rgba(c.r, c.g, c.b, a);
    }
    function hex(c: color): string {
        return "#" + [c.r, c.g, c.b].map(v => {
            const n = Math.round(v * 255);
            return (n < 16 ? "0" : "") + n.toString(16);
        }).join("");
    }
    // WCAG 2 contrast ratio, linearised at 0.03928 like the token rules
    function contrast(a: color, b: color): real {
        return TokenMath.contrast(hex(a), hex(b));
    }

    // ---- motion ----------------------------------------------------------------
    // Theme switches and picker previews cross-fade. The first real palette snaps
    // in, so the shell does not fade from the fallback look on every start.
    property bool animate: false
    function settle() {
        if (!animate && p && (p.background || p.bg))
            Qt.callLater(() => root.animate = true);
    }
    onPChanged: settle()
    Component.onCompleted: {
        root.onAccent = Qt.binding(() => root.inkOnAccent);
        root.onFg = Qt.binding(() => root.inkOnFg);
        settle();
    }

    component Fade: ColorAnimation {
        duration: Motion.effects
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.spring
    }
    component FadeNumber: NumberAnimation {
        duration: Motion.effects
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.spring
    }

    Behavior on bg { enabled: root.animate; Fade {} }
    Behavior on fg { enabled: root.animate; Fade {} }
    Behavior on accent { enabled: root.animate; Fade {} }
    Behavior on surface { enabled: root.animate; Fade {} }
    Behavior on raised { enabled: root.animate; Fade {} }
    Behavior on overlay { enabled: root.animate; Fade {} }
    Behavior on hairline { enabled: root.animate; Fade {} }
    Behavior on fillLow { enabled: root.animate; Fade {} }
    Behavior on fillHigh { enabled: root.animate; Fade {} }
    Behavior on inkDim { enabled: root.animate; Fade {} }
    Behavior on inkMid { enabled: root.animate; Fade {} }
    Behavior on faint { enabled: root.animate; Fade {} }
    Behavior on accentTint { enabled: root.animate; Fade {} }
    Behavior on inkOnAccent { enabled: root.animate; Fade {} }
    Behavior on inkOnFg { enabled: root.animate; Fade {} }
    Behavior on bad { enabled: root.animate; Fade {} }
    Behavior on darker { enabled: root.animate; Fade {} }
    Behavior on shadowAlpha { enabled: root.animate; FadeNumber {} }
    Behavior on slate { enabled: root.animate; Fade {} }
    Behavior on shadow2Alpha { enabled: root.animate; FadeNumber {} }
    Behavior on muted { enabled: root.animate; Fade {} }
    Behavior on darkFg { enabled: root.animate; Fade {} }
    Behavior on red { enabled: root.animate; Fade {} }
    Behavior on green { enabled: root.animate; Fade {} }
    Behavior on yellow { enabled: root.animate; Fade {} }
    Behavior on blue { enabled: root.animate; Fade {} }
    Behavior on cyan { enabled: root.animate; Fade {} }
    Behavior on magenta { enabled: root.animate; Fade {} }
    Behavior on magentaBright { enabled: root.animate; Fade {} }
}
