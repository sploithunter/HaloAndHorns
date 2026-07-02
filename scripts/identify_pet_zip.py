#!/usr/bin/env python3
"""Identify which game pet a Meshy download zip belongs to — no renaming needed.

The zip's texture_0.png is fingerprinted (perceptual hash) against the ORIGINAL pet
textures in assets/exports/pets/<pet_id>_basic/<pet_id>_basic.png. Decimation only ever
touched meshes, so a re-download of the same Meshy model carries a pixel-identical
texture: correct matches score ~0, wrong pets score ~90+. Anything above MAX_DIST is
reported as unknown rather than guessed.

Usage: python3 scripts/identify_pet_zip.py <zip-or-dir> [...more]
Prints one line per zip: <zip-name> -> <pet_id> (dist=N, skeleton=<biped|quadruped|?>)
"""

import glob
import io
import os
import re
import sys
import zipfile

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
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


def identify(zpath, index):
    with zipfile.ZipFile(zpath) as z:
        # the base color map: *_texture_0.png (skip normal/metallic/roughness)
        tex = [n for n in z.namelist() if re.search(r"texture_0\.png$", n)]
        skeleton = "?"
        for n in z.namelist():
            low = n.lower()
            if "quadruped" in low:
                skeleton = "quadruped"
                break
            if "biped" in low:
                skeleton = "biped"
                break
        if not tex:
            return None, None, skeleton
        h = ahash(Image.open(io.BytesIO(z.read(tex[0]))))
    best = sorted(index.items(), key=lambda kv: dist(h, kv[1]))
    pid, ph = best[0]
    return pid, dist(h, ph), skeleton


def main():
    index = library()
    print(f"library: {len(index)} pet textures", file=sys.stderr)
    zips = []
    for arg in sys.argv[1:]:
        if os.path.isdir(arg):
            zips += sorted(glob.glob(os.path.join(arg, "*.zip")))
        else:
            zips.append(arg)
    for zpath in zips:
        try:
            pid, d, skel = identify(zpath, index)
        except Exception as e:
            print(f"{os.path.basename(zpath)} -> ERROR {e}")
            continue
        if pid is None:
            print(f"{os.path.basename(zpath)} -> no texture_0 in zip (skeleton={skel})")
        elif d <= MAX_DIST:
            print(f"{os.path.basename(zpath)} -> {pid} (dist={d}, skeleton={skel})")
        else:
            print(f"{os.path.basename(zpath)} -> UNKNOWN (best {pid} dist={d}, skeleton={skel})")


if __name__ == "__main__":
    main()
