#!/usr/bin/env python3
"""Convert a 2:1 equirectangular panorama into Roblox Sky face images.

Uses py360convert (https://github.com/sunset1995/py360convert) for projection,
then applies the Roblox-specific Up/Down rotations from:
https://devforum.roblox.com/t/custom-skyboxes-101/2849003

Output files are named for Roblox Studio's Sky object:
  SkyboxBk, SkyboxDn, SkyboxFt, SkyboxLf, SkyboxRt, SkyboxUp

Usage:
  python3 scripts/panorama_to_roblox_skybox.py input.png [--output dir] [--face-size 512]
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
import py360convert
from PIL import Image


ROBLOX_FACES = {
    "B": "SkyboxBk",
    "D": "SkyboxDn",
    "F": "SkyboxFt",
    "L": "SkyboxLf",
    "R": "SkyboxRt",
    "U": "SkyboxUp",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Convert equirectangular panorama to Roblox skybox faces.")
    parser.add_argument("input", help="2:1 equirectangular PNG/JPG")
    parser.add_argument(
        "--output",
        help="Output directory (default: assets/skybox/<input_stem>/)",
    )
    parser.add_argument(
        "--face-size",
        type=int,
        default=0,
        help="Square face resolution (default: source height or 512, whichever is larger up to height)",
    )
    parser.add_argument(
        "--dice",
        action="store_true",
        help="Also write cubemap_dice.png preview (F R B L / U / D layout)",
    )
    return parser.parse_args()


def default_face_size(width: int, height: int) -> int:
    # Equirect height caps useful cubemap detail; prefer power-of-two faces.
    base = max(height, width // 2)
    for candidate in (1024, 512, 256, 128):
        if candidate <= base:
            return candidate
    return max(64, height)


def prepare_roblox_face(face_key: str, face_img: Image.Image) -> Image.Image:
    if face_key == "U":
        return face_img.rotate(-90, expand=False)  # 90° clockwise
    if face_key == "D":
        return face_img.rotate(90, expand=False)  # 90° counter-clockwise
    return face_img


def write_dice_preview(faces: dict[str, np.ndarray], output_path: Path) -> None:
    face_w = faces["F"].shape[0]
    canvas = np.zeros((face_w * 3, face_w * 4, faces["F"].shape[2]), dtype=faces["F"].dtype)
    # py360convert dice layout:
    #        U
    #   L  F  R  B
    #        D
    canvas[0:face_w, face_w : face_w * 2] = faces["U"]
    canvas[face_w : face_w * 2, 0:face_w] = faces["L"]
    canvas[face_w : face_w * 2, face_w : face_w * 2] = faces["F"]
    canvas[face_w : face_w * 2, face_w * 2 : face_w * 3] = faces["R"]
    canvas[face_w : face_w * 2, face_w * 3 : face_w * 4] = faces["B"]
    canvas[face_w * 2 : face_w * 3, face_w : face_w * 2] = faces["D"]
    Image.fromarray(canvas).save(output_path)


def main() -> int:
    args = parse_args()
    input_path = Path(args.input).expanduser().resolve()
    if not input_path.exists():
        print(f"Input not found: {input_path}", file=sys.stderr)
        return 1

    image = Image.open(input_path).convert("RGB")
    width, height = image.size
    if width != height * 2:
        print(
            f"Warning: expected 2:1 equirectangular aspect ratio, got {width}x{height}.",
            file=sys.stderr,
        )

    face_size = args.face_size or default_face_size(width, height)
    output_dir = Path(args.output) if args.output else Path("assets/skybox") / input_path.stem
    output_dir = output_dir.expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    equirect = np.array(image)
    cube = py360convert.e2c(equirect, face_w=face_size, mode="bilinear", cube_format="dict")

    manifest_lines = [
        f"source: {input_path}",
        f"source_size: {width}x{height}",
        f"face_size: {face_size}x{face_size}",
        "",
        "Upload these six PNGs in Roblox Studio (Asset Manager bulk import),",
        "then assign to Lighting > Sky:",
        "",
    ]

    for face_key, roblox_name in ROBLOX_FACES.items():
        face = Image.fromarray(cube[face_key])
        face = prepare_roblox_face(face_key, face)
        out_path = output_dir / f"{roblox_name}.png"
        face.save(out_path)
        manifest_lines.append(f"{roblox_name}.png  <- cubemap {face_key}")

    if args.dice:
        write_dice_preview(cube, output_dir / "cubemap_dice_preview.png")
        manifest_lines.append("")
        manifest_lines.append("cubemap_dice_preview.png  (layout preview, not used in Studio)")

    manifest_lines.extend(
        [
            "",
            "Roblox rotations applied:",
            "  SkyboxUp: 90° clockwise",
            "  SkyboxDn: 90° counter-clockwise",
        ]
    )
    (output_dir / "README.txt").write_text("\n".join(manifest_lines) + "\n", encoding="utf-8")

    print(f"Wrote Roblox skybox faces to: {output_dir}")
    for face_key, roblox_name in ROBLOX_FACES.items():
        print(f"  {roblox_name}.png")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
