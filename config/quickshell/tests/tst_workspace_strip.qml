import QtQuick
import QtTest
import qs
import qs.Kit
import "../lib/Celestial.js" as Celestial

// Kit/WorkspaceStrip and Kit/FocusShape (PLAN M1). Runs under tests/kit.sh:
// real Kit/, Motion.qml and lib/, stub Tokens (hackerman) and Prefs.
//
// The point of the strip's gate: the same names arriving again, as Hyprland
// sends them on every event, must not rebuild a single delegate.
TestCase {
    id: test
    name: "WorkspaceStrip"
    when: windowShown
    visible: true
    width: 400
    height: 200

    function init() {
        Prefs.motion = "spring";
        Prefs.reducedMotion = false;
    }

    Component {
        id: stripComponent
        WorkspaceStrip {}
    }
    Component {
        id: shapeComponent
        FocusShape {}
    }
    SignalSpy {
        id: activations
        signalName: "activated"
    }

    function items(names, focused, urgent) {
        return names.map(n => ({ name: n, focused: n === focused, urgent: (urgent || []).includes(n) }));
    }
    function letters(strip) {
        const out = [];
        for (let i = 0; i < strip.children.length; i++) {
            const c = strip.children[i];
            if (c.modelData !== undefined && c.index !== undefined) out[c.index] = c;
        }
        return out;
    }
    function ink(cell) {
        for (let i = 0; i < cell.children.length; i++)
            if (cell.children[i].text !== undefined) return cell.children[i];
        return null;
    }
    function strip(props) {
        const s = createTemporaryObject(stripComponent, test, props || { items: items(["W", "C", "D", "S"], "D") });
        verify(s !== null);
        return s;
    }

    // ---- the gate ---------------------------------------------------------------

    SignalSpy {
        id: nameChanges
        signalName: "namesChanged"
    }

    function test_same_items_do_not_rebuild() {
        const s = strip();
        compare(s.names, ["W", "C", "D", "S"]);
        compare(s.builds, 4, "one delegate per letter");
        const before = letters(s);
        compare(before.length, 4);
        nameChanges.target = s;
        nameChanges.clear();

        // Hyprland's push: a new array of new objects, same names, same focus.
        for (let i = 0; i < 5; i++)
            s.items = items(["W", "C", "D", "S"], "D");
        // The gate itself: names is not even reassigned. (Qt 6.12's Repeater
        // also skips an equal array, so builds alone would not catch a
        // missing gate.)
        compare(nameChanges.count, 0, "same names: the model is not replaced");
        compare(s.builds, 4, "same names: no rebuild");
        const again = letters(s);
        for (let i = 0; i < 4; i++)
            verify(again[i] === before[i], "delegate " + i + " is the same object");

        // Focus and urgency move without a rebuild too.
        s.items = items(["W", "C", "D", "S"], "W", ["S"]);
        compare(nameChanges.count, 0, "focus change: the model is not replaced");
        compare(s.builds, 4, "focus change: no rebuild");
        compare(s.focusedName, "W");
        compare(s.urgentNames, ["S"]);
        verify(letters(s)[0] === before[0]);

        // A new name is a real change.
        s.items = items(["W", "C", "D", "N", "S"], "W");
        compare(s.names, ["W", "C", "D", "N", "S"]);
        compare(nameChanges.count, 1);
        verify(s.builds > 4, "a new workspace rebuilds, " + s.builds);
        compare(letters(s).length, 5);
        nameChanges.target = null;
    }

    function test_same_items_helper() {
        const s = strip();
        verify(s.sameItems(["A", "B"], ["A", "B"]));
        verify(!s.sameItems(["A", "B"], ["B", "A"]));
        verify(!s.sameItems(["A"], ["A", "B"]));
        verify(!s.sameItems(null, []));
    }

    // ---- layout and ink -----------------------------------------------------------

    function test_layout() {
        const s = strip();
        compare(s.implicitWidth, 4 * 22 + 3 * 2, "n * 22 + (n - 1) * 2");
        compare(s.implicitHeight, 22);
        const cells = letters(s);
        compare(cells[2].x, 48);
        compare(cells[2].width, 22);
        compare(s.focusedIndex, 2);
        compare(s.shape.x, 48, "the shape sits under D");
        compare(s.shape.size, 22);
        compare(ink(cells[2]).font.family, "Monaspace Argon");
        compare(ink(cells[2]).font.pixelSize, 12);
        compare(ink(cells[2]).font.weight, Font.Medium);
        tryCompare(ink(cells[2]), "color", Tokens.onAccent);
        tryCompare(ink(cells[0]), "color", Tokens.inkDim);
        compare(s.shape.color, Tokens.accent);
        compare(s.Accessible.name, "Workspaces W, C, D focused, S");
        const empty = strip({ items: [] });
        compare(empty.implicitWidth, 0);
        compare(empty.shape.opacity, 0, "no focus, no shape");
    }

    function test_focus_slides_and_recolours() {
        const s = strip();
        tryCompare(s.shape, "placed", true);
        s.items = items(["W", "C", "D", "S"], "W");
        verify(s.shape.x > 0, "the shape slides, not jumps: " + s.shape.x);
        tryCompare(s.shape, "x", 0, 1000);
        const cells = letters(s);
        tryCompare(ink(cells[0]), "color", Tokens.onAccent);
        tryCompare(ink(cells[2]), "color", Tokens.inkDim);
    }

    // The slide runs lib/Spring.js step(): a new focus mid-slide keeps the
    // speed the shape has instead of restarting from rest (PLAN 1.5).
    function test_focus_retarget_keeps_speed() {
        const s = strip();
        tryCompare(s.shape, "placed", true);
        s.items = items(["W", "C", "D", "S"], "W");
        verify(s.shape.sliding, "a focus change slides");
        tryVerify(() => s.shape.velocity < -20, 500, "heading left toward W: " + s.shape.velocity);
        const speed = s.shape.velocity;
        const x = s.shape.x;
        verify(x > 0 && x < 48, "mid-slide: " + x);
        s.items = items(["W", "C", "D", "S"], "S");
        compare(s.shape.velocity, speed, "the new target keeps the velocity on screen");
        compare(s.shape.x, x, "and the position: nothing jumps");
        tryVerify(() => s.shape.velocity > 0, 500, "then turns toward S");
        tryCompare(s.shape, "x", 72, 1500);
        compare(s.shape.velocity, 0);
        verify(!s.shape.sliding, "settled");
    }

    function test_focus_reduced_motion_snaps() {
        Prefs.reducedMotion = true;
        const s = strip();
        tryCompare(s.shape, "placed", true);
        s.items = items(["W", "C", "D", "S"], "S");
        compare(s.shape.x, 72, "reduced motion: the shape jumps");
        verify(!s.shape.sliding);
    }

    function test_urgent() {
        const s = strip({ items: items(["W", "C", "D", "S"], "D", ["C", "D"]) });
        compare(s.urgentNames, ["C"], "the focused workspace is never urgent");
        tryCompare(ink(letters(s)[1]), "color", Tokens.accent);
    }

    // ---- shape picks -----------------------------------------------------------------

    function test_first_focus_keeps_cookie() {
        const s = strip({ items: [] });
        s.items = items(["W", "C", "D", "S"], "D");
        compare(s.shapeName, "Cookie6Sided", "the boards' shape on the first focus");
    }

    function test_each_later_focus_picks_a_new_shape() {
        const s = strip();
        s.random = () => 0;
        s.items = items(["W", "C", "D", "S"], "W");
        compare(s.shapeName, s.pool.filter(n => n !== "Cookie6Sided")[0]);
        const was = s.shapeName;
        s.items = items(["W", "C", "D", "S"], "C");
        verify(s.shapeName !== was, "never the shape just shown");
        compare(s.shape.shapeName, s.shapeName, "the shape follows");
        s.random = () => 0.9999999;
        s.items = items(["W", "C", "D", "S"], "D");
        const choices = s.pool.filter(n => n !== s.shape.previousShapeName);
        compare(s.shapeName, choices[choices.length - 1]);
        // the same focus arriving again draws nothing new
        const kept = s.shapeName;
        s.items = items(["W", "C", "D", "S"], "D");
        compare(s.shapeName, kept);
        compare(s.pickShape("Gem") !== "Gem", true);
        s.pool = ["Gem"];
        compare(s.pickShape("Gem"), "Gem", "a pool of one keeps it");
    }

    function test_pool_is_wayline() {
        compare(Celestial.POOL.length, 18);
        const s = strip();
        compare(s.pool, Celestial.POOL);
    }

    // ---- input -------------------------------------------------------------------------

    function test_click_and_wheel() {
        const s = strip();
        activations.target = s;
        activations.clear();
        mouseClick(s, 24 + 11, 11);
        compare(activations.count, 1);
        compare(activations.signalArguments[0][0], "C");
        // wheel down one notch: the next letter
        mouseWheel(s, 50, 11, 0, -120);
        compare(activations.count, 2);
        compare(activations.signalArguments[1][0], "S");
        // touchpad deltas add up to a notch: two halves up is one step back
        mouseWheel(s, 50, 11, 0, 60);
        compare(activations.count, 2);
        mouseWheel(s, 50, 11, 0, 60);
        compare(activations.count, 3);
        compare(activations.signalArguments[2][0], "C");
        // no wrap at the ends
        s.items = items(["W", "C", "D", "S"], "S");
        mouseWheel(s, 50, 11, 0, -120);
        compare(activations.count, 3, "no step past the last letter");
        activations.target = null;
    }

    // ---- FocusShape -----------------------------------------------------------------------

    function test_shape_starts_without_morph() {
        const f = createTemporaryObject(shapeComponent, test, { shapeName: "Gem" });
        compare(f.path, Celestial.path("Gem"));
        compare(f.progress, 1);
        verify(!f.morphing);
        compare(f.implicitWidth, 22);
        compare(f.color, Tokens.accent);
    }

    function test_shape_morphs_on_spatial() {
        const f = createTemporaryObject(shapeComponent, test, { shapeName: "Cookie6Sided" });
        f.shapeName = "Gem";
        verify(f.morphing, "the change runs a morph");
        compare(f.previousShapeName, "Cookie6Sided");
        verify(f.progress < 1);
        wait(150);
        verify(f.progress > 0 && f.progress < 1, "mid-morph at 150 ms: " + f.progress);
        verify(f.path !== Celestial.path("Gem") && f.path !== Celestial.path("Cookie6Sided"), "in between");
        tryCompare(f, "progress", 1, 1000);
        compare(f.path, Celestial.path("Gem"));
    }

    function test_shape_retargets_from_screen() {
        const f = createTemporaryObject(shapeComponent, test, { shapeName: "Cookie6Sided" });
        f.shapeName = "Gem";
        wait(120);
        const onScreen = f.path;
        f.shapeName = "Oval";
        compare(f.path, onScreen, "a new target starts from what is drawn");
        compare(f.previousShapeName, "Gem");
        tryCompare(f, "progress", 1, 1000);
        compare(f.path, Celestial.path("Oval"));
    }

    function test_shape_reduced_motion_swaps() {
        Prefs.reducedMotion = true;
        const f = createTemporaryObject(shapeComponent, test, { shapeName: "Cookie6Sided" });
        f.shapeName = "Sunny";
        tryCompare(f, "progress", 1, 100);
        compare(f.path, Celestial.path("Sunny"));
    }
}
