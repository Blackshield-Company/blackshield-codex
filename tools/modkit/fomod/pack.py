#!/usr/bin/env python3
"""Package a mod as a FOMOD installer archive for Mod Organizer 2 and Vortex.

  pack.py --fomod <dir with info.xml + ModuleConfig.xml> --stage <staging dir>
          --version 0.1.0 --out dist/MyMod-0.1.0.zip

* "@VERSION@" in info.xml / ModuleConfig.xml is replaced with --version.
* ModuleConfig.xml is validated against the FOMOD schema (schema/ModuleConfig.xsd)
  with xmllint, and every <file>/<folder> source must exist in the staging dir.
* The zip is reproducible: sorted entries, fixed timestamps (SOURCE_DATE_EPOCH).
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import time
import xml.etree.ElementTree as ET
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
SCHEMA = os.path.join(HERE, "schema", "ModuleConfig.xsd")


def render(src, dst, version):
    text = open(src, encoding="utf-8").read().replace("@VERSION@", version)
    with open(dst, "w", encoding="utf-8", newline="\r\n") as f:
        f.write(text)


def validate(fomod_dir, stage):
    errors = []
    mc = os.path.join(fomod_dir, "ModuleConfig.xml")
    ET.parse(os.path.join(fomod_dir, "info.xml"))  # well-formed check
    if shutil.which("xmllint"):
        r = subprocess.run(["xmllint", "--noout", "--schema", SCHEMA, mc], capture_output=True, text=True)
        if r.returncode != 0:
            errors.append("schema: " + r.stderr.strip())
        else:
            print("[fomod] ModuleConfig.xml validates against the FOMOD schema")
    else:
        print("[fomod] WARN xmllint not found, schema validation skipped")
    root = ET.parse(mc).getroot()
    for el in root.iter():
        if el.tag in ("file", "folder") and "source" in el.attrib:
            src = el.attrib["source"].replace("\\", "/")
            path = os.path.join(stage, src)
            if el.tag == "file" and not os.path.isfile(path):
                errors.append(f"missing file: {src}")
            if el.tag == "folder" and not os.path.isdir(path):
                errors.append(f"missing folder: {src}")
            if el.tag == "folder" and os.path.isdir(path) and not any(os.scandir(path)):
                errors.append(f"empty folder: {src}")
    return errors


def zip_dir(root, out):
    stamp = int(os.environ.get("SOURCE_DATE_EPOCH", "315532800"))  # 1980-01-01
    dt = time.gmtime(max(stamp, 315532800))[:6]
    entries = []
    for base, dirs, files in os.walk(root):
        dirs.sort()
        for name in sorted(files):
            full = os.path.join(base, name)
            entries.append((os.path.relpath(full, root).replace(os.sep, "/"), full))
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for arc, full in sorted(entries):
            info = zipfile.ZipInfo(arc, date_time=dt)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            with open(full, "rb") as f:
                z.writestr(info, f.read())
    return len(entries)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--fomod", required=True)
    ap.add_argument("--stage", required=True)
    ap.add_argument("--version", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()

    with tempfile.TemporaryDirectory() as tmp:
        root = os.path.join(tmp, "pkg")
        shutil.copytree(a.stage, root)
        fdir = os.path.join(root, "fomod")
        os.makedirs(fdir, exist_ok=True)
        for name in ("info.xml", "ModuleConfig.xml"):
            render(os.path.join(a.fomod, name), os.path.join(fdir, name), a.version)
        for extra in os.listdir(a.fomod):
            if extra not in ("info.xml", "ModuleConfig.xml"):
                src = os.path.join(a.fomod, extra)
                (shutil.copytree if os.path.isdir(src) else shutil.copy2)(src, os.path.join(fdir, extra))
        errors = validate(fdir, root)
        if errors:
            for e in errors:
                print(f"[fomod] ERROR {e}", file=sys.stderr)
            return 1
        n = zip_dir(root, a.out)
    print(f"[fomod] wrote {a.out} ({n} files, {os.path.getsize(a.out)} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
