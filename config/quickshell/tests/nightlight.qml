import Quickshell
import Quickshell.Io
import QtQuick

// NightLight.qml against a fake hyprsunset (tests/nightlight.sh): fake
// hyprctl, journalctl and systemctl on PATH share one state dir, NL_FAKE:
//   running   present while "hyprsunset" runs (else hyprctl answers as 0.4.0
//             does with no socket: "Couldn't connect ... (3)", exit 3)
//   screen    what the screen shows: "identity" or a kelvin
//   calls     one line per hyprctl run
//   journal   the user manager's lines about hyprsunset.service and
//             hyprsunset's own output; the fake journalctl follows it
//   nojournal present: the fake journalctl exits at once
// NL_TEST_PHASE names the run: first (a fresh state dir), restart (the same
// one again), down (no hyprsunset at start), nojournal (no journal to follow),
// dry (SHELL_DRY_RUN=1), session (no Hyprland session). The schedule runs on
// a fake clock (NightLight.clock) moved by hand, minute ticks included.
ShellRoot {
    id: test

    readonly property string phase: Quickshell.env("NL_TEST_PHASE") || "first"
    // Builds the singleton (and its IPC target) at start in every phase, as
    // ShellServices does in the shell.
    readonly property bool built: NightLight.started || true
    readonly property string fake: Quickshell.env("NL_FAKE") || ""
    property var failures: []
    property real fakeNow: 0
    property int step: 0
    property var steps: []
    // hyprctl runs counted at a mark (calls since).
    property int mark: 0

    function check(ok, message) {
        if (!ok) {
            test.failures.push(message);
            console.log("NIGHTLIGHT_TEST_FAIL " + test.phase + ": " + message);
        }
    }
    function at(y, mo, d, h, mi, s) {
        return new Date(y, mo - 1, d, h, mi, s || 0, 0).getTime();
    }
    // Moves the fake clock and runs the minute timer's work.
    function clockTo(ms) {
        test.fakeNow = ms;
        NightLight.tick();
    }
    function read(name) {
        reader.path = "";
        reader.path = test.fake + "/" + name;
        // text() first: it is what blocks on the read (Fixture.qml).
        const t = reader.text();
        return reader.loaded ? t.trim() : "";
    }
    function screen() {
        return test.read("screen");
    }
    function callLines() {
        const t = test.read("calls");
        return t === "" ? [] : t.split("\n");
    }
    function since() {
        return NightLight.calls - test.mark;
    }
    function markCalls() {
        test.mark = NightLight.calls;
    }
    // A shell line run against the fake's dir ($1).
    function sh(script) {
        shell.command = ["sh", "-c", script, "sh", test.fake];
        shell.running = true;
    }
    // hyprsunset's 07:00 identity profile firing by itself: the screen goes
    // neutral and it logs what milhouse's journal shows (`journal`: true).
    // Its CTM lines, as it logs them for every request, ride along.
    readonly property string ctmLines: "'┣ Resetting the matrix (--identity passed)' '┃' '┣ Calculated the CTM to be [mat3x3: 1, 0, 0, 0, 1, 0, 0, 0, 1]' '┃'"
    function profileFires(journal) {
        test.sh("echo identity > \"$1/screen\"" + (journal ? "; printf '%s\\n' '┣ Switched to new profile from: 7:0' " + test.ctmLines + " >> \"$1/journal\"" : ""));
    }

    FileView {
        id: reader
        blockLoading: true
        printErrors: false
        watchChanges: false
    }
    Process {
        id: shell
    }

    // ---- phases -----------------------------------------------------------------

    // Each step returns the ms to wait before the next one.
    readonly property var first: [
        () => {
            test.check(NightLight.started && Prefs.loaded, "started once Prefs had read the file");
            test.check(NightLight.live && NightLight.available && NightLight.reason === "", "hyprsunset answered: " + NightLight.reason + " " + NightLight.message);
            test.check(NightLight.calls === 1 && test.callLines().join("|") === "hyprsunset identity", "one call at start, the stored off: " + test.callLines().join("|"));
            test.check(!NightLight.on && !NightLight.active && NightLight.temperature === 4000 && NightLight.schedule === "off", "defaults: off, 4000 K, no schedule");
            test.check(test.read("journalctl.args") === "--user --follow --lines=0 --quiet --output=cat USER_UNIT=hyprsunset.service + _SYSTEMD_USER_UNIT=hyprsunset.service", "one journal listener on the unit's manager lines and hyprsunset's own: " + test.read("journalctl.args"));
            // The fallback when no profile line comes, short for the test.
            NightLight.lateMs = 2500;
            test.check(JSON.stringify(NightLight.profiles) === JSON.stringify([{ minute: 420, identity: true, temperature: 6000 }]), "hyprsunset.conf's 07:00 identity profile: " + JSON.stringify(NightLight.profiles));
            NightLight.clock = () => test.fakeNow;
            test.clockTo(test.at(2026, 11, 14, 12, 0));
            test.markCalls();
            test.check(NightLight.toggle() === "ok", "toggle");
            return 400;
        },
        () => {
            test.check(NightLight.on && NightLight.active && Prefs.nightLightManual, "on, without a schedule the manual state");
            test.check(test.since() === 1 && test.screen() === "4000", "one call: temperature 4000, screen " + test.screen());
            test.markCalls();
            // A drag: three warmths in a row, one call once it settles.
            NightLight.setTemperature(3500);
            NightLight.setTemperature(3400);
            NightLight.setTemperature(3300);
            test.check(NightLight.setTemperature(1200).startsWith("error"), "warmth out of range is refused");
            return 500;
        },
        () => {
            test.check(test.since() === 1 && test.screen() === "3300" && Prefs.nightLightTemperature === 3300, "a drag is one call, at the last warmth: " + test.since() + " " + test.screen());
            test.markCalls();
            // Ticks with nothing to do spawn nothing.
            for (let m = 1; m <= 30; m++) test.clockTo(test.at(2026, 11, 14, 12, m));
            test.check(test.since() === 0, "thirty minute ticks, no call: " + test.since());
            // A schedule at 19:58: outside 20:00 to 07:00, so off.
            test.clockTo(test.at(2026, 11, 14, 19, 58));
            test.check(NightLight.setSchedule("custom", "20:00", "07:00") === "ok", "set the schedule");
            test.check(NightLight.setSchedule("custom", "08:00", "08:00").startsWith("error"), "an empty window is refused");
            return 400;
        },
        () => {
            test.check(!NightLight.on && test.since() === 1 && test.screen() === "identity", "the schedule turned it off at 19:58: " + test.screen());
            test.check(NightLight.until === "20:00", "until 20:00: " + NightLight.until);
            test.markCalls();
            test.clockTo(test.at(2026, 11, 14, 19, 59, 30));
            test.check(test.since() === 0 && !NightLight.on, "19:59: still off, no call");
            test.clockTo(test.at(2026, 11, 14, 20, 0, 30));
            return 400;
        },
        () => {
            test.check(NightLight.on && test.since() === 1 && test.screen() === "3300", "20:00: on, one call: " + test.since() + " " + test.screen());
            test.check(NightLight.until === "07:00", "on until 07:00: " + NightLight.until);
            test.markCalls();
            // Across midnight: on all night, no call.
            for (const t of [[23, 59, 30], [0, 0, 30], [3, 0, 0], [6, 59, 30]]) {
                test.clockTo(test.at(2026, 11, t[0] >= 20 ? 14 : 15, t[0], t[1], t[2]));
                test.check(NightLight.on, "on at " + t.join(":"));
            }
            test.check(test.since() === 0, "the night across midnight spawns nothing: " + test.since());
            test.clockTo(test.at(2026, 11, 15, 7, 0, 30));
            return 400;
        },
        () => {
            // 07:00: the schedule ends it (identity), and hyprsunset's own 07:00
            // identity profile fires too: it agrees, so no second call.
            test.check(!NightLight.on && test.since() === 1 && test.screen() === "identity", "07:00: off, one call: " + test.since());
            test.markCalls();
            return 3500;
        },
        () => {
            test.check(test.since() === 0, "the identity profile agreeing with off adds nothing: " + test.since());
            // The manual override: off at 22:00 inside the window, until 07:00.
            test.clockTo(test.at(2026, 11, 15, 20, 0, 30));
            return 400;
        },
        () => {
            test.check(NightLight.on && test.screen() === "3300", "on again the next evening");
            test.clockTo(test.at(2026, 11, 15, 22, 0));
            test.markCalls();
            test.check(NightLight.toggle() === "ok", "toggle off inside the window");
            return 400;
        },
        () => {
            test.check(!NightLight.on && NightLight.overridden && Prefs.nightLightOverride === "off", "an override, stored");
            test.check(new Date(Prefs.nightLightUntil).getHours() === 7 && new Date(Prefs.nightLightUntil).getDate() === 16, "until the next edge, 07:00 on the 16th");
            test.check(test.since() === 1 && test.screen() === "identity", "one call: identity");
            test.check(NightLight.until === "20:00", "off until 20:00 tomorrow: the override runs out into the schedule's off: " + NightLight.until);
            test.markCalls();
            for (const t of [[23, 0], [0, 30], [6, 59]]) {
                test.clockTo(test.at(2026, 11, t[0] >= 20 ? 15 : 16, t[0], t[1], 30));
                test.check(!NightLight.on, "the override holds at " + t.join(":"));
            }
            test.clockTo(test.at(2026, 11, 16, 7, 0, 30));
            test.check(!NightLight.on && Prefs.nightLightOverride === "" && Prefs.nightLightUntil === 0, "the edge passed: the override is gone from the file too");
            test.clockTo(test.at(2026, 11, 16, 20, 0, 30));
            return 400;
        },
        () => {
            test.check(test.since() === 1 && NightLight.on && test.screen() === "3300", "the schedule decides again: on at 20:00, one call: " + test.since());
            // A profile firing inside an active window: 05:00 to 09:00, on at
            // 06:30, and hyprsunset's 07:00 identity profile turns the screen
            // neutral by itself.
            test.clockTo(test.at(2026, 11, 17, 6, 30));
            NightLight.setSchedule("custom", "05:00", "09:00");
            return 400;
        },
        () => {
            test.check(NightLight.on && test.screen() === "3300", "05:00 to 09:00 at 06:30: on");
            test.markCalls();
            // hyprsunset's own output for a request of ours: read, nothing done.
            test.sh("printf '%s\\n' '┣ already initialized, applying CTM instantly' " + test.ctmLines + " >> \"$1/journal\"");
            return 1500;
        },
        () => {
            test.check(test.since() === 0, "hyprsunset's CTM lines are ignored: " + test.since());
            // On time: hyprsunset switches at 07:00:00 and says so, the minute
            // timer ticks just after.
            test.profileFires(true);
            return 300;
        },
        () => {
            test.check(NightLight.on && test.screen() === "identity", "the fake profile reset the screen");
            test.clockTo(test.at(2026, 11, 17, 7, 0, 30));
            test.check(test.since() === 0, "no call before hyprsunset's switch has landed");
            return 1200;
        },
        () => {
            test.check(test.since() === 1 && test.screen() === "3300", "hyprsunset's switch line while on: put back once, a second later: " + test.since() + " " + test.screen());
            test.check(NightLight.lastSwitch === "07:00", "the switch heard: " + NightLight.lastSwitch);
            return 3500;
        },
        () => {
            test.check(test.since() === 1, "the tick over 07:00 adds no second call once the line was heard: " + test.since());
            // Late, after a resume: suspended at 08:00 (on), woken at 07:30
            // the next day. The minute timer ticks first; hyprsunset's 07:00
            // switch comes a second and a half later (6 to 50 s on milhouse).
            test.clockTo(test.at(2026, 11, 17, 8, 0));
            test.clockTo(test.at(2026, 11, 18, 7, 30, 1));
            test.markCalls();
            return 1500;
        },
        () => {
            test.check(NightLight.on && test.since() === 0 && test.screen() === "3300", "woken across 07:00, no switch yet: the screen still warm, no call: " + test.since() + " " + test.screen());
            test.profileFires(true);
            return 1700;
        },
        () => {
            test.check(test.since() === 1 && test.screen() === "3300", "the late switch, after the shell's tick: put back once: " + test.since() + " " + test.screen());
            return 2500;
        },
        () => {
            test.check(test.since() === 1 && test.screen() === "3300", "the line stood in for the fallback: still one call: " + test.since());
            // No line at all (a hyprsunset that says it differently): the
            // fallback puts it back lateMs after the tick.
            test.clockTo(test.at(2026, 11, 18, 8, 0));
            test.clockTo(test.at(2026, 11, 19, 7, 30, 1));
            test.markCalls();
            test.profileFires(false);
            return 1500;
        },
        () => {
            test.check(test.since() === 0 && test.screen() === "identity", "no line: waits for the fallback: " + test.since());
            return 1700;
        },
        () => {
            test.check(test.since() === 1 && test.screen() === "3300", "the fallback put it back: " + test.since() + " " + test.screen());
            NightLight.lateMs = 60000;
            test.markCalls();
            // hyprsunset stops: the manager's lines, then a call that fails.
            test.sh("rm -f \"$1/running\"; printf '%s\\n' 'Stopping An application to enable a blue-light filter on Hyprland....' 'Stopped An application to enable a blue-light filter on Hyprland..' >> \"$1/journal\"");
            return 1800;
        },
        () => {
            test.check(!NightLight.available && NightLight.reason === "stopped" && !NightLight.active, "stopped: unavailable: " + NightLight.reason);
            test.check(NightLight.on, "the choice stays on");
            test.check(NightLight.toggle().startsWith("error") && NightLight.on, "a toggle while it is down is refused");
            test.check(NightLight.setTemperature(3200) === "ok 3200", "the warmth still changes, for later");
            return 500;
        },
        () => {
            test.check(!NightLight.available && Prefs.nightLightTemperature === 3200, "still down, 3200 kept");
            test.markCalls();
            // Started before the socket is up: the first call fails, a retry lands.
            test.sh("printf '%s\\n' 'Started An application to enable a blue-light filter on Hyprland..' >> \"$1/journal\"; sleep 1.4; echo identity > \"$1/screen\"; touch \"$1/running\"");
            return 4000;
        },
        () => {
            test.check(NightLight.available && NightLight.active && test.screen() === "3200", "hyprsunset back (its state reset to identity): re-applied at 3200: " + test.screen() + " " + NightLight.reason);
            test.check(test.since() === 2, "a failed call while the socket came up, then the retry that landed: " + test.since());
            test.markCalls();
            // A plain restart.
            test.sh("echo identity > \"$1/screen\"; printf '%s\\n' 'Stopping x' 'Stopped x' 'Started x' >> \"$1/journal\"");
            return 1800;
        },
        () => {
            test.check(test.screen() === "3200" && test.since() === 1, "a restart's lines in one burst: one call, back at 3200: " + test.since() + " " + test.screen());
            // Schedule Off keeps the light as it is: on by the schedule at
            // 07:30, the last toggle without a schedule long gone (off).
            Prefs.setNightLight({ manual: false });
            test.markCalls();
            test.check(NightLight.on && NightLight.setSchedule("off", "", "") === "ok", "schedule Off while the schedule has it on");
            test.check(NightLight.on && Prefs.nightLightSchedule === "off" && Prefs.nightLightManual, "it stays on, and on is now the manual state");
            return 400;
        },
        () => {
            test.check(test.since() === 0 && test.screen() === "3200", "no call: nothing changed on the screen: " + test.since() + " " + test.screen());
            // And off by the schedule (10:00), the manual state on: stays off.
            test.clockTo(test.at(2026, 11, 19, 10, 0));
            NightLight.setSchedule("custom", "05:00", "09:00");
            return 400;
        },
        () => {
            test.check(!NightLight.on && test.screen() === "identity" && Prefs.nightLightManual, "10:00 outside 05:00 to 09:00: off, the manual state still on");
            test.markCalls();
            NightLight.setSchedule("off", "", "");
            test.check(!NightLight.on && !Prefs.nightLightManual, "schedule Off at 10:00: stays off");
            return 400;
        },
        () => {
            test.check(test.since() === 0 && test.screen() === "identity", "and no call: " + test.since());
            // For the restart phase: no schedule, on, so the start is certain.
            Prefs.setNightLight({ manual: true });
            return 400;
        },
        () => {
            test.check(NightLight.on && Prefs.nightLightSchedule === "off" && Prefs.nightLightManual, "left on without a schedule for the restart");
            test.check(test.callLines().length === NightLight.calls, "every hyprctl run is one of NightLight's calls: " + test.callLines().length + " " + NightLight.calls);
            test.check(test.read("journalctl.runs") === "1", "one journal listener the whole run: " + test.read("journalctl.runs"));
            return -1;
        }
    ]

    readonly property var restart: [
        () => {
            test.check(NightLight.available && NightLight.on && NightLight.temperature === 3200, "the stored state came back: on at 3200");
            test.check(NightLight.calls === 1 && test.callLines().slice(-1)[0] === "hyprsunset temperature 3200", "and went on the screen at start, one call: " + test.callLines().slice(-1)[0]);
            test.check(test.screen() === "3200", "screen 3200");
            return -1;
        }
    ]

    readonly property var down: [
        () => {
            test.check(!NightLight.available && NightLight.reason === "stopped" && NightLight.message === "hyprsunset is not running", "no hyprsunset at start: unavailable, stopped");
            test.check(NightLight.toggle().startsWith("error") && !NightLight.on, "toggle refused");
            test.check(NightLight.setTemperature(4500) === "ok 4500", "the warmth is kept for later");
            test.markCalls();
            test.check(NightLight.startDaemon() === "ok", "the explicit start");
            return 3500;
        },
        () => {
            test.check(test.read("systemctl.args") === "--user start hyprsunset.service", "systemctl --user start hyprsunset.service: " + test.read("systemctl.args"));
            test.check(NightLight.available && NightLight.reason === "", "started: available");
            test.check(test.since() >= 1 && test.screen() === "identity", "the stored off applied: " + test.screen());
            test.check(NightLight.setOn(true) === "ok", "on now works");
            return 400;
        },
        () => {
            test.check(test.screen() === "4500", "at the kept warmth: " + test.screen());
            return -1;
        }
    ]

    // No journal to follow: the minute timer alone puts a profile back.
    readonly property var nojournal: [
        () => {
            test.check(NightLight.available && test.read("journalctl.runs") === "1" && NightLight.watchState.startsWith("exited"), "the journal listener ran and exited: " + NightLight.watchState);
            NightLight.clock = () => test.fakeNow;
            NightLight.lateMs = 5000;
            test.clockTo(test.at(2026, 11, 16, 6, 0));
            test.check(NightLight.setOn(true) === "ok", "on, no schedule");
            return 400;
        },
        () => {
            test.check(test.screen() === "4000", "on at 4000: " + test.screen());
            // On time: hyprsunset fires at 07:00:00, the tick follows; 3 s later
            // it is put back, and only once (no gap).
            test.profileFires(false);
            return 300;
        },
        () => {
            test.markCalls();
            test.clockTo(test.at(2026, 11, 16, 6, 59, 30));
            test.clockTo(test.at(2026, 11, 16, 7, 0, 30));
            return 3600;
        },
        () => {
            test.check(test.since() === 1 && test.screen() === "4000", "no journal: put back by the clock 3 s later: " + test.since() + " " + test.screen());
            return 3000;
        },
        () => {
            test.check(test.since() === 1, "no second call without a gap: " + test.since());
            // Woken at 08:55 after a night's suspend: the tick's put-back at
            // 3 s lands before hyprsunset's late switch; the second one after.
            test.clockTo(test.at(2026, 11, 17, 8, 55, 3));
            test.markCalls();
            return 3500;
        },
        () => {
            test.check(test.since() === 1 && test.screen() === "4000", "the first put-back, before hyprsunset switched: " + test.since());
            test.profileFires(false);
            return 400;
        },
        () => {
            test.check(test.screen() === "identity", "hyprsunset's late switch reset the screen");
            return 1600;
        },
        () => {
            test.check(test.since() === 2 && test.screen() === "4000", "a resume's second put-back lands after it: " + test.since() + " " + test.screen());
            return -1;
        }
    ]

    readonly property var dry: [
        () => {
            test.check(!NightLight.live && NightLight.reason === "dry" && !NightLight.available, "SHELL_DRY_RUN: never live");
            test.check(NightLight.toggle().startsWith("error: dry run"), "toggle refused");
            test.check(NightLight.calls === 0 && test.callLines().length === 0 && test.read("journalctl.runs") === "", "no hyprctl, no journal listener");
            return -1;
        }
    ]

    readonly property var session: [
        () => {
            test.check(!NightLight.live && NightLight.reason === "session" && !NightLight.inSession, "no Hyprland session: not live");
            test.check(NightLight.calls === 0 && test.callLines().length === 0 && test.read("journalctl.runs") === "", "nothing spawned");
            return -1;
        }
    ]

    Timer {
        id: runner
        interval: 900
        // "idle": the IPC run, where nightlight.sh drives it from outside.
        running: test.phase !== "idle"
        onTriggered: {
            const list = test[test.phase] ?? [];
            if ((!NightLight.started || NightLight.reason === "checking") && test.phase !== "dry" && test.phase !== "session") {
                // Prefs reads the file first.
                runner.interval = 200;
                runner.restart();
                return;
            }
            let wait = -1;
            try {
                wait = list[test.step++]();
            } catch (e) {
                test.check(false, "threw: " + e);
                wait = -1;
            }
            if (wait < 0 || test.step >= list.length) {
                console.log(test.failures.length === 0 ? "NIGHTLIGHT_TEST_PASS " + test.phase : "NIGHTLIGHT_TEST_FAIL " + test.phase + " (" + test.failures.length + ")");
                Qt.quit();
                return;
            }
            runner.interval = wait;
            runner.restart();
        }
    }
}
