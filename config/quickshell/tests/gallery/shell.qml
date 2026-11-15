// tests/gallery/shell.qml - the Kit on one screen, for sandbox shots (PLAN M0).
//
// It runs as the shell.qml of a copied config, never in place and never against
// the live ~/.config/quickshell (imports are relative to the config root):
//
//   snap=$(mktemp -d); cp -R config/quickshell/. "$snap"
//   cp config/quickshell/tests/gallery/shell.qml "$snap/shell.qml"
//   bin/theme-color -f themes/hackerman/colors.toml --name hackerman --mode dark --json > colors.json
//   ~/Developer/dotfiles/.shell-rebuild/tmp/sandbox.sh -e THEME_COLORS=$PWD/colors.json "$snap" kit.png
//
// Positions are fixed logical px so shots can be sampled: the rest-pill surface
// at (60, 80) 360 x 38, the controls panel (surface) at (40, 136) 900 x 150
// with the accent chip at (300, 166), the 96 px stroke specimen at (1720, 40),
// the icon grid from (60, 324) in 120 x 64 cells.
import Quickshell
import Quickshell.Wayland
import QtQuick
import qs
import qs.Kit
import "Kit/IconPaths.js" as IconPaths

ShellRoot {
    PanelWindow {
        id: win
        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell-kit-gallery"
        WlrLayershell.layer: WlrLayer.Top
        color: Tokens.darker

        component Caption: Text {
            color: Tokens.inkDim
            font.family: "Adwaita Sans"
            font.pixelSize: 11
            font.weight: Font.Medium
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 0.66
        }

        Text {
            x: 60
            y: 24
            text: "Kit gallery · " + (Tokens.name || "unnamed") + " · " + Tokens.mode + " · motion " + Motion.profile
            color: Tokens.fg
            font.family: "Adwaita Sans"
            font.pixelSize: 15
            font.weight: Font.Medium
        }

        // ---- surfaces ------------------------------------------------------
        Caption { x: 60; y: 60; text: "Surface · floating, 1 px ring" }
        Surface {
            id: restPill
            x: 60
            y: 80
            width: 360
            height: 38
            radius: 19
            Text {
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                text: "rest 360 × 38"
                color: Tokens.inkDim
                font.family: "Adwaita Sans"
                font.pixelSize: 12
            }
        }
        Caption { x: 480; y: 60; text: "card · raised, grounded" }
        Surface {
            x: 480
            y: 80
            width: 200
            height: 50
            radius: 14
            floating: false
            color: Tokens.raised
        }
        Caption { x: 740; y: 60; text: "ring 1 / 1.5 px (risk 13)" }
        Surface {
            x: 740
            y: 80
            width: 160
            height: 38
            radius: 19
            border.width: 1 / 1.5
        }

        // Controls sit on a surface panel, as they do in the shell: on the bare
        // `darker` backdrop latte's fillHigh (#d4d7de vs #d7d8dc) would vanish.
        Surface {
            x: 40
            y: 136
            width: 900
            height: 150
            radius: 14
            floating: false
        }

        // ---- chips ---------------------------------------------------------
        Caption { x: 60; y: 146; text: "Chip" }
        Chip { x: 60; y: 166; text: "All sources" }
        Chip { x: 160; y: 166; text: "12"; tone: "strong"; mono: true; fontSize: 11; padX: 6; padY: 1 }
        Chip { x: 210; y: 166; text: "tint"; tone: "tint" }
        Chip { id: accentChip; x: 300; y: 166; text: "accent"; tone: "accent" }
        Chip { x: 390; y: 166; text: "agent"; tone: "quiet"; icon: "sparkle" }

        // ---- keycaps -------------------------------------------------------
        Caption { x: 480; y: 176; text: "Keycap" }
        Row {
            x: 540
            y: 172
            spacing: 6
            Keycap { text: "Tab" }
            Keycap { text: "Super" }
            Keycap { text: "Space" }
            Keycap { text: "Print" }
            Keycap { text: "Super Space"; small: true }
            Keycap { text: "L"; small: true; fontSize: 10; ink: Tokens.inkDim }
        }

        // ---- controls ------------------------------------------------------
        Caption { x: 60; y: 216; text: "PillButton · Switch · Slider" }
        Row {
            x: 60
            y: 236
            spacing: 8
            PillButton { text: "Run"; hint: "↵"; width: 160 }
            PillButton { text: "Actions"; tone: "outline" }
            PillButton { text: "Cancel"; tone: "quiet"; padX: 16 }
            PillButton { text: "Authenticate"; tone: "accent"; padX: 16 }
            PillButton { text: "Open"; size: 30; anchors.verticalCenter: parent.verticalCenter }
            PillButton { text: "Assign"; size: 26; padX: 10; anchors.verticalCenter: parent.verticalCenter }
            Switch { checked: true; label: "on"; anchors.verticalCenter: parent.verticalCenter }
            Switch { checked: false; label: "off"; anchors.verticalCenter: parent.verticalCenter }
            Slider { width: 160; value: 0.4; label: "volume"; anchors.verticalCenter: parent.verticalCenter }
        }
        Surface {
            x: 1000
            y: 60
            width: 460
            height: 116
            radius: 14
            floating: false
            Column {
                x: 10
                y: 10
                width: parent.width - 20
                ListRow { width: parent.width; icon: "crop"; title: "Screenshot region"; subtitle: "capture shot region"; keys: ["Print"]; selected: true }
                ListRow { width: parent.width; icon: "clip"; title: "Clipboard history"; subtitle: "Pastes into the focused window"; meta: "2m" }
            }
        }

        // ---- stroke specimens (risk 15) ------------------------------------
        Caption { x: 1720; y: 20; text: "stroke 7.2 @ 96" }
        Icon { x: 1720; y: 40; name: "plus"; size: 96 }
        Row {
            x: 1720
            y: 150
            spacing: 10
            Icon { name: "plus"; size: 14 }
            Icon { name: "plus"; size: 16 }
            Icon { name: "plus"; size: 18 }
            Icon { name: "plus"; size: 22 }
        }

        // ---- every icon ----------------------------------------------------
        Caption {
            x: 60
            y: 300
            text: "Icon · " + IconPaths.NAMES.length + " (Lucide 1.65.0, ISC) · 16 px, then 14 px in accent"
        }
        Grid {
            x: 60
            y: 324
            columns: 15
            columnSpacing: 0
            rowSpacing: 0
            Repeater {
                model: IconPaths.NAMES
                Item {
                    width: 120
                    height: 64
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 6
                        spacing: 10
                        Icon { name: modelData; size: 16 }
                        Icon { name: modelData; size: 14; color: Tokens.accent; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 32
                        text: modelData
                        color: Tokens.inkDim
                        font.family: "Monaspace Argon"
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
