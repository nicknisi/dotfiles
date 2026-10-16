import QtQuick
import QtTest

TestCase {
    id: test
    name: "BarActions"
    when: windowShown
    visible: true
    width: 400
    height: 200
    BarActionsFixture { id: bar }
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
        Media.player = player;
        player.isPlaying = false;
        player.trackTitle = "A small song";
        player.trackArtist = "A small band";
        player.trackArtUrl = "";
        bar.vertical = false;
        player.canTogglePlaying = player.canGoNext = player.canGoPrevious = true;
        player.toggles = player.nexts = player.previouses = 0;
        bar.openMenu = "";
        bar.suppressClicks = false;
        bar.media.wheelAccumulator = 0;
        NotificationState.dnd = NotificationState.centerOpen = false;
        Audio.sink = { nickname: "Laptop speakers", properties: {} };
        Audio.muted = false;
        Audio.volume = 0.5;
        waitForRendering(bar);
    }
    function test_bell() {
        mouseClick(bar.bell, 16, 16, Qt.RightButton);
        verify(NotificationState.dnd);
        compare(bar.bell.glyph, "");
        verify(!NotificationState.centerOpen, "right-click does not open center");
        mouseClick(bar.bell, 16, 16, Qt.RightButton);
        verify(!NotificationState.dnd);
        mouseClick(bar.bell, 16, 16, Qt.LeftButton);
        verify(NotificationState.centerOpen, "left-click still opens center");
        verify(!NotificationState.dnd);
        mouseClick(bar.bell, 16, 16, Qt.RightButton);
        verify(NotificationState.dnd);
        verify(NotificationState.centerOpen, "DND does not close the open center");
    }
    function cleanup() { Media.player = null; }
    function test_mediaButtons_data() {
        return [{tag: "horizontal", vertical: false}, {tag: "vertical", vertical: true}];
    }
    function test_mediaButtons(data) {
        bar.vertical = data.vertical;
        waitForRendering(bar);
        verify(!findChild(bar.media, "mediaPlayPause"), "no transport buttons in the bar");
        mouseClick(bar.media, 16, 16, Qt.LeftButton);
        compare(bar.openMenu, "media", "artwork opens dedicated media controls, not system preferences");
        compare(player.toggles, 0);
        if (!data.vertical) {
            bar.openMenu = "";
            mouseClick(bar.media, bar.media.width - 12, 16, Qt.LeftButton);
            compare(bar.openMenu, "media", "metadata also opens media controls");
        }
        bar.openMenu = "";
        mouseClick(bar.media, 16, 16, Qt.MiddleButton);
        compare(player.toggles, 1);
        compare(bar.openMenu, "", "middle-click stays a playback shortcut");
        player.canTogglePlaying = false;
        mouseClick(bar.media, 16, 16, Qt.MiddleButton);
        compare(player.toggles, 1, "respect player capabilities");
    }
    function test_mediaWidthFollowsText() {
        player.trackTitle = "Hi";
        player.trackArtist = "AB";
        waitForRendering(bar);
        const title = findChild(bar.media, "mediaTitle");
        const artist = findChild(bar.media, "mediaArtist");
        const rightEdge = Math.max(title.mapToItem(bar.media, 0, 0).x + title.implicitWidth,
            artist.mapToItem(bar.media, 0, 0).x + artist.implicitWidth);
        verify(bar.media.width - rightEdge <= 4, "short metadata must not leave a large empty right gutter (actual " + (bar.media.width - rightEdge) + ")");
        player.trackTitle = "A very long track title ".repeat(20);
        waitForRendering(bar);
        compare(bar.media.width, 160, "long metadata is still capped");
    }
    function test_mediaArtworkAndMetadata() {
        const art = findChild(bar.media, "mediaArtwork");
        const fallback = findChild(bar.media, "mediaArtworkFallback");
        const title = findChild(bar.media, "mediaTitle");
        const artist = findChild(bar.media, "mediaArtist");
        verify(fallback.visible);
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
        verify(!bar.media.visible);
    }
    function test_mediaWheel() {
        mouseWheel(bar.media, 16, 16, 0, 120);
        compare(player.nexts, 1);
        mouseWheel(bar.media, 16, 16, 0, -120);
        compare(player.previouses, 1);
        player.canGoNext = player.canGoPrevious = false;
        mouseWheel(bar.media, 16, 16, 0, 120);
        mouseWheel(bar.media, 16, 16, 0, -120);
        compare(player.nexts, 1);
        compare(player.previouses, 1);
        compare(bar.openMenu, "");
    }
    function test_trackpad() {
        for (let i = 0; i < 3; i++) bar.media.scrolled(30);
        compare(player.nexts, 0);
        bar.media.scrolled(30);
        compare(player.nexts, 1);
        bar.media.scrolled(90);
        bar.media.scrolled(-30);
        compare(bar.media.wheelAccumulator, -30, "direction change starts fresh");
        wait(450);
        compare(bar.media.wheelAccumulator, 0, "partial gesture expires");
        bar.media.scrolled(90);
        Media.player = null;
        compare(bar.media.wheelAccumulator, 0, "player change discards partial gesture");
        verify(!bar.media.visible);
        bar.media.scrolled(120);
        compare(player.nexts, 1, "absent player is safe");
    }
    function test_suppressedClicks() {
        bar.suppressClicks = true;
        mouseClick(bar.bell, 16, 16, Qt.RightButton);
        verify(!NotificationState.dnd);
        bar.suppressClicks = true;
        mouseClick(bar.media, 16, 16, Qt.MiddleButton);
        compare(player.toggles, 0);
        bar.suppressClicks = true;
        mouseWheel(bar.media, 16, 16, 0, 120);
        compare(player.nexts, 0);
    }
    function test_audio_data() {
        return [
            { tag: "speakers", node: { properties: {} }, glyph: "\u{f057e}" },
            { tag: "headphones", node: { nickname: "Headphones" }, glyph: "\u{f02cb}" },
            { tag: "headset", node: { properties: { "device.form-factor": "headset" } }, glyph: "\u{f02ce}" },
            { tag: "bluetooth", node: { properties: { "device.api": "bluez5" } }, glyph: "\u{f00af}" },
            { tag: "bluetooth-bus", node: { properties: { "device.bus": "bluetooth" } }, glyph: "\u{f00af}" },
            { tag: "bluetooth-name", node: { name: "bluez_output.fixture" }, glyph: "\u{f00af}" },
            { tag: "usb-headphones", node: { properties: { "device.icon-name": "audio-headphones-usb" } }, glyph: "\u{f02cb}" },
            { tag: "hdmi", node: { properties: { "device.profile.name": "HiFi: HDMI1: sink" } }, glyph: "\u{f0379}" },
            { tag: "unknown", node: { name: "virtual_output" }, glyph: "\u{f057e}" },
            { tag: "disconnected", node: null, glyph: "\u{f057e}" }
        ];
    }
    function test_audio(data) {
        Audio.sink = data.node;
        compare(bar.audio.glyph, data.glyph);
        Audio.muted = true;
        compare(bar.audio.glyph, "\u{f0581}", "mute takes priority over device type");
        Audio.muted = false;
        compare(bar.audio.glyph, data.glyph);
    }
    function test_audioControlsUnchanged() {
        mouseClick(bar.audio, 16, 16, Qt.LeftButton);
        compare(bar.openMenu, "audio");
        mouseWheel(bar.audio, 16, 16, 0, 120);
        fuzzyCompare(Audio.volume, 0.52, 0.001);
        verify(bar.audio.text.includes("Laptop speakers"));
    }
}
