#!/usr/bin/env python3
"""Build compact transparent card art for pet families missing flat inventory thumbnails.

The heavy source art intentionally lives outside git's tracked build inputs.  This helper turns the
existing local PNG renders into 256px, transparent, tightly framed card images under /tmp, ready for
the group-owned Open Cloud uploader. White-background concept renders use foreground matting so
white pets keep their silhouettes and interior detail; already-transparent Hall art is preserved.

Colorado and Kade are packaged Roblox Models rather than local Meshy exports.  Their public Roblox
model thumbnails are downloaded from the thumbnail service and pass through the same crop/scale
pipeline.  Creator Colorado deliberately reuses Colorado's two images because both species share
the same model assets in configs/pets.lua.
"""

from __future__ import annotations

import argparse
import io
import json
import math
import urllib.parse
import urllib.request
from pathlib import Path

from PIL import Image

try:
    from rembg import new_session, remove
except ImportError as error:  # pragma: no cover - exercised by the operator-facing error path
    raise SystemExit(
        "rembg is required for the white-background source renders. "
        "Install it in a temporary venv with: pip install 'rembg[cpu]==2.0.50' Pillow"
    ) from error


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = Path("/tmp/halo_horns_pet_thumbnails_256")
CARD_SIZE = 256
CONTENT_SIZE = 224

INFERNAL = ("wyrmling", "obsidian_hound", "cinder_golemite", "ashwing", "cerberus_pup")
CELESTIAL = ("lumen_dove", "archon_spark", "cloudling", "halo_fawn", "seraph_kit")
HOME = (
    "emberling",
    "emberfox",
    "emberimp",
    "emberowl",
    "emberlion",
    "snowflakeowl",
    "snowfox",
    "penguin",
    "snowleopard",
    "polarbear",
    "fennec",
    "camel",
    "meerkat",
    "desertiguana",
    "scorpion",
)
HALL = (
    "keytail_raccoon",
    "vault_beetle",
    "crownwing_falcon",
    "fortune_wisp",
    "lockbox_imp",
    "blade_lynx",
    "bastion_ram",
    "bolt_hawk",
    "banner_hare",
    "chain_serpent",
    "rift_panther",
    "atlas_golem",
    "portal_drake",
    "star_moth",
    "clockwork_spider",
)
LAYER_3 = (
    "ash_ibis",
    "bloom_ibis",
    "bloomlight_sprite",
    "celestial_moth",
    "dread_hart",
    "dread_mongoose",
    "dread_wisp",
    "dreadbloom_sprite",
    "dreadcinder_imp",
    "dreadfire_hawk",
    "dreadglass_dragon",
    "dreadguard_bear",
    "dreadlance_seraph",
    "dreadspire_mammoth",
    "dreadthorn_grovekeeper",
    "dreadveil_moth",
    "duskfrost_seal",
    "empyrean_firehawk",
    "empyrean_grovekeeper",
    "empyrean_mammoth",
    "glory_mongoose",
    "gloryleaf_lamb",
    "gloryscale_salamander",
    "gloryspark_cherub",
    "halo_bear",
    "halo_hart",
    "halo_wisp",
    "ironbark_rhino",
    "light_tortoise",
    "lightbark_rhino",
    "lumen_seal",
    "oasis_dragon",
    "obsidian_tortoise",
    "obsidian_totem",
    "radiant_lance_seraph",
    "radiant_totem",
    "ruinmane_lion",
    "ruinscale_salamander",
    "seraph_lion",
    "thornleaf_lamb",
)

CREATOR_MODEL_ASSETS = {
    "colorado_basic": 100466492312776,
    "colorado_gold": 121192248833075,
    "kade_basic": 107161152905013,
    "kade_gold": 139643909402590,
}


def source_for(family: str, variant: str) -> Path:
    suffix = "gold" if variant == "gold" else "basic"
    if family in INFERNAL:
        stem = f"{family}_gold.png" if variant == "gold" else f"{family}.png"
        return ROOT / "assets/source/pets/source_images/infernal_egg" / stem
    if family in CELESTIAL:
        stem = f"{family}_gold.png" if variant == "gold" else f"{family}.png"
        return ROOT / "assets/source/pets/source_images/celestial_egg" / stem
    if family in HOME:
        return ROOT / "assets/exports/pets" / suffix / f"{family}_{suffix}.png"
    if family in HALL:
        return ROOT / "assets/exports/hall_world/thumbnails" / f"{family}_{suffix}.png"
    if family in LAYER_3:
        card_variant = "gold" if variant == "gold" else "basic"
        return (
            ROOT
            / "assets/concepts/layer_3_pets/cards"
            / card_variant
            / f"{family}_{card_variant}.png"
        )
    raise KeyError(f"No source mapping for {family}/{variant}")


def fetch_creator_thumbnails() -> dict[str, Image.Image]:
    ids = ",".join(str(value) for value in CREATOR_MODEL_ASSETS.values())
    query = urllib.parse.urlencode(
        {
            "assetIds": ids,
            "returnPolicy": "PlaceHolder",
            "size": "420x420",
            "format": "Png",
            "isCircular": "false",
        }
    )
    with urllib.request.urlopen(f"https://thumbnails.roblox.com/v1/assets?{query}") as response:
        payload = json.load(response)
    urls = {int(record["targetId"]): record["imageUrl"] for record in payload.get("data", [])}
    result: dict[str, Image.Image] = {}
    for stem, asset_id in CREATOR_MODEL_ASSETS.items():
        url = urls.get(asset_id)
        if not url:
            raise RuntimeError(f"Roblox returned no thumbnail URL for model {asset_id}")
        with urllib.request.urlopen(url) as response:
            result[stem] = Image.open(io.BytesIO(response.read())).convert("RGBA")
    return result


def has_useful_alpha(image: Image.Image) -> bool:
    if "A" not in image.getbands():
        return False
    lo, hi = image.getchannel("A").getextrema()
    return lo < 250 and hi > 0


_MATTING_SESSION = None


def remove_background(image: Image.Image) -> Image.Image:
    """Matte a rendered pet without erasing white fur, feathers, or highlights."""

    global _MATTING_SESSION
    if _MATTING_SESSION is None:
        # u2netp is the compact, deterministic local model. It is sufficient for centered pet
        # renders and avoids making this one-time asset build unnecessarily expensive.
        _MATTING_SESSION = new_session("u2netp")
    return remove(
        image.convert("RGB"),
        session=_MATTING_SESSION,
        alpha_matting=True,
        alpha_matting_foreground_threshold=245,
        alpha_matting_background_threshold=10,
        alpha_matting_erode_size=5,
    ).convert("RGBA")


def compact_card(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    if not has_useful_alpha(rgba):
        rgba = remove_background(rgba)
    alpha = rgba.getchannel("A")
    bbox = alpha.getbbox()
    if not bbox:
        raise RuntimeError("source image became fully transparent")
    cropped = rgba.crop(bbox)
    scale = min(CONTENT_SIZE / cropped.width, CONTENT_SIZE / cropped.height, 1.0)
    size = (
        max(1, math.floor(cropped.width * scale + 0.5)),
        max(1, math.floor(cropped.height * scale + 0.5)),
    )
    if cropped.size != size:
        cropped = cropped.resize(size, Image.Resampling.LANCZOS)
    card = Image.new("RGBA", (CARD_SIZE, CARD_SIZE), (0, 0, 0, 0))
    card.alpha_composite(cropped, ((CARD_SIZE - size[0]) // 2, (CARD_SIZE - size[1]) // 2))
    return card


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    manifest: dict[str, dict[str, object]] = {}
    for family in (*INFERNAL, *CELESTIAL, *HOME, *HALL, *LAYER_3):
        for variant in ("basic", "gold"):
            source = source_for(family, variant)
            if not source.is_file():
                raise FileNotFoundError(source)
            stem = f"{family}_{variant}"
            output = args.out / f"{stem}.png"
            compact_card(Image.open(source)).save(output, optimize=True)
            manifest[stem] = {"source": str(source), "output": str(output)}

    creators = fetch_creator_thumbnails()
    for stem, image in creators.items():
        output = args.out / f"{stem}.png"
        compact_card(image).save(output, optimize=True)
        manifest[stem] = {
            "source": f"roblox-model:{CREATOR_MODEL_ASSETS[stem]}",
            "output": str(output),
        }

    manifest_path = args.out / "sources.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"wrote {len(manifest)} compact thumbnails to {args.out}")


if __name__ == "__main__":
    main()
