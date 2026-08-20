#!/usr/bin/env python3
"""Rebake hoverboard recolor albedos onto one shared UV layout.

Meshy kept the same silhouette when retexturing, but issued a fresh unwrap
for every colorway. The game uses one uploaded mesh, so only the albedo that
matches that unwrap reads correctly. This transfers each source atlas onto
the destination (shared) UVs by rasterizing dest triangles and sampling the
source texture at the corresponding source UVs.

Same-position skins (black/blue/green/orange) use 1:1 vertex indices.
white_red has a few extra verts and uses nearest-position matching.
"""

from __future__ import annotations

import argparse
import io
import json
import struct
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/source/hoverboards"
EXPORT = ROOT / "assets/exports/hoverboards"
SKINS = ("black_gold", "blue_gold", "green_white", "orange_black", "white_red")


def read_glb(path: Path) -> tuple[dict, bytes]:
    data = path.read_bytes()
    json_len = struct.unpack_from("<I", data, 12)[0]
    json_start = 20
    chunk = json.loads(data[json_start : json_start + json_len])
    bin_start = json_start + json_len
    bin_len = struct.unpack_from("<I", data, bin_start)[0]
    blob = data[bin_start + 8 : bin_start + 8 + bin_len]
    return chunk, blob


def accessor(gltf: dict, blob: bytes, acc_idx: int) -> np.ndarray:
    acc = gltf["accessors"][acc_idx]
    view = gltf["bufferViews"][acc["bufferView"]]
    off = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    ncomp = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[acc["type"]]
    ctype = acc["componentType"]
    dtype = {5121: np.uint8, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}[ctype]
    count = acc["count"]
    raw = np.frombuffer(blob, dtype=dtype, count=count * ncomp, offset=off)
    if ncomp == 1:
        return raw.copy()
    return raw.reshape(count, ncomp).copy()


def load_mesh(path: Path) -> dict:
    gltf, blob = read_glb(path)
    prim = gltf["meshes"][0]["primitives"][0]
    attrs = prim["attributes"]
    mesh = {
        "pos": accessor(gltf, blob, attrs["POSITION"]).astype(np.float64),
        "uv": accessor(gltf, blob, attrs["TEXCOORD_0"]).astype(np.float64),
        "idx": accessor(gltf, blob, prim["indices"]).astype(np.int32),
    }
    image_view = gltf["images"][0]["bufferView"]
    view = gltf["bufferViews"][image_view]
    start = view.get("byteOffset", 0)
    albedo = Image.open(io.BytesIO(blob[start : start + view["byteLength"]]))
    mesh["albedo"] = albedo.convert("RGBA")
    return mesh


def nearest_index(points: np.ndarray, query: np.ndarray) -> np.ndarray:
    # Modest vertex count (~3.5k); brute force is fine and keeps this script
    # free of extra deps.
    d2 = ((points[None, :, :] - query[:, None, :]) ** 2).sum(axis=2)
    return d2.argmin(axis=1)


def sample_rgba(pixels: np.ndarray, uv: np.ndarray, flip_v: bool = False) -> np.ndarray:
    h, w = pixels.shape[:2]
    u = np.clip(uv[0], 0, 1) * (w - 1)
    v_unit = np.clip(uv[1], 0, 1)
    v = ((1.0 - v_unit) if flip_v else v_unit) * (h - 1)
    x0 = int(np.floor(u))
    y0 = int(np.floor(v))
    x1 = min(x0 + 1, w - 1)
    y1 = min(y0 + 1, h - 1)
    tx = u - x0
    ty = v - y0
    c00 = pixels[y0, x0].astype(np.float32)
    c10 = pixels[y0, x1].astype(np.float32)
    c01 = pixels[y1, x0].astype(np.float32)
    c11 = pixels[y1, x1].astype(np.float32)
    return (c00 * (1 - tx) * (1 - ty) + c10 * tx * (1 - ty) + c01 * (1 - tx) * ty + c11 * tx * ty)


def rasterize(
    dest: dict,
    src: dict,
    size: int,
    src_map: np.ndarray,
    *,
    flip_dest_v: bool = False,
    flip_src_v: bool = False,
) -> Image.Image:
    src_px = np.asarray(src["albedo"].convert("RGBA"), dtype=np.uint8)
    acc = np.zeros((size, size, 4), dtype=np.float64)
    weight = np.zeros((size, size), dtype=np.float64)
    dest_uv = dest["uv"]
    src_uv = src["uv"]
    idx = dest["idx"]
    for t in range(0, len(idx), 3):
        di = idx[t : t + 3]
        si = src_map[di]
        duv = dest_uv[di]
        suv = src_uv[si]
        px = duv[:, 0] * (size - 1)
        dest_v = (1.0 - duv[:, 1]) if flip_dest_v else duv[:, 1]
        py = dest_v * (size - 1)
        minx = max(int(np.floor(px.min())), 0)
        maxx = min(int(np.ceil(px.max())), size - 1)
        miny = max(int(np.floor(py.min())), 0)
        maxy = min(int(np.ceil(py.max())), size - 1)
        if maxx < minx or maxy < miny:
            continue
        a = np.array([px[0], py[0]], dtype=np.float64)
        b = np.array([px[1], py[1]], dtype=np.float64)
        c = np.array([px[2], py[2]], dtype=np.float64)
        v0 = b - a
        v1 = c - a
        denom = v0[0] * v1[1] - v0[1] * v1[0]
        if abs(denom) < 1e-8:
            continue
        ys, xs = np.mgrid[miny : maxy + 1, minx : maxx + 1]
        v2x = xs.astype(np.float64) + 0.5 - a[0]
        v2y = ys.astype(np.float64) + 0.5 - a[1]
        v = (v2x * v1[1] - v2y * v1[0]) / denom
        w = (v0[0] * v2y - v0[1] * v2x) / denom
        u = 1.0 - v - w
        inside = (u >= -0.01) & (v >= -0.01) & (w >= -0.01)
        if not inside.any():
            continue
        src_u = suv[0, 0] * u + suv[1, 0] * v + suv[2, 0] * w
        src_v = suv[0, 1] * u + suv[1, 1] * v + suv[2, 1] * w
        for y, x, su, sv in zip(ys[inside], xs[inside], src_u[inside], src_v[inside]):
            acc[y, x] += sample_rgba(src_px, np.array([su, sv], dtype=np.float64), flip_src_v)
            weight[y, x] += 1.0
    out = np.zeros((size, size, 4), dtype=np.uint8)
    covered = weight > 0
    out[covered] = np.clip(acc[covered] / weight[covered, None], 0, 255).astype(np.uint8)
    # Dilate islands so UV seams do not sample empty texels.
    for _ in range(3):
        missing = weight == 0
        if not missing.any():
            break
        padded = np.pad(out, ((1, 1), (1, 1), (0, 0)), mode="edge")
        padded_w = np.pad(weight, 1, mode="constant")
        for y, x in np.argwhere(missing):
            block = padded[y : y + 3, x : x + 3]
            mask = padded_w[y : y + 3, x : x + 3] > 0
            if mask.any():
                out[y, x] = block[mask].mean(axis=0)
                weight[y, x] = 1.0
    return Image.fromarray(out)


def load_live_dump(vert_paths: list[Path], face_path: Path) -> dict:
    rows = []
    for path in vert_paths:
        for line in path.read_text().splitlines():
            parts = line.strip().split()
            if len(parts) == 5:
                rows.append([float(x) for x in parts])
    verts = np.array(rows, dtype=np.float64)
    faces = []
    for line in face_path.read_text().splitlines():
        parts = line.strip().split()
        if len(parts) == 3:
            faces.extend(int(x) - 1 for x in parts)
    return {"pos": verts[:, :3], "uv": verts[:, 3:5], "idx": np.array(faces, dtype=np.int32)}


def align_source(src_pos: np.ndarray, dest_pos: np.ndarray) -> np.ndarray:
    """Try axis permutations/flips, then return transformed source points."""
    dest_c = dest_pos.mean(axis=0)
    dest_s = dest_pos - dest_c
    dest_scale = np.linalg.norm(dest_s, axis=1).max() or 1.0
    dest_n = dest_s / dest_scale
    best = None
    for perm in ((0, 1, 2), (0, 2, 1), (1, 0, 2), (1, 2, 0), (2, 0, 1), (2, 1, 0)):
        for signs in (
            (1, 1, 1),
            (1, 1, -1),
            (1, -1, 1),
            (-1, 1, 1),
            (1, -1, -1),
            (-1, 1, -1),
            (-1, -1, 1),
            (-1, -1, -1),
        ):
            cand = src_pos[:, list(perm)] * np.array(signs, dtype=np.float64)
            cand = cand - cand.mean(axis=0)
            scale = np.linalg.norm(cand, axis=1).max() or 1.0
            cand_n = cand / scale
            mapped = nearest_index(cand_n, dest_n[: min(400, len(dest_n))])
            err = np.linalg.norm(dest_n[: min(400, len(dest_n))] - cand_n[mapped], axis=1).mean()
            if best is None or err < best[0]:
                best = (err, perm, signs, scale)
    perm, signs, scale = best[1], best[2], best[3]
    print(f"  align err={best[0]:.5f} perm={perm} signs={signs}")
    aligned = src_pos[:, list(perm)] * np.array(signs, dtype=np.float64)
    aligned = (aligned - aligned.mean(axis=0)) / scale * dest_scale + dest_c
    return aligned


def bake_one(
    dest: dict,
    src_name: str,
    size: int,
    *,
    flip_dest_v: bool = False,
    flip_src_v: bool = False,
    align: bool = False,
) -> Image.Image:
    src = load_mesh(SOURCE / f"{src_name}.glb")
    src_pos = align_source(src["pos"], dest["pos"]) if align else src["pos"]
    if src_pos.shape[0] == dest["pos"].shape[0] and np.allclose(src_pos, dest["pos"], atol=1e-5):
        src_map = np.arange(dest["pos"].shape[0], dtype=np.int32)
    else:
        src_map = nearest_index(src_pos, dest["pos"]).astype(np.int32)
        nn = np.linalg.norm(dest["pos"] - src_pos[src_map], axis=1)
        print(f"  nearest mean={nn.mean():.5f} p95={np.quantile(nn, 0.95):.5f}")
    return rasterize(
        dest,
        src,
        size,
        src_map,
        flip_dest_v=flip_dest_v,
        flip_src_v=flip_src_v,
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dest", default="blue_gold", choices=SKINS, help="Shared UV source")
    parser.add_argument(
        "--skins",
        default="orange_black,green_white,white_red",
        help="Comma-separated skins to rebake onto --dest UVs",
    )
    parser.add_argument("--size", type=int, default=1024)
    parser.add_argument("--live-verts", nargs="*", default=None)
    parser.add_argument("--live-faces", default=None)
    parser.add_argument("--flip-dest-v", action="store_true")
    parser.add_argument("--flip-src-v", action="store_true")
    args = parser.parse_args()
    if args.live_verts and args.live_faces:
        dest = load_live_dump([Path(p) for p in args.live_verts], Path(args.live_faces))
        dest_name = "live_mesh"
        align = True
    else:
        dest = load_mesh(SOURCE / f"{args.dest}.glb")
        dest_name = args.dest
        align = False
    skins = [s.strip() for s in args.skins.split(",") if s.strip()]
    for name in skins:
        print(f"baking {name} -> {dest_name} UVs")
        image = bake_one(
            dest,
            name,
            args.size,
            flip_dest_v=args.flip_dest_v,
            flip_src_v=args.flip_src_v,
            align=align,
        )
        out_dir = EXPORT / name
        out_dir.mkdir(parents=True, exist_ok=True)
        original = out_dir / f"{name}.png"
        backup = out_dir / f"{name}_meshy_uv.png"
        if original.exists() and not backup.exists():
            original.replace(backup)
            print(f"  kept Meshy atlas as {backup.name}")
        dest_path = out_dir / f"{name}.png"
        image.save(dest_path, optimize=True)
        print(f"  wrote {dest_path}")


if __name__ == "__main__":
    main()
