#!/usr/bin/env python3
"""Icon provenance: every path in Kit/IconPaths.js is a pinned Lucide original.

The island's icons came from the design mocks, and the mocks' paths could not
be traced to a licensed source (main-tokens.md 1.9). So the shell ships Lucide
(ISC) paths instead, and this check proves it, entry by entry: it reads the
pinned lucide-static package, converts each named icon's SVG elements to one
canonical path string, and requires the IconPaths.js entry to equal it exactly.

Entries with "lucide": null are drawn here, not taken from anywhere; each one
must say so in "origin". The file must also carry Lucide's ISC notice, and the
Feather MIT notice when any icon on Lucide's Feather-derived list is used.

    python3 -B tests/icon-provenance.py            # check (downloads the package once)
    python3 -B tests/icon-provenance.py --write    # refill every "d" from Lucide
    python3 -B tests/icon-provenance.py --offline-ok   # pass with a SKIP line when
                                                   # the package is not cached and
                                                   # the registry is unreachable

The tarball is verified against its npm sha512 and read in memory, never
extracted. It is cached at $XDG_CACHE_HOME/quickshell-tests/.
"""
import argparse
import base64
import hashlib
import io
import json
import os
import re
import sys
import tarfile
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

VERSION = "1.65.0"
TARBALL = f"https://registry.npmjs.org/lucide-static/-/lucide-static-{VERSION}.tgz"
INTEGRITY = "sha512-Mbahsp1MHXzBK2qQ+j+OpdwvPwOFYFBOe2pD1O5eI+XLRpbqPY2euz6vemAddXGevRvJ5n8D83ilUCrtxP07RQ=="

ROOT = Path(__file__).resolve().parent.parent
ICON_FILE = ROOT / "Kit" / "IconPaths.js"
BEGIN, END = "// BEGIN ICONS", "// END ICONS"


# ---- the package ---------------------------------------------------------

def cache_path():
    base = os.environ.get("XDG_CACHE_HOME") or os.path.join(os.path.expanduser("~"), ".cache")
    return Path(base) / "quickshell-tests" / f"lucide-static-{VERSION}.tgz"


def verified(data):
    digest = "sha512-" + base64.b64encode(hashlib.sha512(data).digest()).decode()
    return digest == INTEGRITY


def load_package(path_arg):
    """Return (svg text by icon name, LICENSE text)."""
    if path_arg:
        data = Path(path_arg).read_bytes()
    else:
        cached = cache_path()
        data = cached.read_bytes() if cached.exists() else b""
        if not verified(data):
            req = urllib.request.Request(TARBALL, headers={"User-Agent": "icon-provenance-check"})
            with urllib.request.urlopen(req, timeout=60) as response:
                data = response.read()
            if verified(data):
                cached.parent.mkdir(parents=True, exist_ok=True)
                tmp = cached.with_suffix(".part")
                tmp.write_bytes(data)
                tmp.replace(cached)
    if not verified(data):
        raise SystemExit(f"FAIL lucide-static {VERSION}: tarball does not match {INTEGRITY}")
    svgs, license_text = {}, ""
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as tar:
        for member in tar:
            if not member.isfile():
                continue
            if member.name == "package/LICENSE":
                license_text = tar.extractfile(member).read().decode()
            m = re.fullmatch(r"package/icons/([a-z0-9-]+)\.svg", member.name)
            if m:
                svgs[m.group(1)] = tar.extractfile(member).read().decode()
    return svgs, license_text


# ---- path data: tokenise, then print one canonical way ---------------------

ARGS = {"M": 2, "L": 2, "H": 1, "V": 1, "C": 6, "S": 4, "Q": 4, "T": 2, "A": 7, "Z": 0}
NUMBER = re.compile(r"[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?")


def parse_d(d):
    """[(command, [numbers])], one tuple per segment, implicit repeats expanded.

    Arc flags may be packed without separators ("a1.5 1.5 0 00-2.4"), which
    Qt's PathSvg would misread, so flags are read as single characters.
    """
    out, i, cmd = [], 0, None
    while True:
        while i < len(d) and d[i] in " \t\r\n,":
            i += 1
        if i >= len(d):
            return out
        if d[i].isalpha():
            cmd = d[i]
            if cmd.upper() not in ARGS:
                raise ValueError(f"unsupported command {cmd!r} in {d!r}")
            i += 1
            if cmd.upper() == "Z":
                out.append((cmd, []))
                continue
        elif cmd is None or cmd.upper() == "Z":
            raise ValueError(f"number without a command at {i} in {d!r}")
        args = []
        for n in range(ARGS[cmd.upper()]):
            while i < len(d) and d[i] in " \t\r\n,":
                i += 1
            if cmd.upper() == "A" and n in (3, 4):
                if i >= len(d) or d[i] not in "01":
                    raise ValueError(f"bad arc flag at {i} in {d!r}")
                args.append(float(d[i]))
                i += 1
                continue
            m = NUMBER.match(d, i)
            if not m:
                raise ValueError(f"expected a number at {i} in {d!r}")
            args.append(float(m.group()))
            i = m.end()
        out.append((cmd, args))
        # a moveto's extra pairs are linetos
        if cmd == "M":
            cmd = "L"
        elif cmd == "m":
            cmd = "l"


def num(v):
    s = f"{v:.4f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def emit(segments):
    return "".join(cmd + " ".join(num(a) for a in args) for cmd, args in segments)


def canonical(d):
    """One element's path, printed so it can be appended to another's.

    A path that opens with a relative moveto starts from the origin, so that
    first "m" is absolute. Joined after another element it would be read from
    that element's end point instead, so it is written as "M".
    """
    segments = parse_d(d)
    if segments and segments[0][0] == "m":
        segments[0] = ("M", segments[0][1])
    return emit(segments)


def attr(el, name, default=None):
    value = el.get(name)
    if value is None:
        if default is None:
            raise ValueError(f"<{el.tag}> without {name}")
        return default
    return float(value)


def element_d(el):
    tag = el.tag.split("}")[-1]
    if el.get("transform"):
        raise ValueError(f"<{tag}> has a transform")
    if tag == "path":
        return canonical(el.get("d"))
    if tag in ("circle", "ellipse"):
        cx, cy = attr(el, "cx", 0.0), attr(el, "cy", 0.0)
        rx = attr(el, "r") if tag == "circle" else attr(el, "rx")
        ry = rx if tag == "circle" else attr(el, "ry")
        return emit([("M", [cx - rx, cy]), ("A", [rx, ry, 0, 1, 0, cx + rx, cy]),
                     ("A", [rx, ry, 0, 1, 0, cx - rx, cy]), ("Z", [])])
    if tag == "rect":
        x, y, w, h = attr(el, "x", 0.0), attr(el, "y", 0.0), attr(el, "width"), attr(el, "height")
        rx, ry = el.get("rx"), el.get("ry")
        rx = float(rx) if rx is not None else (float(ry) if ry is not None else 0.0)
        ry = float(ry) if ry is not None else rx
        rx, ry = min(rx, w / 2), min(ry, h / 2)
        if rx <= 0 or ry <= 0:
            return emit([("M", [x, y]), ("H", [x + w]), ("V", [y + h]), ("H", [x]), ("Z", [])])
        return emit([("M", [x + rx, y]), ("H", [x + w - rx]), ("A", [rx, ry, 0, 0, 1, x + w, y + ry]),
                     ("V", [y + h - ry]), ("A", [rx, ry, 0, 0, 1, x + w - rx, y + h]),
                     ("H", [x + rx]), ("A", [rx, ry, 0, 0, 1, x, y + h - ry]),
                     ("V", [y + ry]), ("A", [rx, ry, 0, 0, 1, x + rx, y]), ("Z", [])])
    if tag == "line":
        return emit([("M", [attr(el, "x1", 0.0), attr(el, "y1", 0.0)]),
                     ("L", [attr(el, "x2", 0.0), attr(el, "y2", 0.0)])])
    if tag in ("polyline", "polygon"):
        pts = [float(v) for v in NUMBER.findall(el.get("points"))]
        segs = [("M" if k == 0 else "L", pts[k:k + 2]) for k in range(0, len(pts), 2)]
        return emit(segs + ([("Z", [])] if tag == "polygon" else []))
    raise ValueError(f"unsupported element <{tag}>")


def lucide_d(svg_text):
    """All drawing elements of one Lucide SVG, in document order, as one path.

    Element fills (palette's dots carry fill="currentColor") are dropped: the
    shell strokes every outline icon, and a stroked r=.5 dot reads the same.
    """
    # The tarball is integrity-pinned, but a DTD has no place in an icon:
    # refuse one rather than let the parser near entity expansion.
    if re.search(r"<!(DOCTYPE|ENTITY)", svg_text, re.I):
        raise ValueError("SVG declares a DTD or entity")
    root = ET.fromstring(svg_text)
    parts = [element_d(el) for el in root.iter()
             if el.tag.split("}")[-1] in ("path", "circle", "ellipse", "rect", "line", "polyline", "polygon")]
    if not parts:
        raise ValueError("no drawing elements")
    return "".join(parts)


# ---- IconPaths.js ----------------------------------------------------------

def read_table(text):
    start, end = text.find(BEGIN), text.find(END)
    if start < 0 or end < start:
        raise SystemExit(f"FAIL {ICON_FILE}: no {BEGIN} ... {END} block")
    body = text[start + len(BEGIN):end].strip()
    body = re.sub(r"^var ICONS = ", "", body).rstrip().rstrip(";")
    return json.loads(body), start, end


def write_table(text, table, start, end):
    rows = [f'    {json.dumps(name)}: {json.dumps(entry, separators=(", ", ": "))}'
            for name, entry in table.items()]
    block = BEGIN + "\nvar ICONS = {\n" + ",\n".join(rows) + "\n};\n"
    return text[:start] + block + text[end:]


def feather_names(license_text):
    m = re.search(r"derived from the Feather project:\s*\n\s*\n(.+?)\n\s*\n", license_text, re.S)
    return {n.strip() for n in m.group(1).split(",")} if m else set()


def notice_lines(block):
    return [line.strip() for line in block.strip().splitlines() if line.strip()]


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--write", action="store_true", help="rewrite each entry's d from Lucide")
    ap.add_argument("--package", help="a local lucide-static tarball instead of the cache")
    ap.add_argument("--offline-ok", action="store_true", help="SKIP instead of FAIL without the package")
    opts = ap.parse_args()

    try:
        svgs, license_text = load_package(opts.package)
    except OSError as e:  # urllib errors are OSErrors
        if opts.offline_ok:
            print(f"ICON_PROVENANCE_SKIP lucide-static {VERSION} not cached and not downloadable: {e}")
            return 0
        raise SystemExit(f"FAIL cannot fetch lucide-static {VERSION}: {e}")

    text = ICON_FILE.read_text()
    table, start, end = read_table(text)
    failures, used_feather = [], []
    feather = feather_names(license_text)

    for name, entry in table.items():
        source = entry.get("lucide")
        if source is None:
            if not entry.get("origin"):
                failures.append(f"{name}: not Lucide and no origin given")
            try:
                parse_d(entry["d"])
            except ValueError as e:
                failures.append(f"{name}: {e}")
            continue
        if source not in svgs:
            failures.append(f"{name}: lucide-static {VERSION} has no icon {source!r}")
            continue
        want = lucide_d(svgs[source])
        if source in feather:
            used_feather.append(source)
        if opts.write:
            entry["d"] = want
        elif entry.get("d") != want:
            failures.append(f"{name}: differs from lucide {source!r}\n    have {entry.get('d')}\n    want {want}")

    # The notices travel with the paths.
    isc, _, rest = license_text.partition("---")
    for line in notice_lines(isc):
        if line not in text:
            failures.append(f"IconPaths.js lacks the ISC notice line: {line}")
    if used_feather:
        mit = rest[rest.find("The MIT License"):]
        for line in notice_lines(mit):
            if line not in text:
                failures.append(f"IconPaths.js lacks the Feather MIT line (used: {', '.join(sorted(set(used_feather)))}): {line}")
    if f"lucide-static {VERSION}" not in text:
        failures.append(f"IconPaths.js does not name lucide-static {VERSION}")

    if opts.write:
        ICON_FILE.write_text(write_table(text, table, start, end))
        print(f"wrote {len(table)} entries to {ICON_FILE}")
        failures = [f for f in failures if "differs" not in f]

    if failures:
        print("\n".join("FAIL " + f for f in failures))
        return 1
    lucide = sum(1 for e in table.values() if e.get("lucide"))
    print(f"ICON_PROVENANCE_PASS {lucide} Lucide {VERSION} icons match, "
          f"{len(table) - lucide} drawn locally, {len(set(used_feather))} Feather-derived")
    return 0


if __name__ == "__main__":
    sys.exit(main())
