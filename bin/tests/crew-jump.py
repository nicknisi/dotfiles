#!/usr/bin/env python3
"""bin/crew-jump against fake tmux, hyprctl and /proc (PLAN M2).

  python3 -B bin/tests/crew-jump.py [path/to/crew-jump]

Ghostty owns every window from one pid, so the cases that matter are how many
windows that pid has and whether the tmux title picks one. Every command goes
through a fake run(); nothing reaches the real tmux or Hyprland.
"""

import importlib.machinery
import importlib.util
import json
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCRIPT = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE.parent / "crew-jump"
TITLE = "✳ Hypr launcher text color - dotfiles"

failures = []


def check(cond, message):
    if not cond:
        failures.append(message)
        print("FAIL", message)


def load():
    loader = importlib.machinery.SourceFileLoader("crew_jump_under_test", str(SCRIPT))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


# pid: ppid. 2309 ghostty -> 2554 zsh -> 2792 tmux client; 4990 zsh -> 5000 claude
# in a bare Ghostty window; 2599 tmux server; 7000 foot -> 7001 sh -> 7002 pi.
TREE = {2309: 1303, 1303: 1, 2554: 2309, 2792: 2554, 2599: 1303, 4990: 2309, 5000: 4990,
        7000: 1303, 7001: 7000, 7002: 7001}


def make_proc(root):
    for pid, ppid in TREE.items():
        d = root / str(pid)
        d.mkdir()
        (d / "stat").write_text("%d (tmux: client) S %d 0 0 0 -1 0\n" % (pid, ppid))


def world(clients=None, windows=None, titles_on=True, panes=None):
    """A fake run() and the list of commands it saw."""
    calls = []
    clients = clients if clients is not None else [("/dev/pts/0", 2792, "projects", 100)]
    windows = windows if windows is not None else [("0x5603affa7120", 2309, TITLE)]
    panes = panes if panes is not None else {"%0": ("projects", "@0"), "%2": ("projects", "@1"), "%5": ("scratch", "@4")}

    def run(*cmd, timeout=5):
        calls.append(list(cmd))
        if cmd[:2] == ("tmux", "display-message") and "-t" in cmd:
            pane = cmd[cmd.index("-t") + 1]
            if pane not in panes:
                return 1, ""
            return 0, "%s\t%s\n" % panes[pane]
        if cmd[:2] == ("tmux", "list-clients"):
            return 0, "".join("%s\t%d\t%s\t%d\n" % c for c in clients)
        if cmd[:2] == ("tmux", "show-options"):
            return 0, "on\n" if titles_on else "off\n"
        if cmd[:2] == ("tmux", "display-message") and "-c" in cmd:
            return 0, TITLE + "\n"
        if cmd[:3] == ("hyprctl", "clients", "-j"):
            return 0, json.dumps([{"address": a, "pid": p, "title": t, "class": "x"} for a, p, t in windows])
        return 0, ""
    return run, calls


def focused(plan):
    cmds = [c for c in plan["commands"] if c[0] == "hyprctl"]
    return cmds[0][2] if cmds else None


def main():
    m = load()
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        make_proc(root)
        m.PROC = root

        # One Ghostty window: the pid alone decides.
        m.run, calls = world()
        plan = m.plan_pane("%2", "", "")
        check(plan["code"] == 0, "one window: ok (%s)" % plan["message"])
        check(plan["commands"][:3] == [["tmux", "switch-client", "-c", "/dev/pts/0", "-t", "projects"],
                                      ["tmux", "select-window", "-t", "@1"], ["tmux", "select-pane", "-t", "%2"]],
              "switch, select window, select pane: %r" % plan["commands"])
        check(focused(plan) == 'hl.dsp.focus({ window = "address:0x5603affa7120" })', "focus the window by address: %r" % focused(plan))
        check(not any(c[:2] in (["tmux", "switch-client"], ["hyprctl", "dispatch"]) for c in calls),
              "planning runs no tmux switch and no dispatch")

        # Two Ghostty windows, one wearing the client's title.
        m.run, _ = world(windows=[("0xa1", 2309, "zsh"), ("0xb2", 2309, TITLE)])
        plan = m.plan_pane("%2")
        check(focused(plan) == 'hl.dsp.focus({ window = "address:0xb2" })', "the title picks the window: %r" % plan["message"])

        # Two windows with the same title: ambiguous, so the pane is selected and no window focused.
        m.run, _ = world(windows=[("0xa1", 2309, TITLE), ("0xb2", 2309, TITLE)])
        plan = m.plan_pane("%2")
        check(plan["code"] == 0 and focused(plan) is None and "not focused" in plan["message"], "two same titles: no focus (%s)" % plan["message"])
        check(any(c[:2] == ["tmux", "select-pane"] for c in plan["commands"]), "the pane is still selected")

        # Two windows and tmux not setting titles: nothing to tell them apart.
        m.run, _ = world(windows=[("0xa1", 2309, "zsh"), ("0xb2", 2309, TITLE)], titles_on=False)
        plan = m.plan_pane("%2")
        check(focused(plan) is None and "no title" in plan["message"], "titles off: no focus (%s)" % plan["message"])

        # Several clients: the one on the agent's session wins, then the most recent.
        m.run, _ = world(clients=[("/dev/pts/0", 2792, "projects", 100), ("/dev/pts/3", 2792, "scratch", 50),
                                  ("/dev/pts/4", 2792, "scratch", 90)])
        plan = m.plan_pane("%5")
        check(plan["commands"][0] == ["tmux", "switch-client", "-c", "/dev/pts/4", "-t", "scratch"],
              "the latest client on the agent's session: %r" % plan["commands"][0])
        plan = m.plan_pane("%2")
        check(plan["commands"][0][3] == "/dev/pts/0", "a session with one client uses it")

        # No client, a gone pane, a bad pane id.
        m.run, _ = world(clients=[])
        check(m.plan_pane("%2")["code"] == 1, "no attached client is an error")
        m.run, _ = world()
        check(m.plan_pane("%9")["code"] == 1, "a gone pane is an error")
        check(m.plan_pane("2; rm -rf /")["code"] == 2, "a pane id is %<n> only")

        # An address that is not hex never reaches the Lua expression.
        m.run, _ = world(windows=[('0x1" }) hl.dsp.exit() --', 2309, TITLE)])
        check(focused(m.plan_pane("%2")) is None, "a strange address is never dispatched")

        # Outside tmux: the bare Ghostty agent is focusable only while Ghostty has one window.
        m.run, _ = world()
        plan = m.plan_pid(5000)
        check(plan["code"] == 0 and focused(plan) == 'hl.dsp.focus({ window = "address:0x5603affa7120" })', "a bare agent in the only window: %s" % plan["message"])
        m.run, _ = world(windows=[("0xa1", 2309, "zsh"), ("0xb2", 2309, TITLE)])
        plan = m.plan_pid(5000)
        check(plan["code"] == 3 and plan["commands"] == [], "two Ghostty windows and no tmux title: do nothing (%s)" % plan["message"])
        # Another terminal with its own pid per window (foot): unambiguous.
        m.run, _ = world(windows=[("0xa1", 2309, "zsh"), ("0xc3", 7000, "pi")])
        check(focused(m.plan_pid(7002)) == 'hl.dsp.focus({ window = "address:0xc3" })', "foot's own window")
        m.run, _ = world()
        check(m.plan_pid(424242)["code"] == 1, "a gone pid is an error")

        # Argument parsing.
        for argv, code in [([], 2), (["--pane", "%2", "--pid", "1"], 2), (["--pid", "x"], 2), (["--bogus"], 2)]:
            check(m.main(argv) == code, "argv %r exits %d" % (argv, code))
        m.run, calls = world()
        check(m.main(["--pane", "%2", "--dry-run"]) == 0, "dry run exits 0")
        check(not any(c[:2] == ["tmux", "switch-client"] for c in calls), "a dry run switches nothing")

    if failures:
        print("CREW_JUMP_TEST_FAIL: %d check(s) failed" % len(failures))
        return 1
    print("CREW_JUMP_TEST_PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
