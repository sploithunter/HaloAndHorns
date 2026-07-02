#!/usr/bin/env python3
"""Batch-render pet FBX exports to transparent PNG previews via Blender.

These are **gameplay viewport renders** from the textured FBX mesh — NOT replacements for
concept art in assets/exports/pets/basic/ and gold/ (Meshy source-of-truth concept PNGs).

Default output (separate tree, both camera views):
  assets/exports/pets/model_renders/front/basic/<stem>.png
  assets/exports/pets/model_renders/front/gold/<stem>.png
  assets/exports/pets/model_renders/hero/basic/<stem>.png
  assets/exports/pets/model_renders/hero/gold/<stem>.png

Camera views:
  front — azimuth 0° (face-on)
  hero  — azimuth 35° (3/4 “hero” angle)

Examples:
  python3 scripts/render_pet_previews.py --dry-run
  python3 scripts/render_pet_previews.py --views front,hero --crop
  python3 scripts/render_pet_previews.py --views hero --only emberfox_gold --crop
  python3 scripts/render_pet_previews.py --views front --only grumpy_cat_basic --crop --contact-sheet
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
EXPORTS = ROOT / "assets/exports/pets"
MODEL_RENDERS = EXPORTS / "model_renders"
BLENDER_SCRIPT = ROOT / "scripts/blender/render_pet_preview.py"
CONTACT_SHEET_SCRIPT = ROOT / "scripts/build_icon_contact_sheet.py"
DEFAULT_BLENDER = Path("/Applications/Blender.app/Contents/MacOS/Blender")

EXPORT_DIR_SKIP = frozenset({"basic", "gold", "model_renders", "_mislabeled_previews"})


@dataclass(frozen=True)
class CameraView:
    name: str
    folder: str
    azimuth: float


VIEWS: dict[str, CameraView] = {
    "front": CameraView(name="front", folder="front", azimuth=0.0),
    "hero": CameraView(name="hero", folder="hero", azimuth=35.0),
}


@dataclass(frozen=True)
class PetExport:
    stem: str
    export_dir: Path
    fbx: Path
    texture: Path | None


@dataclass(frozen=True)
class RenderJob:
    export: PetExport
    view: CameraView
    output: Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Render pet model previews with Blender.")
    parser.add_argument(
        "--exports-dir",
        default=str(EXPORTS),
        help="Root of pet export folders (default: assets/exports/pets)",
    )
    parser.add_argument(
        "--blender",
        default=str(DEFAULT_BLENDER),
        help="Blender executable (override with BLENDER env var)",
    )
    parser.add_argument(
        "--views",
        default="front,hero",
        help="Comma-separated camera views to render (default: front,hero). Choices: front, hero",
    )
    parser.add_argument("--size", type=int, default=1024, help="Square render resolution")
    parser.add_argument("--padding", type=float, default=1.18, help="Camera framing padding")
    parser.add_argument("--elevation", type=float, default=12.0, help="Camera elevation degrees")
    parser.add_argument(
        "--crop",
        action="store_true",
        help="Tight-crop transparent margins after render",
    )
    parser.add_argument(
        "--crop-padding",
        type=int,
        default=8,
        help="Transparent padding after --crop (default: 8px)",
    )
    parser.add_argument(
        "--only",
        help="Comma-separated export folder stems to render (e.g. bear_basic,emberfox_gold)",
    )
    parser.add_argument("--limit", type=int, default=0, help="Max export folders (0 = all)")
    parser.add_argument(
        "--output-root",
        help="Flat override: write <stem>.png here (single-view batches only)",
    )
    parser.add_argument("--force", action="store_true", help="Re-render even if PNG is newer than FBX")
    parser.add_argument("--dry-run", action="store_true", help="Print planned renders only")
    parser.add_argument(
        "--contact-sheet",
        action="store_true",
        help="Build contact_sheet.png in each rendered view folder (basic/ + gold/ PNGs combined)",
    )
    return parser.parse_args()


def parse_views(raw: str) -> list[CameraView]:
    names = [part.strip().lower() for part in raw.split(",") if part.strip()]
    if not names:
        raise ValueError("Provide at least one view in --views")
    views: list[CameraView] = []
    for name in names:
        if name not in VIEWS:
            choices = ", ".join(sorted(VIEWS))
            raise ValueError(f"Unknown view {name!r}; choose from: {choices}")
        views.append(VIEWS[name])
    return views


def pick_fbx(export_dir: Path) -> Path | None:
    for pattern in ("*_5k.fbx", "*_7500tris.fbx", "*_10k.fbx", "*.fbx"):
        hits = sorted(export_dir.glob(pattern))
        if hits:
            return hits[0]
    return None


def pick_texture(export_dir: Path, fbx: Path) -> Path | None:
    stem = fbx.stem
    folder_name = export_dir.name
    for name in (f"{folder_name}.png", f"{stem}.png", f"{stem.replace('_5k', '')}.png"):
        candidate = export_dir / name
        if candidate.is_file():
            return candidate
    pngs = sorted(export_dir.glob("*.png"))
    return pngs[0] if pngs else None


def output_for_stem(stem: str, view: CameraView, output_root: Path | None = None) -> Path:
    if output_root is not None:
        return output_root / f"{stem}.png"
    base = MODEL_RENDERS / view.folder
    if stem.endswith("_basic"):
        return base / "basic" / f"{stem}.png"
    if stem.endswith("_gold"):
        return base / "gold" / f"{stem}.png"
    return base / f"{stem}.png"


def discover(exports_dir: Path, only: set[str] | None) -> list[PetExport]:
    entries: list[PetExport] = []
    for export_dir in sorted(exports_dir.iterdir()):
        if not export_dir.is_dir() or export_dir.name in EXPORT_DIR_SKIP or export_dir.name.startswith("_"):
            continue
        stem = export_dir.name
        if only and stem not in only:
            continue
        fbx = pick_fbx(export_dir)
        if fbx is None:
            continue
        entries.append(
            PetExport(
                stem=stem,
                export_dir=export_dir,
                fbx=fbx,
                texture=pick_texture(export_dir, fbx),
            )
        )
    return entries


def build_jobs(
    exports: list[PetExport],
    views: list[CameraView],
    output_root: Path | None,
) -> list[RenderJob]:
    if output_root is not None and len(views) != 1:
        raise ValueError("--output-root requires exactly one view in --views")
    jobs: list[RenderJob] = []
    for export in exports:
        for view in views:
            jobs.append(
                RenderJob(
                    export=export,
                    view=view,
                    output=output_for_stem(export.stem, view, output_root),
                )
            )
    return jobs


def crop_png(path: Path, padding: int) -> None:
    image = Image.open(path).convert("RGBA")
    bbox = image.getchannel("A").getbbox()
    if not bbox:
        return
    cropped = image.crop(bbox)
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
    cropped.save(path, format="PNG", optimize=True, compress_level=9)


def should_skip(job: RenderJob, force: bool) -> bool:
    if force or not job.output.is_file():
        return False
    return job.output.stat().st_mtime >= job.export.fbx.stat().st_mtime


def render_job(
    blender: Path,
    job: RenderJob,
    *,
    size: int,
    padding: float,
    elevation: float,
    crop: bool,
    crop_padding: int,
) -> None:
    cmd = [
        str(blender),
        "--background",
        "--python",
        str(BLENDER_SCRIPT),
        "--",
        "--input",
        str(job.export.fbx),
        "--output",
        str(job.output),
        "--size",
        str(size),
        "--padding",
        str(padding),
        "--elevation",
        str(elevation),
        "--azimuth",
        str(job.view.azimuth),
    ]
    if job.export.texture is not None:
        cmd.extend(["--texture", str(job.export.texture)])

    subprocess.run(cmd, check=True, cwd=ROOT)
    if crop:
        crop_png(job.output, crop_padding)


def build_view_contact_sheet(view: CameraView) -> None:
    view_dir = MODEL_RENDERS / view.folder
    pngs = sorted(
        p
        for sub in (view_dir / "basic", view_dir / "gold", view_dir)
        if sub.is_dir()
        for p in sub.glob("*.png")
        if p.name != "contact_sheet.png" and p.stat().st_size > 0
    )
    if not pngs:
        return
    staging = view_dir / "_contact_sheet_staging"
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir(parents=True)
    for path in pngs:
        shutil.copy2(path, staging / path.name)
    columns = min(6, max(1, len(pngs)))
    sheet = view_dir / "contact_sheet.png"
    subprocess.run(
        [
            sys.executable,
            str(CONTACT_SHEET_SCRIPT),
            "--rebuild-from",
            str(staging),
            "--contact-sheet",
            str(sheet),
            "--columns",
            str(columns),
            "--thumb-size",
            "400",
        ],
        check=True,
        cwd=ROOT,
    )


def main() -> int:
    args = parse_args()
    exports_dir = Path(args.exports_dir).expanduser().resolve()
    blender = Path(args.blender).expanduser().resolve()
    output_root = Path(args.output_root).expanduser().resolve() if args.output_root else None

    try:
        views = parse_views(args.views)
    except ValueError as error:
        print(error, file=sys.stderr)
        return 1

    if not exports_dir.is_dir():
        print(f"Exports dir not found: {exports_dir}", file=sys.stderr)
        return 1
    if not blender.is_file():
        print(f"Blender not found: {blender}", file=sys.stderr)
        print("Install Blender or set --blender /path/to/Blender", file=sys.stderr)
        return 1
    if not BLENDER_SCRIPT.is_file():
        print(f"Missing Blender script: {BLENDER_SCRIPT}", file=sys.stderr)
        return 1

    only = {part.strip() for part in args.only.split(",") if part.strip()} if args.only else None
    exports = discover(exports_dir, only)
    if args.limit > 0:
        exports = exports[: args.limit]

    if not exports:
        print("No pet export folders with FBX files found.", file=sys.stderr)
        return 1

    jobs = build_jobs(exports, views, output_root)
    todo = [job for job in jobs if not should_skip(job, args.force)]
    skipped = len(jobs) - len(todo)

    view_label = ",".join(v.name for v in views)
    print(
        f"Discovered {len(exports)} export(s) × {len(views)} view(s) [{view_label}]; "
        f"{len(todo)} to render, {skipped} up-to-date."
    )
    if args.dry_run:
        for job in todo:
            tex = job.export.texture.name if job.export.texture else "none"
            print(
                f"  [{job.view.name}] {job.export.stem}\t{job.export.fbx.name}\t{tex}"
                f"\t-> {job.output.relative_to(ROOT)}"
            )
        return 0

    manifest_lines = [
        f"# Pet viewport renders from FBX ({datetime.now(timezone.utc).date().isoformat()})",
        f"# Blender: {blender}",
        f"# views: {view_label}  size: {args.size}  crop: {args.crop}",
        "",
        "view\tstem\tfbx\ttexture\toutput",
    ]
    errors: list[str] = []

    for index, job in enumerate(todo, start=1):
        print(f"[{index}/{len(todo)}] [{job.view.name}] {job.export.stem} ...")
        try:
            render_job(
                blender,
                job,
                size=args.size,
                padding=args.padding,
                elevation=args.elevation,
                crop=args.crop,
                crop_padding=args.crop_padding,
            )
            manifest_lines.append(
                "\t".join(
                    [
                        job.view.name,
                        job.export.stem,
                        str(job.export.fbx.relative_to(ROOT)),
                        str(job.export.texture.relative_to(ROOT)) if job.export.texture else "-",
                        str(job.output.relative_to(ROOT)),
                    ]
                )
            )
        except subprocess.CalledProcessError as error:
            errors.append(f"{job.view.name}:{job.export.stem}")
            print(
                f"  FAILED: [{job.view.name}] {job.export.stem} (exit {error.returncode})",
                file=sys.stderr,
            )

    manifest_path = ROOT / "assets/ui/imports/manifest_pet_blender_renders.txt"
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    if len(manifest_lines) > 4:
        manifest_path.write_text("\n".join(manifest_lines) + "\n", encoding="utf-8")
        print(f"Manifest -> {manifest_path.relative_to(ROOT)}")

    if args.contact_sheet:
        for view in views:
            sheet = MODEL_RENDERS / view.folder / "contact_sheet.png"
            print(f"Contact sheet -> {sheet}")
            build_view_contact_sheet(view)

    if errors:
        print(f"Failed ({len(errors)}): {', '.join(errors)}", file=sys.stderr)
        return 1

    print("Done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
