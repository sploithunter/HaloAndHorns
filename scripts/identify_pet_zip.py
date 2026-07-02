#!/usr/bin/env python3
"""Identify + dedupe + (optionally) onboard Meshy pet-rig zips — no renaming, safe to rerun.

Identification: the zip's texture_0.png is fingerprinted (perceptual hash) against the
ORIGINAL pet textures in assets/exports/pets/<pet_id>_basic/<pet_id>_basic.png. Decimation
only ever touched meshes, so a re-download of the same Meshy model carries a pixel-identical
texture: correct matches score ~0, wrong pets ~90+. Above MAX_DIST -> UNKNOWN, never guessed.

Robustness (scripts/pet_rig_manifest.json):
  - every processed zip is recorded by CONTENT hash (inner file names+CRCs, so "(1).zip"
    re-downloads and renamed copies dedupe) -> reruns over an uncleaned Downloads skip them
  - per-pet state records the uploaded rig asset -> a second different download of an
    already-rigged pet is flagged and skipped (rerun with --force to replace)
  - dry-run by default; --upload actually uploads rig FBXs via scripts/upload_models.js
    (group-owned) and records the asset ids

Usage:
  python3 scripts/identify_pet_zip.py <zip-or-dir> [...]            # plan only
  python3 scripts/identify_pet_zip.py --upload <zip-or-dir> [...]   # upload new rigs
"""

import glob
import hashlib
import io
import json
import os
import re
import subprocess
import sys
import tempfile
import zipfile

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "scripts", "pet_rig_manifest.json")
HASH_SIZE = 16
MAX_DIST = 20  # identical bakes score 0; anything near this is suspect


def ahash(img):
    img = img.convert("L").resize((HASH_SIZE, HASH_SIZE))
    px = list(img.getdata())
    avg = sum(px) / len(px)
    return "".join("1" if p > avg else "0" for p in px)


def dist(a, b):
    return sum(c1 != c2 for c1, c2 in zip(a, b))


def library():
    index = {}
    for folder in glob.glob(os.path.join(ROOT, "assets/exports/pets/*_basic")):
        pid = os.path.basename(folder)[: -len("_basic")]
        png = os.path.join(folder, os.path.basename(folder) + ".png")
        if os.path.exists(png):
            try:
                index[pid] = ahash(Image.open(png))
            except Exception:
                pass
    return index


def content_hash(z):
    # hash the zip's CONTENTS (inner basenames + CRCs + sizes), not the file: renamed
    # copies and re-downloads of the same export collapse to one identity
    parts = sorted(
        (os.path.basename(i.filename), i.CRC, i.file_size)
        for i in z.infolist()
        if not i.is_dir()
    )
    return hashlib.sha256(repr(parts).encode()).hexdigest()[:16]


def inspect(zpath, index):
    with zipfile.ZipFile(zpath) as z:
        chash = content_hash(z)
        names = z.namelist()
        rig_fbx = [n for n in names if n.endswith("Character_output.fbx")]
        anim_fbx = [n for n in names if n.lower().endswith(".fbx") and n not in rig_fbx]
        kind = "rig" if rig_fbx else ("clips" if anim_fbx else "other")
        skeleton = "?"
        for n in names:
            low = n.lower()
            if "quadruped" in low:
                skeleton = "quadruped"
                break
            if "biped" in low:
                skeleton = "biped"
                break
        pid, d = None, None
        tex = [n for n in names if re.search(r"texture_0\.png$", n)]
        if tex and index:
            h = ahash(Image.open(io.BytesIO(z.read(tex[0]))))
            best = sorted(index.items(), key=lambda kv: dist(h, kv[1]))
            pid, d = best[0][0], dist(h, best[0][1])
            if d > MAX_DIST:
                pid = None
    return {
        "hash": chash,
        "kind": kind,
        "skeleton": skeleton,
        "pet_id": pid,
        "dist": d,
        "rig_fbx": rig_fbx[0] if rig_fbx else None,
    }


def load_manifest():
    if os.path.exists(MANIFEST):
        with open(MANIFEST) as f:
            return json.load(f)
    return {"zips": {}, "pets": {}}


def save_manifest(m):
    with open(MANIFEST, "w") as f:
        json.dump(m, f, indent=2, sort_keys=True)
        f.write("\n")


def upload_rig(zpath, rig_member, pet_id):
    with zipfile.ZipFile(zpath) as z, tempfile.TemporaryDirectory() as tmp:
        fbx = os.path.join(tmp, pet_id + "_rig.fbx")
        with open(fbx, "wb") as f:
            f.write(z.read(rig_member))
        out = subprocess.run(
            ["node", os.path.join(ROOT, "scripts", "upload_models.js"), "--fbx", fbx, "--name", pet_id + "_rig"],
            capture_output=True,
            text=True,
            cwd=ROOT,
        )
        m = re.search(r"OK\s+\S+\s+->\s+(\d+)", out.stdout)
        if not m:
            raise RuntimeError(f"upload failed: {out.stdout[-200:]} {out.stderr[-200:]}")
        return m.group(1)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    do_upload = "--upload" in sys.argv
    force = "--force" in sys.argv

    index = library()
    manifest = load_manifest()
    print(f"library: {len(index)} pet textures; manifest: {len(manifest['zips'])} zips, "
          f"{len(manifest['pets'])} pets", file=sys.stderr)

    zips = []
    for arg in args:
        if os.path.isdir(arg):
            zips += sorted(glob.glob(os.path.join(arg, "*.zip")))
        else:
            zips.append(arg)

    for zpath in zips:
        name = os.path.basename(zpath)
        try:
            info = inspect(zpath, index)
        except Exception as e:
            print(f"{name} -> ERROR {e}")
            continue

        seen = manifest["zips"].get(info["hash"])
        if seen and not force:
            print(f"{name} -> SKIP duplicate of '{seen.get('first_seen')}' "
                  f"({seen.get('pet_id')}, {seen.get('kind')})")
            continue
        if info["kind"] == "other" or (info["pet_id"] is None and info["kind"] != "other"):
            label = "not a pet export" if info["kind"] == "other" else f"UNKNOWN pet (dist={info['dist']})"
            print(f"{name} -> {label} — skipped, not recorded")
            continue

        pet = manifest["pets"].get(info["pet_id"])
        if info["kind"] == "rig" and pet and pet.get("rig_asset") and not force:
            print(f"{name} -> {info['pet_id']} already rigged (asset {pet['rig_asset']}) — SKIP (--force to replace)")
            manifest["zips"][info["hash"]] = {"first_seen": name, **{k: info[k] for k in ("kind", "skeleton", "pet_id")}}
            continue

        line = f"{name} -> {info['pet_id']} (dist={info['dist']}, {info['skeleton']}, {info['kind']})"
        if info["kind"] == "rig" and do_upload:
            asset = upload_rig(zpath, info["rig_fbx"], info["pet_id"])
            manifest["pets"][info["pet_id"]] = {
                "rig_asset": asset,
                "skeleton": info["skeleton"],
                "prebaked": False,
            }
            line += f" -> uploaded rig {asset}"
        elif info["kind"] == "clips":
            line += " -> clip zip (feed to import_animation.sh)"
        else:
            line += " -> would upload (rerun with --upload)"
        manifest["zips"][info["hash"]] = {"first_seen": name, **{k: info[k] for k in ("kind", "skeleton", "pet_id")}}
        print(line)

    save_manifest(manifest)


if __name__ == "__main__":
    main()
