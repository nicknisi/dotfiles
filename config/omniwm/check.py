"""Check this profile's invariants with Python 3.11+; no dependencies."""

from collections import Counter
from pathlib import Path
import tomllib

with Path(__file__).with_name("settings.toml").open("rb") as file:
    config = tomllib.load(file)

assert config["schemaVersion"] == 4
hotkeys = config["hotkeys"]
assert len({entry["id"] for entry in hotkeys}) == len(hotkeys) == 214
bindings = {entry["id"]: entry["binding"] for entry in hotkeys}
assigned = Counter(value for value in bindings.values() if value != "Unassigned")
assert all(count == 1 for count in assigned.values()), assigned
assert config["general"]["systemHyperTrigger"] == "None"
assert config["general"]["defaultLayoutType"] == "dwindle"
assert config["focus"]["followsWindowToMonitor"] is False

# Workspaces 1-9 are plain numbers on Option+digit; the lettered workspaces
# live at 11-18 on Option+letter. Hotkey ids are zero-based (workspace N -> .N-1).
letters = dict(zip(range(11, 19), "ACDNSWXZ"))
expected = {n: str(n) for n in range(1, 10)} | {n: l for n, l in letters.items()}
workspaces = config["workspaces"]
assert [int(w["name"]) for w in workspaces] == list(expected)
for workspace in workspaces:
    number = int(workspace["name"])
    key = expected[number]
    assert workspace.get("displayName", str(number)) == key
    assert workspace["monitorAssignment"] == {"type": "main"}
    assert bindings[f"switchWorkspace.{number - 1}"] == f"Option+{key}"
    assert bindings[f"moveToWorkspace.{number - 1}"] == f"Option+Shift+{key}"
for slot in range(1, 10):
    assert bindings[f"switchWorkspaceSlot.{slot}"] == "Unassigned"
    assert bindings[f"moveToWorkspaceSlot.{slot}"] == "Unassigned"

for key, direction in zip("HJKL", ("left", "down", "up", "right")):
    assert bindings[f"focus.{direction}"] == f"Option+{key}"
    assert bindings[f"move.{direction}"] == f"Option+Shift+{key}"
assert bindings["toggleWorkspaceLayout"] == "Control+Option+L"
assert bindings["toggleFullscreen"] == "Option+F"
assert bindings["toggleNativeFullscreen"] == "Option+Shift+F"
assert bindings["toggleFocusedWindowFloating"] == "Option+Shift+Space"
assert bindings["resizeFocusedWindow.grow"] == "Option+Shift+Equal"
assert bindings["resizeFocusedWindow.shrink"] == "Option+Shift+Minus"

names = {workspace["name"] for workspace in workspaces}
for rule in config["appRules"]:
    if "assignToWorkspace" in rule:
        assert rule["assignToWorkspace"] in names, rule
routes = {rule["bundleId"]: rule.get("assignToWorkspace") for rule in config["appRules"]}
for bundle, target in {
    "com.mitchellh.ghostty": "13",
    "com.hnc.Discord": "12",
    "com.brave.Browser.origin": "16",
    "net.imput.helium": "16",
    "com.tinyspeck.slackmacgap": "15",
    "md.obsidian": "15",
    "us.zoom.xos": "18",
}.items():
    assert routes[bundle] == target

assert config["gestures"]["fingerCount"] == 4
assert config["gestures"]["workspaceSwipeFingerCount"] == 3
assert config["gestures"]["workspaceSwipeAxis"] == "horizontal"
assert config["gestures"]["workspaceSwipeEnabled"] is True
assert config["quakeTerminal"]["position"] == "bottom"
assert config["quakeTerminal"]["widthPercent"] == 80.0
assert config["quakeTerminal"]["heightPercent"] == 65.0
print(f"OK: {len(workspaces)} workspaces, {len(hotkeys)} action IDs, {len(assigned)} unique shortcuts; routes and gestures checked")
