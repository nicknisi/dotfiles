#!/usr/bin/env python3
"""Run: python3 config/sketchybar/tests/workspaces.py (isolated CLI stubs)."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
CONFIG = ROOT / "config/sketchybar"
BASH = shutil.which("bash")

STUB = r'''#!/usr/bin/env python3
import json, os, pathlib, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["CALLS"], "a") as f:
    f.write(json.dumps([name, *args]) + "\n")
if name == "omniwmctl":
    if args[0] == "query":
        if os.environ.get("IPC_FAIL") in ("1", args[1]): sys.exit(1)
        fixtures = json.loads(pathlib.Path(os.environ["FIXTURES"]).read_text())
        print(json.dumps({"ok": True, "result": {"payload": fixtures[args[1]]}}))
elif name == "aerospace":
    if args[0] == "list-workspaces":
        print("D" if "--focused" in args else "A\nD\nW\nN")
    elif args[0] == "list-windows":
        print("Terminal title" if "--focused" in args else "D|Ghostty\nD|Ghostty\nW|Safari")
elif name == "pgrep":
    sys.exit(0 if args[-1] == os.environ.get("RUNNING_WM", "OmniWM") else 1)
'''

with tempfile.TemporaryDirectory() as tmp:
    work = Path(tmp)
    bindir = work / "bin"
    bindir.mkdir()
    for name in ("omniwmctl", "aerospace", "sketchybar", "pgrep", "pkill", "nohup",
                 "fleet", "tmux", "open"):
        script = bindir / name
        script.write_text(STUB)
        script.chmod(0o755)
    calls_file = work / "calls"
    fixtures_file = work / "fixtures.json"
    home = work / "home"
    home.mkdir()
    env = {**os.environ, "HOME": str(home), "CONFIG_DIR": str(CONFIG),
           "PATH": f"{bindir}:{os.environ['PATH']}", "CALLS": str(calls_file),
           "FIXTURES": str(fixtures_file), "OMNIWMCTL": str(bindir / "omniwmctl"),
           "SKETCHYBAR_WM": "omniwm", "SENDER": "omniwm_change"}
    workspaces = [{"number": n, "displayName": label} for n, label in
                  [(1, "A"), (3, "D"), (6, "W"), (4, "N")]]
    windows = [
        {"workspace": {"number": 3}, "app": {"name": "Ghostty"},
         "title": 'Terminal "quoted" | title', "isFocused": True},
        {"workspace": {"number": 3}, "app": {"name": "Ghostty"},
         "title": "Second terminal", "isFocused": False},
        {"workspace": {"number": 6}, "app": {"name": "Safari"},
         "title": "Browser", "isFocused": False},
    ]
    fixtures = {"workspaces": {"workspaces": workspaces},
                "windows": {"windows": windows},
                "active-workspace": {"workspace": {"number": 3}}}

    def run(script, *args, expected=0, **overrides):
        fixtures_file.write_text(json.dumps(fixtures))
        calls_file.write_text("")
        result = subprocess.run([BASH, str(CONFIG / script), *args],
                                env={**env, **overrides}, capture_output=True, text=True)
        assert result.returncode == expected, (script, result.stdout, result.stderr)
        return [json.loads(line) for line in calls_file.read_text().splitlines()]

    def settings(calls, item):
        props = {}
        for command in calls:
            if command[0] != "sketchybar": continue
            active = False
            for i, arg in enumerate(command):
                if arg.startswith("--"):
                    active = arg == "--set" and command[i + 1] == item
                elif active and "=" in arg:
                    key, value = arg.split("=", 1)
                    props[key] = value
        return props

    calls = run("plugins/workspaces.sh")
    focused = settings(calls, "space.3")
    assert focused["icon"] == "D" and focused["drawing"] == "on", focused
    assert len(focused["label"].split()) == 1, "App icons should deduplicate"
    assert settings(calls, "space.6")["drawing"] == "on"
    assert settings(calls, "space.4")["drawing"] == "off"
    assert settings(calls, "title")["label"] == 'Terminal "quoted" | title'
    assert settings(calls, "title")["icon.drawing"] == "off"
    assert settings(calls, "ring.3")["background.border_color"] != settings(calls, "ring.6")["background.border_color"]
    assert (home / ".cache/sketchybar/focused-workspace").read_text().strip() == "D"
    assert (home / ".cache/sketchybar/focused-workspace-id").read_text().strip() == "3"
    assert ["sketchybar", "--trigger", "wm_workspace_rendered"] in calls
    assert not any(c[0] == "aerospace" for c in calls)
    hover = run("plugins/space_hover.sh", NAME="space.3", SENDER="mouse.entered")
    assert not any(c[0] == "sketchybar" for c in hover), "Focused hover stays lit"

    # Existing agent LEDs and PUA stripping survive the OmniWM title path.
    for glyph in ("✳", "⠋"):
        windows[0]["title"] = f"{glyph} Agent task \U000f167a"
        calls = run("plugins/workspaces.sh")
        title = settings(calls, "title")
        assert title["icon.drawing"] == "on" and title["label"].strip() == "Agent task", title

    # Purpose-based widget clicks resolve labels to OmniWM numbers.
    for plugin, label, number in (("agents_click.sh", "D", "3"),
                                  ("spend_click.sh", "D", "3"),
                                  ("github_click.sh", "W", "6")):
        calls = run(f"plugins/{plugin}", BUTTON="right")
        assert ["omniwmctl", "command", "switch-workspace", number] in calls, (label, calls)

    # Empty active workspaces remain visible even without a focused window.
    fixtures["active-workspace"]["workspace"] = {"number": 4}
    for window in windows: window["isFocused"] = False
    calls = run("plugins/workspaces.sh")
    assert settings(calls, "space.4")["drawing"] == "on"
    assert settings(calls, "title")["drawing"] == "off"
    for failed_query in ("workspaces", "windows", "active-workspace"):
        assert not any(c[0] == "sketchybar" for c in
                       run("plugins/workspaces.sh", IPC_FAIL=failed_query, expected=1))

    # Labels can be renamed without changing click IDs; render updates them.
    workspaces[1]["displayName"] = "Dev tools"
    calls = run("plugins/workspaces.sh")
    assert settings(calls, "space.3")["icon"] == "Dev tools"
    calls = run("plugins/wm.sh", "focus-label", "Dev tools")
    assert ["omniwmctl", "command", "switch-workspace", "3"] in calls
    calls = run("plugins/wm.sh", "focus", "6")
    assert ["omniwmctl", "command", "switch-workspace", "6"] in calls
    calls = run("plugins/wm.sh", "focus-label", "missing", expected=1)
    assert not any(c[:2] == ["omniwmctl", "command"] for c in calls)

    # Existing AeroSpace render, navigation and cached labels keep working.
    calls = run("plugins/workspaces.sh", SKETCHYBAR_WM="aerospace", SENDER="aerospace_focus_change")
    assert settings(calls, "space.D")["drawing"] == "on"
    assert settings(calls, "title")["label"] == "Terminal title"
    assert not any(c[0] == "omniwmctl" for c in calls)
    assert ["sketchybar", "--trigger", "wm_workspace_rendered"] in calls
    calls = run("plugins/workspaces.sh", SKETCHYBAR_WM="aerospace", FOCUSED_WORKSPACE="N")
    assert settings(calls, "space.N")["drawing"] == "on"
    assert ["aerospace", "list-workspaces", "--focused"] not in calls
    calls = run("plugins/wm.sh", "focus-label", "D", SKETCHYBAR_WM="aerospace")
    assert ["aerospace", "workspace", "D"] in calls

    # Config creates numeric IDs with label text and executable click commands.
    calls = run("sketchybarrc")
    assert settings(calls, "space.3")["icon"] == "Dev tools"
    assert settings(calls, "space.3")["click_script"].endswith("wm.sh focus 3")
    assert any(c[:4] == ["sketchybar", "--add", "item", "wm_watchdog"] for c in calls)
    calls = run("plugins/wm.sh", "watch")
    watch = next(c for c in calls if c[:2] == ["omniwmctl", "watch"])
    assert "--reconnect" in watch and "active-workspace" in watch[2]
    assert watch[-4:] == ["--exec", "sketchybar", "--trigger", "omniwm_change"]

    # Auto-detection prefers OmniWM; quitting AeroSpace cannot kill its bar.
    calls = run("plugins/wm.sh", "focus", "3", SKETCHYBAR_WM="")
    assert ["omniwmctl", "command", "switch-workspace", "3"] in calls
    for running in ("OmniWM", "AeroSpace"):
        calls = run("plugins/wm.sh", "watchdog", RUNNING_WM=running)
        assert not any(c[0] == "pkill" for c in calls)
    calls = run("plugins/wm.sh", "watchdog", RUNNING_WM="none")
    assert ["pkill", "-x", "sketchybar"] in calls
    pattern = next(c[2] for c in calls if c[:2] == ["pkill", "-f"] and "omniwmctl" in c[2])
    watch_command = "/opt/homebrew/bin/omniwmctl watch focus --reconnect --exec sketchybar --trigger omniwm_change"
    assert re.search(pattern, watch_command)
    assert not re.search(pattern, f"bash -c echo '{watch_command}'"), "Do not kill parent shells"

print("Workspace checks passed: OmniWM/AeroSpace rendering, focus, labels, hover, IPC failure, events, and lifecycle.")
