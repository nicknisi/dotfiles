#!/usr/bin/env python3
"""bin/omniwm-agents against fake process trees (PLAN M2).

  python3 -B bin/tests/omniwm-agents.py [path/to/omniwm-agents]

Linux: a fake /proc (stat, cmdline, cwd links, uptime) with the shapes milhouse
has: tmux's server named "tmux: server", two agents in its panes, a Claude in a
bare Ghostty window, a subagent, and a Riker worker. Checks host detection,
pid/pane/session/windowId, cwd from /proc, ages, sort, and that the scan never
shells out to ps or lsof.

--crew (the Quickshell Crew's scan): no `fleet list` and no `riker jobs`.

macOS: fake `ps` and `lsof` output for the same tree with comm "tmux". The
script's output must equal what it printed before the Linux work (the golden
below, captured from the pre-M2 script), field for field: the jump fields
(pid, pane, session, windowId) are Linux only. With fleet answering and with
fleet knowing no pane (where stays "" there).

spend(): its cache and, on Linux, its backoff in a temp dir, with Popen
recorded, not run. On macOS it runs the pre-M2 refresh: no backoff.

No real process, tmux or fleet is touched: every command goes through a fake
run(), and spend() and claude_usage() are stubbed so nothing writes ~/.cache.
Python 3.9 compatible, like the script.
"""

import importlib.machinery
import importlib.util
import json
import os
import sys
import tempfile
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCRIPT = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE.parent / "omniwm-agents"
HOME = "/home/x"
HZ = 100
UPTIME = 1000000.0

failures = []


def check(cond, message):
    if not cond:
        failures.append(message)
        print("FAIL", message)


def load(path):
    loader = importlib.machinery.SourceFileLoader("omniwm_agents_under_test", str(path))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    module.real_spend = module.spend
    module.HOME = Path(HOME)
    module.spend = lambda: {"today": 4.37, "sessions": 3, "tools": [], "models": []}
    module.claude_usage = lambda: None
    return module


# pid: (ppid, comm, cmdline, cwd, seconds alive)
TREE = {
    1: (0, "systemd", "/sbin/init", "/", 99990),
    1303: (1, "systemd", "/usr/lib/systemd/systemd --user", HOME, 99000),
    2309: (1303, "ghostty", "/usr/bin/ghostty", HOME, 90000),
    2554: (2309, "zsh", "-zsh", HOME, 89990),
    2792: (2554, "tmux: client", "tmux attach", HOME, 89980),
    2599: (1303, "tmux: server", "tmux", HOME, 89985),
    2790: (2599, "zsh", "-zsh", HOME + "/Developer/dotfiles", 89000),
    3157: (2790, "claude", "claude", HOME + "/Developer/dotfiles", 7200),
    3200: (3157, "claude", "claude --subagent", HOME + "/Developer/dotfiles", 60),
    11240: (2599, "zsh", "-zsh", HOME + "/Developer", 80000),
    11818: (11240, "pi", "pi", HOME + "/Developer", 300),
    4990: (2309, "zsh", "-zsh", HOME + "/Developer/notes", 5000),
    5000: (4990, "2.1.220", "claude", HOME + "/Developer/notes", 2 * 86400 + 5),
    6000: (1303, "bun", "bun run /opt/riker/riker.ts worker", HOME, 4000),
    6010: (6000, "pi", "pi --worker", HOME + "/Developer/dotfiles/.riker/worktrees/12", 1500),
    # A kernel thread and a comm that would trip a naive "(...)" split.
    2: (0, "kthreadd", "", "/", 99990),
    7000: (1303, "a) b (c", "weird", HOME, 10),
}

PANES = "\n".join([
    "2790\t%0\tprojects\t@0\t" + HOME + "/Developer/dotfiles",
    "11240\t%2\tprojects\t@1\t" + HOME + "/Developer",
    "",
])

FLEET = json.dumps({"agents": [
    {"pane": "%0", "label": "Hypr launcher text color", "project": "~/Developer/dotfiles", "status": "IDLE",
     "needsAttention": False, "session": "projects", "windowId": "@0"},
    {"pane": "%2", "label": "Make a detailed artifact", "project": "~/Developer", "status": "QUESTION",
     "needsAttention": True, "session": "projects", "windowId": "@1"},
]})

RIKER = json.dumps([{"id": 12, "goal": "Rebuild the crew"}])


def make_proc(root):
    (root / "uptime").write_text("%.2f 12345.00\n" % UPTIME)
    (root / "self").mkdir()  # not a pid: skipped
    for pid, (ppid, comm, cmdline, cwd, alive) in TREE.items():
        d = root / str(pid)
        d.mkdir()
        start = int((UPTIME - alive) * HZ)
        rest = " ".join(["0"] * 12)  # fields 10 to 21: starttime is field 22
        (d / "stat").write_text("%d (%s) S %d %d %d 0 -1 4194560 %s %d 0 0\n" % (pid, comm, ppid, pid, pid, rest, start))
        (d / "cmdline").write_bytes(cmdline.replace(" ", "\0").encode() + (b"\0" if cmdline else b""))
        os.symlink(cwd, str(d / "cwd"))
    # A process that exits between listing and reading.
    (root / "9999").mkdir()


def fake_run(calls, ps=None, lsof=None, fleet=None):
    def run(*cmd, timeout=10):
        calls.append(cmd)
        if cmd[0] == "tmux" and cmd[1] == "list-panes":
            fmt = cmd[-1]
            if "\t" in fmt:
                return PANES
            # The pre-M2 format: "#{pane_pid} #{pane_id}".
            return "\n".join(" ".join(line.split("\t")[:2]) for line in PANES.splitlines() if line) + "\n"
        if cmd[:3] == ("fleet", "list", "--json"):
            return FLEET if fleet is None else fleet
        if cmd[:2] == ("riker", "jobs"):
            return RIKER
        if cmd[0] == "ps" and ps is not None:
            return ps(cmd)
        if cmd[0] == "lsof" and lsof is not None:
            return lsof(cmd)
        return ""
    return run


def by_pid(payload):
    return {a.get("pid"): a for a in payload["agents"]}


# ---- Linux ------------------------------------------------------------------

def test_linux():
    m = load(SCRIPT)
    m.self_check()
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        make_proc(root)
        m.PROC = root
        m.LINUX = True
        m.os.sysconf = lambda name: HZ if name == "SC_CLK_TCK" else os.sysconf(name)
        calls = []
        m.run = fake_run(calls)
        procs = m.processes()
        check(procs[2599][2] == "tmux: server", "the tmux server keeps its full Linux comm: %r" % (procs[2599],))
        check(procs[7000][2] == "a) b (c", "comm with parentheses parses: %r" % (procs[7000],))
        check(procs[3157][0] == 2790 and procs[3157][3] == "claude", "ppid and cmdline from /proc")
        check(procs[6000][3] == "bun run /opt/riker/riker.ts worker", "cmdline NULs become spaces")
        check(9999 not in procs and 2 in procs, "a vanished pid is skipped, a kernel thread kept")
        check(m.age(procs[5000][1]) == "2d" and m.age(procs[11818][1]) == "5m", "ages from starttime and uptime")
        check(m.host_of(3157, procs) == "tmux", "tmux: server is a tmux host")
        check(m.host_of(5000, procs) == "ghostty", "a bare Ghostty agent is a ghostty host")
        check(m.host_of(6010, procs) == "riker", "a Riker worker is a riker host")
        check(m.cwd(5000) == HOME + "/Developer/notes", "cwd comes from /proc/<pid>/cwd")
        check(m.cwd(424242) == "", "a missing pid has no cwd")

        out = m.collect()
        agents = by_pid(out)
        check(out["total"] == 4 and out["subagents"] == 1, "four top-level agents, one subagent: %r" % ((out["total"], out["subagents"]),))
        check(out["attention"] == 1 and out["hosts"] == {"tmux": 2, "ghostty": 1, "riker": 1}, "attention and hosts: %r" % (out["hosts"],))
        claude = agents.get(3157, {})
        check(claude.get("host") == "tmux" and claude.get("pane") == "%0" and claude.get("session") == "projects"
              and claude.get("windowId") == "@0", "tmux claude gets pane, session and windowId: %r" % claude)
        check(claude.get("label") == "Hypr launcher text color" and claude.get("state") == "idle"
              and claude.get("where") == "~/Developer/dotfiles", "fleet label, state and project")
        pi = agents.get(11818, {})
        check(pi.get("attention") is True and pi.get("state") == "question" and pi.get("pane") == "%2", "fleet attention: %r" % pi)
        bare = agents.get(5000, {})
        check(bare.get("kind") == "claude" and bare.get("host") == "ghostty" and bare.get("label") == "notes"
              and bare.get("where") == "~/Developer/notes" and bare.get("pane") == "" and bare.get("age") == "2d",
              "bare Ghostty claude: version comm, cwd label, no pane: %r" % bare)
        riker = agents.get(6010, {})
        check(riker.get("host") == "riker" and riker.get("label") == "#12 Rebuild the crew"
              and riker.get("where") == "~/Developer/dotfiles/.riker/worktrees/12", "riker job: %r" % riker)
        check([a["pid"] for a in out["agents"]][0] == 11818, "the agent that needs you sorts first")
        check(all(set(a) >= {"pid", "pane", "session", "windowId"} for a in out["agents"]), "every agent has the jump fields")
        check(out["spend"]["today"] == 4.37, "spend passes through")
        tools = sorted({c[0] for c in calls})
        check("ps" not in tools and "lsof" not in tools, "the Linux scan never runs ps or lsof: %r" % tools)
        check(tools == ["fleet", "riker", "tmux"], "only tmux, fleet and riker are asked: %r" % tools)
        json.dumps(out)

        # --crew: the Crew polls fleet itself and shows the job id from the path.
        calls[:] = []
        crew = m.collect(crew=True)
        tools = sorted({c[0] for c in calls})
        check(tools == ["tmux"], "--crew asks tmux only, no fleet or riker: %r" % tools)
        agents = by_pid(crew)
        check(crew["total"] == 4 and crew["attention"] == 0, "--crew sees every agent, attention comes from fleet in the Crew")
        check(agents[3157]["where"] == "~/Developer/dotfiles" and agents[3157]["pane"] == "%0"
              and agents[3157]["state"] == "running", "--crew tmux agents: the pane's path, pane ids: %r" % agents[3157])
        check(agents[6010]["label"] == "#12", "--crew keeps the riker job id without its goal: %r" % agents[6010]["label"])


# ---- macOS ------------------------------------------------------------------

def mac_ps(cmd):
    cols = cmd[-1]
    lines = []
    for pid, (ppid, comm, cmdline, _cwd, alive) in sorted(TREE.items()):
        if pid in (2, 7000):
            continue
        mac_comm = "tmux" if comm.startswith("tmux") else comm
        if cols == "pid=,command=":
            lines.append("%5d %s" % (pid, cmdline or mac_comm))
        else:
            # ps etime as macOS prints it, and comm with a full path for apps.
            path = "/Applications/Ghostty.app/Contents/MacOS/ghostty" if comm == "ghostty" else mac_comm
            lines.append("%5d %5d %11s %s" % (pid, ppid, etime(alive), path))
    return "\n".join(lines) + "\n"


def etime(secs):
    days, rest = divmod(int(secs), 86400)
    hours, rest = divmod(rest, 3600)
    mins, secs = divmod(rest, 60)
    clock = "%02d:%02d:%02d" % (hours, mins, secs) if days or hours else "%02d:%02d" % (mins, secs)
    return "%d-%s" % (days, clock) if days else clock


def mac_lsof(cmd):
    pid = int(cmd[cmd.index("-p") + 1])
    return "p%d\nfcwd\nn%s\n" % (pid, TREE[pid][3])


# What the pre-M2 script printed for this tree on macOS (captured by running it
# with the same fakes), minus `t`.
MAC_GOLDEN = {
    "total": 4, "subagents": 1, "attention": 1, "hosts": {"tmux": 2, "ghostty": 1, "riker": 1},
    "agents": [
        {"kind": "pi", "host": "tmux", "age": "5m", "state": "question", "label": "Make a detailed artifact",
         "where": "~/Developer", "attention": True},
        {"kind": "claude", "host": "ghostty", "age": "2d", "state": "running", "label": "notes",
         "where": "~/Developer/notes"},
        {"kind": "pi", "host": "riker", "age": "25m", "state": "running", "label": "#12 Rebuild the crew",
         "where": "~/Developer/dotfiles/.riker/worktrees/12"},
        {"kind": "claude", "host": "tmux", "age": "2h", "state": "idle", "label": "Hypr launcher text color",
         "where": "~/Developer/dotfiles", "attention": False},
    ],
    "spend": {"today": 4.37, "sessions": 3, "tools": [], "models": []}, "claude5h": None,
}
JUMP_FIELDS = {"pid", "pane", "session", "windowId"}


def mac_collect(path, fleet=None):
    m = load(path)
    m.LINUX = False
    calls = []
    m.run = fake_run(calls, ps=mac_ps, lsof=mac_lsof, fleet=fleet)
    out = m.collect()
    out.pop("t", None)
    return out, calls


# The same, with fleet answering but knowing no pane (captured from the
# pre-M2 script with FLEET='{"agents": []}'): tmux agents keep where "".
MAC_GOLDEN_NO_FLEET = {
    "total": 4, "subagents": 1, "attention": 0, "hosts": {"tmux": 2, "ghostty": 1, "riker": 1},
    "agents": [
        {"kind": "claude", "host": "ghostty", "age": "2d", "state": "running", "label": "notes",
         "where": "~/Developer/notes"},
        {"kind": "pi", "host": "riker", "age": "25m", "state": "running", "label": "#12 Rebuild the crew",
         "where": "~/Developer/dotfiles/.riker/worktrees/12"},
        {"kind": "claude", "host": "tmux", "age": "2h", "state": "running", "label": "", "where": "",
         "attention": False},
        {"kind": "pi", "host": "tmux", "age": "5m", "state": "running", "label": "", "where": "",
         "attention": False},
    ],
    "spend": {"today": 4.37, "sessions": 3, "tools": [], "models": []}, "claude5h": None,
}


def test_macos(golden_from=None):
    if golden_from:
        old, _ = mac_collect(golden_from)
        print(json.dumps(old, indent=1))
        old, _ = mac_collect(golden_from, fleet='{"agents": []}')
        print(json.dumps(old, indent=1))
        return
    out, calls = mac_collect(SCRIPT)
    check(out == MAC_GOLDEN, "macOS output is unchanged:\n%s" % json.dumps(out, indent=1))
    # Key order too: the widget gets the same JSON text.
    check([list(a) for a in out["agents"]] == [list(a) for a in MAC_GOLDEN["agents"]], "macOS agents keep their key order")
    empty, _ = mac_collect(SCRIPT, fleet='{"agents": []}')
    check(empty == MAC_GOLDEN_NO_FLEET,
          "macOS with fleet knowing no pane is unchanged (where stays \"\"):\n%s" % json.dumps(empty, indent=1))
    check(not any(JUMP_FIELDS & set(a) for a in out["agents"] + empty["agents"]), "macOS agents carry no jump fields")
    tools = sorted({c[0] for c in calls})
    check("ps" in tools and "lsof" in tools, "macOS keeps ps and lsof: %r" % tools)


# ---- spend ------------------------------------------------------------------

def test_spend():
    m = load(SCRIPT)
    m.LINUX = True
    spend = m.real_spend
    spawned = []

    class FakePopen:
        def __init__(self, argv, **kw):
            spawned.append(argv)

    m.subprocess.Popen = FakePopen
    with tempfile.TemporaryDirectory() as tmp:
        cache = Path(tmp) / "omniwm-agents"
        m.CACHE, m.SPEND = cache, cache / "spend.json"
        check(spend() is None and len(spawned) == 1 and cache.is_dir(), "no cache: one refresh starts, the dir is made")
        check(spend() is None and len(spawned) == 1, "a running refresh (fresh lock) is not doubled")
        (cache / "spend.lock").unlink()
        (cache / "spend.failed").touch()
        check(spend() is None and len(spawned) == 1, "a failed refresh backs off instead of re-running every scan")
        old = time.time() - m.SPEND_TTL - 5
        os.utime(str(cache / "spend.failed"), (old, old))
        spend()
        check(len(spawned) == 2, "the backoff ends after SPEND_TTL")
        script = spawned[-1][2]
        check('touch "$3"' in script and 'rm -f "$3"' in script and spawned[-1][-1].endswith("spend.failed"),
              "the refresh marks failure and clears it on success: %r" % script)
        (cache / "spend.lock").unlink()
        m.SPEND.write_text(json.dumps({"summary": {"totalCostUSD": 4.371, "sessions": 6}, "byTool": [], "byModel": []}))
        got = spend()
        check(got and got["today"] == 4.37 and len(spawned) == 2, "a fresh cache is read without a refresh: %r" % got)
    with tempfile.TemporaryDirectory() as tmp:
        cache = Path(tmp) / "omniwm-agents"
        m.CACHE, m.SPEND = cache, cache / "spend.json"
        cache.mkdir()
        m.SPEND.write_text("{}")
        spend()
        check(sorted(p.name for p in cache.iterdir()) == ["spend.json"], "a fresh cache writes nothing")
    # macOS: the pre-M2 spend(). The dir is made on every scan, a failed
    # refresh leaves no mark and the next stale scan tries again.
    m.LINUX = False
    spawned[:] = []
    with tempfile.TemporaryDirectory() as tmp:
        cache = Path(tmp) / "omniwm-agents"
        m.CACHE, m.SPEND = cache, cache / "spend.json"
        check(spend() is None and len(spawned) == 1 and cache.is_dir(), "macOS: no cache, one refresh, the dir is made")
        check(spawned[0] == ["sh", "-c", 'sessions report --today --stdout > "$1.tmp" && mv "$1.tmp" "$1"; rm -f "$2"',
                             "sh", str(m.SPEND), str(cache / "spend.lock")], "macOS: the pre-M2 refresh, unchanged: %r" % spawned[0])
        (cache / "spend.lock").unlink()
        (cache / "spend.failed").touch()  # as a Linux run would leave it: ignored
        check(spend() is None and len(spawned) == 2, "macOS: no backoff, the next stale scan tries again")


if __name__ == "__main__":
    if os.environ.get("OMNIWM_AGENTS_GOLDEN"):
        test_macos(golden_from=os.environ["OMNIWM_AGENTS_GOLDEN"])
        sys.exit(0)
    test_linux()
    test_macos()
    test_spend()
    if failures:
        print("OMNIWM_AGENTS_TEST_FAIL: %d check(s) failed" % len(failures))
        sys.exit(1)
    print("OMNIWM_AGENTS_TEST_PASS")
