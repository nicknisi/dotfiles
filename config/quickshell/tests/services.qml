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
        // Island is a bar mode (M1): the fourth stop of the cycle. It sits at
        // the top whatever the stored edge, and leaves that edge alone so the
        // bar goes back to it.
        test.check(JSON.stringify(Prefs.barModes) === JSON.stringify(["pill", "full", "rail", "island"]), "four bar modes");
        test.check(Prefs.nextBarMode("rail") === "island" && Prefs.nextBarMode("island") === "pill", "rail -> island -> pill");
        Prefs.setEdge("bottom");
        Prefs.setBarMode("island");
        test.check(Prefs.barMode === "island", "island is a bar mode");
        test.check(Prefs.edge === "top" && !Prefs.vertical && Prefs.storedEdge === "bottom", "island forces the top edge and keeps the stored one");
        Prefs.setEdge("left");
        test.check(Prefs.edge === "top" && Prefs.storedEdge === "left", "an edge chosen in island mode is remembered for later");
        Prefs.setBarMode("pill");
        test.check(Prefs.edge === "left" && Prefs.vertical, "leaving island restores the stored edge");
        Prefs.setEdge("top");
        Prefs.setBarMode("bogus");
        test.check(Prefs.barMode === "pill", "unknown bar modes are refused");
        // Invalid values are refused, valid ones land.
        Prefs.setIslandForm("bubble"); Prefs.setLook("vaporwave"); Prefs.setMotion("warp");
        test.check(Prefs.islandForm === "float" && Prefs.look === "crew" && Prefs.motion === "spring", "invalid values are rejected");
        Prefs.setIslandForm("notch"); Prefs.setLook("arcade"); Prefs.setMotion("off");
        Prefs.setReducedMotion(true); Prefs.setDnd(true);
        test.check(Prefs.islandForm === "notch" && Prefs.look === "arcade" && Prefs.motion === "off", "valid values are stored");
        test.check(Prefs.reducedMotion && Prefs.dnd, "booleans are stored");
        test.check(Prefs.looks.length === 6 && Prefs.motions.length === 4 && Prefs.islandForms.length === 2, "allowed lists");
        // The night light's keys (NightLight.qml): defaults, then one patch
        // at a time, junk refused key by key.
        test.check(Prefs.nightLightTemperature === 4000 && Prefs.nightLightSchedule === "off" && Prefs.nightLightFrom === "20:00" && Prefs.nightLightTo === "07:00", "night light defaults: 4000 K, no schedule, 20:00 to 07:00");
        test.check(!Prefs.nightLightManual && Prefs.nightLightOverride === "" && Prefs.nightLightUntil === 0, "off, no override");
        Prefs.setNightLight({ temperature: 3333 });
        test.check(Prefs.nightLightTemperature === 3300, "warmth on 100 K: " + Prefs.nightLightTemperature);
        Prefs.setNightLight({ temperature: 99999 });
        test.check(Prefs.nightLightTemperature === 6000, "clamped to neutral");
        Prefs.setNightLight({ temperature: "junk", schedule: "sunset", from: "25:00", to: "x", override: "maybe", until: "soon" });
        test.check(Prefs.nightLightTemperature === 6000 && Prefs.nightLightSchedule === "off" && Prefs.nightLightFrom === "20:00" && Prefs.nightLightTo === "07:00" && Prefs.nightLightOverride === "" && Prefs.nightLightUntil === 0, "junk changes nothing");
        Prefs.setNightLight({ temperature: 3300, schedule: "custom", from: "21:30", to: "6:30", manual: true, override: "on", until: 1794700000000 });
        test.check(Prefs.nightLightSchedule === "custom" && Prefs.nightLightFrom === "21:30" && Prefs.nightLightTo === "06:30", "a schedule, the time written HH:MM: " + Prefs.nightLightTo);
        test.check(Prefs.nightLightManual && Prefs.nightLightOverride === "on" && Prefs.nightLightUntil === 1794700000000, "the manual state and an override");
    }

    function stale() {
        // services.sh replaced look/motion/islandForm with junk and kept the rest.
        test.check(Prefs.islandForm === "float" && Prefs.look === "crew" && Prefs.motion === "spring", "junk in the file reads as the defaults");
        test.check(Prefs.reducedMotion && Prefs.dnd, "the other keys survive a reload");
        test.check(Prefs.edge === "top" && !Prefs.translucent, "the old keys are untouched");
        // services.sh wrote junk night light keys too.
        test.check(Prefs.nightLightTemperature === 2500 && Prefs.nightLightSchedule === "off" && Prefs.nightLightFrom === "20:00" && Prefs.nightLightTo === "06:30", "junk night light keys read as the nearest good value: " + Prefs.nightLightTemperature + " " + Prefs.nightLightSchedule + " " + Prefs.nightLightFrom);
        test.check(Prefs.nightLightOverride === "" && Prefs.nightLightUntil === 0 && Prefs.nightLightManual, "no override from junk; the manual state kept");
    }

    function legacy() {
        // services.sh wrote a pre-M4 file: the old rail on the top.
        test.check(Prefs.barMode === "full" && Prefs.edge === "top" && Prefs.storedEdge === "top", "the old rail on the top is the full strip on the top: " + Prefs.barMode + " " + Prefs.edge);
        test.check(Prefs.translucent && Prefs.dnd, "the other keys are kept");
    }

    function kept() {
        // An M4 file (layout 1) with the rail chosen while the top is remembered.
        test.check(Prefs.barMode === "rail" && Prefs.edge === "left" && Prefs.storedEdge === "top", "M4's rail stays the rail down the left: " + Prefs.barMode + " " + Prefs.edge);
    }

    function legacyside() {
        test.check(Prefs.barMode === "rail" && Prefs.edge === "right" && Prefs.storedEdge === "right", "the old full strip on the right is the rail there: " + Prefs.barMode + " " + Prefs.edge);
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
            // The conversions wait for their file the same way: the seeded
            // barMode differs from the pill default once it has loaded.
            const loads = { stale: () => Prefs.dnd, legacy: () => Prefs.barMode !== "pill", kept: () => Prefs.barMode !== "pill", legacyside: () => Prefs.barMode !== "pill" };
            if (loads[test.phase] && !loads[test.phase]() && ++tries < 30) return;
            if (!loads[test.phase] && ++tries < 3) return;
            stop();
            try {
                if (test.phase === "first") test.first();
                else if (test.phase === "stale") test.stale();
                else if (test.phase === "legacy") test.legacy();
                else if (test.phase === "kept") test.kept();
                else if (test.phase === "legacyside") test.legacyside();
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
