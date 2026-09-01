#!/usr/bin/env python3
"""Normalize accepted Meshy cannon alpha renders for the workshop UI.

The Meshy retexture outputs are developer-side source artifacts and are intentionally
gitignored. This script promotes exactly one accepted alpha render per cannon tier into
the tracked UI asset set, normalizes every silhouette to the same visual footprint, and
writes provenance/hashes that can be checked without contacting Meshy or Roblox.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
FAMILIES = ("heal", "rage", "debuff", "gravity", "repulsor", "nullifier")
TIERS = range(1, 5)
CANVAS_SIZE = 256
SUBJECT_FILL = 0.78
ALPHA_THRESHOLD = 8
OUTPUT_DIR = ROOT / "assets" / "ui" / "merge_cannons"
QA_PATH = ROOT / "assets" / "qa" / "merge_cannons" / "menu_alpha_contact_sheet.png"
MANIFEST_PATH = ROOT / "scripts" / "merge_cannon_preview_sources.json"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = image.getchannel("A")
    mask = alpha.point(lambda value: 255 if value >= ALPHA_THRESHOLD else 0)
    bbox = mask.getbbox()
    if bbox is None:
        raise ValueError("image contains no visible alpha pixels")
    return bbox


def normalized_preview(source: Path) -> tuple[Image.Image, dict[str, Any]]:
    with Image.open(source) as opened:
        if opened.mode != "RGBA":
            raise ValueError(f"{source}: expected RGBA, got {opened.mode}")
        image = opened.copy()

    alpha_min, alpha_max = image.getchannel("A").getextrema()
    if alpha_min >= 255 or alpha_max <= 0:
        raise ValueError(f"{source}: expected a non-opaque alpha silhouette")

    source_bbox = alpha_bbox(image)
    cropped = image.crop(source_bbox)
    target_extent = round(CANVAS_SIZE * SUBJECT_FILL)
    scale = min(target_extent / cropped.width, target_extent / cropped.height)
    rendered_size = (
        max(1, round(cropped.width * scale)),
        max(1, round(cropped.height * scale)),
    )
    rendered = cropped.resize(rendered_size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    offset = (
        (CANVAS_SIZE - rendered.width) // 2,
        (CANVAS_SIZE - rendered.height) // 2,
    )
    canvas.alpha_composite(rendered, offset)
    output_bbox = alpha_bbox(canvas)
    return canvas, {
        "sourceDimensions": list(image.size),
        "sourceAlphaBoundingBox": list(source_bbox),
        "outputDimensions": [CANVAS_SIZE, CANVAS_SIZE],
        "outputAlphaBoundingBox": list(output_bbox),
        "subjectFill": SUBJECT_FILL,
        "alphaThreshold": ALPHA_THRESHOLD,
    }


def build_contact_sheet(records: list[dict[str, Any]]) -> None:
    tile = 288
    header = 34
    sheet = Image.new("RGB", (tile * 4, (tile + header) * len(FAMILIES)), (19, 24, 34))
    draw = ImageDraw.Draw(sheet)
    checker = 16
    for index, record in enumerate(records):
        row = index // 4
        column = index % 4
        x0 = column * tile + 16
        y0 = row * (tile + header) + header
        for cy in range(0, CANVAS_SIZE, checker):
            for cx in range(0, CANVAS_SIZE, checker):
                color = (54, 61, 73) if (cx // checker + cy // checker) % 2 else (38, 44, 55)
                draw.rectangle((x0 + cx, y0 + cy, x0 + cx + checker - 1, y0 + cy + checker - 1), fill=color)
        with Image.open(ROOT / record["file"]) as preview:
            sheet.paste(preview, (x0, y0), preview)
        draw.text(
            (x0, row * (tile + header) + 9),
            f'{record["family"]} T{record["tier"]}',
            fill=(240, 244, 250),
        )
    QA_PATH.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(QA_PATH, optimize=True)


def build(input_root: Path) -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    records: list[dict[str, Any]] = []
    for family in FAMILIES:
        for tier in TIERS:
            source = input_root / family / f"tier_{tier}" / "textured" / "preview_alpha.png"
            if not source.is_file():
                raise FileNotFoundError(f"missing accepted Meshy alpha render: {source}")
            output = OUTPUT_DIR / f"{family}_tier{tier}.png"
            preview, metrics = normalized_preview(source)
            preview.save(output, optimize=True)
            record = {
                "family": family,
                "tier": tier,
                "source": str(source.relative_to(input_root.parent.parent.parent.parent)),
                "sourceSha256": sha256(source),
                "file": str(output.relative_to(ROOT)),
                "sha256": sha256(output),
                "bytes": output.stat().st_size,
                **metrics,
            }
            records.append(record)
            print(f"{family} tier {tier}: {output.relative_to(ROOT)}")

    manifest = {
        "schemaVersion": 1,
        "status": "COMPLETE",
        "note": (
            "Accepted Meshy retexture alpha renders normalized to a 256px power-of-two canvas. "
            "Each visible silhouette occupies at most 78% of the canvas so tier art stays inside "
            "the artillery workshop card without live ViewportFrames."
        ),
        "canvasSize": [CANVAS_SIZE, CANVAS_SIZE],
        "subjectFill": SUBJECT_FILL,
        "alphaThreshold": ALPHA_THRESHOLD,
        "count": len(records),
        "records": records,
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    build_contact_sheet(records)
    print(f"Wrote {len(records)} previews and {MANIFEST_PATH.relative_to(ROOT)}")


def check() -> None:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    records = manifest.get("records", [])
    if manifest.get("status") != "COMPLETE" or len(records) != 24:
        raise ValueError("cannon preview source manifest is not COMPLETE with 24 records")
    seen: set[tuple[str, int]] = set()
    hashes: set[str] = set()
    for record in records:
        key = (record["family"], int(record["tier"]))
        if key in seen:
            raise ValueError(f"duplicate preview record: {key}")
        seen.add(key)
        path = ROOT / record["file"]
        if not path.is_file() or sha256(path) != record["sha256"]:
            raise ValueError(f"preview hash mismatch: {path}")
        with Image.open(path) as image:
            if image.mode != "RGBA" or image.size != (CANVAS_SIZE, CANVAS_SIZE):
                raise ValueError(f"invalid preview format: {path}")
            bbox = alpha_bbox(image)
            if max(bbox[2] - bbox[0], bbox[3] - bbox[1]) > round(CANVAS_SIZE * SUBJECT_FILL) + 2:
                raise ValueError(f"preview exceeds normalized visual footprint: {path}")
        hashes.add(record["sha256"])
    expected = {(family, tier) for family in FAMILIES for tier in TIERS}
    if seen != expected or len(hashes) != 24:
        raise ValueError("preview coverage or uniqueness check failed")
    print("PASS: 24 unique 256x256 RGBA cannon previews match the normalized source manifest")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("build", "check"))
    parser.add_argument(
        "--input-root",
        type=Path,
        default=ROOT / "assets" / "source" / "props" / "merge_cannons",
    )
    args = parser.parse_args()
    if args.command == "build":
        build(args.input_root.resolve())
    else:
        check()


if __name__ == "__main__":
    main()
