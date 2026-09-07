#!/usr/bin/env python3
"""Counts painted and yellow pixels in a rendered PNG.

grabToImage() does not deliver in an offscreen/software Qt, so the check that
matters - did anything actually get drawn - cannot be made from inside QML here.
The renderer already saves a PNG, so it is decoded from outside instead. Pure
zlib + struct: no image library to install.
"""
import sys, zlib, struct

def decode(path):
    d = open(path, "rb").read()
    assert d[:8] == b"\x89PNG\r\n\x1a\n", "not a PNG"
    pos, idat, w = 8, b"", None
    while pos < len(d):
        ln, typ = struct.unpack(">I4s", d[pos:pos+8])
        body = d[pos+8:pos+8+ln]
        if typ == b"IHDR":
            w, h, depth, color = struct.unpack(">IIBB", body[:10])
            assert depth == 8 and color in (2, 6), f"unsupported format: depth={depth} color={color}"
            nch = 3 if color == 2 else 4
        elif typ == b"IDAT":
            idat += body
        elif typ == b"IEND":
            break
        pos += 12 + ln
    raw = zlib.decompress(idat)
    stride = w * nch
    out, prev = [], bytearray(stride)
    p = 0
    for _ in range(h):
        f = raw[p]; p += 1
        line = bytearray(raw[p:p+stride]); p += stride
        for i in range(stride):
            a = line[i-nch] if i >= nch else 0
            b = prev[i]
            c = prev[i-nch] if i >= nch else 0
            if f == 1: line[i] = (line[i] + a) & 255
            elif f == 2: line[i] = (line[i] + b) & 255
            elif f == 3: line[i] = (line[i] + (a+b)//2) & 255
            elif f == 4:
                pa, pb, pc = abs(b-c), abs(a-c), abs(a+b-2*c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        out.append(bytes(line)); prev = line
    return w, h, nch, out

w, h, nch, rows = decode(sys.argv[1])
painted = yellow = 0
for row in rows:
    for x in range(w):
        r, g, b = row[x*nch], row[x*nch+1], row[x*nch+2]
        if r + g + b > 30: painted += 1
        if r > 180 and g > 140 and b < 120: yellow += 1
total = w * h
print(f"   {w}x{h}: painted={painted} ({painted*100//total}%)  yellow={yellow}")
# The yellow check only applies to Pac-Man renders; looking for it anywhere
# else reports a failure that means nothing.
checks = [("something was drawn", painted > 0)]
if len(sys.argv) > 2 and sys.argv[2] == "--pacman":
    checks.append(("Pac-Man is visible", yellow > 20))
ok = True
for label, cond in checks:
    print(("PASS " if cond else "FAIL ") + label + " = " + str(cond))
    ok = ok and cond
sys.exit(0 if ok else 1)
