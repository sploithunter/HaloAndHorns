#!/usr/bin/env python3
"""Build a labeled contact sheet for ring frame PNGs in a directory."""

from __future__ import annotations

import argparse
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build ring frames contact sheet.")
    parser.add_argument(
        "input_dir",
        nargs="?",
        help="Directory containing ring PNGs (not used with --all-colors)",
    )
    parser.add_argument(
        "--output",
        help="Output PNG (default: <input_dir>/contact_sheet.png or assets/ui/ring_frames_all_colors.png)",
    )
    parser.add_argument(
        "--all-colors",
        action="store_true",
        help="Build a style×color matrix from ring_frames_{white,blue,green,red,yellow}",
    )
    parser.add_argument(
        "--base-dir",
        default="assets/ui",
        help="UI assets root for --all-colors (default: assets/ui)",
    )
    parser.add_argument("--columns", type=int, default=5)
    parser.add_argument("--thumb-size", type=int, default=320)
    parser.add_argument("--label-height", type=int, default=40)
    parser.add_argument("--padding", type=int, default=24)
    return parser.parse_args()


RING_FRAMES = {
    "ring_target_in": "target in",
    "ring_target_out": "target out",
    "ring_aoe": "aoe",
    "ring_target_aoe": "target aoe",
    "ring_aura": "aura",
    "ring_enhancement": "enhancement",
    "ring_enhancement_filled": "enhancement filled",
}

RING_ORDER = list(RING_FRAMES.keys())
COLOR_ORDER = ["white", "blue", "green", "red", "yellow", "purple"]


def load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for path in (
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ):
        if Path(path).exists():
            return ImageFont.truetype(path, size=size)
    return ImageFont.load_default()


def label_for(path: Path) -> str:
    stem = path.stem
    return RING_FRAMES.get(stem, stem.removeprefix("ring_"))


def fit_image(image: Image.Image, max_size: int) -> Image.Image:
    scale = min(max_size / image.width, max_size / image.height, 1.0)
    return image.resize(
        (max(1, int(image.width * scale)), max(1, int(image.height * scale))),
        Image.Resampling.LANCZOS,
    )


def ring_file_for(color: str, ring_name: str, base_dir: Path) -> Path:
    color_dir = base_dir / f"ring_frames_{color}"
    path = color_dir / f"{ring_name}.png"
    if not path.is_file():
        raise FileNotFoundError(f"Missing ring PNG: {path}")
    return path


def build_single_dir_sheet(
    icons: list[Path],
    output: Path,
    columns: int,
    thumb_size: int,
    label_height: int,
    padding: int,
) -> None:
    rows = math.ceil(len(icons) / columns)
    cell_w = thumb_size + padding * 2
    cell_h = thumb_size + label_height + padding * 2
    sheet = Image.new("RGBA", (columns * cell_w, rows * cell_h), (48, 48, 48, 255))
    draw = ImageDraw.Draw(sheet)
    font = load_font(20)

    for index, path in enumerate(icons):
        fitted = fit_image(Image.open(path).convert("RGBA"), thumb_size)
        col = index % columns
        row = index // columns
        x0 = col * cell_w + padding
        y0 = row * cell_h + padding
        paste_x = x0 + (thumb_size - fitted.width) // 2
        paste_y = y0 + (thumb_size - fitted.height) // 2
        sheet.paste(fitted, (paste_x, paste_y), fitted)
        draw.text(
            (x0 + thumb_size / 2, y0 + thumb_size + 10),
            label_for(path),
            fill=(235, 235, 235, 255),
            font=font,
            anchor="ma",
        )

    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output, optimize=True, compress_level=9)


def build_all_colors_sheet(
    output: Path,
    base_dir: Path,
    thumb_size: int,
    label_height: int,
    padding: int,
) -> None:
    row_label_width = 148
    header_height = 36
    columns = len(COLOR_ORDER)
    rows = len(RING_ORDER)
    cell_w = thumb_size + padding * 2
    cell_h = thumb_size + label_height + padding * 2
    sheet = Image.new(
        "RGBA",
        (row_label_width + columns * cell_w, header_height + rows * cell_h),
        (48, 48, 48, 255),
    )
    draw = ImageDraw.Draw(sheet)
    header_font = load_font(22)
    label_font = load_font(18)

    for col, color in enumerate(COLOR_ORDER):
        x = row_label_width + col * cell_w + cell_w / 2
        draw.text(
            (x, header_height / 2),
            color,
            fill=(235, 235, 235, 255),
            font=header_font,
            anchor="mm",
        )

    for row, ring_name in enumerate(RING_ORDER):
        y0 = header_height + row * cell_h
        draw.text(
            (row_label_width / 2, y0 + thumb_size / 2 + padding),
            RING_FRAMES[ring_name],
            fill=(235, 235, 235, 255),
            font=label_font,
            anchor="mm",
        )

        for col, color in enumerate(COLOR_ORDER):
            path = ring_file_for(color, ring_name, base_dir)
            fitted = fit_image(Image.open(path).convert("RGBA"), thumb_size)
            x0 = row_label_width + col * cell_w + padding
            paste_x = x0 + (thumb_size - fitted.width) // 2
            paste_y = y0 + padding + (thumb_size - fitted.height) // 2
            sheet.paste(fitted, (paste_x, paste_y), fitted)

    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output, optimize=True, compress_level=9)


def main() -> int:
    args = parse_args()

    if args.all_colors:
        base_dir = Path(args.base_dir).expanduser().resolve()
        output = Path(
            args.output or base_dir / "ring_frames_all_colors.png"
        ).expanduser().resolve()
        build_all_colors_sheet(
            output,
            base_dir,
            args.thumb_size,
            args.label_height,
            args.padding,
        )
        print(output)
        return 0

    if args.input_dir is None:
        raise SystemExit("input_dir is required unless --all-colors is set")

    input_dir = Path(args.input_dir).expanduser().resolve()
    output = Path(args.output or input_dir / "contact_sheet.png").expanduser().resolve()

    icons = sorted(
        p for p in input_dir.glob("*.png") if p.is_file() and p.name != output.name
    )
    order = {name: index for index, name in enumerate(RING_ORDER)}
    icons.sort(key=lambda path: (order.get(path.stem, 999), path.stem))
    if not icons:
        raise SystemExit(f"No ring PNGs found in {input_dir}")

    build_single_dir_sheet(
        icons,
        output,
        args.columns,
        args.thumb_size,
        args.label_height,
        args.padding,
    )
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
