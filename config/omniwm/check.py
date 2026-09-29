"""Check this profile's invariants with Python 3.11+; no dependencies."""

from collections import Counter
from pathlib import Path
import tomllib

with Path(__file__).with_name("settings.toml").open("rb") as file:
    config = tomllib.load(file)

assert config["schemaVersion"] == 3
hotkeys = config["hotkeys"]
assert len({entry["id"] for entry in hotkeys}) == len(hotkeys) == 188
bindings = {entry["id"]: entry["binding"] for entry in hotkeys}
assigned = Counter(value for value in bindings.values() if value != "Unassigned")
assert all(count == 1 for count in assigned.values()), assigned
assert config["general"]["systemHyperTrigger"] == "None"
assert config["general"]["defaultLayoutType"] == "dwindle"
assert config["focus"]["followsWindowToMonitor"] is False

labels = ["A", "C", "D", "N", "S", "W", "X", "Z", "9"]
workspaces = config["workspaces"]
assert len(workspaces) == len(labels)
for index, (workspace, label) in enumerate(zip(workspaces, labels)):
    number = str(index + 1)
    assert workspace["name"] == number
    assert workspace.get("displayName", number) == label
    assert workspace["layoutType"] == ("niri" if label == "D" else "default")
    assert workspace["monitorAssignment"] == {"type": "main"}
    assert bindings[f"switchWorkspace.{index}"] == f"Option+{label}"
    assert bindings[f"moveToWorkspace.{index}"] == f"Option+Shift+{label}"
    if label != "9":
        assert bindings[f"switchWorkspaceSlot.{number}"] == f"Option+{number}"
        assert bindings[f"moveToWorkspaceSlot.{number}"] == f"Option+Shift+{number}"

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
    "com.mitchellh.ghostty": "3",
    "com.hnc.Discord": "2",
    "com.brave.Browser.origin": "6",
    "net.imput.helium": "6",
    "com.tinyspeck.slackmacgap": "5",
    "md.obsidian": "5",
    "us.zoom.xos": "8",
}.items():
    assert routes[bundle] == target

assert config["gestures"]["fingerCount"] == 4
assert config["gestures"]["workspaceSwipeFingerCount"] == 3
assert config["gestures"]["workspaceSwipeAxis"] == "horizontal"
assert config["gestures"]["workspaceSwipeEnabled"] is True
assert config["quakeTerminal"]["position"] == "top"
assert config["quakeTerminal"]["widthPercent"] == 70.0
assert config["quakeTerminal"]["heightPercent"] == 50.0
print(f"OK: {len(workspaces)} workspaces, {len(hotkeys)} action IDs, {len(assigned)} unique shortcuts; routes and gestures checked")
