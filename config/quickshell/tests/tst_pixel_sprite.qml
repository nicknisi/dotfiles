import QtQuick
import QtTest
import qs
import qs.Kit
import "../lib/CrewModel.js" as CrewModel

// Kit/PixelSprite, Kit/CrewBot and Kit/CrewStrip (PLAN M2). Runs under
// tests/kit.sh: real Kit/, Motion.qml and lib/, stub Tokens (hackerman) and Prefs.
//
// The sprite's promise is the cell grid: every rectangle it draws covers a
// whole number of device pixels at dpr 1.5, and so does every bob or hop
// offset, rounded halves away from zero so the bob stays symmetric. The
// strip's promise is the same as WorkspaceStrip's: the feed sending the same
// agents again must not rebuild a bot; and its bots share one clock, so they
// move on the same tick (one frame per tick for the whole strip).
TestCase {
    id: test
    name: "PixelSprite"
    when: windowShown
    visible: true
    width: 400
    height: 200

    function init() {
        Prefs.motion = "spring";
        Prefs.reducedMotion = false;
    }

    Component {
        id: spriteComponent
        PixelSprite {}
    }
    Component {
        id: botComponent
        CrewBot {}
    }
    Component {
        id: stripComponent
        CrewStrip {}
    }

    function rects(item) {
        const out = [];
        for (let i = 0; i < item.children.length; i++) {
            const c = item.children[i];
            if (c.modelData !== undefined && c.antialiasing !== undefined) out.push(c);
        }
        return out;
    }
    function whole(v) {
        return Math.abs(v - Math.round(v)) < 1e-6;
    }
    function agent(id, mood, extra) {
        return Object.assign({ id: id, mood: mood, riker: false, attention: mood === "needs", name: "Pi",
            state: CrewModel.MOODS[mood].word }, extra || {});
    }

    // ---- the cell grid ----------------------------------------------------------------

    function test_cell_grid() {
        const s = createTemporaryObject(spriteComponent, test, { rows: CrewModel.SPRITES.awake, size: 16, dpr: 1.5, color: "#82fb9c" });
        verify(s !== null);
        compare(s.rowCount, 8);
        compare(s.columns, 8);
        compare(s.cell, 2, "16 px over 8 rows: 2 logical px per cell");
        compare(s.cell * s.dpr, 3, "3 device px per cell at 1.5");
        compare(s.implicitWidth, 16);
        compare(s.implicitHeight, 16);
        const r = rects(s);
        compare(r.length, 13, "awake is 13 runs of #");
        let filled = 0;
        for (const rect of r) {
            filled += rect.width / s.cell;
            verify(!rect.antialiasing, "cells draw without antialiasing");
            verify(String(rect.color) === "#82fb9c", "cells take the sprite's colour");
            for (const v of [rect.x, rect.y, rect.width, rect.height])
                verify(whole(v * s.dpr), "every edge on a device pixel: " + v + " x 1.5");
        }
        compare(filled, 31, "31 filled cells in awake");
        // The run table itself.
        compare(JSON.stringify(s.runsOf([".#.##.#."])), JSON.stringify([{ x: 1, y: 0, w: 1 }, { x: 3, y: 0, w: 2 }, { x: 6, y: 0, w: 1 }]));
        compare(s.runsOf(["........"]).length, 0);
    }

    function test_device_pixel_snap() {
        const s = createTemporaryObject(spriteComponent, test, { rows: CrewModel.SPRITES.wave, dpr: 1.5 });
        // personal-looks 1.4: 18 -> 16, 24 -> 21.333, 14 -> 16 at 1.5.
        for (const [size, drawn] of [[16, 16], [18, 16], [24, 64 / 3], [14, 16]]) {
            s.size = size;
            fuzzyCompare(s.implicitHeight, drawn, 1e-9, "size " + size + " draws " + drawn);
            verify(whole(s.cell * 1.5), "size " + size + ": whole device px per cell");
        }
        s.dpr = 1;
        s.size = 20;
        compare(s.cell, 2, "half rounds down: 2.5 px cells become 2");
        s.dpr = 2;
        s.size = 16;
        compare(s.cell, 2);
        compare(s.cell * 2, 4);
        // Offsets: the nearest device pixel, halves away from zero.
        for (const [v, want] of [[0, 0], [-1, -4 / 3], [1, 4 / 3], [-2, -2], [-4, -4], [1.2, 4 / 3], [-0.2, 0]]) {
            fuzzyCompare(s.snap(v, 1.5), want, 1e-9, "snap " + v);
            verify(whole(s.snap(v, 1.5) * 1.5));
            fuzzyCompare(s.snap(-v, 1.5), -s.snap(v, 1.5), 1e-9, "snap is odd: " + v);
        }
        // The rule M2 chose (personal-looks 1.4): the board's four frames on
        // device pixels, symmetric. The bob is 0 / -2 / -3 / -2 device px at 1.5,
        // the hop 0 / -3 / -6 / -3; at 1 and 2 they keep the board's numbers.
        const device = (frames, r) => frames.map(f => Math.round(s.snap(f, r) * r));
        compare(device(CrewModel.MOODS.working.frames, 1.5), [0, -2, -3, -2], "bob at 1.5");
        compare(device(CrewModel.HOP, 1.5), [0, -3, -6, -3], "hop at 1.5");
        compare(device(CrewModel.MOODS.working.frames, 1), [0, -1, -2, -1], "bob at 1");
        compare(device(CrewModel.MOODS.working.frames, 2), [0, -2, -4, -2], "bob at 2");
        compare(s.snapCell(0.1, 1.5), 1 / 1.5, "never thinner than one device pixel");
    }

    // ---- the bot ----------------------------------------------------------------------

    function test_bot_moods() {
        const b = createTemporaryObject(botComponent, test, { mood: "needs", dpr: 1.5 });
        compare(b.spriteName, "wave");
        compare(String(b.tint), String(Tokens.accent), "needs is accent");
        compare(b.period, 4000, "two 500 ms hops, then 3 s still");
        compare(b.frameCount, 32);
        compare(b.frameMs, 125);
        b.mood = "working";
        compare(b.spriteName, "awake");
        compare(String(b.tint), String(Tokens.fg));
        compare(b.period, 1000);
        b.riker = true;
        compare(b.spriteName, "hat", "a Riker worker wears the hat");
        b.mood = "asleep";
        compare(b.spriteName, "sleep", "asleep has no hat variant");
        compare(String(b.tint), String(Tokens.inkDim));
        verify(!b.moving, "asleep holds still");
        compare(b.offset, 0);
        compare(b.width, 16);
        compare(b.height, 16);
    }

    // The hail ring's bot: the board's endless hop (HOP over 500 ms), own timer.
    function test_bot_hops_on_device_pixels() {
        const b = createTemporaryObject(botComponent, test, { mood: "needs", dpr: 1.5, frames: CrewModel.HOP, period: CrewModel.HOP_PERIOD });
        verify(b.moving, "a waiting bot hops");
        const seen = {};
        for (let i = 0; i < 8; i++) {
            seen[b.offset] = true;
            verify(whole(b.offset * 1.5), "hop offset on a device pixel: " + b.offset);
            verify(whole(b.sprite.y * 1.5));
            wait(130);
        }
        verify(seen[-4] && seen[0], "the hop reaches -4 and comes back: " + JSON.stringify(Object.keys(seen)));
        Prefs.reducedMotion = true;
        verify(!b.moving, "reduced motion stops the loop");
        compare(b.offset, 0, "and the bot rests on its baseline");
    }

    // On the rest pill a needs bot hops twice, then holds for 3 s (OmniWM's
    // waving bot moves for the first 0.9 s of every 4 s).
    function test_needs_hops_in_bursts() {
        const f = CrewModel.MOODS.needs.frames;
        compare(f.length, 32);
        compare(f.slice(0, 8), CrewModel.HOP.concat(CrewModel.HOP), "two hops first");
        verify(f.slice(8).every(v => v === 0), "then still for 24 frames (3 s)");
        compare(CrewModel.MOODS.needs.period / f.length, 125, "125 ms frames, the board's hop speed");
    }

    function test_bot_stops_when_hidden() {
        const b = createTemporaryObject(botComponent, test, { mood: "working" });
        verify(b.moving);
        b.visible = false;
        verify(!b.moving, "a hidden bot does not tick");
        b.visible = true;
        b.phase = 2;
        b.visible = false;
        b.visible = true;
        compare(b.frame, 2, "a restart begins at the phase");
    }

    // ---- the strip ----------------------------------------------------------------------

    function test_strip_gate_and_overflow() {
        const four = [agent("%2", "needs"), agent("pid:6010", "working", { riker: true }), agent("%0", "working"), agent("%3", "asleep")];
        const s = createTemporaryObject(stripComponent, test, { agents: four, dpr: 1.5 });
        compare(s.ids, ["%2", "pid:6010", "%0", "%3"]);
        compare(s.builds, 4);
        compare(s.width, 4 * 16 + 3 * 6, "four bots and three gaps");
        compare(s.height, 18);
        verify(s.visible);
        compare(s.Accessible.name, "Crew: 4 agents, 1 needs you");
        // The feed's next answer: new objects, same agents, one mood changed.
        const again = four.map(a => Object.assign({}, a));
        again[3].mood = "working";
        s.agents = again;
        compare(s.builds, 4, "same ids: no bot rebuilt");
        // Every second working bot starts two frames (450 ms) into its bob.
        compare([0, 1, 2, 3].map(i => s.phaseFor(i)), [0, 0, 2, 0]);

        const many = [];
        for (let i = 0; i < 12; i++)
            many.push(agent("a" + i, i < 2 ? "needs" : "working"));
        s.agents = many;
        compare(s.ids.length, 8, "eight bots at most");
        compare(s.more, 4);
        // Row lays out on the next polish, so widths settle a frame later.
        tryVerify(() => s.width > 8 * 16 + 7 * 6, 1000, "+4 follows the bots");

        s.agents = [];
        verify(!s.visible, "no agents: the zone is hidden");
        compare(s.width, 0, "and adds no width");

        s.agents = four;
        s.stale = true;
        compare(s.ids.length, 0, "a stale feed hides the bots");
        verify(s.visible, "and shows a sleeping bot and ?");
        tryVerify(() => s.width > 16 && s.width < 16 + 6 + 16, 1000, "one bot and a ?: " + s.width);
        compare(s.Accessible.name, "Crew feed isn't updating");
    }

    // personal-looks 6: every bot is named "{name}, {state word}"; 3.3: the
    // stale feed has a tooltip.
    function test_strip_names_and_tooltip() {
        const four = [agent("%2", "needs"), agent("pid:6010", "working", { riker: true, name: "Riker \u00b7 worker" }), agent("%0", "working", { name: "Claude Code" }), agent("%3", "asleep", { name: "Codex" })];
        const s = createTemporaryObject(stripComponent, test, { agents: four, dpr: 1.5 });
        compare([0, 1, 2, 3].map(i => s.botAt(i).Accessible.name), ["Pi, needs you", "Riker \u00b7 worker, working", "Claude Code, working", "Codex, asleep"]);
        verify(!s.botAt(0).Accessible.ignored, "listed bots are not ignored");
        compare(s.tooltip.text, "Crew feed isn't updating");
        verify(!s.tooltip.visible, "no tooltip while the feed is fresh");
        s.stale = true;
        mouseMove(s, 4, 4);
        tryVerify(() => s.hovered, 1000, "the strip sees the pointer");
        tryVerify(() => s.tooltip.visible, 2000, "a stale feed shows its tooltip on hover");
        verify(s.tooltip.y >= s.height, "under the strip, not above the pill");
        s.stale = false;
        verify(!s.tooltip.visible, "and hides it once the feed answers");
    }

    // One clock for the strip: every bot's frame follows its ticks.
    function test_strip_shares_one_clock() {
        const four = [agent("%2", "needs"), agent("pid:6010", "working"), agent("%0", "working"), agent("%3", "asleep")];
        const s = createTemporaryObject(stripComponent, test, { agents: four, dpr: 1.5 });
        const c = s.clock;
        compare(c.step, 125, "a needs bot sets 125 ms ticks");
        verify(c.ticking);
        for (let i = 0; i < 4; i++)
            verify(s.botAt(i).clock === c, "bot " + i + " reads the strip's clock");
        verify(s.botAt(0).moving && s.botAt(1).moving && !s.botAt(3).moving, "needs and working move, asleep holds");
        // Each tick moves every bot to the frame elapsed says, together.
        let ticks = 0, bad = "";
        const check = () => {
            ticks++;
            for (let i = 0; i < 3; i++) {
                const b = s.botAt(i);
                const want = (Math.floor(c.elapsed / b.frameMs) + b.phase) % b.frameCount;
                if (b.frame !== want) bad += " bot" + i + "@" + c.elapsed + ":" + b.frame + "!=" + want;
            }
        };
        c.elapsedChanged.connect(check);
        wait(700);
        c.elapsedChanged.disconnect(check);
        verify(ticks >= 4 && ticks <= 7, "about one tick per 125 ms: " + ticks);
        compare(bad, "", "every bot on the shared frame");
        compare(s.botAt(2).phase, 2, "the second working bot runs half a bob behind");
        // Working bots only: 250 ms ticks; nobody moving: no ticks at all.
        s.agents = [agent("%2", "working"), agent("pid:6010", "working"), agent("%0", "working"), agent("%3", "asleep")];
        compare(c.step, 250, "only working bots: 250 ms ticks");
        s.agents = [agent("%2", "asleep"), agent("pid:6010", "asleep"), agent("%0", "asleep"), agent("%3", "asleep")];
        compare(c.step, 0);
        verify(!c.ticking, "an all-asleep strip never ticks");
        // The host's gate (the session idle) stops the clock and grounds every bot.
        s.agents = four;
        verify(c.ticking);
        s.animated = false;
        verify(!c.ticking && c.elapsed === 0, "animated false stops the clock");
        for (let i = 0; i < 4; i++)
            compare(s.botAt(i).offset, 0, "bot " + i + " rests on its baseline");
        s.animated = true;
        Prefs.reducedMotion = true;
        verify(!c.ticking, "reduced motion stops it too");
    }
}
