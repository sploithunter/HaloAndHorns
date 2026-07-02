#!/usr/bin/env python3
"""Normalize UI icon PNGs: transparent background, tight crop to content, optional resize.

Crops out empty/transparent sides so output XY matches the visible icon (the disk),
instead of forcing every file into one fixed canvas size.

Usage:
  python3 scripts/normalize_icons.py ~/Downloads/BlueIcons ~/Downloads/BlueIcons/normalized
  python3 scripts/normalize_icons.py input.png output.png --size 512
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from PIL import Image

from remove_image_background import (
    background_alpha,
    blue_screen_alpha,
    despill_blue,
    despill_green,
    edge_connected_background,
    edge_connected_blue_screen,
    edge_connected_green_screen,
    green_screen_alpha,
    is_blue_screen_candidate,
    is_green_screen_candidate,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Normalize icon PNGs for Roblox UI.")
    parser.add_argument("input", help="Input PNG or directory of PNGs")
    parser.add_argument(
        "output",
        nargs="?",
        help="Output PNG path or directory (default: <input>/normalized)",
    )
    parser.add_argument(
        "--size",
        type=int,
        default=0,
        help="Optional output width/height after crop (0 = keep native cropped size)",
    )
    parser.add_argument(
        "--padding",
        type=int,
        default=0,
        help="Extra transparent pixels around the cropped content (default: 0)",
    )
    parser.add_argument(
        "--square",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Fit crop into a square canvas sized to the largest content side (default: on)",
    )
    parser.add_argument(
        "--white-threshold",
        type=int,
        default=242,
        help="RGB threshold for white backgrounds",
    )
    parser.add_argument(
        "--dark-threshold",
        type=int,
        default=32,
        help="Max RGB for dark backgrounds",
    )
    parser.add_argument(
        "--softness",
        type=int,
        default=20,
        help="Feather range for background edges",
    )
    parser.add_argument(
        "--green-min",
        type=int,
        default=120,
        help="Minimum green channel for green-screen key",
    )
    parser.add_argument(
        "--green-dominance",
        type=int,
        default=40,
        help="Required green excess over max(red, blue) for green-screen key",
    )
    parser.add_argument(
        "--blue-min",
        type=int,
        default=120,
        help="Minimum blue channel for blue-screen key",
    )
    parser.add_argument(
        "--blue-dominance",
        type=int,
        default=40,
        help="Required blue excess over max(red, green) for blue-screen key",
    )
    parser.add_argument(
        "--background-mode",
        choices=["auto", "white", "dark", "green", "blue"],
        default="auto",
        help="Background removal mode (default: auto-detect from corners)",
    )
    parser.add_argument(
        "--prefix",
        default="icon",
        help="Output filename prefix when processing a directory",
    )
    return parser.parse_args()


def is_dark_background_candidate(red: int, green: int, blue: int, threshold: int, softness: int) -> bool:
    darkness = max(red, green, blue)
    return darkness <= threshold + softness


def dark_background_alpha(red: int, green: int, blue: int, threshold: int, softness: int) -> int:
    darkness = max(red, green, blue)
    if darkness <= threshold:
        return 0
    if softness <= 0 or darkness >= threshold + softness:
        return 255
    return int(255 * (darkness - threshold) / softness)


def edge_connected_dark_background(image: Image.Image, threshold: int, softness: int) -> set[tuple[int, int]]:
    width, height = image.size
    seeds: list[tuple[int, int]] = []
    for x in range(width):
        seeds.extend([(x, 0), (x, height - 1)])
    for y in range(height):
        seeds.extend([(0, y), (width - 1, y)])

    pixels = image.load()
    queue = list(seeds)
    seen: set[tuple[int, int]] = set()

    def enqueue(x: int, y: int) -> None:
        if (x, y) in seen:
            return
        if not (0 <= x < width and 0 <= y < height):
            return
        red, green, blue, _alpha = pixels[x, y]
        if not is_dark_background_candidate(red, green, blue, threshold, softness):
            return
        seen.add((x, y))
        queue.append((x, y))

    for seed in seeds:
        enqueue(seed[0], seed[1])

    while queue:
        x, y = queue.pop()
        for next_x, next_y in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            enqueue(next_x, next_y)

    return seen


def corner_samples(image: Image.Image) -> list[tuple[int, int, int]]:
    width, height = image.size
    points = [
        (0, 0),
        (width - 1, 0),
        (0, height - 1),
        (width - 1, height - 1),
        (width // 2, 0),
        (width // 2, height - 1),
        (0, height // 2),
        (width - 1, height // 2),
    ]
    rgb_points = []
    pixels = image.load()
    for x, y in points:
        red, green, blue, alpha = pixels[x, y]
        if alpha < 16:
            continue
        rgb_points.append((red, green, blue))
    return rgb_points


def detect_background_mode(
    image: Image.Image,
    white_threshold: int,
    dark_threshold: int,
    green_min: int,
    green_dominance: int,
    blue_min: int = 120,
    blue_dominance: int = 40,
) -> str | None:
    alpha = image.split()[-1]
    transparent_corners = sum(1 for value in alpha.getdata() if value < 16)
    if transparent_corners > len(alpha.getdata()) * 0.05:
        return None

    samples = corner_samples(image)
    if not samples:
        return None

    white_votes = sum(1 for red, green, blue in samples if min(red, green, blue) >= white_threshold - 20)
    dark_votes = sum(1 for red, green, blue in samples if max(red, green, blue) <= dark_threshold + 20)
    green_votes = sum(
        1
        for red, green, blue in samples
        if is_green_screen_candidate(red, green, blue, green_min, green_dominance, 0)
    )
    blue_votes = sum(
        1
        for red, green, blue in samples
        if is_blue_screen_candidate(red, green, blue, blue_min, blue_dominance, 0)
    )

    screen_votes = max(green_votes, blue_votes)
    if screen_votes >= max(white_votes, dark_votes) and screen_votes >= len(samples) // 2:
        return "green" if green_votes >= blue_votes else "blue"
    if white_votes >= dark_votes and white_votes >= len(samples) // 2:
        return "white"
    if dark_votes > white_votes:
        return "dark"
    return "white"


def remove_green_spill(image: Image.Image, max_dist: int = 10) -> Image.Image:
    """Remove residual green-screen spill near the keyed silhouette edge."""
    from collections import deque

    rgba = image.convert("RGBA")
    width, height = rgba.size
    pixels = rgba.load()
    dist: dict[tuple[int, int], int] = {}
    queue: deque[tuple[int, int]] = deque()

    for y in range(height):
        for x in range(width):
            if pixels[x, y][3] < 16:
                dist[(x, y)] = 0
                queue.append((x, y))

    while queue:
        x, y = queue.popleft()
        for next_x, next_y in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if not (0 <= next_x < width and 0 <= next_y < height):
                continue
            if (next_x, next_y) in dist:
                continue
            dist[(next_x, next_y)] = dist[(x, y)] + 1
            queue.append((next_x, next_y))

    cleaned = []
    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            if alpha < 16:
                cleaned.append((red, green, blue, alpha))
                continue

            distance = dist.get((x, y), max_dist + 1)
            excess = green - max(red, blue)
            greenish = excess >= 12 or (excess >= 5 and green >= 35)
            if distance <= max_dist and greenish:
                cleaned.append((red, green, blue, 0))
            else:
                cleaned.append((red, green, blue, alpha))

    result = rgba.copy()
    result.putdata(cleaned)
    return result


def remove_blue_spill(image: Image.Image, max_dist: int = 10) -> Image.Image:
    """Remove residual blue-screen spill near the keyed silhouette edge."""
    from collections import deque

    rgba = image.convert("RGBA")
    width, height = rgba.size
    pixels = rgba.load()
    dist: dict[tuple[int, int], int] = {}
    queue: deque[tuple[int, int]] = deque()

    for y in range(height):
        for x in range(width):
            if pixels[x, y][3] < 16:
                dist[(x, y)] = 0
                queue.append((x, y))

    while queue:
        x, y = queue.popleft()
        for next_x, next_y in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if not (0 <= next_x < width and 0 <= next_y < height):
                continue
            if (next_x, next_y) in dist:
                continue
            dist[(next_x, next_y)] = dist[(x, y)] + 1
            queue.append((next_x, next_y))

    cleaned = []
    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            if alpha < 16:
                cleaned.append((red, green, blue, alpha))
                continue

            distance = dist.get((x, y), max_dist + 1)
            excess = blue - max(red, green)
            bluish = excess >= 12 or (excess >= 5 and blue >= 35)
            if distance <= max_dist and bluish:
                cleaned.append((red, green, blue, 0))
            else:
                cleaned.append((red, green, blue, alpha))

    result = rgba.copy()
    result.putdata(cleaned)
    return result


def remove_background(
    image: Image.Image,
    mode: str | None,
    white_threshold: int,
    dark_threshold: int,
    softness: int,
    green_min: int = 120,
    green_dominance: int = 40,
    blue_min: int = 120,
    blue_dominance: int = 40,
) -> Image.Image:
    if mode is None:
        return image

    if mode == "white":
        background_mask = edge_connected_background(image, white_threshold, softness)

        def alpha_for_pixel(red: int, green: int, blue: int, alpha: int) -> int:
            return min(alpha, background_alpha(red, green, blue, white_threshold, softness))
    elif mode == "green":
        background_mask = edge_connected_green_screen(image, green_min, green_dominance, softness)

        def alpha_for_pixel(red: int, green: int, blue: int, alpha: int) -> int:
            return min(
                alpha,
                green_screen_alpha(red, green, blue, green_min, green_dominance, softness),
            )
    elif mode == "blue":
        background_mask = edge_connected_blue_screen(image, blue_min, blue_dominance, softness)

        def alpha_for_pixel(red: int, green: int, blue: int, alpha: int) -> int:
            return min(
                alpha,
                blue_screen_alpha(red, green, blue, blue_min, blue_dominance, softness),
            )
    else:
        background_mask = edge_connected_dark_background(image, dark_threshold, softness)

        def alpha_for_pixel(red: int, green: int, blue: int, alpha: int) -> int:
            return min(alpha, dark_background_alpha(red, green, blue, dark_threshold, softness))

    pixels = []
    for index, (red, green, blue, alpha) in enumerate(image.getdata()):
        x = index % image.width
        y = index // image.width
        if (x, y) not in background_mask:
            pixels.append((red, green, blue, alpha))
            continue
        next_alpha = alpha_for_pixel(red, green, blue, alpha)
        if mode == "green" and next_alpha > 0:
            red, green, blue = despill_green(red, green, blue, next_alpha)
        elif mode == "blue" and next_alpha > 0:
            red, green, blue = despill_blue(red, green, blue, next_alpha)
        pixels.append((red, green, blue, next_alpha))

    result = image.copy()
    result.putdata(pixels)
    return result


def crop_to_content(image: Image.Image, padding: int, square: bool) -> Image.Image:
    bbox = image.split()[-1].getbbox()
    if not bbox:
        raise ValueError("Image has no visible content after background removal.")

    cropped = image.crop(bbox)
    if padding > 0:
        canvas = Image.new(
            "RGBA",
            (cropped.width + padding * 2, cropped.height + padding * 2),
            (0, 0, 0, 0),
        )
        canvas.paste(cropped, (padding, padding), cropped)
        cropped = canvas

    if not square:
        return cropped

    width, height = cropped.size
    side = max(width, height)
    if width == height:
        return cropped

    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    offset_x = (side - width) // 2
    offset_y = (side - height) // 2
    canvas.paste(cropped, (offset_x, offset_y), cropped)
    return canvas


def normalize_icon(
    image: Image.Image,
    size: int,
    padding: int,
    square: bool,
    white_threshold: int,
    dark_threshold: int,
    softness: int,
    green_min: int = 120,
    green_dominance: int = 40,
    blue_min: int = 120,
    blue_dominance: int = 40,
    background_mode: str = "auto",
) -> tuple[Image.Image, str | None]:
    rgba = image.convert("RGBA")
    if background_mode == "auto":
        mode = detect_background_mode(
            rgba,
            white_threshold,
            dark_threshold,
            green_min,
            green_dominance,
            blue_min,
            blue_dominance,
        )
    else:
        mode = background_mode
    rgba = remove_background(
        rgba,
        mode,
        white_threshold,
        dark_threshold,
        softness,
        green_min,
        green_dominance,
        blue_min,
        blue_dominance,
    )
    if mode == "green":
        rgba = remove_green_spill(rgba)
    elif mode == "blue":
        rgba = remove_blue_spill(rgba)
    rgba = crop_to_content(rgba, padding, square)
    if size > 0:
        rgba = rgba.resize((size, size), Image.Resampling.LANCZOS)
    return rgba, mode


def save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True, compress_level=9)


def collect_inputs(path: Path) -> list[Path]:
    if path.is_file():
        return [path]
    if path.is_dir():
        return sorted(p for p in path.glob("*.png") if p.is_file())
    raise FileNotFoundError(f"Input not found: {path}")


def output_path_for(
    input_path: Path,
    input_root: Path,
    output_root: Path,
    prefix: str,
    index: int,
) -> Path:
    if input_root.is_file():
        if output_root.suffix.lower() == ".png":
            return output_root
        return output_root / f"{prefix}.png"

    return output_root / f"{prefix}_{index:03d}.png"


def main() -> int:
    args = parse_args()
    input_path = Path(args.input).expanduser().resolve()
    output_root = (
        Path(args.output).expanduser().resolve()
        if args.output
        else (input_path / "normalized" if input_path.is_dir() else input_path.with_name(f"{input_path.stem}_normalized.png"))
    )

    try:
        inputs = collect_inputs(input_path)
    except FileNotFoundError as error:
        print(error, file=sys.stderr)
        return 1

    if not inputs:
        print(f"No PNG files found in: {input_path}", file=sys.stderr)
        return 1

    if len(inputs) > 1 and output_root.suffix.lower() == ".png":
        print("Output must be a directory when processing multiple inputs.", file=sys.stderr)
        return 1

    size_label = f"{args.size}x{args.size}" if args.size > 0 else "native-crop"
    manifest_lines = [
        f"size: {size_label}",
        f"padding: {args.padding}px",
        f"square: {args.square}",
        "",
    ]

    for index, source in enumerate(inputs, start=1):
        normalized, bg_mode = normalize_icon(
            Image.open(source),
            args.size,
            args.padding,
            args.square,
            args.white_threshold,
            args.dark_threshold,
            args.softness,
            args.green_min,
            args.green_dominance,
            args.blue_min,
            args.blue_dominance,
            args.background_mode,
        )
        destination = output_path_for(source, input_path, output_root, args.prefix, index)
        save_png(normalized, destination)
        bg_label = bg_mode or "existing-alpha"
        manifest_lines.append(
            f"{destination.name}\t{normalized.width}x{normalized.height}\t<- {source.name}\t({bg_label})"
        )
        print(f"{destination}\t{normalized.width}x{normalized.height}\t({bg_label})")

    if input_path.is_dir() or len(inputs) > 1:
        manifest_dir = output_root if output_root.is_dir() else output_root.parent
        (manifest_dir / "manifest.txt").write_text("\n".join(manifest_lines) + "\n", encoding="utf-8")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
