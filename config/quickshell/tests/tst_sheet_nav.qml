import QtQuick
import QtTest
import qs
import qs.Panels
import "../lib/CcData.js" as CcData

// The control center's sheet stack and the sheet frame (control-lock 3.1,
// 3.2, PLAN M6): a sheet slides in from +760 to 0 over Motion.spatial, back
// slides it out and unloads it, home fades and returns; the frame's keys
// (Up/Down, Enter, Delete, Esc / Backspace / Alt+Left), a nested page's back,
// the passphrase row, and focus going back to the tile that opened it. The M6
// review: rows are 46 with a sub too, the row's ring and trash show only for
// the keys (never after a click), and a data change keeps the rows.
Item {
    id: root
    width: 800
    height: 600

    ControlCenter {
        id: cc
        model: CcData.home({ dnd: false }, 0, null)
        animated: false
        sheetUrl: function (name) {
            if (name === "nightlight" || name === "awake") return Qt.resolvedUrl("StepStub.qml");
            return ["wifi", "sound", "tailscale", "bt", "notifications"].indexOf(name) >= 0 ? Qt.resolvedUrl("SheetStub.qml") : "";
        }
    }

    SignalSpy {
        id: asks
        target: cc
        signalName: "action"
    }

    SignalSpy {
        id: closes
        target: cc
        signalName: "closeRequested"
    }

    TestCase {
        name: "SheetNav"
        when: windowShown
        visible: true

        function init() {
            cc.closeSheet(true);
            cc.shown = true;
            cc.model = CcData.home({ dnd: false }, 0, null);
            closes.clear();
            asks.clear();
            tryCompare(cc, "sheetOffset", 760);
        }

        function test_slides_in_and_out() {
            verify(cc.openSheet("wifi"));
            compare(cc.sheet, "wifi");
            const sheet = cc.sheetItem;
            verify(sheet !== null && sheet.shown, "the sheet shows as it slides");
            compare(sheet.width, 728);
            compare(sheet.height, 528);
            compare(cc.sheetOffset, 760, "it starts off to the right, at +760");
            tryCompare(cc, "sheetOffset", 0, Motion.spatial + 200);
            tryCompare(cc.home, "opacity", 0, 500);
            verify(!cc.home.visible && !cc.home.enabled, "home is out of the way");
            sheet.back();
            compare(cc.sheet, "");
            verify(!sheet.shown, "a sheet stops (scanners, agents) as soon as it leaves");
            verify(cc.sliding);
            tryCompare(cc, "sheetOffset", 760, Motion.spatial + 200);
            tryCompare(cc.sheetLoader, "status", Loader.Null, 500);
            tryCompare(cc.home, "opacity", 1, 800);
        }

        function test_unknown_sheet() {
            verify(!cc.openSheet("display"), "no component for it");
            verify(!cc.openSheet(""));
            compare(cc.sheet, "");
        }

        function test_frame_layout() {
            cc.openSheet("wifi");
            const sheet = cc.sheetItem;
            compare(sheet.backButton.width, 32);
            compare(sheet.body.y, 36 + 14, "groups 14 under the 36 px header");
            compare(sheet.footerButton.height, 38);
            compare(sheet.footerButton.y, 528 - 38, "the footer sits at the bottom");
            compare(sheet.rows.length, 3, "the inert row is not a stop");
            const home = sheet.rowItem("home");
            verify(home !== null && home.subText.visible, "home-5g has a sub");
            compare(home.height, 46, "a two-line row is 46 too: the text column's 6 + 6 padding counts once");
            compare(sheet.rowItem("note").height, 46, "and a one-line row 46");
            compare(home.objectName, "sheetRow-home");
        }

        function test_rows_survive_a_data_change() {
            cc.openSheet("wifi");
            const sheet = cc.sheetItem;
            const before = sheet.rowItem("cafe");
            // A service changing: the same rows in fresh arrays, one sub new.
            const data = JSON.parse(JSON.stringify(sheet.sheetData));
            data.groups[1].rows[0].sub = "Connecting…";
            sheet.sheetData = data;
            compare(sheet.rowItem("cafe"), before, "the row is updated in place, not rebuilt");
            compare(before.subText.text, "Connecting…");
        }

        function ring(row) {
            return findChild(row, "sheetRowRing");
        }
        function forget(row) {
            return findChild(row, "sheetForget");
        }

        function test_ring_follows_the_keys() {
            // Opened by the pointer (a chevron click): no ring, no trash.
            cc.tiles.itemAt(0).more(false);
            const sheet = cc.sheetItem;
            tryVerify(() => sheet.activeFocus, 500, "the keys are in the sheet all the same");
            const home = sheet.rowItem("home");
            verify(!sheet.keyboard && !ring(home).visible && !forget(home).visible, "a click draws neither the ring nor the trash");
            // The first arrow shows where the keys are; the next one moves.
            keyClick(Qt.Key_Down);
            compare(sheet.current, 0, "the first Down shows the first row");
            verify(ring(home).visible && forget(home).visible, "now the ring and the trash show");
            const ringBox = ring(home).mapToItem(home, 0, 0);
            compare(ringBox.x, -4, "2 px outside the row with a 2 px gap (Kit FocusRing)");
            compare(ring(home).width, home.width + 8);
            compare(ring(home).border.width, 2);
            keyClick(Qt.Key_Down);
            compare(sheet.current, 1);
            verify(!ring(home).visible && ring(sheet.rowItem("cafe")).visible, "the ring moves with the keys");
            // A pointer press hides it again.
            mouseClick(sheet.rowItem("nested"));
            verify(!sheet.keyboard && !ring(sheet.rowItem("nested")).visible, "no ring after a click");
            // Tab to the back button: its own ring, none on the row.
            sheet.backHandler();
            sheet.forceActiveFocus();
            keyClick(Qt.Key_Tab);
            verify(sheet.backButton.activeFocus && sheet.keyboard, "Tab reaches the back button and counts as the keys");
            verify(!ring(sheet.rowItem("nested")).visible, "the row's ring stays off while the header has the keys");
            cc.closeSheet(true);
            // Opened by key: the first row's ring and trash at once.
            verify(cc.openSheet("wifi", null, true));
            const keyed = cc.sheetItem.rowItem("home");
            tryVerify(() => cc.sheetItem.activeFocus, 500);
            verify(cc.sheetItem.keyboard && ring(keyed).visible && forget(keyed).visible, "opened by key: ring and trash on the first row");
        }

        function test_focus_home_with_a_sheet() {
            // `island open cc/<sheet>` from rest: the island's focusPanel()
            // runs after the sheet opened, and must not pull the keys home.
            cc.openSheet("sound", null, false);
            cc.focusHome(true);
            tryVerify(() => cc.sheetItem.activeFocus, 500, "the keys go to the sheet, not the hidden Wi-Fi disc");
            verify(!cc.tiles.itemAt(0).disc.activeFocus);
            verify(cc.sheetItem.keyboard, "and by key, so its ring shows");
        }

        // A stepper row (the night light's From and To) and a slider naming its
        // `step` (its warmth): Left and Right reach them, and the pointer has
        // a minus and a plus either side of the trail. A plain slider row and
        // Alt+Left keep what they did.
        function test_steps() {
            verify(cc.openSheet("nightlight", null, true));
            const sheet = cc.sheetItem;
            tryVerify(() => sheet.activeFocus, 500, "focus lands in the sheet");
            compare(sheet.rows.map(r => r.key).join(" "), "warmth from plain", "the inert stepper is no stop");
            compare(findChild(sheet.rowItem("warmth"), "sheetRowSlider").stepSize, 0.1, "the row's step");
            compare(findChild(sheet.rowItem("plain"), "sheetRowSlider").stepSize, 0.05, "5 % when it names none");
            keyClick(Qt.Key_Right);
            keyClick(Qt.Key_Left);
            compare(sheet.log.join("|"), "slid warmth 0.60|slid warmth 0.40", "the warmth moves by its step");
            keyClick(Qt.Key_Down);
            keyClick(Qt.Key_Right);
            keyClick(Qt.Key_Left);
            compare(sheet.log.slice(2).join("|"), "step from 1|step from -1", "From steps later and earlier");
            keyClick(Qt.Key_Down);
            keyClick(Qt.Key_Right);
            compare(sheet.log.length, 4, "a plain slider row ignores the arrows, as before");
            // The pointer: minus, the trail, plus.
            const from = sheet.rowItem("from");
            const down = findChild(from, "sheetStepDown"), up = findChild(from, "sheetStepUp");
            verify(down.visible && up.visible, "a stepper row has both buttons");
            compare([down.width, down.height, down.radius, up.width], [26, 26, 8, 26]);
            const dx = down.mapToItem(from, 0, 0).x, ux = up.mapToItem(from, 0, 0).x;
            verify(dx < ux && ux + 26 <= from.width - 10 + 0.01, "minus, then plus at the row's right padding: " + dx + " " + ux);
            mouseClick(up);
            mouseClick(down);
            compare(sheet.log.slice(4).join("|"), "step from 1|step from -1", "the buttons step");
            verify(!findChild(sheet.rowItem("plain"), "sheetStepUp").visible && !findChild(sheet.rowItem("warmth"), "sheetStepDown").visible, "only stepper rows have them");
            mouseClick(findChild(sheet.rowItem("dead"), "sheetStepUp"));
            compare(sheet.log.length, 6, "an inert stepper does nothing");
            keyClick(Qt.Key_Left, Qt.AltModifier);
            compare(cc.sheet, "", "Alt+Left still goes back");
        }

        // The night light's mini: a press toggles while hyprsunset answers and
        // opens the sheet while it does not; the chevron, a right click and
        // Alt+Right open it either way. Keep awake keeps its toggle.
        function test_night_light_mini() {
            const night = cc.minis.itemAt(1);
            compare(night.objectName, "ccMini-nightlight");
            verify(night.hasSheet && night.chevron.visible, "a chevron: it has a sheet");
            verify(cc.minis.itemAt(0).chevron.visible && !cc.minis.itemAt(2).chevron.visible, "Keep awake has one, Display none");
            compare(night.sub, "Unavailable");
            mouseClick(night);
            compare(cc.sheet, "nightlight", "unavailable: the press opens the sheet");
            compare(asks.count, 0, "and asks for no toggle");
            cc.closeSheet(true);
            tryCompare(cc, "sheetOffset", 760);
            cc.model = CcData.home({ dnd: false, nightlight: { available: true, on: false, temperature: 4000, until: "20:00" } }, 0, null);
            compare(night.sub, "From 20:00");
            mouseClick(night);
            compare(cc.sheet, "", "available: the press toggles");
            compare(asks.count, 1);
            compare(asks.signalArguments[0][0], "mini");
            compare(asks.signalArguments[0][1], "nightlight");
            mouseClick(night.chevron);
            compare(cc.sheet, "nightlight", "the chevron opens the sheet");
            cc.closeSheet(true);
            tryCompare(cc, "sheetOffset", 760);
            mouseClick(night, 20, 40, Qt.RightButton);
            compare(cc.sheet, "nightlight", "so does a right click");
            cc.closeSheet(true);
            tryCompare(cc, "sheetOffset", 760);
            night.forceActiveFocus();
            keyClick(Qt.Key_Right, Qt.AltModifier);
            compare(cc.sheet, "nightlight", "and Alt+Right");
            compare(asks.count, 1, "none of them toggled");
            cc.closeSheet(true);
            tryCompare(cc, "sheetOffset", 760);
            mouseClick(cc.minis.itemAt(0).chevron);
            compare(cc.sheet, "awake", "Keep awake's chevron opens its durations");
        }

        function test_keys() {
            cc.openSheet("wifi", null, true);
            const sheet = cc.sheetItem;
            tryVerify(() => sheet.activeFocus, 500, "focus lands in the sheet");
            compare(sheet.current, 0);
            keyClick(Qt.Key_Down);
            compare(sheet.current, 1);
            keyClick(Qt.Key_J, Qt.ControlModifier);
            compare(sheet.current, 2);
            keyClick(Qt.Key_Down);
            compare(sheet.current, 0, "wraps");
            keyClick(Qt.Key_Up);
            compare(sheet.current, 2);
            keyClick(Qt.Key_Return);
            compare(sheet.log[sheet.log.length - 1], "activate nested");
            compare(sheet.page, "nested");
            keyClick(Qt.Key_Escape);
            compare(sheet.page, "", "back leaves the nested page first");
            compare(cc.sheet, "wifi", "and stays in the sheet");
            sheet.current = 0;
            keyClick(Qt.Key_Delete);
            compare(sheet.log[sheet.log.length - 1], "forget home");
            keyClick(Qt.Key_Backspace);
            compare(cc.sheet, "", "Backspace goes back");
        }

        function test_alt_left_and_escape_at_home() {
            cc.openSheet("sound");
            tryVerify(() => cc.sheetItem.activeFocus, 500);
            keyClick(Qt.Key_Left, Qt.AltModifier);
            compare(cc.sheet, "");
            cc.focusHome();
            keyClick(Qt.Key_Escape);
            compare(closes.count, 1, "Esc at home asks to close");
        }

        function test_focus_returns_to_the_opener() {
            const tile = cc.tiles.itemAt(2);
            compare(tile.key, "ts");
            tile.chevron.forceActiveFocus();
            keyClick(Qt.Key_Right);
            compare(cc.sheet, "tailscale", "Right on a chevron opens its sheet");
            verify(cc.sheetItem.keyboard, "by key");
            cc.sheetItem.back();
            verify(tile.chevron.activeFocus, "focus goes back to the chevron that opened it");
            // After the pointer: back to the ring-less holder, no ring on the chevron.
            tile.more(false);
            cc.sheetItem.back();
            verify(!tile.chevron.activeFocus && findChild(cc, "ccHomeKeys").activeFocus, "a click leaves no ring behind");
        }

        function test_navigate_and_dismiss() {
            cc.openSheet("wifi");
            cc.sheetItem.navigate("sound");
            compare(cc.sheet, "sound", "a sheet can open another");
            cc.sheetItem.dismissed();
            compare(closes.count, 1, "dismissed asks the host to close");
        }

        function test_passphrase_row() {
            cc.openSheet("wifi");
            const sheet = cc.sheetItem;
            const row = sheet.rowItem("cafe");
            const before = row.height;
            sheet.activate(sheet.rows[1]);
            compare(sheet.expandedKey, "cafe");
            compare(row.height, before + 52, "the row grows 52 for its field");
            tryVerify(() => row.field.activeFocus, 500, "the field takes the keys");
            keyClick(Qt.Key_S);
            keyClick(Qt.Key_3);
            compare(row.field.text, "s3");
            keyClick(Qt.Key_Return);
            compare(sheet.log[sheet.log.length - 1], "submit cafe s3");
            compare(sheet.expandedKey, "");
            compare(row.field.text, "", "the secret is gone once submitted");
            sheet.expandedKey = "cafe";
            keyClick(Qt.Key_X);
            cc.shown = false;
            compare(row.field.text === "" || cc.sheetItem === null, true, "hiding clears what was typed");
        }

        function test_hidden_host_closes_the_sheet() {
            cc.openSheet("bt");
            cc.shown = false;
            compare(cc.sheet, "", "the island leaving cc drops the sheet");
            compare(cc.sheetOffset, 760);
            compare(cc.home.opacity, 1);
        }

        function test_switch_and_footer() {
            cc.openSheet("notifications");
            const sheet = cc.sheetItem;
            mouseClick(sheet.toggle);
            compare(sheet.log[sheet.log.length - 1], "switch false", "the switch asks, the sheet decides");
            mouseClick(sheet.footerButton);
            compare(sheet.log[sheet.log.length - 1], "footer");
        }
    }
}
