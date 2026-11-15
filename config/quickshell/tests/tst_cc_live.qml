import QtQuick
import QtTest
import qs
import qs.Panels
import qs.Panels.Sheets
import "../lib/CcData.js" as CcData

// The control center against a model that changes under it, as CcModel's
// does (M6 review): every press feeds back into the data, so `model` is a new
// object with new arrays after each one. Drags, key presses and focus must
// survive that, in the levels, the tiles and a sheet's app slider. Also the
// keys of control-lock 2.9: the arrows inside the tile grid and the mini row,
// Up and Down along the focus chain elsewhere (the sliders keep Left/Right).
Item {
    id: root
    width: 800
    height: 600

    property real volume: 0.2
    property bool wifiOn: true
    property int volumeMoves: 0
    property int wifiToggles: 0
    readonly property var source: ({
            wifi: { present: true, radioOn: root.wifiOn, connected: true, ssid: "home-5g" },
            bt: { present: true, enabled: true, device: "Headphones" },
            tailscale: { installed: true, running: true, state: "Connected" },
            dnd: false,
            volume: { value: root.volume, muted: false, device: "Speakers" },
            brightness: { value: 0.48, present: true },
            awake: { active: false },
            hz: 60,
            scale: 1.5,
            theme: "hackerman",
            notifications: [{ summary: "Session finished", appName: "Claude Code", body: "Ready", created: 1000 }],
            count: 1,
            user: "nicknisi",
            battery: { present: true, percent: 25 },
            tray: [{ id: "one", title: "One", glyph: "sparkle" }]
        })

    ControlCenter {
        id: cc
        model: CcData.home(root.source, 2000, { title: "Neon Grid", artist: "Night Rider", playing: false, position: 10, length: 100, canSeek: true })
        animated: false
        sheetUrl: function (name) {
            return name === "sound" ? Qt.resolvedUrl("SheetStub.qml") : "";
        }
        onAction: (name, arg) => {
            if (name === "level" && arg.key === "volume") {
                root.volumeMoves++;
                root.volume = arg.value;
            } else if (name === "tile" && arg.key === "wifi") {
                root.wifiToggles++;
                root.wifiOn = arg.on;
            }
        }
    }

    // A sheet's app slider, fed back the same way (the Sound sheet's Apps).
    property real appVolume: 0.5
    property int appMoves: 0
    SheetFrame {
        id: sheet
        x: 800
        width: 728
        height: 528
        title: "Sound"
        sheetData: ({
                status: "Speakers", hasSwitch: false, footer: "",
                groups: [{ label: "Apps", rows: [{ key: "firefox", title: "Firefox", icon: "globe", slider: root.appVolume, trail: String(Math.round(root.appVolume * 100)) }] }]
            })
        onSlid: (row, value) => {
            root.appMoves++;
            root.appVolume = value;
        }
    }

    TestCase {
        name: "CcLive"
        when: windowShown
        visible: true

        function slider() {
            return cc.levels.repeater.itemAt(0).slider;
        }

        function test_volume_drag_holds_while_the_model_changes() {
            root.volumeMoves = 0;
            const row = cc.levels.repeater.itemAt(0);
            const s = slider();
            const y = s.height / 2;
            mousePress(s, 10, y);
            for (let i = 1; i <= 10; i++) mouseMove(s, 10 + i * 20, y);
            mouseRelease(s, 10 + 10 * 20, y);
            compare(root.volumeMoves, 11, "the press and all ten moves reached the host");
            compare(cc.levels.repeater.itemAt(0), row, "the row was not rebuilt");
            fuzzyCompare(root.volume, s.clamp(210 / s.width), 0.02);
            compare(row.valueText.text, String(Math.round(100 * root.volume)));
        }

        function test_slider_keys_keep_focus() {
            root.volumeMoves = 0;
            root.volume = 0.4;
            const s = slider();
            s.forceActiveFocus();
            keyClick(Qt.Key_Right);
            keyClick(Qt.Key_Right);
            keyClick(Qt.Key_Right);
            compare(root.volumeMoves, 3, "three steps, each from the new value");
            fuzzyCompare(root.volume, 0.55, 0.001);
            verify(s.activeFocus, "the same slider still has the keys");
        }

        function test_tile_space_twice() {
            root.wifiToggles = 0;
            root.wifiOn = true;
            const disc = cc.tiles.itemAt(0).disc;
            disc.forceActiveFocus();
            keyClick(Qt.Key_Space);
            verify(!root.wifiOn && disc.activeFocus, "off, and the disc keeps the keys");
            keyClick(Qt.Key_Space);
            verify(root.wifiOn, "the second Space turns it back on");
            compare(root.wifiToggles, 2);
            compare(cc.tiles.itemAt(0).disc, disc, "the tile was not rebuilt");
        }

        function test_sheet_app_slider_drag() {
            root.appMoves = 0;
            const row = sheet.rowItem("firefox");
            const bar = findChild(row, "sheetRowSlider");
            verify(bar !== null && bar.visible, "the app row has its slider");
            const y = bar.height / 2;
            mousePress(bar, 5, y);
            for (let i = 1; i <= 5; i++) mouseMove(bar, 5 + i * 18, y);
            mouseRelease(bar, 5 + 5 * 18, y);
            compare(root.appMoves, 6, "the press and all five moves");
            compare(sheet.rowItem("firefox"), row, "the row was not rebuilt");
        }

        function test_arrows_in_the_tile_grid() {
            const t = i => cc.tiles.itemAt(i);
            t(0).disc.forceActiveFocus();
            keyClick(Qt.Key_Right);
            verify(t(1).disc.activeFocus, "Right: Wi-Fi to Bluetooth");
            keyClick(Qt.Key_Down);
            verify(t(3).disc.activeFocus, "Down: Bluetooth to Do not disturb");
            keyClick(Qt.Key_Left);
            verify(t(2).disc.activeFocus, "Left: to Tailscale");
            keyClick(Qt.Key_Up);
            verify(t(0).disc.activeFocus, "Up: back to Wi-Fi");
            keyClick(Qt.Key_Left);
            verify(t(0).disc.activeFocus, "the grid's edge holds");
            t(0).chevron.forceActiveFocus();
            keyClick(Qt.Key_Down);
            verify(t(2).chevron.activeFocus, "a chevron moves to the chevron below");
            keyClick(Qt.Key_Down);
            verify(cc.media.previousButton.activeFocus, "Down out of the grid: on along the chain, to the media's previous");
            keyClick(Qt.Key_K, Qt.ControlModifier);
            verify(t(3).chevron.activeFocus, "Ctrl+K: back along the chain");
            keyClick(Qt.Key_J, Qt.ControlModifier);
            verify(cc.media.previousButton.activeFocus, "Ctrl+J: on along it");
        }

        function test_arrows_elsewhere() {
            // The levels: Up and Down move focus; Left and Right stay the value's.
            root.volume = 0.4;
            root.volumeMoves = 0;
            const s = slider();
            s.forceActiveFocus();
            keyClick(Qt.Key_Down);
            verify(!s.activeFocus && cc.levels.repeater.itemAt(0).children.some(c => c.activeFocus), "Down leaves the slider for its device button");
            compare(root.volumeMoves, 0, "and does not step the volume");
            keyClick(Qt.Key_Up);
            verify(s.activeFocus, "Up comes back");
            // The minis: Left and Right along the row.
            const m = i => cc.minis.itemAt(i);
            m(0).forceActiveFocus();
            keyClick(Qt.Key_Right);
            verify(m(1).activeFocus);
            keyClick(Qt.Key_Left);
            keyClick(Qt.Key_Left);
            verify(m(0).activeFocus, "the row's edge holds");
            keyClick(Qt.Key_Up);
            verify(!m(0).activeFocus, "Up leaves the row along the chain");
            // Opened by the pointer: any arrow brings the ring to the Wi-Fi disc.
            cc.focusHome(false);
            keyClick(Qt.Key_Down);
            verify(cc.tiles.itemAt(0).disc.activeFocus);
        }
    }
}
