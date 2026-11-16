// The classic modes' notification cards (Hosts/NotifStack.qml, which
// Hosts/NotifHost.qml holds in its window) on a fake with
// NotificationServer.qml's shape, offscreen: tests/notif-host.sh. What the
// old toasts did (Notifications.qml, gone in M10) and the banner adds.
import Quickshell
import QtQuick
import qs
import qs.Hosts
import "lib/IslandMachine.js" as IslandMachine

ShellRoot {
    id: test

    property int stage: 0
    property int ticks: 0
    property var invoked: []
    property int paused: 0
    readonly property string longBody: "The notch looks right on the panel now. I checked pill, full and rail on the XPS, and the cards sit under the bar in each one; the second card has its actions under the body, and a critical one has the bad ring. Ship it? Then the lock, the polkit prompt and the pickers, one at a time, with the shots beside each."

    QtObject {
        id: fake
        property var tracked: []
        property var expired: []
        property var dismissed: []
        property bool dnd: false
        property var deadlines: ({})
        function critical(n) {
            return n?.critical === true;
        }
        function timeoutFor(n) {
            return IslandMachine.notifTimeout(n?.expireTimeout ?? -1, fake.critical(n));
        }
        function shows(n) {
            return !fake.dnd || fake.critical(n);
        }
        function remainingFor(n) {
            const at = fake.deadlines[n?.id] ?? 0;
            return at > 0 ? Math.max(0, at - Date.now()) : 0;
        }
        function make(fields) {
            const n = Object.assign({ appName: "notify-send", summary: "", body: "", appIcon: "", image: "", desktopEntry: "", expireTimeout: -1, critical: false, actions: [] }, fields);
            n.expire = () => fake.close(n.id, "expired");
            n.dismiss = () => fake.close(n.id, "dismissed");
            return n;
        }
        function close(id, how) {
            if (how === "expired") fake.expired = fake.expired.concat([id]);
            else fake.dismissed = fake.dismissed.concat([id]);
            fake.tracked = fake.tracked.filter(n => n.id !== id);
        }
    }

    function action(id, text) {
        return { identifier: id, text: text, invoke: () => test.invoked = test.invoked.concat([id]) };
    }
    function check(condition, message) {
        if (!condition) throw new Error(message);
    }
    function pill(card, i) {
        for (const c of card.actionsRow.children)
            if (c.objectName === "notifAction-" + i) return c;
        return null;
    }
    function card(id) {
        return stack.cards.find(c => c.notification?.id === id) ?? null;
    }
    function pass() {
        console.log("NOTIF_HOST_TEST_PASS");
        Qt.quit();
    }
    function fail(message) {
        console.error("NOTIF_HOST_TEST_FAIL: stage " + test.stage + ": " + message);
        Qt.exit(1);
    }

    FloatingWindow {
        visible: true
        implicitWidth: 600
        implicitHeight: 480
        NotifStack {
            id: stack
            x: 28
            y: 8
            source: fake
            model: fake.tracked
        }
    }

    Timer {
        interval: 150
        repeat: true
        running: true
        onTriggered: {
            try {
                test.ticks++;
                if (test.ticks > 60) throw new Error("timed out");
                switch (test.stage) {
                case 0: {
                    // Oldest on top: a timed one with a long body, a critical
                    // one, one with actions (its default is Open's, so three
                    // pills), one whose body has line breaks.
                    fake.tracked = [
                        fake.make({ id: 1, summary: "first", expireTimeout: 900, body: test.longBody }),
                        fake.make({ id: 2, summary: "battery low", critical: true }),
                        fake.make({ id: 3, appName: "Slack", summary: "third", expireTimeout: 5000, actions: [test.action("default", "Open"), test.action("reply", "Reply"), test.action("mute", "Mute"), test.action("later", "Later")] }),
                        fake.make({ id: 5, summary: "lines", expireTimeout: 5000, body: "one<br/>two &amp; <b>three</b>\n\n  four" })
                    ];
                    test.stage++;
                    break;
                }
                case 1: {
                    if (stack.cards.length !== 4) return;
                    test.check(stack.visibleCount === 4, "four cards show: " + stack.visibleCount);
                    const a = test.card(1), b = test.card(2), c = test.card(3), e = test.card(5);
                    // The board where nothing asks for more: 520 x 92, the
                    // tile, Open and the x centred in it.
                    test.check(b.card.width === 520 && b.height === 92 && b.card.height === 92, "a card with one line and no actions is the island's banner, 520 x 92: " + b.height);
                    test.check(b.card.tile.y === 24 && b.card.openButton.y === 31 && b.card.dismissButton.y === 31, "tile, Open and x centred in the 92: " + [b.card.tile.y, b.card.openButton.y, b.card.dismissButton.y]);
                    // A long body wraps to four lines, cut with an ellipsis,
                    // and the card grows by the three past the first.
                    const body = a.card.bodyText;
                    const line = body.height / Math.max(1, body.lineCount);
                    test.check(body.lineCount === 4 && body.truncated, "a long body wraps to four lines, cut: " + body.lineCount + " " + body.truncated);
                    test.check(a.height === Math.ceil(92 + 3 * line) && a.card.tile.y === 24 && a.card.openButton.y === 31, "the card grows by three lines, the tile and Open stay in the top 92: " + [a.height, line]);
                    test.check(e.card.body === "one\ntwo & three\nfour" && e.card.bodyText.lineCount === 3 && e.height === Math.ceil(92 + 2 * e.card.bodyText.height / 3), "line breaks stay, markup and blank lines go: " + JSON.stringify(e.card.body) + " " + e.height);
                    test.check(a.y === 0 && b.y === a.height + 12 && c.y === b.y + 104 && e.y === c.y + c.height + 12 && stack.height === a.height + 92 + c.height + e.height + 3 * 12, "oldest on top, 12 apart: " + [a.y, b.y, c.y, e.y, stack.height]);
                    test.check(!a.card.actionsRow.visible, "no pills without actions");
                    // Every labelled action but the default, in a row under
                    // the body; the card grows by it.
                    test.check(c.card.actionsRow.visible && c.card.extraActions.map(x => x.identifier).join() === "reply,mute,later", "every action but the default: " + c.card.extraActions.map(x => x.identifier));
                    const p0 = test.pill(c.card, 0), p2 = test.pill(c.card, 2);
                    const at0 = p0.mapToItem(c.card, 0, 0), at2 = p2.mapToItem(c.card, 0, 0);
                    test.check(c.height === 92 + 3 + 5 + 30 && Math.round(at0.y) === Math.round(at2.y) && at0.x === 72 && at0.y > 60 && at0.y + 30 <= c.height - 9, "the pills sit in one row under the text, left with it, the card 130 high: " + [c.height, at0.x, at0.y, at2.y]);
                    // Critical: a `bad` ring, the others `hairline`.
                    test.check(String(b.surface.border.color) === String(Tokens.bad) && String(a.surface.border.color) === String(Tokens.hairline), "a critical card's ring is bad: " + [b.surface.border.color, a.surface.border.color]);
                    test.check(a.timeout === 900 && b.timeout === 0 && b.card.progress.parent.visible === false, "timeouts: the sender's, none for critical");
                    test.check(a.expiry.running && !b.expiry.running, "timed cards count down, critical ones do not");
                    // Do not disturb hides all but critical.
                    fake.dnd = true;
                    test.stage++;
                    break;
                }
                case 2: {
                    if (stack.visibleCount !== 1) return;
                    test.check(!test.card(1).visible && test.card(2).visible && !test.card(3).visible && !test.card(5).visible, "Do not disturb keeps only the critical card");
                    test.check(test.card(1).expiry.running, "a hidden card still runs out, as the toast did");
                    fake.dnd = false;
                    test.stage++;
                    break;
                }
                case 3: {
                    if (fake.expired.indexOf(1) < 0) return;
                    test.check(fake.expired.join() === "1" && fake.tracked.some(n => n.id === 2), "the timed card expired; a critical card stays until handled: " + fake.expired);
                    // The pointer on card 3: its countdown waits.
                    test.card(3).pauseCountdown();
                    test.paused = test.card(3).remaining;
                    test.stage++;
                    break;
                }
                case 4: {
                    const c = test.card(3);
                    test.check(!c.expiry.running && c.remaining === test.paused && c.remaining > 0 && c.remaining < 5000, "paused with what it had left: " + c.remaining);
                    c.resumeCountdown();
                    test.check(c.expiry.running && c.remaining >= IslandMachine.RESUME_MIN, "resumed with at least RESUME_MIN: " + c.remaining);
                    c.remaining = 0;
                    c.pauseCountdown();
                    c.resumeCountdown();
                    test.check(c.remaining === IslandMachine.RESUME_MIN, "a nearly spent card gets RESUME_MIN: " + c.remaining);
                    // A pill invokes its action.
                    test.pill(c.card, 0).run();
                    test.check(test.invoked.join() === "reply", "the Reply pill invoked its action: " + test.invoked);
                    test.check(test.pill(c.card, 1).width <= 120, "a pill is at most 120 wide");
                    test.stage++;
                    break;
                }
                case 5: {
                    // Open goes through NotificationState.open: the default
                    // action. The x dismisses.
                    test.card(3).card.open();
                    test.check(test.invoked.join() === "reply,default", "Open invokes the default action: " + test.invoked);
                    test.card(2).card.dismiss();
                    test.check(fake.dismissed.join() === "2", "the x dismisses: " + fake.dismissed);
                    // One that was up before (an island's): the rest of its time.
                    const at = Date.now() + 2500;
                    fake.deadlines = { 4: at };
                    fake.tracked = fake.tracked.concat([fake.make({ id: 4, summary: "adopted", expireTimeout: 8000 })]);
                    test.stage++;
                    break;
                }
                case 6: {
                    const d = test.card(4);
                    if (!d) return;
                    test.check(d.remaining <= 2500 && d.remaining > 1500, "picked up for the rest of its time: " + d.remaining);
                    test.pass();
                    break;
                }
                }
            } catch (e) {
                test.fail(e.message);
            }
        }
    }
}
