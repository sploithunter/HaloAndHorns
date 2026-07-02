#!/usr/bin/env python3
"""Bake the shared homeworld bear face into basic Base1_diff for Blender renders.

Roblox homeworld bear OBJ exports put body color in Base1_diff and the expressive
face (blue eyes, brows, snout) in the gold atlas. Basic Base1 is body-only stripes,
so we composite the gold face sprite into a reserved UV island before rendering.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
HOMEWORLD = ROOT / "assets/source/pets/bear_homeworld"

# Shared face atlas region in gold Base1_diff (64×36) — top-right face sprite only.
FACE_UV = (0.20, 0.0, 1.0, 0.48)


def _uv_rect_to_pixels(size: tuple[int, int], uv: tuple[float, float, float, float]) -> tuple[int, int, int, int]:
    w, h = size
    u0, v0, u1, v1 = uv
    return (int(u0 * w), int(v0 * h), int(u1 * w), int(v1 * h))


def bake_basic_face(force: bool = False) -> Path:
    basic_dir = HOMEWORLD / "basic"
    gold_atlas = HOMEWORLD / "gold" / "Base1_diff.png"
    base_path = basic_dir / "Base1_diff.png"
    baked_path = basic_dir / "Base1_diff_baked.png"

    if not force and baked_path.is_file():
        stamps = [base_path.stat().st_mtime, gold_atlas.stat().st_mtime]
        if baked_path.stat().st_mtime >= max(stamps):
            return baked_path

    base = Image.open(base_path).convert("RGBA")
    gold = Image.open(gold_atlas).convert("RGBA")

    face_src = gold.crop(_uv_rect_to_pixels(gold.size, FACE_UV))
    dest_box = _uv_rect_to_pixels(base.size, FACE_UV)
    face = face_src.resize((dest_box[2] - dest_box[0], dest_box[3] - dest_box[1]), Image.LANCZOS)
    out = base.copy()
    out.paste(face, dest_box[:2], face)
    out.save(baked_path, format="PNG", optimize=True)
    print(f"Baked basic bear face -> {baked_path.relative_to(ROOT)}")
    return baked_path


def main() -> int:
    if not HOMEWORLD.is_dir():
        print(f"Missing {HOMEWORLD}")
        return 1
    bake_basic_face(force=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
