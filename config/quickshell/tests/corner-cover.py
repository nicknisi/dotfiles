#!/usr/bin/env python3
"""The surfaces that paint the scrim paint the screen corners over it.

ScreenCorners' strips are Overlay layer surfaces, and Hyprland stacks a
layer's surfaces in map order: a full-screen Overlay surface that maps after
them and fills with Tokens.scrim (rgba(bg, .56)) covers their wedges and
turns them grey (keys review: the window switcher, the bars' power menu, the
polkit window). So every file that fills with Tokens.scrim is one of:

  - Island/Scrim.qml, which stays on the Top layer, under the strips;
  - the lock (Lock/), a session lock that Hyprland draws above every layer,
    corners and all;
  - a surface that paints a Kit/ScreenCornerSet over everything else it
    draws, filling it, at ScreenCorners.drawn (handed down from shell.qml).

The pixels are tst_kit's test_screen_corner_set and, for the power menu,
check.qml; this keeps a new scrim surface from forgetting them. Run by
tests/shortcuts.sh.
"""
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else pathlib.Path(__file__).resolve().parent.parent)
fail = []


def need(cond, msg):
    if not cond:
        fail.append(msg)


def read(rel):
    path = root / rel
    need(path.is_file(), f"no {rel}")
    return path.read_text() if path.is_file() else ""


scrims = sorted(
    p for p in root.rglob("*.qml")
    if "tests" not in p.relative_to(root).parts
    and re.search(r"\bcolor:\s*Tokens\.scrim\b", p.read_text())
)
names = [str(p.relative_to(root)) for p in scrims]
for want in ("WindowSwitcher.qml", "PolkitWindow.qml", "Hosts/AnchoredView.qml", "Island/Scrim.qml"):
    need(want in names, f"{want} no longer fills with Tokens.scrim: update this check")

for p in scrims:
    rel, text = str(p.relative_to(root)), p.read_text()
    if rel == "Island/Scrim.qml":
        need("WlrLayershell.layer: WlrLayer.Top" in text,
             "Island/Scrim.qml left the Top layer: it would cover the corner strips")
        continue
    if rel.startswith("Lock/"):
        continue
    m = re.search(r"\n(?P<indent>[ ]*)ScreenCornerSet\s*\{(?P<body>[^{}]*)\}", text)
    need(m is not None, f"{rel} fills with the scrim but paints no ScreenCornerSet over it")
    if not m:
        continue
    need(re.search(r"anchors\.fill:\s*parent\b", m["body"]) is not None,
         f"{rel}: its ScreenCornerSet does not fill the surface")
    need(re.search(r"radius:[^\n]*\b\w+\.corners\?\.drawn\b", m["body"]) is not None,
         f"{rel}: its ScreenCornerSet is not at corners.drawn")
    need(re.search(r"^\s*property var corners: null$", text, re.M) is not None,
         f"{rel} has no `property var corners: null`")
    # Drawn last at its level: no sibling object after it to paint over it.
    indent = m["indent"]
    rest = text[m.end():]
    need(re.search(r"\n" + indent + r"[A-Za-z][\w.]*\s*\{", rest) is None,
         f"{rel}: something is drawn after its ScreenCornerSet")

shell = read("shell.qml")
for host in ("WindowSwitcher", "PolkitWindow", "Bar"):
    m = re.search(r"\b" + host + r"\s*\{(?P<body>[^{}]*)\}", shell)
    need(m is not None and "corners: screenCorners" in m["body"],
         f"shell.qml: {host} is not handed ScreenCorners (corners: screenCorners)")
need(re.search(r"ScreenCorners\s*\{\s*id:\s*screenCorners\b", shell) is not None,
     "shell.qml: ScreenCorners has no id screenCorners")
need("corners: bar.corners" in read("Bar.qml"), "Bar.qml does not hand corners to its AnchoredHost")
need("corners: host.corners" in read("Hosts/AnchoredHost.qml"), "AnchoredHost does not hand corners to AnchoredView")
need(re.search(r"readonly property real drawn:\s*root\.on \? root\.shown : 0\b", read("ScreenCorners.qml")) is not None,
     "ScreenCorners.drawn is not `on ? shown : 0`")

for f in fail:
    print("CORNER_COVER_FAIL: " + f, file=sys.stderr)
if fail:
    sys.exit(1)
print(f"CORNER_COVER_PASS: {len(scrims)} scrim files; the switcher, polkit window and power menu paint the corners over theirs")
