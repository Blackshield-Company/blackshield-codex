#!/usr/bin/env python3
"""Normalize .pex headers so builds are reproducible and carry no machine info.

The PEX header stores the compile time, the user name and the machine name.
This rewrites them to fixed values (time from SOURCE_DATE_EPOCH, else 0).
Format reference: UESP "Skyrim Mod:Compiled Script File Format" (big-endian).
"""
import os
import struct
import sys

MAGIC = 0xFA57C0DE


def read_wstring(buf, off):
    (n,) = struct.unpack_from(">H", buf, off)
    return buf[off + 2 : off + 2 + n].decode("latin-1"), off + 2 + n


def wstring(s):
    b = s.encode("latin-1")
    return struct.pack(">H", len(b)) + b


def normalize(path, user="modkit", machine="build", stamp=0):
    data = open(path, "rb").read()
    (magic,) = struct.unpack_from(">I", data, 0)
    if magic != MAGIC:
        raise SystemExit(f"{path}: not a Skyrim PEX file")
    # magic(4) major(1) minor(1) game_id(2) compilation_time(8)
    head = bytearray(data[:16])
    struct.pack_into(">Q", head, 8, stamp)
    off = 16
    src, off = read_wstring(data, off)
    _user, off = read_wstring(data, off)
    _machine, off = read_wstring(data, off)
    out = bytes(head) + wstring(src) + wstring(user) + wstring(machine) + data[off:]
    open(path, "wb").write(out)


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    stamp = int(os.environ.get("SOURCE_DATE_EPOCH", "0"))
    for p in argv[1:]:
        normalize(p, stamp=stamp)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
