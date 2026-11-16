pragma Singleton
// Look.qml - the island's personal look, separate from the theme pack
// (personal-looks 2.6 and 4, PLAN M9).
//
// Prefs.look names it: "crew" (the plain island, the default) or one of the
// five voiced looks, phosphor, bridge, arcade, liner and outrun. lib/LookModel.js
// holds what each look is (its cells, inks, material and the Crew cards'
// skin); Looks/<Name>.qml draws its rest bar and moment line, and
// Island/LookLayer.qml hosts them on the island. A look restyles the rest
// pill and the island's moments only; hover, the panels and the classic bars
// stay as they are.
//
// `current` is the look on screen: Prefs.look, or "crew" where the look is
// marked dark-only and the pack is light (LookModel.DARK_ONLY, from the
// contrast audit: none today). The inks follow the pack live: `tokens` is
// Tokens' colours as hex, so a theme switch or a picker preview recolours the
// look with the rest of the island.
//
// The `look` IPC (set, get, list) lives in shell.qml, which is loaded in every
// bar mode; bin/bar calls it on Linux. Antonio and Press Start 2P load here
// from assets/fonts (OFL 1.1, their licences beside them).
import Quickshell
import QtQuick
import "lib/LookModel.js" as LookModel

Singleton {
    id: root

    readonly property var names: LookModel.LOOKS
    // The look asked for, and the one drawn.
    readonly property string name: Prefs.look
    readonly property bool active: LookModel.shows(root.name, Tokens.dark)
    readonly property string current: root.active ? root.name : "crew"
    readonly property var meta: LookModel.meta(root.current)
    // "signoff" | "hail" | "nowplaying" | "" (crew).
    readonly property string momentKind: root.active ? root.meta.moment : ""

    readonly property var tokens: ({
            bg: Tokens.hex(Tokens.bg),
            fg: Tokens.hex(Tokens.fg),
            accent: Tokens.hex(Tokens.accent),
            surface: Tokens.hex(Tokens.surface),
            hairline: Tokens.hex(Tokens.hairline),
            inkDim: Tokens.hex(Tokens.inkDim),
            inkMid: Tokens.hex(Tokens.inkMid),
            fillHigh: Tokens.hex(Tokens.fillHigh),
            darker: Tokens.hex(Tokens.darker),
            bad: Tokens.hex(Tokens.bad),
            red: Tokens.hex(Tokens.red),
            yellow: Tokens.hex(Tokens.yellow),
            cyan: Tokens.hex(Tokens.cyan),
            blue: Tokens.hex(Tokens.blue),
            magenta: Tokens.hex(Tokens.magenta),
            magentaBright: Tokens.hex(Tokens.magentaBright),
            dark: Tokens.dark
        })
    readonly property var ink: LookModel.ink(root.current, root.tokens)
    readonly property var skin: LookModel.skin(root.current, root.tokens)

    // The island body for a cell: "rest", the moment kind, or "card".
    function material(cell: string): var {
        return LookModel.material(root.current, cell, root.tokens);
    }

    // "ok", or an error line naming the looks.
    function set(look: string): string {
        const n = LookModel.canonical(look);
        if (n === "") return "error: unknown look \"" + look + "\" (looks: " + root.names.join(" ") + ", or none)";
        Prefs.setLook(n);
        if (n !== "crew" && !LookModel.shows(n, Tokens.dark)) return "ok: " + n + " is for dark packs; the island stays plain on " + (Tokens.name || "this pack");
        return "ok";
    }
    // The looks, one per line, "*" before the one set (bin/bar's listing).
    function list(): string {
        return root.names.map(n => (n === root.name ? "* " : "  ") + n + "\t" + LookModel.meta(n).sub).join("\n");
    }

    FontLoader {
        id: antonio
        source: Qt.resolvedUrl("assets/fonts/Antonio.ttf")
    }
    FontLoader {
        id: pressStart
        source: Qt.resolvedUrl("assets/fonts/PressStart2P-Regular.ttf")
    }
    // The families as loaded ("Antonio", "Press Start 2P"), for the checks.
    readonly property var fonts: ({
            antonio: antonio.status === FontLoader.Ready ? antonio.name : "",
            pressStart: pressStart.status === FontLoader.Ready ? pressStart.name : ""
        })
}
