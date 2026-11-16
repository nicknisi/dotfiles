#!/usr/bin/env python3
"""Generated stand-ins for a profile picture (no photo of anyone).

    face-images.py DIR [--big]

DIR/face.png      96 x 64: a 32 px band of each of three colours, so a
                  centred crop to a circle shows only the middle one
DIR/face2.png     64 x 64, one colour (a second picture to switch to)
DIR/empty.png     0 bytes
DIR/text.png      a text file with an image's name
DIR/loop.png      a symlink to loop2.png, which links back (ELOOP)
DIR/big.png       8192 x 6144 (50.3 MP) with --big, about 0.3 s to write
Pure Python (zlib, struct): no PIL, no ImageMagick.
"""
import os
import struct
import sys
import zlib


def png(path, width, height, row_for):
    def chunk(kind, data):
        c = struct.pack(">I", len(data)) + kind + data
        return c + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    comp = zlib.compressobj(1)
    body = []
    last = None
    for y in range(height):
        row = row_for(y)
        if row is not last:
            line = b"\x00" + row
            last = row
        body.append(comp.compress(line))
    body.append(comp.flush())
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)))
        f.write(chunk(b"IDAT", b"".join(body)))
        f.write(chunk(b"IEND", b""))


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    bands = bytes([255, 0, 0]) * 32 + bytes([0, 200, 80]) * 32 + bytes([0, 0, 255]) * 32
    png(os.path.join(out, "face.png"), 96, 64, lambda y: bands)
    one = bytes([240, 180, 20]) * 64
    png(os.path.join(out, "face2.png"), 64, 64, lambda y: one)
    open(os.path.join(out, "empty.png"), "wb").close()
    with open(os.path.join(out, "text.png"), "w") as f:
        f.write("this is not an image\n")
    for a, b in (("loop.png", "loop2.png"), ("loop2.png", "loop.png")):
        p = os.path.join(out, a)
        if os.path.lexists(p):
            os.remove(p)
        os.symlink(b, p)
    if "--big" in sys.argv:
        w, h = 8192, 6144
        rows = [bytes([(x * 7 + k * 40) & 255 for x in range(256)] * 3)[: 768] * (w // 256) for k in range(4)]
        png(os.path.join(out, "big.png"), w, h, lambda y: rows[(y // 1536) % 4])


if __name__ == "__main__":
    main()
