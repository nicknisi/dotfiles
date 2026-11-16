import QtQuick
import QtTest
import qs
import qs.Lock
import "../lib/LockMachine.js" as LockMachine

// One lock screen (PLAN M8, control-lock 4.3 to 4.8) at 1920 x 1200: where
// the parts sit, what a secondary screen leaves out, keys reaching the
// buffer from anywhere, the lock's power menu (Suspend, Reboot, Shut down
// only) and the pills' data.
Item {
    id: root
    width: 1920
    height: 1200

    property var typedText: []

    LockSurface {
        id: lock
        anchors.fill: parent
        name: "Nick Nisi"
        sub: "nicknisi on milhouse"
        now: new Date(2026, 10, 14, 10, 45)
        auth: LockMachine.initial()
        media: ({ present: true, title: "Neon Grid", artist: "Night Rider", playing: false, canPrevious: true, canNext: true })
        status: ({ wifi: { present: true, radioOn: true, icon: "wifi2" }, battery: { present: true, percent: 25, icon: "batteryLow" } })
        onTyped: text => root.typedText = root.typedText.concat([text])
    }

    // A second surface, as lock.qml builds one per screen: `shown` false
    // until the lock is secure.
    Component {
        id: arriving
        LockSurface {
            width: 1920
            height: 1200
            name: "Nick Nisi"
            now: new Date(2026, 10, 14, 10, 45)
            auth: LockMachine.initial()
            status: ({ wifi: { present: true, radioOn: true, icon: "wifi2" }, battery: { present: true, percent: 25, icon: "batteryLow" } })
        }
    }

    SignalSpy {
        id: runs
        target: lock
        signalName: "powerRun"
    }
    SignalSpy {
        id: suspends
        target: lock
        signalName: "suspendRequested"
    }
    SignalSpy {
        id: mediaActions
        target: lock
        signalName: "mediaAction"
    }
    SignalSpy {
        id: submits
        target: lock
        signalName: "submitted"
    }

    TestCase {
        name: "LockSurface"
        when: windowShown
        visible: true

        function box(item) {
            const p = item.mapToItem(root, 0, 0);
            return { x: Math.round(p.x * 100) / 100, y: Math.round(p.y * 100) / 100, w: item.width, h: item.height };
        }

        function initTestCase() {
            lock.shown = true;
            wait(600);
        }
        function init() {
            lock.primary = true;
            lock.powerOpen = false;
            root.typedText = [];
            runs.clear();
            suspends.clear();
            mediaActions.clear();
            submits.clear();
            wait(450);
        }

        function test_layout() {
            const card = box(lock.card);
            compare(card.x, 770, "the card is centred");
            compare(card.y, 602, "top = round(H / 2) + 2");
            const clockLayer = lock.clock.parent.parent;
            compare(clockLayer.y + clockLayer.height, 602 - 120, "the clock block ends 120 above the card");
            compare(lock.clock.text, "10:45");
            compare(lock.clock.font.pixelSize, 128);
            compare(lock.clock.font.family, "Monaspace Argon");
            // Qt keeps letter spacing in 1/64 px.
            fuzzyCompare(lock.clock.font.letterSpacing, -2.56, 0.02);
            compare(lock.clock.height, 136);
            const cap = box(lock.capsule);
            compare(cap.y, 8);
            compare(cap.h, 38);
            verify(Math.abs(cap.w - 96) <= 2, "the capsule rests at about 96: " + cap.w);
            compare(cap.x, Math.round((1920 - cap.w) / 2 * 100) / 100);
            const media = box(lock.mediaPill);
            compare(media.x, 24);
            compare(media.y + media.h, 1200 - 24);
            compare(media.h, 52);
            const status = box(lock.statusPill);
            compare(status.x + status.w, 1920 - 24);
            compare(status.y + status.h, 1200 - 24);
            compare(status.h, 52);
            compare(lock.statusPill.suspendButton.width, 36);
            compare(String(lock.statusPill.suspendButton.color), String(Tokens.fillLow));
            compare(String(lock.mediaPill.playButton.color), String(Tokens.fg), "play is fg");
            compare(String(lock.mediaPill.playButton.ink), String(Tokens.bg), "with a bg glyph");
        }

        function test_scrim_and_wallpaper() {
            compare(lock.wall.opacity, 1, "the wallpaper faded in");
            const scrim = lock.wall.children[1];
            compare(String(scrim.color), String(Tokens.scrim));
            compare(scrim.width, 1920);
            compare(lock.wall.children[0].fillMode, Image.PreserveAspectCrop);
        }

        function test_short_screen() {
            root.height = 540;
            wait(50);
            const clockLayer = lock.clock.parent.parent;
            compare(clockLayer.y, 70, "the clock stays 24 under the capsule on a 540 high screen");
            root.height = 1200;
            wait(50);
            compare(clockLayer.y + clockLayer.height, 602 - 120);
        }

        function test_secondary_screen() {
            lock.primary = false;
            wait(450);
            verify(!lock.card.parent.visible, "no card");
            verify(!lock.mediaPill.parent.visible && !lock.statusPill.parent.visible, "no pills");
            verify(lock.capsule.visible && lock.clock.parent.parent.visible, "capsule and clock stay");
            // Keys typed here still reach the one buffer.
            keyClick(Qt.Key_Q);
            compare(root.typedText.join(""), "q");
        }

        function test_keys_from_anywhere() {
            lock.forceActiveFocus();
            keyClick(Qt.Key_A);
            compare(root.typedText.join(""), "a", "a key with focus on the surface goes to the field");
            verify(lock.card.field.activeFocus);
            lock.statusPill.suspendButton.forceActiveFocus();
            keyClick(Qt.Key_B);
            compare(root.typedText.join(""), "ab", "and with focus on a button");
            verify(lock.card.field.activeFocus);
            keyClick(Qt.Key_Return);
            compare(submits.count, 1);
        }

        function test_tab_order() {
            lock.card.focusField();
            const names = [];
            let item = lock.card.field;
            for (let i = 0; i < 7; i++) {
                names.push(item.objectName || item.Accessible.name);
                item = item.nextItemInFocusChain(true);
            }
            compare(names.slice(0, 7).join("|"), "lockField|lockUnlock|Previous track|Pause|Next track|lockSuspend|lockPower".replace("Pause", "Play"));
        }

        function test_power_menu() {
            lock.statusPill.powerButton.activated();
            verify(lock.powerOpen);
            wait(500);
            const pm = lock.powerMenu;
            compare(pm.items.length, 3);
            compare([0, 1, 2].map(i => pm.repeater.itemAt(i).objectName).join(" "), "powerItem-suspend powerItem-reboot powerItem-shutdown");
            compare(pm.itemWidth, 108);
            compare(pm.width, 32 + 3 * 108 + 16, "372: whole device pixels at 1.5");
            fuzzyCompare(lock.capsule.width, pm.width, 0.5);
            compare(box(lock.capsule).x, 774, "an even logical x: device x 1161");
            compare(lock.capsule.height, 156);
            compare(pm.selectedId, "suspend", "Suspend is selected first");
            verify(pm.activeFocus, "the menu has the keys");
            keyClick(Qt.Key_E);
            compare(pm.selectedId, "suspend", "no Log out on the lock");
            keyClick(Qt.Key_L);
            compare(pm.selectedId, "suspend", "no Lock on the lock");
            keyClick(Qt.Key_R);
            compare(pm.selectedId, "reboot");
            keyClick(Qt.Key_Escape);
            verify(!lock.powerOpen, "Esc closes it");
            compare(runs.count, 0);
            verify(lock.card.field.activeFocus, "and the field has the keys back");
            lock.powerOpen = true;
            wait(450);
            keyClick(Qt.Key_P);
            keyClick(Qt.Key_Return);
            compare(runs.count, 1);
            compare(runs.signalArguments[0][0], "shutdown");
            verify(!lock.powerOpen);
        }

        function test_pills() {
            lock.statusPill.suspendButton.activated();
            compare(suspends.count, 1);
            lock.mediaPill.playButton.activated();
            compare(mediaActions.signalArguments[0][0], "toggle");
            verify(!lock.mediaPill.eqClock.ticking, "the bars are still while paused");
            lock.media = ({ present: true, title: "Neon Grid", artist: "Night Rider", playing: true });
            verify(lock.mediaPill.eqClock.ticking, "and step while playing");
            compare(lock.mediaPill.eqClock.step, 100);
            lock.media = ({ present: false });
            wait(300);
            verify(!lock.mediaPill.parent.visible, "no player, no pill");
            verify(!lock.mediaPill.eqClock.ticking);
            lock.status = ({ wifi: { present: false }, battery: { present: false } });
            verify(!lock.statusPill.wifiShown && !lock.statusPill.batteryShown);
            lock.status = ({ wifi: { present: true, radioOn: true, icon: "wifi2" }, battery: { present: true, percent: 25, icon: "batteryLow" } });
            lock.media = ({ present: true, title: "Neon Grid", artist: "Night Rider", playing: false });
        }

        // lock.qml builds every surface with shown false and sets it once the
        // lock is secure (M8 review: built shown, nothing moved).
        function test_lock_in() {
            const s = createTemporaryObject(arriving, root, { focus: false });
            wait(50);
            compare(s.capsule.width, 360, "the capsule starts at the island's rest width");
            compare(s.card.parent.opacity, 0, "the card is not in yet");
            compare(s.clock.parent.parent.opacity, 0, "nor the clock");
            compare(s.wall.opacity, 0, "the wallpaper and scrim are not in: darker shows");
            s.shown = true;
            wait(30);
            verify(s.capsule.width < 360, "the capsule springs in: " + s.capsule.width);
            verify(s.wall.opacity > 0 && s.wall.opacity < 1, "the wallpaper fades in: " + s.wall.opacity);
            verify(s.card.parent.opacity < 0.5, "the card waits out the stagger: " + s.card.parent.opacity);
            wait(600);
            verify(Math.abs(s.capsule.width - 96) <= 2, "and rests at about 96: " + s.capsule.width);
            compare(s.card.parent.opacity, 1);
            compare(s.clock.parent.parent.opacity, 1);
            compare(s.wall.opacity, 1);
        }

        // In pill, full and rail (M10): no island pill to spring from, so the
        // capsule stays at its width and fades in after the stagger, and
        // fades out in place on the way out.
        function test_lock_in_without_island() {
            const s = createTemporaryObject(arriving, root, { focus: false, fromIsland: false });
            wait(50);
            verify(Math.abs(s.capsule.width - 96) <= 2, "the capsule is at its own width from the start: " + s.capsule.width);
            compare(s.capsule.opacity, 0, "and not in yet");
            s.shown = true;
            wait(40);
            verify(s.capsule.opacity < 0.2, "it waits out the stagger: " + s.capsule.opacity);
            wait(600);
            compare(s.capsule.opacity, 1);
            verify(Math.abs(s.capsule.width - 96) <= 2, "no spring: " + s.capsule.width);
            s.shown = false;
            wait(60);
            verify(s.capsule.opacity > 0 && s.capsule.opacity < 1, "it fades out on the leave rule: " + s.capsule.opacity);
            wait(200);
            compare(s.capsule.opacity, 0);
            verify(Math.abs(s.capsule.width - 96) <= 2, "in place, never back to 360: " + s.capsule.width);
        }

        // An output added while locked: its surface is built with shown true.
        function test_built_shown() {
            const s = createTemporaryObject(arriving, root, { focus: false, shown: true });
            wait(20);
            compare(s.card.parent.opacity, 1, "at once");
            compare(s.wall.opacity, 1);
            verify(Math.abs(s.capsule.width - 96) <= 2, "at rest: " + s.capsule.width);
        }

        function test_leave() {
            lock.shown = false;
            wait(500);
            verify(!lock.card.parent.visible, "the card leaves");
            compare(lock.capsule.width, 360, "the capsule springs back to the island's rest width");
            compare(lock.wall.opacity, 1, "the wallpaper stays for the hand-over");
            lock.shown = true;
            wait(600);
        }
    }
}
