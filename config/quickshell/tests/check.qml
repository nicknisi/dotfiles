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
        visible: true
        implicitWidth: 392
        implicitHeight: 300
        MediaCard { id: card; width: 392; player: player }
        HudHome { id: home; width: 392; visible: false }
        CaffeineMenu { width: 320; visible: false }
        Flip { id: flip; width: 80; height: 20; front: "19:57"; back: "Sat 5 Sep" }
        NickAvatar { id: avatar; width: 30; height: 30 }
        SurfaceShadow { id: outerShadow; surface: samplePanel }
        Rectangle {
            id: samplePanel
            x: 100; y: 100; width: 120; height: 80
            radius: Theme.panelRadius
            color: Theme.surface
            opacity: 0.5
            SurfaceShadow { id: innerShadow; surface: samplePanel }
        }
    }

    Hud {
        id: hud
        anchorItem: avatar
        now: new Date()
        monitor: ({ width: 800, height: 600 })
    }

    Connections {
        id: avatarFrames
        target: null
        property int changes: 0
        function onCurrentFrameChanged() { changes++ }
    }

    Timer {
        id: avatarCheck
        interval: 2300
        repeat: true
        property int step: 0
        onTriggered: {
            try {
                const greeting = test.child(avatar, "nickGreeting");
                const runner = test.child(avatar, "nickRunning");
                if (step++ === 0) {
                    test.check(greeting.running && avatarFrames.changes > greeting.frameCount, "hover animation advances beyond its first loop");
                    test.check(greeting.loops === AnimatedSprite.Infinite && greeting.frameRate === 4, "hover animation loops at a relaxed pace");
                    avatar.page = "theme";
                    test.check(!greeting.running, "menu stops the hidden hover animation");
                    avatar.moving = true;
                    avatarFrames.target = runner;
                    avatarFrames.changes = 0;
                    test.check(runner.visible && runner.running && !greeting.visible, "drag overrides menu costumes");
                } else {
                    test.check(avatarFrames.changes > 0, "running frames actually advance");
                    avatar.visible = false;
                    test.check(!runner.running, "hidden runner stops animating");
                    avatar.moving = false;
                    avatar.hovered = false;
                    avatar.page = "";
                    test.check(!test.child(avatar, "nickFace").running, "hidden portrait stops animating");
                    console.log("CAPSULE_TEST_PASS");
                    Qt.quit();
                }
            } catch (error) {
                console.error("CAPSULE_TEST_FAIL: " + error.message);
                Qt.quit();
            }
        }
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
                test.check(Prefs.nextBarMode("full") === "pill", "full mode cycles to pill");
                test.check(Prefs.nextBarMode("pill") === "minimal", "pill mode cycles to minimal");
                test.check(Prefs.nextBarMode("minimal") === "full", "minimal mode cycles to full");

                test.check(!Caffeine.active && Caffeine.selectedMinutes === 60, "stay-awake defaults to a one-hour timer");
                const caffeineStarted = Date.now();
                Caffeine.start(120);
                test.check(Caffeine.active && Caffeine.selectedMinutes === 120, "a duration starts idle inhibition");
                test.check(Caffeine.endsAt >= caffeineStarted + 120 * 60000, "a timed duration records its deadline");
                Caffeine.stop();
                test.check(!Caffeine.active && Caffeine.endsAt === 0, "stay-awake can be stopped early");
                Caffeine.start(-1);
                test.check(Caffeine.active && Caffeine.endsAt === 0, "an indefinite duration has no deadline");
                Caffeine.stop();
                Caffeine.selectedMinutes = 60;

                NotificationState.clear();
                NotificationState.remember({ appName: "Test", summary: "Saved", body: "One", critical: false });
                NotificationState.remember({ appName: "Test", summary: "Urgent", body: "Two", critical: true });
                test.check(NotificationState.count === 2 && NotificationState.unread === 2, "notifications enter history as unread");
                test.check(NotificationState.history.get(0).summary === "Urgent" && NotificationState.history.get(0).critical, "newest notification is first");
                const notificationScreen = ({ name: "test-screen" });
                NotificationState.toggleCenter(notificationScreen);
                test.check(NotificationState.centerOpen && NotificationState.centerScreen === notificationScreen
                    && NotificationState.unread === 0, "opening notification sidebar marks history read");
                NotificationState.toggleCenter(notificationScreen);
                test.check(!NotificationState.centerOpen, "notification sidebar toggles closed on the same screen");
                NotificationState.toggleDnd();
                test.check(NotificationState.dnd, "do not disturb toggles on");
                NotificationState.toggleDnd();
                NotificationState.clear();
                test.check(NotificationState.count === 0 && !NotificationState.dnd, "notification history clears without changing DND");

                test.check(avatar.costume === 0 && !avatar.fullBody, "resting avatar shows Nick's portrait");
                test.check(test.child(avatar, "nickFace").running, "visible portrait can blink");
                for (const [page, costume] of [["home", 2], ["audio", 2], ["net", 3], ["bt", 3], ["display", 3], ["tailscale", 3], ["theme", 4], ["clock", 5], ["unknown", 0]]) {
                    avatar.page = page;
                    avatar.hovered = true;
                    const portrait = test.child(avatar, "nickCostume");
                    test.check(avatar.costume === costume && !avatar.fullBody, "menu costume takes priority over hover: " + page);
                    test.check(portrait.status === Image.Ready && portrait.sourceClipRect.x === costume * 32, "costume atlas loads the correct cell: " + page);
                }
                for (const [edge, anchor, gravity] of [
                    ["top", Edges.Bottom | Edges.Left, Edges.Bottom | Edges.Right],
                    ["bottom", Edges.Top | Edges.Left, Edges.Top | Edges.Right],
                    ["left", Edges.Right | Edges.Top, Edges.Right | Edges.Bottom],
                    ["right", Edges.Left | Edges.Top, Edges.Left | Edges.Bottom]
                ]) {
                    hud.edge = edge;
                    test.check(hud.anchor.edges === anchor && hud.anchor.gravity === gravity, "HUD opens inward from the leading button: " + edge);
                }
                avatar.page = "";
                test.check(avatar.fullBody && test.child(avatar, "nickGreeting").running, "hover starts the full-body animation");
                avatarFrames.target = test.child(avatar, "nickGreeting");

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

                // The context lane reads the focused window. These are the
                // readings, driven directly so no compositor is needed. Not
                // named `home`: that is the HudHome instance a few lines down.
                const homeDir = Quickshell.env("HOME");
                test.check(Context.classify("com.mitchellh.ghostty", false) === "terminal", "ghostty is a terminal");
                test.check(Context.classify("com.mitchellh.ghostty", true) === "agent", "a terminal wearing an agent title is an agent");
                test.check(Context.classify("helium", false) === "browser", "helium is a browser");
                test.check(Context.classify("", false) === "", "no app, no kind");
                test.check(Context.agentParts("◑ Bar ricing redesign")[2] === "Bar ricing redesign", "an agent title splits off its spinner");
                test.check(Context.agentParts("✳ Waiting")[1] === "✳", "the still glyph counts too");
                test.check(Context.agentParts("/home/x/y") === null, "a path is not an agent");
                test.check(Context.pageTitle("Some page - Helium") === "Some page", "the browser suffix goes");
                test.check(Context.pageTitle("A - B - Helium") === "A - B", "only the last suffix goes");
                test.check(Context.pageTitle("No suffix") === "No suffix", "a bare title is left alone");
                test.check(Context.shortPath(homeDir + "/Developer/dotfiles") === "~/Developer/dotfiles", "home folds to ~");
                test.check(Context.shortPath(homeDir) === "~", "home itself is ~");
                test.check(Context.shortPath("/tmp") === "/tmp", "a path outside home stays");
                test.check(Context.describe("terminal", homeDir + "/x", "") === "~/x", "a shell shows its directory");
                test.check(Context.describe("terminal", "nvim", "") === "nvim", "a shell running something shows that");
                test.check(Context.describe("music", "Spotify", "Band – Song") === "Band – Song", "a player shows the track");
                test.check(Context.describe("music", "Spotify", "") === "Spotify", "a silent player shows its title");
                test.check(card.implicitHeight < 200, "media card stays compact");
                test.check(home.implicitHeight < 420, "HUD overview stays compact");
                player.canSeek = true;
                player.lengthSupported = false;
                test.check(!seek.enabled, "unknown duration cannot seek");
                player.lengthSupported = true;
                player.length = 0;
                test.check(!seek.enabled, "zero-duration track cannot seek");

                test.check(innerShadow.radius === Theme.panelRadius && outerShadow.radius === samplePanel.radius, "shadows follow panel corners");
                test.check(innerShadow.width === samplePanel.width && outerShadow.x === samplePanel.x, "child and sibling shadows follow surface geometry");
                test.check(innerShadow.z < 0 && outerShadow.z === samplePanel.z, "shadows draw behind their surfaces without falling behind the scrim");
                test.check(innerShadow.opacity === 1 && outerShadow.opacity === samplePanel.opacity, "surface opacity is applied once");
                test.check(Theme.shadowPadding >= innerShadow.blur, "compact panels reserve the full shadow extent");
                const shadowColor = String(innerShadow.color);
                Theme.palette = { accent: "#a53b62", foreground: "#202020", background: "#f7f3e8", lighter_background: "#e8e0d0", mode: "light" };
                test.check(String(innerShadow.color) === shadowColor && String(samplePanel.color) === String(Theme.surface), "theme switches recolor surfaces without tinting shadows");
                test.check(String(play.background.color) === String(Theme.accent), "controls follow changed theme");
                test.check(String(card.color) === String(Theme.raised), "card follows changed theme");
                card.player = null;
                test.check(!play.enabled && !seek.enabled && !next.enabled, "no-player controls disabled");
                avatarCheck.start();
            } catch (error) {
                console.error("CAPSULE_TEST_FAIL: " + error.message);
                Qt.quit();
            }
        }
    }
}
