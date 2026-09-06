pragma Singleton
// NOTE: `pragma Singleton` must come before any '{' in the file, comments
// included. Quickshell scans only up to the first brace looking for it, so a
// header comment containing one (this file had %-brace-app-name and a \u-brace
// escape example) makes it register as a plain component instead, with no
// error: the type resolves but every property reads back undefined.
//
// Icons.qml - app -> Nerd Font glyph, ported from sketchybar's plugins/icons.sh.
//
// The codepoints are the same Font Awesome set. What changed is the matching
// key: sketchybar matched macOS app names from `aerospace list-windows`
// (%{app-name}), and here it is the Wayland app_id, which is a reverse-DNS or
// lowercase binary name rather than a display name. So "Ghostty" becomes
// "com.mitchellh.ghostty" and "Code" becomes "code-oss" or "Code".
//
// Matching is case-insensitive substring, which covers both spellings of the
// apps that report differently depending on how they were launched.
//
// All of these are in the BMP, so plain \uXXXX is fine. Anything from the
// Material Design range (U+F0001 and up) would need \u{...} instead.
import Quickshell
import QtQuick

Singleton {
    id: root

    readonly property string fallback: "\uf2d0" // window

    // Order matters: first substring hit wins, so put specific before generic.
    readonly property var rules: [
        { match: ["ghostty", "wezterm", "kitty", "alacritty", "foot", "terminal"], glyph: "\uf120" },
        { match: ["chromium", "chrome", "brave", "vivaldi", "helium"],             glyph: "\uf268" },
        { match: ["firefox", "zen", "librewolf", "floorp"],                        glyph: "\uf269" },
        { match: ["epiphany", "safari"],                                           glyph: "\uf267" },
        { match: ["slack"],                                                        glyph: "\uf198" },
        { match: ["discord", "vesktop", "element"],                                glyph: "\uf086" },
        { match: ["signal", "telegram", "fractal"],                                glyph: "\uf075" },
        { match: ["thunderbird", "geary", "evolution", "mail"],                    glyph: "\uf0e0" },
        { match: ["calendar", "gnome.calendar"],                                   glyph: "\uf073" },
        { match: ["spotify", "rhythmbox", "music"],                                glyph: "\uf001" },
        { match: ["notion"],                                                       glyph: "\uf249" },
        { match: ["obsidian"],                                                     glyph: "\uf219" },
        { match: ["linear"],                                                       glyph: "\uf0ae" },
        { match: ["zoom", "facetime"],                                             glyph: "\uf03d" },
        { match: ["nautilus", "thunar", "nemo", "dolphin", "files"],               glyph: "\uf07b" },
        { match: ["1password", "bitwarden", "keepass"],                            glyph: "\uf023" },
        { match: ["code", "vscodium", "zed"],                                      glyph: "\uf121" },
        { match: ["github"],                                                       glyph: "\uf09b" },
        { match: ["settings", "control-center"],                                   glyph: "\uf013" },
    ]

    // BlueZ puts a freedesktop icon name on org.bluez.Device1.Icon, derived from
    // the device's class-of-device bits. That set is small and fixed, so this is
    // an exact lookup rather than the substring scan above.
    //
    // Most of these are Material Design codepoints (U+F0001 and up), which need
    // \u{...} rather than \uXXXX. They were picked over the Font Awesome ones
    // because the Awesome set has no headset glyph in the installed Symbols Nerd
    // Font at all: U+F590 is missing from its charset and renders as tofu.
    readonly property string btFallback: "\u{f00af}" // md bluetooth

    readonly property var btGlyphs: ({
        "audio-card":        "\u{f04c3}",
        "audio-headphones":  "\u{f02cb}",
        "audio-headset":     "\u{f02ce}",
        "camera-photo":      "\uf030",
        "camera-video":      "\uf03d",
        "computer":          "\u{f0322}",
        "input-gaming":      "\uf11b",
        "input-keyboard":    "\u{f030c}",
        "input-mouse":       "\u{f037d}",
        "input-tablet":      "\uf10a",
        "modem":             "\uf1eb",
        "multimedia-player": "\uf001",
        "network-wireless":  "\uf1eb",
        "phone":             "\u{f011c}",
        "printer":           "\u{f042a}",
        "scanner":           "\uf02f",
        "video-display":     "\u{f0379}",
    })

    readonly property var forBluetooth: function (icon) {
        return root.btGlyphs[String(icon ?? "")] ?? root.btFallback;
    }

    // Exposed as a property holding a function rather than a plain method:
    // a declared method on this singleton is not reachable from another file
    // ("Property 'forClass' of object Icons is not a function"), while a var
    // property holding a function is.
    // PipeWire hands out node.nick for a sink, which is a short human label like
    // "Speaker", "Headphones" or "HDMI 1". Substring again, because the wording
    // varies by driver and there is no enum behind it.
    readonly property var forSink: function (label) {
        const s = String(label ?? "").toLowerCase();
        if (s.includes("headphone") || s.includes("headset")) return "\u{f02cb}"; // md headphones
        if (s.includes("hdmi") || s.includes("displayport")) return "\u{f0379}";  // md monitor
        if (s.includes("bluez") || s.includes("bluetooth")) return "\u{f00af}";   // md bluetooth
        return "\u{f04c3}"; // md speaker
    }

    readonly property var forClass: function (cls) {
        if (!cls) return root.fallback;
        const c = String(cls).toLowerCase();
        for (const rule of root.rules) {
            for (const needle of rule.match) {
                if (c.includes(needle)) return rule.glyph;
            }
        }
        return root.fallback;
    }
}
