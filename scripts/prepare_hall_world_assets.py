#!/usr/bin/env python3
"""Stage Hall of Worlds bays 2-4 assets from Downloads into canonical repo paths.

This is intentionally a source-preparation step only.  It does not assign pet stats,
rarities, hatch weights, or unlock costs.  Pet card art is converted from an edge-
connected white background to alpha using the repository's established cleanup tool.
"""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DOWNLOADS = Path.home() / "Downloads"
PET_SOURCE = ROOT / "assets/source/references/pets"
EGG_SOURCE = ROOT / "assets/source/eggs"
HALL_THUMBNAILS = ROOT / "assets/exports/hall_world/thumbnails"
CLEANER = ROOT / "scripts/remove_image_background.py"


PETS = {
    "keytail_raccoon": {
        "basic": "Meshy_AI_Keytail_Raccoon_0819005111_texture.glb",
        "gold": "Meshy_AI_Keytail_Raccoon_0819010045_texture.glb",
        "basic_png": "keytail_raccoon.png",
        "gold_png": "keytail_raccoon_gold.png",
    },
    "vault_beetle": {
        "basic": "Meshy_AI_vault_bettle_0819005125_texture.glb",
        "gold": "Meshy_AI_vault_bettle_0819010040_texture.glb",
        "basic_png": "vault_beetle.png",
        "gold_png": "vault_bettle_gold.png",
    },
    "crownwing_falcon": {
        "basic": "Meshy_AI_crowning_falcon_0819005140_texture.glb",
        "gold": "Meshy_AI_crowning_falcon_0819010036_texture.glb",
        "basic_png": "crowning_falcon.png",
        "gold_png": "crowning_falcon_gold.png",
    },
    "fortune_wisp": {
        "basic": "Meshy_AI_fortune_wisp_0819005155_texture.glb",
        "gold": "Meshy_AI_fortune_wisp_0819010031_texture.glb",
        "basic_png": "fortune_wisp.png",
        "gold_png": "fortune_wisp_gold.png",
    },
    "lockbox_imp": {
        "basic": "Meshy_AI_lockbox_imp_0819005220_texture.glb",
        "gold": "Meshy_AI_lockbox_imp_0819010025_texture.glb",
        "basic_png": "lockbox_imp.png",
        "gold_png": "lockbox_imp_gold.png",
    },
    "blade_lynx": {
        "basic": "Meshy_AI_blade_lynx_0819005251_texture.glb",
        "gold": "Meshy_AI_blade_lynx_0819010020_texture.glb",
        "basic_png": "blade_lynx.png",
        "gold_png": "blade_lynx_gold.png",
    },
    "bastion_ram": {
        "basic": "Meshy_AI_bastion_ram_0819005307_texture.glb",
        "gold": "Meshy_AI_bastion_ram_0819010016_texture.glb",
        "basic_png": "bastion_ram.png",
        "gold_png": "bastion_ram_gold.png",
    },
    "bolt_hawk": {
        "basic": "Meshy_AI_bolt_hawk_0819005322_texture.glb",
        "gold": "Meshy_AI_bolt_hawk_0819010010_texture.glb",
        "basic_png": "bolt_hawk.png",
        "gold_png": "bolt_hawk_gold.png",
    },
    "banner_hare": {
        "basic": "Meshy_AI_banner_hare_0819005345_texture.glb",
        "gold": "Meshy_AI_banner_hare_0819010004_texture.glb",
        "basic_png": "banner_hare.png",
        "gold_png": "banner_hare_gold.png",
    },
    "chain_serpent": {
        "basic": "Meshy_AI_chain_serpent_0819005943_texture.glb",
        "gold": "Meshy_AI_chain_serpent_0819005949_texture.glb",
        "basic_png": "chain_serpent.png",
        "gold_png": "chain_serpent_gold.png",
    },
    "rift_panther": {
        "basic": "Meshy_AI_rift_panther_0819044331_texture.glb",
        "gold": "Meshy_AI_rift_panther_0819044356_texture.glb",
        "basic_png": "rift_panther.png",
        "gold_png": "rift_panther_gold.png",
    },
    "atlas_golem": {
        "basic": "Meshy_AI_atlas_golem_0819044338_texture.glb",
        "gold": "Meshy_AI_atlas_golem_0819044400_texture.glb",
        "basic_png": "atlas_golem.png",
        "gold_png": "atlas_golem_gold.png",
    },
    "portal_drake": {
        "basic": "Meshy_AI_portal_drake_0819044342_texture.glb",
        "gold": "Meshy_AI_portal_drake_0819044404_texture.glb",
        "basic_png": "portal_drake.png",
        "gold_png": "portal_drake_gold.png",
    },
    "star_moth": {
        "basic": "Meshy_AI_star_moth_0819044347_texture.glb",
        # No separate gold GLB was delivered as of 2026-08-18.
        "basic_png": "star_moth.png",
        "gold_png": "star_moth_gold.png",
    },
    "clockwork_spider": {
        "basic": "Meshy_AI_clockwork_spider_0819044352_texture.glb",
        "gold": "Meshy_AI_clockwork_spider_0819044409_texture.glb",
        "basic_png": "clockwork_spider.png",
        "gold_png": "clockwork_spider_gold.png",
    },
}


EGGS = {
    # Canonical key avoids colliding with the existing Heaven Desert `gilded_egg`.
    "hall_gilded_egg": {
        "glb": "Meshy_AI_guilded_egg_0819003927_texture.glb",
        "png": "guilded_egg.png",
    },
    "vanguard_egg": {
        "glb": "Meshy_AI_vanguard_egg_0819003944_texture.glb",
        "png": "vanguard_egg.png",
    },
    "worldheart_egg": {
        "glb": "Meshy_AI_worldheart_egg_0819004005_texture.glb",
        "png": "worldheart_egg.png",
    },
}


def require(path: Path) -> Path:
    if not path.is_file():
        raise FileNotFoundError(path)
    return path


def copy(source_name: str, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(require(DOWNLOADS / source_name), destination)
    print(f"staged {destination.relative_to(ROOT)}")


def clean(source_name: str, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            "python3",
            str(CLEANER),
            str(require(DOWNLOADS / source_name)),
            str(destination),
            "--mode",
            "edge-white",
        ],
        check=True,
    )


def main() -> None:
    for pet, files in PETS.items():
        for variant in ("basic", "gold"):
            glb = files.get(variant)
            png = files.get(f"{variant}_png")
            if glb:
                copy(glb, PET_SOURCE / f"{pet}_{variant}.glb")
            elif variant == "gold":
                print(f"WARNING: {pet}_gold has thumbnail art but no delivered gold GLB")
            if png:
                canonical_thumbnail = PET_SOURCE / f"{pet}_{variant}.png"
                clean(png, canonical_thumbnail)
                HALL_THUMBNAILS.mkdir(parents=True, exist_ok=True)
                shutil.copy2(canonical_thumbnail, HALL_THUMBNAILS / canonical_thumbnail.name)

    for egg, files in EGGS.items():
        copy(files["glb"], EGG_SOURCE / f"{egg}.glb")
        clean(files["png"], EGG_SOURCE / f"{egg}.png")


if __name__ == "__main__":
    main()
