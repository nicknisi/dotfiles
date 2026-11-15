// Prefs' island keys and the Fixture singleton. services.sh runs this four
// times in one isolated XDG_STATE_HOME, with SERVICES_TEST_PHASE naming the step.
import Quickshell
import QtQuick

ShellRoot {
    id: test
    readonly property string phase: Quickshell.env("SERVICES_TEST_PHASE") ?? ""

    function check(condition, message) {
        if (!condition) throw new Error(message);
    }

    function first() {
        // Defaults on a machine with no capsule.json.
        test.check(Prefs.islandForm === "float", "islandForm defaults to float");
        test.check(Prefs.look === "crew", "look defaults to crew");
        test.check(Prefs.motion === "spring", "motion defaults to spring");
        test.check(!Prefs.reducedMotion && !Prefs.dnd, "reducedMotion and dnd default off");
        test.check(Prefs.barMode === "pill", "barMode keeps its pill default");
        // Island is M1: not a bar mode yet.
        Prefs.setBarMode("island");
        test.check(Prefs.barMode === "pill", "island is not a bar mode yet");
        test.check(Prefs.nextBarMode("rail") === "pill", "the cycle is unchanged");
        // Invalid values are refused, valid ones land.
        Prefs.setIslandForm("bubble"); Prefs.setLook("vaporwave"); Prefs.setMotion("warp");
        test.check(Prefs.islandForm === "float" && Prefs.look === "crew" && Prefs.motion === "spring", "invalid values are rejected");
        Prefs.setIslandForm("notch"); Prefs.setLook("arcade"); Prefs.setMotion("off");
        Prefs.setReducedMotion(true); Prefs.setDnd(true);
        test.check(Prefs.islandForm === "notch" && Prefs.look === "arcade" && Prefs.motion === "off", "valid values are stored");
        test.check(Prefs.reducedMotion && Prefs.dnd, "booleans are stored");
        test.check(Prefs.looks.length === 6 && Prefs.motions.length === 4 && Prefs.islandForms.length === 2, "allowed lists");
    }

    function stale() {
        // services.sh replaced look/motion/islandForm with junk and kept the rest.
        test.check(Prefs.islandForm === "float" && Prefs.look === "crew" && Prefs.motion === "spring", "junk in the file reads as the defaults");
        test.check(Prefs.reducedMotion && Prefs.dnd, "the other keys survive a reload");
        test.check(Prefs.edge === "top" && !Prefs.translucent, "the old keys are untouched");
    }

    function fixture() {
        test.check(Fixture.sandbox, "SHELL_SANDBOX=1 is seen");
        test.check(Object.keys(Fixture.data).length === 0 && Fixture.name === "", "nothing is loaded at start");
        test.check(Fixture.load("alpha") && Fixture.data.value === 1 && Fixture.name === "alpha", "a fixture loads");
        test.check(Fixture.load("beta") && Fixture.data.value === 2 && Fixture.data.value !== 1, "a second fixture replaces the first");
        test.check(!Fixture.load("missing") && Fixture.error.startsWith("no fixture") && Fixture.data.value === 2, "a missing fixture fails and keeps the data");
        test.check(!Fixture.load("../alpha") && Fixture.error.startsWith("bad fixture name"), "path tricks are refused");
        test.check(!Fixture.load("broken") && Fixture.error.includes("not JSON"), "bad JSON is reported");
        test.check(!Fixture.load("list") && Fixture.error.includes("object"), "a top-level array is refused");
        test.check(Fixture.load("alpha") && Fixture.error === "" && Fixture.data.value === 1, "the same name loads again after others");
        Fixture.clear();
        test.check(Object.keys(Fixture.data).length === 0 && Fixture.name === "", "clear empties it");
    }

    function inert() {
        test.check(!Fixture.sandbox, "no sandbox without SHELL_SANDBOX=1");
        test.check(!Fixture.load("alpha") && Object.keys(Fixture.data).length === 0, "load refuses outside the sandbox");
        test.check((Fixture.data.anything ?? "live") === "live", "data.x ?? live falls through to live");
    }

    Timer {
        // Prefs loads its file asynchronously, and a restart with a saved file
        // can take over half a second. The stale step polls until the saved
        // booleans arrive (3 s at most) before it checks anything.
        interval: 100
        running: true
        repeat: true
        property int tries: 0
        onTriggered: {
            if (test.phase === "stale" && !Prefs.dnd && ++tries < 30) return;
            if (test.phase !== "stale" && ++tries < 3) return;
            stop();
            try {
                if (test.phase === "first") test.first();
                else if (test.phase === "stale") test.stale();
                else if (test.phase === "fixture") test.fixture();
                else if (test.phase === "inert") test.inert();
                else throw new Error("unknown phase " + test.phase);
                console.log("SERVICES_TEST_PASS " + test.phase);
            } catch (e) {
                console.log("SERVICES_TEST_FAIL " + test.phase + ": " + e.message);
            }
            // Leave time for Prefs to write the file back.
            quit.start();
        }
    }
    Timer {
        id: quit
        interval: 300
        onTriggered: Qt.quit()
    }
}
