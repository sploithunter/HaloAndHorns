#!/usr/bin/env python3
"""Normalize Roblox Studio viewport captures to match Blender model_renders PNGs.

Same contract as render_pet_previews.crop_png:
  - transparent background (optional blue viewport key)
  - largest opaque blob only (drops cursor specks)
  - tight alpha crop + 8px padding + centered square canvas
  - native cropped size (no forced 1024 upscale)
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from collections import deque
from dataclasses import dataclass
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MODEL_RENDERS = ROOT / "assets/exports/pets/model_renders"
CURSOR_ASSETS = Path.home() / ".cursor/projects/Users-jason-Documents-RBX-Template/assets"

DEFAULT_PADDING = 8

# (pet_id, variant) -> Studio screenshot
HOMEWORLD_CAPTURES: dict[tuple[str, str], Path] = {
    ("bear", "basic"): CURSOR_ASSETS / "image-7d922ed3-1ae7-4699-8e5c-819499ac2e15.png",
    ("bear", "gold"): CURSOR_ASSETS / "Screenshot_2026-06-28_at_2.52.13_PM-d3c3630d-f940-4f4d-acbd-b3eba170c78d.png",
    ("bunny", "basic"): CURSOR_ASSETS / "Screenshot_2026-06-28_at_2.38.44_PM-419e8419-314b-4875-9722-85c6fcb8024d.png",
    ("bunny", "gold"): CURSOR_ASSETS / "Screenshot_2026-06-28_at_2.53.03_PM-e8331b41-b496-4fdd-bf8d-40298429a9a2.png",
    ("doggy", "basic"): CURSOR_ASSETS / "Screenshot_2026-06-28_at_2.40.17_PM-11ae96d4-c366-4617-8c11-56b02c8dfd15.png",
    ("doggy", "gold"): CURSOR_ASSETS / "Screenshot_2026-06-28_at_2.52.38_PM-ebf46c9c-1711-4aff-9421-6d84a0230cfa.png",
    ("dragon", "basic"): CURSOR_ASSETS / "Screenshot_2026-06-28_at_2.40.51_PM-e75b9afe-de27-4d22-83b5-9574c682abe1.png",
    ("dragon", "gold"): CURSOR_ASSETS / "Screenshot_2026-06-28_at_2.53.36_PM-09bcf4c3-1322-40ea-ae41-6e51385a095a.png",
    ("kitty", "basic"): CURSOR_ASSETS / "Screenshot_2026-06-28_at_2.54.25_PM-d904c088-302a-4b6c-99a8-b6218a7c13b5.png",
    ("kitty", "gold"): CURSOR_ASSETS / "Screenshot_2026-06-28_at_2.54.02_PM-feff928a-d6ff-49c7-bce9-45e72ed5247b.png",
}


@dataclass(frozen=True)
class CaptureJob:
    pet_id: str
    variant: str


def is_viewport_blue(r: int, g: int, b: int, a: int) -> bool:
    if a < 20:
        return True
    if b > 140 and b > r + 35 and b > g + 15:
        return True
    if b > 100 and g < 120 and r < 100 and b >= max(r, g) + 30:
        return True
    return False


def key_viewport_blue(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    px = rgba.load()
    width, height = rgba.size
    for y in range(height):
        for x in range(width):
            r, g, b, a = px[x, y]
            if is_viewport_blue(r, g, b, a):
                px[x, y] = (0, 0, 0, 0)
    return rgba


def keep_largest_blob(image: Image.Image, *, alpha_min: int = 32) -> Image.Image:
    rgba = image.convert("RGBA")
    width, height = rgba.size
    alpha = rgba.getchannel("A")
    opaque = [[alpha.getpixel((x, y)) >= alpha_min for x in range(width)] for y in range(height)]
    visited = [[False] * width for _ in range(height)]
    best: list[tuple[int, int]] = []

    for y in range(height):
        for x in range(width):
            if not opaque[y][x] or visited[y][x]:
                continue
            component: list[tuple[int, int]] = []
            queue: deque[tuple[int, int]] = deque([(x, y)])
            visited[y][x] = True
            while queue:
                cx, cy = queue.popleft()
                component.append((cx, cy))
                for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                    nx, ny = cx + dx, cy + dy
                    if 0 <= nx < width and 0 <= ny < height and opaque[ny][nx] and not visited[ny][nx]:
                        visited[ny][nx] = True
                        queue.append((nx, ny))
            if len(component) > len(best):
                best = component

    if not best:
        return rgba

    cleaned = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    src = rgba.load()
    dst = cleaned.load()
    for x, y in best:
        dst[x, y] = src[x, y]
    return cleaned


def normalize_viewport_png(image: Image.Image, padding: int = DEFAULT_PADDING) -> Image.Image:
    """Match render_pet_previews.crop_png framing."""
    rgba = image.convert("RGBA")
    bbox = rgba.getchannel("A").getbbox()
    if not bbox:
        raise ValueError("image has no opaque pixels")

    cropped = rgba.crop(bbox)
    if padding > 0:
        canvas = Image.new(
            "RGBA",
            (cropped.width + padding * 2, cropped.height + padding * 2),
            (0, 0, 0, 0),
        )
        canvas.paste(cropped, (padding, padding), cropped)
        cropped = canvas

    side = max(cropped.width, cropped.height)
    if cropped.width != cropped.height:
        square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        square.paste(
            cropped,
            ((side - cropped.width) // 2, (side - cropped.height) // 2),
            cropped,
        )
        cropped = square
    return cropped


def load_capture(path: Path, *, key_blue: bool) -> Image.Image:
    image = Image.open(path)
    if key_blue:
        image = key_viewport_blue(image)
    return keep_largest_blob(image)


def write_pet_renders(job: CaptureJob, image: Image.Image) -> list[Path]:
    stem = f"{job.pet_id}_{job.variant}"
    normalized = normalize_viewport_png(image)
    written: list[Path] = []
    for view in ("front", "hero"):
        out = MODEL_RENDERS / view / job.variant / f"{stem}.png"
        out.parent.mkdir(parents=True, exist_ok=True)
        normalized.save(out, format="PNG", optimize=True, compress_level=9)
        written.append(out)
    return written


def rebuild_pet_review_sheet(pet_id: str) -> Path | None:
    review_dir = MODEL_RENDERS / f"{pet_id}_homeworld_review"
    review_dir.mkdir(parents=True, exist_ok=True)

    copied = 0
    for variant in ("basic", "gold"):
        src = MODEL_RENDERS / "front" / variant / f"{pet_id}_{variant}.png"
        if not src.is_file():
            continue
        image = Image.open(src)
        for suffix in ("front", "hero"):
            image.save(review_dir / f"{pet_id}_{variant}_{suffix}.png", format="PNG", optimize=True, compress_level=9)
        copied += 1

    if copied == 0:
        return None

    sheet = review_dir / "contact_sheet.png"
    subprocess.run(
        [
            sys.executable,
            str(ROOT / "scripts/build_icon_contact_sheet.py"),
            "--rebuild-from",
            str(review_dir),
            "--contact-sheet",
            str(sheet),
            "--columns",
            "2",
            "--thumb-size",
            "512",
        ],
        check=True,
        cwd=ROOT,
    )
    return sheet


def parse_capture_spec(raw: str) -> CaptureJob:
    if ":" in raw:
        pet_id, variant = raw.split(":", 1)
    elif raw.endswith("_basic") or raw.endswith("_gold"):
        pet_id, variant = raw.rsplit("_", 1)
    else:
        pet_id, variant = raw, "basic"
    return CaptureJob(pet_id=pet_id, variant=variant)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Normalize Studio pet viewport captures.")
    parser.add_argument(
        "--capture",
        action="append",
        help="Pet capture as pet_id:variant (e.g. kitty:basic, bear:gold). Default: all known.",
    )
    parser.add_argument(
        "--from-rendered",
        action="store_true",
        help="Re-normalize existing model_renders PNGs in place (skip source screenshots)",
    )
    parser.add_argument(
        "--no-key-blue",
        action="store_true",
        help="Skip viewport blue key (input already has transparency)",
    )
    parser.add_argument("--padding", type=int, default=DEFAULT_PADDING)
    return parser.parse_args()


def normalize_existing(path: Path, padding: int) -> None:
    image = keep_largest_blob(Image.open(path))
    normalized = normalize_viewport_png(image, padding=padding)
    normalized.save(path, format="PNG", optimize=True, compress_level=9)


def default_jobs() -> list[CaptureJob]:
    return [CaptureJob(pet_id=pet, variant=variant) for (pet, variant) in sorted(HOMEWORLD_CAPTURES)]


def main() -> int:
    args = parse_args()
    jobs = [parse_capture_spec(raw) for raw in args.capture] if args.capture else default_jobs()
    padding = args.padding
    touched_pets: set[str] = set()

    if args.from_rendered:
        for job in jobs:
            touched_pets.add(job.pet_id)
            for view in ("front", "hero"):
                path = MODEL_RENDERS / view / job.variant / f"{job.pet_id}_{job.variant}.png"
                if not path.is_file():
                    print(f"Skip missing {path.relative_to(ROOT)}", file=sys.stderr)
                    continue
                normalize_existing(path, padding)
                print(f"Normalized {path.relative_to(ROOT)} -> {Image.open(path).size}")
    else:
        for job in jobs:
            source = HOMEWORLD_CAPTURES.get((job.pet_id, job.variant))
            if source is None or not source.is_file():
                print(f"Missing capture for {job.pet_id}:{job.variant}: {source}", file=sys.stderr)
                return 1
            capture = load_capture(source, key_blue=not args.no_key_blue)
            outputs = write_pet_renders(job, capture)
            touched_pets.add(job.pet_id)
            for path in outputs:
                size = Image.open(path).size
                print(f"Wrote {path.relative_to(ROOT)} ({size[0]}×{size[1]})")

    for pet_id in sorted(touched_pets):
        sheet = rebuild_pet_review_sheet(pet_id)
        if sheet is not None:
            print(f"Contact sheet -> {sheet.relative_to(ROOT)}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
