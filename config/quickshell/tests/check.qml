// Run with ./config/quickshell/tests/check.sh. No real player is controlled.
import Quickshell
import QtQuick

ShellRoot {
    id: test

    QtObject {
        id: player
        property string dbusName: "test.player"
        property string identity: "Test player"
        property string trackTitle: "A small song"
        property string trackArtist: "A small band"
        property string trackArtUrl: ""
        property bool isPlaying: false
        property bool canTogglePlaying: true
        property bool canGoPrevious: true
        property bool canGoNext: true
        property bool canSeek: true
        property bool positionSupported: true
        property bool lengthSupported: true
        property real length: 240
        property real position: 30
        property int nextCalls: 0
        property int previousCalls: 0
        signal postTrackChanged()
        function togglePlaying() { isPlaying = !isPlaying }
        function next() { nextCalls++ }
        function previous() { previousCalls++ }
    }

    FloatingWindow {
        visible: false
        implicitWidth: 392
        implicitHeight: 300
        MediaCard { id: card; width: 392; player: player }
        HudHome { id: home; width: 392; visible: false }
        Flip { id: flip; width: 80; height: 20; front: "19:57"; back: "Sat 5 Sep" }
    }

    function check(condition, message) {
        if (!condition) throw new Error(message);
    }
    function child(item, name) {
        if (item.objectName === name) return item;
        for (const c of (item.children ?? [])) {
            const found = child(c, name);
            if (found) return found;
        }
        return null;
    }

    Timer {
        interval: 200
        running: true
        onTriggered: {
            try {
                const paused = { dbusName: "paused", isPlaying: false };
                const playing = { dbusName: "playing", isPlaying: true };
                test.check(Media.choosePlayer([], "") === null, "empty player list");
                test.check(Media.choosePlayer([paused, playing], "") === playing, "prefer playing app");
                test.check(Media.choosePlayer([paused, playing], "paused") === paused, "retain chosen app");
                test.check(Media.choosePlayer([playing], "paused") === playing, "removed player fallback");

                const play = test.child(card, "playPause");
                const next = test.child(card, "next");
                const previous = test.child(card, "previous");
                const seek = test.child(card, "seek");
                test.check(play && next && previous && seek, "media controls exist");
                play.click();
                test.check(player.isPlaying, "play invokes player");
                play.click();
                test.check(!player.isPlaying, "pause invokes player");
                next.click();
                previous.click();
                test.check(player.nextCalls === 1 && player.previousCalls === 1, "track controls invoke player");
                seek.moved(0.5);
                test.check(player.position === 120, "seek uses seconds");
                seek.moved(2);
                test.check(player.position === 240, "seek clamps at track length");
                player.canSeek = false;
                seek.moved(0);
                test.check(!seek.enabled && player.position === 240, "unsupported seeking is inert");
                player.canGoNext = false;
                next.click();
                test.check(!next.enabled && player.nextCalls === 1, "unsupported next is inert");
                test.check(card.formatTime(65) === "1:05", "timestamp formatting");

                // A label only turns over when it has a second face. The
                // battery's back is UPower's estimate, which is an empty string
                // until it has worked out a rate, and flipping to nothing would
                // read as the number vanishing under the pointer.
                flip.flipped = true;
                test.check(flip.turned, "a flip with both faces turns");
                flip.back = "";
                test.check(!flip.turned, "a flip with nothing to say stays put");
                flip.back = "Sat 5 Sep";
                flip.flipped = false;
                test.check(!flip.turned, "a flip at rest shows its front");

                // Nothing speaks before the shell has settled, otherwise
                // PipeWire binding the sink at login reads as a volume change.
                Interrupt.kind = "";
                Interrupt.primed = false;
                Interrupt.show("volume");
                test.check(!Interrupt.active, "unprimed interrupts are dropped");

                Interrupt.primed = true;
                Interrupt.show("brightness");
                test.check(Interrupt.kind === "brightness" && Interrupt.active, "a primed interrupt speaks");
                test.check(Interrupt.metered, "brightness draws a meter");

                // Last writer wins: the newest event is the one you caused.
                Interrupt.show("mic");
                test.check(Interrupt.kind === "mic", "the newest interrupt takes the slot");
                test.check(!Interrupt.metered, "the mic has no quantity to meter");
                test.check(Interrupt.label === "mic on", "the mic says its state in words");
                Interrupt.kind = "";
                test.check(!Interrupt.active, "a cleared interrupt is silent");
                test.check(card.implicitHeight < 200, "media card stays compact");
                test.check(home.implicitHeight < 420, "HUD overview stays compact");
                player.canSeek = true;
                player.lengthSupported = false;
                test.check(!seek.enabled, "unknown duration cannot seek");
                player.lengthSupported = true;
                player.length = 0;
                test.check(!seek.enabled, "zero-duration track cannot seek");

                Theme.palette = { accent: "#a53b62", foreground: "#202020", background: "#f7f3e8", lighter_background: "#e8e0d0", mode: "light" };
                test.check(String(play.background.color) === String(Theme.accent), "controls follow changed theme");
                test.check(String(card.color) === String(Theme.raised), "card follows changed theme");
                card.player = null;
                test.check(!play.enabled && !seek.enabled && !next.enabled, "no-player controls disabled");
                console.log("CAPSULE_TEST_PASS");
            } catch (error) {
                console.error("CAPSULE_TEST_FAIL: " + error.message);
            }
            Qt.quit();
        }
    }
}
