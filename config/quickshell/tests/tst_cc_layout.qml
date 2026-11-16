import QtQuick
import QtTest
import qs
import qs.Panels
import "../lib/CcData.js" as CcData

// The control center's layout (control-lock 2.2 to 2.8, PLAN M6): 552 of 560
// used, the parts at their board sizes, the tile label eliding inside its 75
// px, the play icon in `bg` on `fg`, and what each press asks the host.
Item {
    id: root
    width: 800
    height: 600

    readonly property var source: ({
            wifi: { present: true, radioOn: true, connected: true, ssid: "home-5g" },
            bt: { present: true, enabled: true, device: "Headphones" },
            tailscale: { installed: true, running: true, state: "Connected" },
            dnd: true,
            volume: { value: 0.62, muted: false, device: "Speakers" },
            brightness: { value: 0.48, present: true },
            awake: { active: true, label: "1 hour" },
            hz: 60,
            scale: 1.5,
            theme: "catppuccin-latte",
            recording: false,
            notifications: [
                { summary: "Session finished", appName: "Claude Code", body: "Island mocks are ready for review", created: 1000 },
                { summary: "Recording saved", appName: "capture", body: "Region recording, 0:42", created: 1000 }
            ],
            count: 2,
            user: "nicknisi",
            battery: { present: true, percent: 25 },
            tray: [{ id: "one", title: "One", glyph: "sparkle" }, { id: "two", title: "Two", glyph: "bell", passive: true }]
        })

    ControlCenter {
        id: cc
        model: CcData.home(root.source, 1000 + 2 * 60000, { title: "Neon Grid", artist: "Night Rider", playing: true, position: 102, length: 271 })
        animated: false
    }

    SignalSpy {
        id: actions
        target: cc
        signalName: "action"
    }

    TestCase {
        name: "CcLayout"
        when: windowShown
        visible: true

        function at(item) {
            return item.mapToItem(cc, 0, 0);
        }

        function test_frame() {
            compare(cc.width, 760);
            compare(cc.height, 560);
            compare(at(cc.home).x, 16);
            compare(at(cc.home).y, 16);
            compare(cc.home.width, 728);
        }

        function test_content_552_inside_560() {
            const tile = cc.tiles.itemAt(0);
            compare(at(tile).y, 16, "tiles at the top padding");
            compare(at(cc.media).y, 16);
            compare(cc.media.height, 148);
            compare(at(cc.levels).y, 16 + 148 + 12);
            compare(cc.levels.height, 92);
            compare(at(cc.minis.itemAt(0)).y, 176 + 92 + 12);
            compare(cc.minis.itemAt(0).height, 64);
            compare(at(cc.notes).y, 280 + 64 + 12);
            compare(cc.notes.height, 132);
            compare(at(cc.footer).y, 356 + 132 + 12);
            compare(cc.footer.height, 36);
            compare(at(cc.footer).y + cc.footer.height + 16, 552, "16 + content + 16 = 552");
            verify(cc.height - 552 === 8, "8 px stay empty at the bottom");
        }

        function test_tiles() {
            compare(cc.tiles.count, 4);
            const names = [];
            for (let i = 0; i < 4; i++) {
                const t = cc.tiles.itemAt(i);
                names.push(t.objectName);
                compare(t.width, 174);
                compare(t.height, 70);
                compare(t.labelText.width, 75, "the text column is what is left, 75");
            }
            compare(names.join(" "), "ccTile-wifi ccTile-bt ccTile-ts ccTile-dnd");
            compare(at(cc.tiles.itemAt(1)).x, 16 + 174 + 8);
            compare(at(cc.tiles.itemAt(2)).y, 16 + 70 + 8);
            const dnd = cc.tiles.itemAt(3);
            compare(dnd.label, "Do not disturb");
            verify(dnd.labelText.implicitWidth > 75, "Do not disturb is wider than its column: " + dnd.labelText.implicitWidth);
            verify(dnd.labelText.truncated, "so it elides");
            verify(!cc.tiles.itemAt(0).labelText.truncated, "Wi-Fi fits");
            compare(cc.tiles.itemAt(0).sub, "home-5g");
            verify(dnd.checked, "DND on");
            compare(cc.tiles.itemAt(0).chevron.x, 174 - 6 - 26);
        }

        function test_media() {
            compare(cc.media.width, 728 - 356 - 12);
            compare(cc.media.art.width, 120);
            compare(cc.media.playButton.width, 34);
            compare(String(cc.media.playButton.fill), String(Tokens.fg));
            compare(String(cc.media.playButton.ink), String(Tokens.bg), "the play icon is bg on fg");
            compare(cc.media.titleText.text, "Neon Grid");
            verify(!cc.media.eqClock.running, "no eq loop while not animated");
        }

        // The player's cover fills the well (M10, the old MediaCard's), and
        // the bars and their clock rest; a broken one leaves the bars.
        function test_media_cover() {
            const m = CcData.mediaCard({ title: "Neon Grid", artist: "Night Rider", playing: true, position: 102, length: 271, art: Qt.resolvedUrl("cover.png") });
            const card = coverCard.createObject(root, { media: m });
            tryCompare(card.cover, "status", Image.Ready);
            verify(card.coverShown, "the cover shows once it loads");
            verify(!card.eqClock.running, "the bars' clock rests under a cover");
            card.media = CcData.mediaCard({ title: "t", playing: true, length: 10, art: Qt.resolvedUrl("missing.png") });
            tryCompare(card.cover, "status", Image.Error);
            verify(!card.coverShown && card.eqClock.running, "a cover that fails leaves the bars, running");
            card.media = CcData.mediaCard({ title: "t", playing: true, length: 10 });
            verify(!card.coverShown && String(card.cover.source) === "", "no cover, no image");
            card.destroy();
        }
        Component {
            id: coverCard
            CcMedia {
                width: 360
            }
        }

        function test_minis() {
            compare(cc.minis.count, 6);
            const names = [];
            for (let i = 0; i < 6; i++) names.push(cc.minis.itemAt(i).objectName);
            compare(names.join(" "), "ccMini-awake ccMini-power ccMini-display ccMini-theme ccMini-record ccMini-clipboard");
            fuzzyCompare(cc.minis.itemAt(0).width, (728 - 40) / 6, 0.01);
            compare(cc.minis.itemAt(0).sub, "1 hour");
            verify(cc.minis.itemAt(0).checked);
            compare(cc.minis.itemAt(1).sub, "60 Hz");
            compare(cc.minis.itemAt(2).sub, "1.5× scale");
            compare(cc.minis.itemAt(3).sub, "catppuccin-latte");
            verify(cc.minis.itemAt(3).subText.width <= 114.67 - 24 + 0.01, "theme names elide inside the box");
        }

        function test_levels_and_notes() {
            const volume = cc.levels.repeater.itemAt(0);
            compare(volume.objectName, "ccLevel-volume");
            compare(volume.height, 40);
            compare(volume.valueText.text, "62");
            compare(cc.levels.repeater.itemAt(1).valueText.text, "48");
            compare(cc.notes.rowRepeater.count, 2);
            compare(cc.notes.rowRepeater.itemAt(0).height, 44);
        }

        function test_footer() {
            compare(cc.lockButton.width, 34);
            compare(cc.powerButton.width, 34);
            compare(cc.tray.count, 2, "the tray sits in the footer");
            verify(at(cc.tray.itemAt(1)).x < at(cc.lockButton).x, "between the battery and Lock");
            compare(at(cc.powerButton).x + 34, 16 + 728, "Power at the right edge");
        }

        function test_focus_by_key_and_by_pointer() {
            const disc = cc.tiles.itemAt(0).disc;
            cc.focusHome();
            verify(disc.activeFocus, "opened by key: the Wi-Fi disc, ring and all");
            cc.focusHome(false);
            verify(cc.activeFocus && !disc.activeFocus, "opened by the pointer: the keys stay in the control center, no ring");
            const ring = findChild(cc, "ccHomeKeys");
            verify(ring !== null && ring.activeFocus, "on the ring-less holder");
            keyClick(Qt.Key_Tab);
            verify(disc.activeFocus, "Tab moves on to the Wi-Fi disc");
        }

        function test_presses_ask_the_host() {
            actions.clear();
            mouseClick(cc.tiles.itemAt(0).disc);
            compare(actions.count, 1);
            compare(actions.signalArguments[0][0], "tile");
            compare(JSON.stringify(actions.signalArguments[0][1]), JSON.stringify({ key: "wifi", on: false }));
            mouseClick(cc.minis.itemAt(0));
            compare(actions.signalArguments[1][0], "mini");
            compare(actions.signalArguments[1][1], "awake");
            mouseClick(cc.powerButton);
            compare(actions.signalArguments[2][0], "power");
            mouseClick(cc.lockButton);
            compare(actions.signalArguments[3][0], "lock");
            mouseClick(cc.media.playButton);
            compare(actions.signalArguments[4][0], "media");
            compare(actions.signalArguments[4][1], "toggle");
            mouseClick(cc.tray.itemAt(0), 14, 14, Qt.RightButton);
            compare(actions.signalArguments[5][0], "tray");
            compare(actions.signalArguments[5][1].button, "right");
            // A sheet opener with no sheets given: nothing opens.
            verify(!cc.openSheet("wifi"), "no sheetUrl, no sheet");
            compare(cc.sheet, "");
        }
    }
}
