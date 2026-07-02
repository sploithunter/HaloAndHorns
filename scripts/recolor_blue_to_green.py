#!/usr/bin/env python3
"""Recolor blue UI art while preserving alpha, shading, and glossy highlights.

Two modes:
  channel - fast remap for flat blue icons (plus, fist, etc.)
  hue     - hue rotation for glossy rings with light/dark blue parts
  white   - grayscale art for Roblox ImageColor3 tinting (preserves value shading)

White mode (one upload set, tint per element/realm in Studio):
  Roblox ImageColor3 multiplies the image by the tint color. The ring must be
  GRAYSCALE with glossy value range baked in — not flat white:
    highlight ≈ near-white (255)   body ≈ mid-bright gray   shadow ≈ dark gray
  grayscale ring × element color = glossy colored ring
  flat-white ring × element color = flat matte ring (loses 3D pop)
  Hue comes from ImageColor3; gloss lives in the gray values.

Usage:
  python3 scripts/recolor_blue_to_green.py input.png output.png --color green
  python3 scripts/recolor_blue_to_green.py assets/ui/ring_frames_blue assets/ui/ring_frames_green --color green --mode hue
  python3 scripts/recolor_blue_to_green.py assets/ui/ring_frames_blue assets/ui/ring_frames_white --mode white
  python3 scripts/recolor_blue_to_green.py assets/ui/blue_icons assets/ui/white_icons --mode white

Faceted gems (sapphire source in assets/ui/gems_blue/):
  gem_single + gem_pile -> --mode hue (rich ruby/emerald/citrine highlights)
  gem_bag            -> --mode channel (brown bag/rope must not shift)

After adding icons to assets/ui/blue_icons, recolor all five sets then rebuild sheets:
  python3 scripts/recolor_blue_to_green.py assets/ui/blue_icons assets/ui/green_icons --color green
  python3 scripts/recolor_blue_to_green.py assets/ui/blue_icons assets/ui/red_icons --color red
  python3 scripts/recolor_blue_to_green.py assets/ui/blue_icons assets/ui/yellow_icons --color yellow
  python3 scripts/recolor_blue_to_green.py assets/ui/blue_icons assets/ui/purple_icons --color purple
  python3 scripts/recolor_blue_to_green.py assets/ui/blue_icons assets/ui/white_icons --mode white
  python3 scripts/recolor_blue_to_green.py assets/ui/pill_frames_blue assets/ui/pill_frames_purple --color purple --mode channel
  python3 scripts/recolor_blue_to_green.py assets/ui/ring_frames_blue assets/ui/ring_frames_purple --color purple --mode hue
  python3 scripts/build_icon_contact_sheet.py --rebuild-from assets/ui/blue_icons
  python3 scripts/build_icon_contact_sheet.py --all-colors
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

COLOR_DEFAULTS = {
    "green": "_green",
    "red": "_red",
    "amber": "_amber",
    "yellow": "_yellow",
    "purple": "_purple",
}

# Target hues on a 0-1 scale (HSV). Blue source art centers around ~0.62 (222°).
TARGET_HUES = {
    "green": 0.33,   # ~120° dark green
    "red": 0.0,      # ~0° dark red
    "amber": 0.11,   # ~40° gold
    "yellow": 0.13,  # ~47° dark yellow
    "purple": 0.77,  # ~277° violet (matches leveling.lua purple patch)
}

SOURCE_HUE = 0.62


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Recolor blue-toned transparent PNG art.")
    parser.add_argument("input", help="Input PNG or directory of PNGs")
    parser.add_argument(
        "output",
        nargs="?",
        help="Output PNG path, or output directory when input is a directory",
    )
    parser.add_argument(
        "--color",
        choices=["green", "red", "amber", "yellow", "purple"],
        default="green",
        help="Target color (default: green)",
    )
    parser.add_argument(
        "--mode",
        choices=["channel", "hue", "white"],
        default="channel",
        help="channel for flat icons; hue for glossy rings; white for tintable grayscale (default: channel)",
    )
    parser.add_argument(
        "--suffix",
        help="Filename suffix when processing a directory (default: _green, _red, etc.)",
    )
    parser.add_argument(
        "--min-blue-excess",
        type=float,
        default=8.0,
        help="Minimum (blue - min(red,green)) before channel recolor applies",
    )
    parser.add_argument(
        "--min-saturation",
        type=float,
        default=0.06,
        help="Hue mode: minimum saturation to recolor a pixel",
    )
    parser.add_argument(
        "--highlight-value",
        type=float,
        default=0.94,
        help="Hue mode: also recolor bright highlights below this value",
    )
    parser.add_argument(
        "--low-sat-boost",
        type=float,
        default=0.10,
        help="Hue mode: saturation added to pale highlight pixels",
    )
    return parser.parse_args()


def rgb_to_hsv(
    red: np.ndarray,
    green: np.ndarray,
    blue: np.ndarray,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    red = red / 255.0
    green = green / 255.0
    blue = blue / 255.0

    maxc = np.maximum(np.maximum(red, green), blue)
    minc = np.minimum(np.minimum(red, green), blue)
    delta = maxc - minc

    hue = np.zeros_like(maxc)
    safe = delta > 1e-6

    idx = safe & (maxc == red)
    hue[idx] = ((green[idx] - blue[idx]) / delta[idx]) % 6.0
    idx = safe & (maxc == green)
    hue[idx] = ((blue[idx] - red[idx]) / delta[idx]) + 2.0
    idx = safe & (maxc == blue)
    hue[idx] = ((red[idx] - green[idx]) / delta[idx]) + 4.0
    hue = (hue / 6.0) % 1.0

    saturation = np.zeros_like(maxc)
    saturation[maxc > 1e-6] = delta[maxc > 1e-6] / maxc[maxc > 1e-6]
    value = maxc
    return hue, saturation, value


def hsv_to_rgb(
    hue: np.ndarray,
    saturation: np.ndarray,
    value: np.ndarray,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    chroma = value * saturation
    hue_six = (hue * 6.0) % 6.0
    sector = np.floor(hue_six).astype(np.int32) % 6
    second = chroma * (1.0 - np.abs((hue_six % 2.0) - 1.0))
    match = value - chroma

    red = np.zeros_like(hue)
    green = np.zeros_like(hue)
    blue = np.zeros_like(hue)

    assignments = (
        (chroma, second, np.zeros_like(hue)),  # red → yellow
        (second, chroma, np.zeros_like(hue)),  # yellow → green
        (np.zeros_like(hue), chroma, second),  # green → cyan
        (np.zeros_like(hue), second, chroma),  # cyan → blue
        (second, np.zeros_like(hue), chroma),  # blue → magenta
        (chroma, np.zeros_like(hue), second),  # magenta → red
    )
    for index, (cr, cg, cb) in enumerate(assignments):
        mask = sector == index
        red[mask] = cr[mask]
        green[mask] = cg[mask]
        blue[mask] = cb[mask]

    red += match
    green += match
    blue += match
    return red * 255.0, green * 255.0, blue * 255.0


def recolor_blue_channel(
    image: Image.Image,
    color: str,
    min_blue_excess: float = 8.0,
) -> Image.Image:
    rgba = np.array(image.convert("RGBA"), dtype=np.float32)
    alpha = rgba[:, :, 3]
    mask = alpha > 0

    red = rgba[:, :, 0]
    green = rgba[:, :, 1]
    blue = rgba[:, :, 2]

    blue_excess = np.clip(blue - np.minimum(red, green), 0, 255)
    recolor = mask & (blue_excess > min_blue_excess)

    if color == "green":
        green[recolor] = np.clip(green[recolor] + blue_excess[recolor] * 0.92, 0, 255)
        blue[recolor] = np.clip(blue[recolor] - blue_excess[recolor] * 0.78, 0, 255)
        red[recolor] = np.clip(red[recolor] * 0.85 + blue_excess[recolor] * 0.05, 0, 255)
    elif color == "red":
        red[recolor] = np.clip(red[recolor] + blue_excess[recolor] * 0.92, 0, 255)
        blue[recolor] = np.clip(blue[recolor] - blue_excess[recolor] * 0.78, 0, 255)
        green[recolor] = np.clip(green[recolor] * 0.85 + blue_excess[recolor] * 0.05, 0, 255)
    elif color in {"amber", "yellow"}:
        red[recolor] = np.clip(red[recolor] + blue_excess[recolor] * 0.88, 0, 255)
        green[recolor] = np.clip(green[recolor] + blue_excess[recolor] * 0.58, 0, 255)
        blue[recolor] = np.clip(blue[recolor] - blue_excess[recolor] * 0.82, 0, 255)
    elif color == "purple":
        red[recolor] = np.clip(red[recolor] + blue_excess[recolor] * 0.72, 0, 255)
        green[recolor] = np.clip(green[recolor] - blue_excess[recolor] * 0.35, 0, 255)
        blue[recolor] = np.clip(blue[recolor] + blue_excess[recolor] * 0.12, 0, 255)

    rgba[:, :, 0] = red
    rgba[:, :, 1] = green
    rgba[:, :, 2] = blue
    return Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8))


def recolor_blue_hue(
    image: Image.Image,
    color: str,
    min_saturation: float,
    highlight_value: float,
    low_sat_boost: float,
) -> Image.Image:
    rgba = np.array(image.convert("RGBA"), dtype=np.float32)
    alpha = rgba[:, :, 3]
    visible = alpha > 0

    red = rgba[:, :, 0]
    green = rgba[:, :, 1]
    blue = rgba[:, :, 2]

    hue, saturation, value = rgb_to_hsv(red, green, blue)
    target_hue = TARGET_HUES[color]
    # Fixed delta preserves highlight/shadow relationships (e.g. arrow tips stay lighter
    # than the rim) instead of taking the shortest arc on the color wheel.
    hue_offset = target_hue - SOURCE_HUE

    recolor = visible & ((saturation >= min_saturation) | (value <= highlight_value))
    hue[recolor] = (hue[recolor] + hue_offset) % 1.0

    pale = recolor & (saturation < min_saturation + 0.08)
    saturation[pale] = np.clip(saturation[pale] + low_sat_boost, 0.0, 1.0)

    new_red, new_green, new_blue = hsv_to_rgb(hue, saturation, value)
    rgba[:, :, 0] = np.where(recolor, new_red, red)
    rgba[:, :, 1] = np.where(recolor, new_green, green)
    rgba[:, :, 2] = np.where(recolor, new_blue, blue)
    return Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8))


def recolor_to_white(
    image: Image.Image,
    min_saturation: float,
    highlight_value: float,
) -> Image.Image:
    """Grayscale ring art for Roblox ImageColor3 multiply-tinting.

    Stores HSV value (max RGB) as R=G=B luminance so highlights, body, and rim
    shadows survive tinting as glossy light/mid/dark tones of the element color.
    """
    del min_saturation, highlight_value  # white mode grays all visible pixels

    rgba = np.array(image.convert("RGBA"), dtype=np.float32)
    alpha = rgba[:, :, 3]
    visible = alpha > 0

    red = rgba[:, :, 0]
    green = rgba[:, :, 1]
    blue = rgba[:, :, 2]

    _, _, value = rgb_to_hsv(red, green, blue)
    gray = value * 255.0

    rgba[:, :, 0] = np.where(visible, gray, red)
    rgba[:, :, 1] = np.where(visible, gray, green)
    rgba[:, :, 2] = np.where(visible, gray, blue)
    return Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8))


def recolor_blue_ui(
    image: Image.Image,
    color: str,
    mode: str,
    min_blue_excess: float,
    min_saturation: float,
    highlight_value: float,
    low_sat_boost: float,
) -> Image.Image:
    if mode == "white":
        return recolor_to_white(image, min_saturation, highlight_value)
    if mode == "hue":
        return recolor_blue_hue(image, color, min_saturation, highlight_value, low_sat_boost)
    return recolor_blue_channel(image, color, min_blue_excess)


def output_name_for(input_path: Path, output: Path | None, suffix: str) -> Path:
    if output is None:
        return input_path.with_name(f"{input_path.stem}{suffix}{input_path.suffix}")

    if output.suffix.lower() == ".png":
        return output

    output.mkdir(parents=True, exist_ok=True)
    return output / input_path.name


def collect_inputs(path: Path) -> list[Path]:
    if path.is_file():
        return [path]
    if path.is_dir():
        return sorted(
            p
            for p in path.glob("*.png")
            if p.is_file() and p.name != "contact_sheet.png"
        )
    raise FileNotFoundError(f"Input not found: {path}")


def main() -> int:
    args = parse_args()
    input_path = Path(args.input).expanduser().resolve()
    output_arg = Path(args.output).expanduser().resolve() if args.output else None
    suffix = args.suffix or COLOR_DEFAULTS[args.color]

    try:
        inputs = collect_inputs(input_path)
    except FileNotFoundError as error:
        print(error, file=sys.stderr)
        return 1

    if not inputs:
        print(f"No PNG files found in: {input_path}", file=sys.stderr)
        return 1

    if len(inputs) > 1 and output_arg is not None and output_arg.suffix.lower() == ".png":
        print("Output must be a directory when processing multiple inputs.", file=sys.stderr)
        return 1

    for source in inputs:
        destination = output_name_for(source, output_arg, suffix)
        destination.parent.mkdir(parents=True, exist_ok=True)
        result = recolor_blue_ui(
            Image.open(source),
            args.color,
            args.mode,
            args.min_blue_excess,
            args.min_saturation,
            args.highlight_value,
            args.low_sat_boost,
        )
        result.save(destination)
        print(destination)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
