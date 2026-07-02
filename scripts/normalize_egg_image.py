#!/usr/bin/env python3
"""Normalize egg reference PNGs: transparent outer bg + bottom floor cleanup only.

ChatGPT egg renders use a white backdrop plus a soft white/gray oval under the egg.
Do NOT flood globally — that reaches the flag white band through transparent gutters.
This script only clears the bottom band after outer white-edge removal.

Usage:
  python3 scripts/normalize_egg_image.py input.png output.png
  python3 scripts/normalize_egg_image.py input.png output.png --floor-band 0.12
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from PIL import Image

from normalize_icons import crop_to_content, remove_background


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Normalize egg PNG with bottom-only floor cleanup.")
    parser.add_argument("input", help="Input PNG")
    parser.add_argument("output", help="Output transparent PNG")
    parser.add_argument("--white-threshold", type=int, default=242)
    parser.add_argument("--softness", type=int, default=20)
    parser.add_argument(
        "--floor-band",
        type=float,
        default=0.12,
        help="Fraction of image height from the bottom to clean (default: 0.12)",
    )
    parser.add_argument("--padding", type=int, default=0)
    parser.add_argument(
        "--square",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Fit crop into a square canvas (default: on)",
    )
    return parser.parse_args()


def is_bottom_floor_pixel(red: int, green: int, blue: int) -> bool:
    """Near-white glow or neutral gray contact shadow — not egg color."""
    mx = max(red, green, blue)
    mn = min(red, green, blue)
    spread = mx - mn

    # White / light gray floor glow
    if mn >= 200 and spread <= 30:
        return True

    # Neutral gray shadow ring (avoid blue egg facets: they have spread from the B channel)
    if mn >= 90 and spread <= 22:
        return True

    return False


def remove_bottom_floor_band(image: Image.Image, band_fraction: float) -> Image.Image:
    rgba = image.convert("RGBA")
    width, height = rgba.size
    y0 = int(height * (1.0 - band_fraction))
    pixels = []

    for index, (red, green, blue, alpha) in enumerate(rgba.getdata()):
        y = index // width
        if y < y0 or alpha < 16 or not is_bottom_floor_pixel(red, green, blue):
            pixels.append((red, green, blue, alpha))
            continue
        pixels.append((red, green, blue, 0))

    rgba.putdata(pixels)
    return rgba


def normalize_egg_image(
    image: Image.Image,
    white_threshold: int,
    softness: int,
    floor_band: float,
    padding: int,
    square: bool,
) -> Image.Image:
    rgba = image.convert("RGBA")
    rgba = remove_background(rgba, "white", white_threshold, 32, softness)
    rgba = remove_bottom_floor_band(rgba, floor_band)
    return crop_to_content(rgba, padding, square)


def main() -> int:
    args = parse_args()
    source = Path(args.input).expanduser().resolve()
    output = Path(args.output).expanduser().resolve()

    result = normalize_egg_image(
        Image.open(source),
        args.white_threshold,
        args.softness,
        args.floor_band,
        args.padding,
        args.square,
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    result.save(output, format="PNG", optimize=True, compress_level=9)
    print(f"{output}\t{result.width}x{result.height}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
