#!/usr/bin/env python3
"""Copy renamed UI icons into assets and build a labeled contact sheet."""

from __future__ import annotations

import argparse
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ICON_COLOR_ORDER = ["white", "blue", "green", "red", "yellow", "purple"]


# ChatGPT-download filenames -> canonical asset names (see docs/PET_REALM_ICONS_AND_POWERS.md).
BATCH_MAPPINGS: dict[str, dict[str, str]] = {
    "jun6_2026": {
        "ChatGPT Image Jun 6, 2026, 08_32_15 AM.png": "clover_huge.png",
        "ChatGPT Image Jun 6, 2026, 08_54_10 AM.png": "clover_lucky.png",
        "ChatGPT Image Jun 6, 2026, 08_44_26 AM.png": "magnet.png",
        "ChatGPT Image Jun 6, 2026, 08_44_33 AM.png": "xp_up.png",
        "ChatGPT Image Jun 6, 2026, 08_44_38 AM.png": "revive.png",
        "ChatGPT Image Jun 6, 2026, 08_44_44 AM.png": "knockback.png",
        "ChatGPT Image Jun 6, 2026, 08_46_07 AM.png": "portal.png",
        "ChatGPT Image Jun 6, 2026, 08_47_57 AM.png": "pet_transfer.png",
    },
}

DEFAULT_MAPPING = {
    "blue_icon_001.png": "plus.png",
    "blue_icon_002.png": "fist.png",
    "blue_icon_003.png": "target_down.png",
    "blue_icon_004.png": "shield_broken.png",
    "blue_icon_005.png": "shield.png",
    "blue_icon_006.png": "target.png",
    "blue_icon_007.png": "fist_broken.png",
    "blue_icon_008.png": "coins_up.png",
    "blue_icon_009.png": "clover_lucky.png",
    "blue_icon_010.png": "gift_up.png",
    "blue_icon_011.png": "plus_down.png",
    "blue_icon_012.png": "capacitor.png",
    "blue_icon_013.png": "user_desk.png",
    "blue_icon_014.png": "capacitor.png",
    "blue_icon_015.png": "user_desk.png",
    "blue_icon_016.png": "arrow_right.png",
    "blue_icon_017.png": "history.png",
    "blue_icon_018.png": "fist_impact.png",
    "blue_icon_019.png": "star_sparkle.png",
    "blue_icon_020.png": "armor_chest.png",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build a labeled icon contact sheet.")
    parser.add_argument(
        "input_dir",
        nargs="?",
        help="Directory of normalized icon PNGs (optional with --rebuild-from)",
    )
    parser.add_argument(
        "--output-dir",
        default="assets/ui/blue_icons",
        help="Destination for renamed icons",
    )
    parser.add_argument(
        "--contact-sheet",
        default="assets/ui/blue_icons/contact_sheet.png",
        help="Contact sheet output path",
    )
    parser.add_argument(
        "--rebuild-from",
        help="Rebuild contact sheet from an existing assets directory (skips copy step)",
    )
    parser.add_argument(
        "--batch",
        choices=sorted(BATCH_MAPPINGS),
        help="Use a named download-batch filename mapping instead of DEFAULT_MAPPING",
    )
    parser.add_argument(
        "--all-colors",
        action="store_true",
        help="Build icon×color matrix from {white,blue,green,red,yellow}_icons",
    )
    parser.add_argument(
        "--base-dir",
        default="assets/ui",
        help="UI assets root for --all-colors (default: assets/ui)",
    )
    parser.add_argument(
        "--output",
        help="Output path for --all-colors (default: <base-dir>/icons_all_colors.png)",
    )
    parser.add_argument("--columns", type=int, default=5, help="Grid columns")
    parser.add_argument("--thumb-size", type=int, default=256, help="Max icon size in sheet")
    parser.add_argument("--label-height", type=int, default=36, help="Label area height")
    parser.add_argument("--padding", type=int, default=24, help="Padding between cells")
    return parser.parse_args()


def load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/Library/Fonts/Arial.ttf",
    ]
    for path in candidates:
        if Path(path).exists():
            return ImageFont.truetype(path, size=size)
    return ImageFont.load_default()


def fit_image(image: Image.Image, max_size: int) -> Image.Image:
    rgba = image.convert("RGBA")
    width, height = rgba.size
    scale = min(max_size / width, max_size / height, 1.0)
    if scale == 1.0:
        return rgba
    new_size = (max(1, int(width * scale)), max(1, int(height * scale)))
    return rgba.resize(new_size, Image.Resampling.LANCZOS)


def unique_entries(input_dir: Path, mapping: dict[str, str]) -> list[tuple[str, Path, str]]:
    seen_names: set[str] = set()
    entries: list[tuple[str, Path, str]] = []
    skipped: list[str] = []

    for source_name, target_name in mapping.items():
        source_path = input_dir / source_name
        if not source_path.exists():
            continue
        if target_name in seen_names:
            skipped.append(f"{source_name} -> {target_name} (duplicate)")
            continue
        seen_names.add(target_name)
        entries.append((target_name, source_path, source_name))

    return entries, skipped


def build_contact_sheet(
    icons: list[tuple[str, Image.Image]],
    output_path: Path,
    columns: int,
    thumb_size: int,
    label_height: int,
    padding: int,
) -> None:
    if not icons:
        raise ValueError("No icons provided for contact sheet.")

    rows = math.ceil(len(icons) / columns)
    cell_w = thumb_size + padding * 2
    cell_h = thumb_size + label_height + padding * 2
    sheet = Image.new("RGBA", (columns * cell_w, rows * cell_h), (48, 48, 48, 255))
    draw = ImageDraw.Draw(sheet)
    font = load_font(18)

    for index, (name, image) in enumerate(icons):
        col = index % columns
        row = index // columns
        x0 = col * cell_w + padding
        y0 = row * cell_h + padding

        fitted = fit_image(image, thumb_size)
        paste_x = x0 + (thumb_size - fitted.width) // 2
        paste_y = y0 + (thumb_size - fitted.height) // 2
        sheet.paste(fitted, (paste_x, paste_y), fitted)

        label = Path(name).stem
        text_y = y0 + thumb_size + 8
        draw.text((x0 + thumb_size / 2, text_y), label, fill=(235, 235, 235, 255), font=font, anchor="ma")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output_path, format="PNG", optimize=True, compress_level=9)


def icon_names_in(base_dir: Path) -> list[str]:
    blue_dir = base_dir / "blue_icons"
    return sorted(
        p.name
        for p in blue_dir.glob("*.png")
        if p.is_file() and p.name not in {"contact_sheet.png"}
    )


def icon_path_for(color: str, icon_name: str, base_dir: Path) -> Path:
    path = base_dir / f"{color}_icons" / icon_name
    if not path.is_file():
        raise FileNotFoundError(f"Missing icon PNG: {path}")
    return path


def build_all_colors_sheet(
    output_path: Path,
    base_dir: Path,
    thumb_size: int,
    label_height: int,
    padding: int,
) -> None:
    icon_names = icon_names_in(base_dir)
    if not icon_names:
        raise ValueError(f"No icons found in {base_dir / 'blue_icons'}")

    row_label_width = 168
    header_height = 36
    columns = len(ICON_COLOR_ORDER)
    rows = len(icon_names)
    cell_w = thumb_size + padding * 2
    cell_h = thumb_size + padding * 2
    sheet = Image.new(
        "RGBA",
        (row_label_width + columns * cell_w, header_height + rows * cell_h),
        (48, 48, 48, 255),
    )
    draw = ImageDraw.Draw(sheet)
    header_font = load_font(20)
    label_font = load_font(16)

    for col, color in enumerate(ICON_COLOR_ORDER):
        x = row_label_width + col * cell_w + cell_w / 2
        draw.text(
            (x, header_height / 2),
            color,
            fill=(235, 235, 235, 255),
            font=header_font,
            anchor="mm",
        )

    for row, icon_name in enumerate(icon_names):
        y0 = header_height + row * cell_h
        draw.text(
            (row_label_width / 2, y0 + thumb_size / 2 + padding / 2),
            Path(icon_name).stem,
            fill=(235, 235, 235, 255),
            font=label_font,
            anchor="mm",
        )

        for col, color in enumerate(ICON_COLOR_ORDER):
            path = icon_path_for(color, icon_name, base_dir)
            fitted = fit_image(Image.open(path), thumb_size)
            x0 = row_label_width + col * cell_w + padding
            paste_x = x0 + (thumb_size - fitted.width) // 2
            paste_y = y0 + padding + (thumb_size - fitted.height) // 2
            sheet.paste(fitted, (paste_x, paste_y), fitted)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output_path, format="PNG", optimize=True, compress_level=9)


def main() -> int:
    args = parse_args()

    if args.all_colors:
        base_dir = Path(args.base_dir).expanduser().resolve()
        output = Path(
            args.output or base_dir / "icons_all_colors.png"
        ).expanduser().resolve()
        build_all_colors_sheet(
            output,
            base_dir,
            args.thumb_size,
            args.label_height,
            args.padding,
        )
        icon_count = len(icon_names_in(base_dir))
        print(f"Built {icon_count}×{len(ICON_COLOR_ORDER)} icon color matrix")
        print(f"Contact sheet: {output}")
        return 0

    if args.rebuild_from:
        assets_dir = Path(args.rebuild_from).expanduser().resolve()
        contact_sheet = Path(args.contact_sheet).expanduser().resolve()
        icons = sorted(
            p
            for p in assets_dir.glob("*.png")
            if p.is_file() and p.name != contact_sheet.name
        )
        if not icons:
            raise SystemExit(f"No icons found in {assets_dir}")

        sheet_icons = [(path.name, Image.open(path)) for path in icons]
        build_contact_sheet(
            sheet_icons,
            contact_sheet,
            args.columns,
            args.thumb_size,
            args.label_height,
            args.padding,
        )

        manifest_lines = [
            f"assets_dir: {assets_dir}",
            f"icon_count: {len(icons)}",
            "",
            *[path.name for path in icons],
            "",
            f"contact_sheet: {contact_sheet.name}",
        ]
        (assets_dir / "manifest.txt").write_text("\n".join(manifest_lines) + "\n", encoding="utf-8")
        print(f"Rebuilt contact sheet with {len(icons)} icons")
        print(f"Contact sheet: {contact_sheet}")
        return 0

    if not args.input_dir:
        raise SystemExit("Provide input_dir or use --rebuild-from")

    args.input_dir = Path(args.input_dir).expanduser().resolve()
    input_dir = args.input_dir
    output_dir = Path(args.output_dir).expanduser().resolve()
    contact_sheet = Path(args.contact_sheet).expanduser().resolve()

    mapping = BATCH_MAPPINGS[args.batch] if args.batch else DEFAULT_MAPPING
    entries, skipped = unique_entries(input_dir, mapping)
    if not entries:
        raise SystemExit(f"No mapped icons found in {input_dir}")

    output_dir.mkdir(parents=True, exist_ok=True)
    manifest_lines = [
        f"source_dir: {input_dir}",
        f"output_dir: {output_dir}",
        f"unique_icons: {len(entries)}",
        "",
    ]

    sheet_icons: list[tuple[str, Image.Image]] = []
    for target_name, source_path, source_name in entries:
        image = Image.open(source_path)
        destination = output_dir / target_name
        image.save(destination, format="PNG", optimize=True, compress_level=9)
        sheet_icons.append((target_name, image))
        manifest_lines.append(f"{target_name}\t<- {source_name}")

    if skipped:
        manifest_lines.extend(["", "skipped_duplicates:"])
        manifest_lines.extend(skipped)

    build_contact_sheet(
        sheet_icons,
        contact_sheet,
        args.columns,
        args.thumb_size,
        args.label_height,
        args.padding,
    )

    manifest_lines.extend(["", f"contact_sheet: {contact_sheet.name}"])
    (output_dir / "manifest.txt").write_text("\n".join(manifest_lines) + "\n", encoding="utf-8")

    print(f"Wrote {len(entries)} icons to {output_dir}")
    print(f"Contact sheet: {contact_sheet}")
    if skipped:
        print(f"Skipped {len(skipped)} duplicate(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
