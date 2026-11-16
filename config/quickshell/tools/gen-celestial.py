#!/usr/bin/env python3
"""gen-celestial.py: refresh the shape data in lib/Celestial.js from OmniWM.

  gen-celestial.py            rewrite lib/Celestial.js in place
  gen-celestial.py --check    exit 1 if lib/Celestial.js is out of date

Reads config/omniwm/shell/lib/shapes.luau (the radii tables) and
wayline-base.luau (FOCUSED_SHAPES, the focus pool) with regular expressions, so
no Luau runtime is needed, and writes them between the BEGIN/END GENERATED
markers in lib/Celestial.js. It also sets the file's first two lines to the
SPDX and copyright lines of shapes.luau, with `--` turned into `//`.

This script holds no shape data and none of the path code: the data stays in
the .luau files and in lib/Celestial.js (GPL-2.0-only, OmniNull), and the path
code is the hand port in Celestial.js outside the markers. It fails rather than
guess when a row does not have 72 numbers or a pool name has no radii.
"""

import argparse
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
CONFIG = HERE.parent
REPO = CONFIG.parent.parent
SHAPES = REPO / "config/omniwm/shell/lib/shapes.luau"
WAYLINE = REPO / "config/omniwm/shell/lib/wayline-base.luau"
TARGET = CONFIG / "lib/Celestial.js"

SAMPLES = 72
BEGIN = "// BEGIN GENERATED"
END = "// END GENERATED"
ROW = re.compile(r"^\s+([A-Za-z][A-Za-z0-9]*) = \{ ([0-9., ]+) \},?\s*$")
POOL = re.compile(r"FOCUSED_SHAPES\s*=\s*\{([^}]*)\}", re.S)


def die(message):
    print(f"gen-celestial: {message}", file=sys.stderr)
    sys.exit(2)


def header(text):
    lines = text.splitlines()[:2]
    if len(lines) < 2 or not lines[0].startswith("-- SPDX-License-Identifier:") or not lines[1].startswith("-- Copyright"):
        die(f"{SHAPES} does not start with its SPDX and copyright lines")
    return ["//" + line[2:] for line in lines]


def radii(text):
    table = {}
    block = text.split("local radii", 1)
    if len(block) != 2:
        die(f"no radii table in {SHAPES}")
    for line in block[1].split("\n}", 1)[0].splitlines():
        m = ROW.match(line)
        if not m:
            continue
        name, body = m.group(1), m.group(2)
        values = [v.strip() for v in body.split(",") if v.strip()]
        if len(values) != SAMPLES:
            die(f"{name} has {len(values)} radii, want {SAMPLES}")
        for v in values:
            float(v)
        if name in table:
            die(f"{name} is defined twice")
        table[name] = values
    if "Circle" not in table:
        die("no Circle row (Celestial.js falls back to it)")
    return table


def pool(text, table):
    m = POOL.search(text)
    if not m:
        die(f"no FOCUSED_SHAPES in {WAYLINE}")
    names = re.findall(r'"([A-Za-z0-9]+)"', m.group(1))
    if not names:
        die("FOCUSED_SHAPES is empty")
    missing = [n for n in names if n not in table]
    if missing:
        die(f"FOCUSED_SHAPES names shapes with no radii: {', '.join(missing)}")
    return names


def render(table, names):
    rows = [f"    {name}: [{', '.join(values)}]" for name, values in table.items()]
    return "\n".join([
        f"{BEGIN} by tools/gen-celestial.py from config/omniwm/shell/lib/{{shapes,wayline-base}}.luau",
        "var RADII = {",
        ",\n".join(rows),
        "};",
        "var POOL = [" + ", ".join(f'"{n}"' for n in names) + "];",
        END,
    ])


def build(current):
    shapes = SHAPES.read_text(encoding="utf-8")
    table = radii(shapes)
    names = pool(WAYLINE.read_text(encoding="utf-8"), table)
    lines = current.split("\n")
    lines[0:2] = header(shapes)
    text = "\n".join(lines)
    start = text.find(BEGIN)
    stop = text.find(END)
    if start < 0 or stop < start:
        die(f"{TARGET} has no {BEGIN} ... {END} block")
    stop += len(END)
    return text[:start] + render(table, names) + text[stop:]


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="fail if lib/Celestial.js is out of date")
    args = parser.parse_args()
    if not TARGET.exists():
        die(f"{TARGET} is missing; it holds the hand-written path code, so restore it from git")
    current = TARGET.read_text(encoding="utf-8")
    fresh = build(current)
    if args.check:
        if fresh != current:
            print("CELESTIAL_GEN_STALE: run config/quickshell/tools/gen-celestial.py", file=sys.stderr)
            sys.exit(1)
        print("CELESTIAL_GEN_PASS")
        return
    if fresh != current:
        TARGET.write_text(fresh, encoding="utf-8")
        print(f"gen-celestial: wrote {TARGET}")
    else:
        print(f"gen-celestial: {TARGET} is up to date")


if __name__ == "__main__":
    main()
