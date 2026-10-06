#!/usr/bin/env python3
"""Independent structural check of a Skyrim SE plugin (no Mutagen involved).

Walks the TES4 header and every GRUP/record, verifies that all sizes add up
exactly to the file length, and reports the ESL flag, masters, record counts by
type and the FormID range of new records.  Usage: esp_check.py Plugin.esp
"""
import collections
import struct
import sys
import zlib


def subrecords(data):
    i = 0
    while i < len(data):
        typ, size = struct.unpack_from("<4sH", data, i)
        yield typ.decode(), data[i + 6 : i + 6 + size]
        i += 6 + size


def main(path):
    buf = open(path, "rb").read()
    typ, size, flags, formid = struct.unpack_from("<4sIII", buf, 0)
    assert typ == b"TES4", "not a TES4 plugin"
    header = buf[24 : 24 + size]
    masters = [d[:-1].decode() for t, d in subrecords(header) if t == "MAST"]
    hedr = next(d for t, d in subrecords(header) if t == "HEDR")
    version, num_records, next_id = struct.unpack("<fiI", hedr)
    esl = bool(flags & 0x200)
    counts = collections.Counter()
    ids = []
    total = 0
    groups = 0

    def walk(off, end, depth):
        nonlocal total, groups
        while off < end:
            t = buf[off : off + 4]
            if t == b"GRUP":
                gsize = struct.unpack_from("<I", buf, off + 4)[0]
                if gsize < 24 or off + gsize > end:
                    raise SystemExit(f"bad GRUP size at {off:#x}")
                groups += 1
                walk(off + 24, off + gsize, depth + 1)
                off += gsize
            else:
                rtype, dsize, rflags, rid = struct.unpack_from("<4sIII", buf, off)
                data = buf[off + 24 : off + 24 + dsize]
                if off + 24 + dsize > end:
                    raise SystemExit(f"record overruns its group at {off:#x}")
                if rflags & 0x40000:
                    data = zlib.decompress(data[4:])
                for _ in subrecords(data):
                    pass  # raises on malformed subrecords
                counts[rtype.decode()] += 1
                total += 1
                if (rid >> 24) == len(masters):
                    ids.append(rid & 0xFFFFFF)
                off += 24 + dsize
        if off != end:
            raise SystemExit("size mismatch while walking groups")

    walk(24 + size, len(buf), 0)
    version = round(version, 2)
    print(f"[esp_check] {path}: header v{version:.2f}, ESL={esl}, masters={masters}")
    print(f"[esp_check] {total} records + {groups} groups (HEDR says {num_records}), new FormIDs {min(ids):03X}-{max(ids):03X}, next {next_id:03X}")
    print("[esp_check] " + ", ".join(f"{k}:{v}" for k, v in sorted(counts.items())))
    ok = total + groups == num_records and version in (1.7, 1.71) and (not esl or (min(ids) >= 0x800 and max(ids) <= 0xFFF and len(ids) <= 2048))
    print("[esp_check] OK" if ok else "[esp_check] FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
