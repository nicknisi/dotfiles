import QtQuick
import QtTest
import qs

// Every module of the classic bar (PLAN M4): what a click, a right or middle
// click and the wheel do, which panel each one asks for (lib/Anchored.js
// MENUS maps the names), the highlight on the clicked module, and the
// features the old bar had: the tray, privacy, keep awake, the bell and Do
// not disturb, recording stop. BarView is the real one; tests/bar-drag.sh
// builds the stand-in services, which count what they are asked.
TestCase {
    id: test
    name: "BarActions"
    when: windowShown
    visible: true
    width: 1920
    height: 1080

    BarView {
        id: bar
        screen: ({ width: 1920, height: 1080 })
        workspaces: test.workspaces
        focusedName: "D"
        trayItems: test.trayItems
    }
    property var activated: []
    readonly property var workspaces: [
        { name: "W", urgent: false, activate: () => test.activated = test.activated.concat(["W"]) },
        { name: "D", urgent: false, activate: () => test.activated = test.activated.concat(["D"]) },
        { name: "S", urgent: true, activate: () => test.activated = test.activated.concat(["S"]) }
    ]
    // SystemTrayItem's shape, as plain objects (an `id` property cannot be
    // declared in QML); what the bar asks of them lands in trayLog.
    property var trayLog: []
    function trayStub(id, title, status, onlyMenu, hasMenu) {
        return {
            id: id,
            title: title,
            tooltipTitle: "",
            icon: Qt.resolvedUrl("art.svg"),
            status: status,
            onlyMenu: onlyMenu,
            hasMenu: hasMenu,
            activate: () => test.trayLog = test.trayLog.concat([id + ":activate"]),
            secondaryActivate: () => test.trayLog = test.trayLog.concat([id + ":secondary"]),
            scroll: (delta, horizontal) => test.trayLog = test.trayLog.concat([id + ":scroll " + delta])
        };
    }
    readonly property var trayItems: [trayStub("slack", "Slack", 1, false, true), trayStub("1password", "1Password", 1, true, true), trayStub("discord", "Discord", 0, false, false)]
    QtObject {
        id: player
        property string trackTitle: "A small song"
        property string trackArtist: "A small band"
        property string identity: "Test player"
        property string trackArtUrl: ""
        property bool isPlaying: false
        property bool canTogglePlaying: true
        property bool canGoNext: true
        property bool canGoPrevious: true
        property int toggles: 0
        property int nexts: 0
        property int previouses: 0
        function togglePlaying() { toggles++; isPlaying = !isPlaying; }
        function next() { nexts++; }
        function previous() { previouses++; }
    }

    function init() {
        Prefs.barMode = "pill";
        Prefs.storedEdge = "top";
        Media.player = player;
        player.isPlaying = false;
        player.trackTitle = "A small song";
        player.trackArtist = "A small band";
        player.trackArtUrl = "";
        player.canTogglePlaying = player.canGoNext = player.canGoPrevious = true;
        player.toggles = player.nexts = player.previouses = 0;
        bar.openMenu = "";
        bar.trayItem = null;
        bar.suppressClicks = false;
        bar.mediaButton.wheelAccumulator = 0;
        bar.status = null;
        NotificationState.dnd = false;
        NotificationState.unread = 0;
        NotificationState.reads = 0;
        NotificationState.focused = [];
        Audio.sink = { nickname: "Laptop speakers", properties: {} };
        Audio.muted = false;
        Audio.volume = 0.5;
        Audio.recorders = [];
        Capture.recording = false;
        Capture.stops = 0;
        Caffeine.active = false;
        Battery.present = true;
        Battery.percent = 64;
        Battery.charging = false;
        Net.connected = true;
        Net.portal = false;
        test.activated = [];
        test.trayLog = [];
        waitForRendering(bar);
    }
    function cleanup() {
        Media.player = null;
    }
    function trayButton(index) {
        return bar.trayRepeater.itemAt(index);
    }

    // ---- which panel each module asks for ----------------------------------
    function test_modules_data() {
        return [
            { tag: "status", item: "systemButton", menu: "home", align: "end" },
            { tag: "clock", item: "clockButton", menu: "clock", align: "center" },
            { tag: "network", item: "networkButton", menu: "net", align: "end" },
            { tag: "sound", item: "audioButton", menu: "audio", align: "end" },
            { tag: "notifications", item: "notificationsButton", menu: "notifications", align: "end" },
            { tag: "media", item: "mediaButton", menu: "media", align: "end" }
        ];
    }
    function test_modules(data) {
        for (const mode of ["pill", "full", "rail"]) {
            Prefs.barMode = mode;
            Prefs.storedEdge = mode === "rail" ? "left" : "top";
            waitForRendering(bar);
            const item = bar[data.item];
            verify(item.visible, data.tag + " shows in " + mode);
            mouseClick(item, item.width / 2, item.height / 2, Qt.LeftButton);
            compare(bar.openMenu, data.menu, mode + ": the module asks for its panel");
            compare(bar.menuAnchor, item, "the panel hangs from that module");
            compare(bar.menuAlignment, data.align);
            verify(item.highlighted, "the clicked module is highlighted");
            tryVerify(() => String(item.background.color) === String(Tokens.accentTint), 1000, "accentTint");
            compare(item.background.border.width, mode === "pill" ? 1 : 0, "a 1 px accent ring in the pill only");
            compare(String(item.background.border.color), String(Tokens.accent));
            const r = bar.rectOf(item);
            const p = item.mapToItem(bar, 0, 0);
            compare([r.x, r.y, r.width, r.height], [p.x, p.y, item.width, item.height], "rectOf is the module's box");
            mouseClick(item, item.width / 2, item.height / 2, Qt.LeftButton);
            compare(bar.openMenu, "", mode + ": a second click closes it");
            verify(!item.highlighted);
        }
    }
    function test_moduleFor() {
        compare(bar.moduleFor("status"), bar.systemButton);
        compare(bar.moduleFor("clock"), bar.clockButton);
        compare(bar.moduleFor("anything"), bar.systemButton, "the status module by default");
    }
    // Right click on the status module: Appearance (the bar's mode and edge,
    // AppearanceMenu's four modes).
    function test_statusRightClick() {
        mouseClick(bar.systemButton, 16, 16, Qt.RightButton);
        compare(bar.openMenu, "appearance");
        compare(bar.menuAnchor, bar.systemButton);
        verify(bar.systemButton.highlighted);
    }
    function test_battery() {
        Battery.percent = 64;
        waitForRendering(bar);
        verify(bar.systemButton.width > 32, "the percent shows beside the icon");
        Battery.percent = 12;
        verify(bar.batteryLow);
        Battery.present = false;
        verify(!bar.batteryPresent);
        // A fixture's status stands in for the services (sandbox shots).
        bar.status = { wifi: true, battery: 25, muted: false };
        compare(bar.batteryPercent, 25);
        verify(bar.batteryPresent && bar.wifiOn);
        // The control center footer's rule (CcData.batteryIcon): 25 % on
        // battery carries the one-bar mark, not the empty one.
        compare(bar.batteryIconName, "batteryLow");
        bar.status = { wifi: true, battery: 75, muted: false };
        compare(bar.batteryIconName, "batteryFull");
        bar.status = { wifi: true, battery: 50, muted: false, charging: true };
        compare(bar.batteryIconName, "batteryCharging");
        bar.status = { wifi: true, battery: 25, muted: false };
        compare(bar.networkButton.iconName, "wifi");
        bar.status = { wifi: false, battery: 25, muted: true };
        compare(bar.networkButton.iconName, "wifiOff");
        compare(bar.audioButton.iconName, "volMute");
    }
    function test_network() {
        compare(bar.networkButton.iconName, "wifi");
        Net.connected = false;
        compare(bar.networkButton.iconName, "wifiOff");
        compare(String(bar.networkButton.tint), String(Tokens.bad), "a device with no connection is bad");
        Net.connected = true;
        Net.portal = true;
        compare(bar.networkButton.iconName, "globe", "a captive portal asks to sign in");
    }

    // ---- workspaces ------------------------------------------------------------
    function test_workspaces() {
        const list = bar.workspaceList;
        compare(list.count, 3);
        const chips = [0, 1, 2].map(i => list.itemAtIndex(i));
        verify(chips[1].selected, "D is focused");
        compare(String(chips[1].background.color), String(Tokens.accent), "the focused chip in accent");
        verify(chips[2].urgent, "S wants attention");
        compare(String(chips[2].background.color), String(Tokens.accentTint));
        verify(chips[0].text === "Workspace W" && chips[2].text === "Workspace S · needs attention");
        mouseClick(chips[0], 10, 10);
        compare(test.activated, ["W"], "a click goes there");
        mouseWheel(chips[1], 10, 10, 0, -120);
        compare(test.activated, ["W", "S"], "the wheel steps to the next");
        mouseWheel(chips[1], 10, 10, 0, 120);
        compare(test.activated, ["W", "S", "W"], "and back");
        // A new list with the same names keeps the chips (the count is the model).
        const first = list.itemAtIndex(0);
        bar.workspaces = test.workspaces.slice();
        compare(list.itemAtIndex(0), first, "same count, same delegates");
        bar.workspaces = Qt.binding(() => test.workspaces);
    }

    // ---- the bell and Do not disturb -------------------------------------------
    function test_bell() {
        NotificationState.unread = 2;
        compare(bar.notificationsButton.iconName, "bell");
        verify(findChild(bar.notificationsButton, "barBellDot").visible, "an unread dot");
        mouseClick(bar.notificationsButton, 16, 16, Qt.RightButton);
        verify(NotificationState.dnd, "right click: Do not disturb");
        compare(bar.notificationsButton.iconName, "bellOff");
        compare(bar.openMenu, "", "right click opens nothing");
        mouseClick(bar.notificationsButton, 16, 16, Qt.RightButton);
        verify(!NotificationState.dnd);
        mouseClick(bar.notificationsButton, 16, 16, Qt.LeftButton);
        compare(bar.openMenu, "notifications", "left click: the Notifications sheet");
        compare(NotificationState.unread, 0, "opening them reads them");
        verify(!findChild(bar.notificationsButton, "barBellDot").visible);
        mouseClick(bar.notificationsButton, 16, 16, Qt.RightButton);
        verify(NotificationState.dnd);
        compare(bar.openMenu, "notifications", "Do not disturb leaves the panel open");
    }

    // ---- privacy, keep awake, recording stop -------------------------------------
    function test_privacy() {
        verify(!bar.micButton.visible && !bar.recordButton.visible, "nothing while nothing listens or records");
        Audio.recorders = [{ app: "Zoom" }];
        Capture.recording = true;
        waitForRendering(bar);
        verify(bar.micButton.visible && bar.recordButton.visible);
        compare(bar.micButton.iconName, "mic");
        compare(String(bar.micButton.tint), String(Tokens.bad));
        verify(bar.micButton.text.includes("Zoom"), "it says who");
        mouseClick(bar.micButton, 16, 16);
        compare(bar.openMenu, "audio", "the mic opens the Sound sheet");
        compare(bar.menuAnchor, bar.micButton);
        verify(bar.micButton.highlighted && !bar.audioButton.highlighted, "only the module that asked");
        mouseClick(bar.recordButton, 16, 16);
        compare(Capture.stops, 1, "the record icon stops the recording");
        bar.suppressClicks = true;
        mouseClick(bar.recordButton, 16, 16);
        compare(Capture.stops, 1, "not after a drag");
    }
    function test_keepAwake() {
        verify(!bar.awakeButton.visible);
        Caffeine.active = true;
        waitForRendering(bar);
        verify(bar.awakeButton.visible);
        compare(bar.awakeButton.iconName, "coffee");
        verify(bar.awakeButton.text.includes("1 hour"));
        mouseClick(bar.awakeButton, 16, 16);
        compare(bar.openMenu, "caffeine", "the Keep awake sheet");
    }

    // ---- the tray -----------------------------------------------------------------
    function test_tray() {
        compare(bar.trayRepeater.count, 3);
        const app = trayButton(0), menuOnly = trayButton(1), passive = trayButton(2);
        const slack = test.trayItems[0], onePassword = test.trayItems[1];
        compare(passive.opacity, 0.55, "a passive item is dimmed");
        compare(app.opacity, 1);
        mouseClick(app, 14, 16);
        compare(test.trayLog, ["slack:activate"], "left click: the app's own action");
        compare(NotificationState.focused.length, 1, "then a jump to its window");
        compare(bar.openMenu, "");
        mouseClick(menuOnly, 14, 16);
        compare(test.trayLog, ["slack:activate"], "a menu-only item opens its menu instead");
        compare(bar.openMenu, "tray");
        compare(bar.trayItem, onePassword);
        verify(menuOnly.highlighted && !app.highlighted);
        bar.openMenu = "";
        mouseClick(app, 14, 16, Qt.RightButton);
        compare(bar.openMenu, "tray", "right click: the Tray sheet");
        compare(bar.trayItem, slack);
        bar.openMenu = "";
        mouseClick(passive, 14, 16, Qt.RightButton);
        compare(bar.openMenu, "", "no menu, nothing to open");
        mouseClick(app, 14, 16, Qt.MiddleButton);
        compare(test.trayLog[1], "slack:secondary", "middle click: the secondary action");
        mouseWheel(app, 14, 16, 0, 240);
        compare(test.trayLog[2], "slack:scroll 2", "the wheel scrolls it");
    }

    // ---- media ----------------------------------------------------------------
    function test_mediaButtons_data() {
        return [{ tag: "horizontal", edge: "top" }, { tag: "vertical", edge: "left" }];
    }
    function test_mediaButtons(data) {
        Prefs.storedEdge = data.edge;
        waitForRendering(bar);
        verify(!findChild(bar.mediaButton, "mediaPlayPause"), "no transport buttons in the bar");
        mouseClick(bar.mediaButton, 16, 16, Qt.LeftButton);
        compare(bar.openMenu, "media", "the artwork opens the control center's media card");
        compare(player.toggles, 0);
        if (data.edge === "top") {
            bar.openMenu = "";
            mouseClick(bar.mediaButton, bar.mediaButton.width - 12, 16, Qt.LeftButton);
            compare(bar.openMenu, "media", "the metadata does too");
        }
        bar.openMenu = "";
        mouseClick(bar.mediaButton, 16, 16, Qt.MiddleButton);
        compare(player.toggles, 1);
        compare(bar.openMenu, "", "middle click stays a playback shortcut");
        player.canTogglePlaying = false;
        mouseClick(bar.mediaButton, 16, 16, Qt.MiddleButton);
        compare(player.toggles, 1, "it respects the player's capabilities");
    }
    function test_mediaWidthFollowsText() {
        player.trackTitle = "Hi";
        player.trackArtist = "AB";
        waitForRendering(bar);
        const title = findChild(bar.mediaButton, "mediaTitle");
        const artist = findChild(bar.mediaButton, "mediaArtist");
        const rightEdge = Math.max(title.mapToItem(bar.mediaButton, 0, 0).x + title.implicitWidth, artist.mapToItem(bar.mediaButton, 0, 0).x + artist.implicitWidth);
        verify(bar.mediaButton.width - rightEdge <= 9, "short metadata leaves no large gutter (" + (bar.mediaButton.width - rightEdge) + ")");
        player.trackTitle = "A very long track title ".repeat(20);
        waitForRendering(bar);
        compare(bar.mediaButton.width, 160, "long metadata is capped");
    }
    function test_mediaArtworkAndMetadata() {
        const art = findChild(bar.mediaButton, "mediaArtwork");
        const fallback = findChild(bar.mediaButton, "mediaArtworkFallback");
        const title = findChild(bar.mediaButton, "mediaTitle");
        const artist = findChild(bar.mediaButton, "mediaArtist");
        verify(fallback.visible);
        compare(fallback.name, "music", "a Lucide music icon with no artwork");
        compare(title.text, "A small song");
        compare(artist.text, "A small band");
        player.trackArtUrl = Qt.resolvedUrl("art.svg");
        tryCompare(art, "status", Image.Ready);
        verify(art.visible && !fallback.visible);
        player.trackTitle = "<b>A long title</b>".repeat(20);
        compare(title.textFormat, Text.PlainText);
        verify(title.width < 160, "long titles stay bounded");
        player.trackArtist = "";
        compare(artist.text, "Test player");
        player.trackArtUrl = "";
        tryVerify(() => fallback.visible && !art.visible);
        Media.player = null;
        verify(!bar.mediaButton.visible);
    }
    function test_mediaWheel() {
        mouseWheel(bar.mediaButton, 16, 16, 0, 120);
        compare(player.nexts, 1);
        mouseWheel(bar.mediaButton, 16, 16, 0, -120);
        compare(player.previouses, 1);
        player.canGoNext = player.canGoPrevious = false;
        mouseWheel(bar.mediaButton, 16, 16, 0, 120);
        mouseWheel(bar.mediaButton, 16, 16, 0, -120);
        compare(player.nexts, 1);
        compare(player.previouses, 1);
        compare(bar.openMenu, "");
    }
    function test_trackpad() {
        for (let i = 0; i < 3; i++)
            bar.mediaButton.scrolled(30);
        compare(player.nexts, 0);
        bar.mediaButton.scrolled(30);
        compare(player.nexts, 1);
        bar.mediaButton.scrolled(90);
        bar.mediaButton.scrolled(-30);
        compare(bar.mediaButton.wheelAccumulator, -30, "a direction change starts fresh");
        wait(450);
        compare(bar.mediaButton.wheelAccumulator, 0, "a partial gesture expires");
        bar.mediaButton.scrolled(90);
        Media.player = null;
        compare(bar.mediaButton.wheelAccumulator, 0, "a player change drops a partial gesture");
        verify(!bar.mediaButton.visible);
        bar.mediaButton.scrolled(120);
        compare(player.nexts, 1, "no player is safe");
    }
    function test_suppressedClicks() {
        bar.suppressClicks = true;
        mouseClick(bar.notificationsButton, 16, 16, Qt.RightButton);
        verify(!NotificationState.dnd);
        bar.suppressClicks = true;
        mouseClick(bar.mediaButton, 16, 16, Qt.MiddleButton);
        compare(player.toggles, 0);
        bar.suppressClicks = true;
        mouseWheel(bar.mediaButton, 16, 16, 0, 120);
        compare(player.nexts, 0);
        bar.suppressClicks = true;
        mouseClick(bar.systemButton, 16, 16);
        compare(bar.openMenu, "", "a release after a drag opens nothing");
    }

    // ---- sound ---------------------------------------------------------------
    function test_audio_data() {
        return [
            { tag: "speakers", node: { properties: {} }, icon: "vol" },
            { tag: "headphones", node: { nickname: "Headphones" }, icon: "headphones" },
            { tag: "headset", node: { properties: { "device.form-factor": "headset" } }, icon: "headphones" },
            { tag: "bluetooth", node: { properties: { "device.api": "bluez5" } }, icon: "bt" },
            { tag: "bluetooth-bus", node: { properties: { "device.bus": "bluetooth" } }, icon: "bt" },
            { tag: "bluetooth-name", node: { name: "bluez_output.fixture" }, icon: "bt" },
            { tag: "usb-headphones", node: { properties: { "device.icon-name": "audio-headphones-usb" } }, icon: "headphones" },
            { tag: "hdmi", node: { properties: { "device.profile.name": "HiFi: HDMI1: sink" } }, icon: "monitor" },
            { tag: "unknown", node: { name: "virtual_output" }, icon: "vol" },
            { tag: "disconnected", node: null, icon: "vol" }
        ];
    }
    function test_audio(data) {
        Audio.sink = data.node;
        compare(bar.audioButton.iconName, data.icon);
        Audio.muted = true;
        compare(bar.audioButton.iconName, "volMute", "mute wins over the device type");
        compare(String(bar.audioButton.tint), String(Tokens.bad));
        Audio.muted = false;
        compare(bar.audioButton.iconName, data.icon);
    }
    function test_audioControlsUnchanged() {
        mouseClick(bar.audioButton, 16, 16, Qt.LeftButton);
        compare(bar.openMenu, "audio");
        mouseWheel(bar.audioButton, 16, 16, 0, 120);
        fuzzyCompare(Audio.volume, 0.52, 0.001);
        verify(bar.audioButton.text.includes("Laptop speakers"));
        Audio.ready = false;
        verify(!bar.audioButton.enabled, "no sink, no sound module");
        Audio.ready = true;
    }

    // ---- keyboard ------------------------------------------------------------
    function test_keyboard() {
        bar.systemButton.forceActiveFocus(Qt.TabFocusReason);
        verify(bar.systemButton.visualFocus);
        keyClick(Qt.Key_Return);
        compare(bar.openMenu, "home", "Enter opens the module's panel");
        keyClick(Qt.Key_Return);
        compare(bar.openMenu, "");
    }
}
