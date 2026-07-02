#!/usr/bin/env python3
"""Import pet model images and build labeled master contact sheets.

Primary source: ~/Downloads/PetImages/Basic and ~/Downloads/PetImages/Gold.
Expected filenames: {pet_id}_basic.png and {pet_id}_gold.png (e.g. bear_basic.png).
Basic supplements missing safari / preview pets from tracked repo assets.
"""

from __future__ import annotations

import argparse
import math
import re
import shutil
from dataclasses import dataclass
from pathlib import Path

from datetime import date

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
PETS_CONFIG = ROOT / "configs/pets.lua"
ENEMIES_CONFIG = ROOT / "configs/enemies.lua"
EXPORTS_PETS = ROOT / "assets/exports/pets"
OUT_DIR = ROOT / "assets/exports/pets/basic"
SHEET_PATH = ROOT / "assets/exports/pets/basic_models_contact_sheet.png"
GOLD_OUT_DIR = ROOT / "assets/exports/pets/gold"
GOLD_SHEET_PATH = ROOT / "assets/exports/pets/gold_models_contact_sheet.png"

# Homeworld grass/earth starter pets (pre–new-import-process art). Shown under "Pets Home".
PETS_HOME_IDS = frozenset({"bear", "bunny", "doggy", "kitty"})
HOMEWORLD_GRASS_PETS = PETS_HOME_IDS | frozenset({"colorado", "colorado_creator"})
SPECIAL_ONE_OFF_PETS = frozenset({"dragon", "colorado", "colorado_creator"})
CATALOG_ORIGINS = ("Grass", "Lava", "Ice", "Desert")
ORIGIN_ALIASES = {
    "lava": "Lava",
    "ember": "Lava",
    "fire": "Lava",
    "solar": "Lava",
    "ice": "Ice",
    "aurora": "Ice",
    "grass": "Grass",
    "earth": "Grass",
    "bloom": "Grass",
    "meadow": "Grass",
    "forest": "Grass",
    "desert": "Desert",
    "sand": "Desert",
}
ENEMY_SKIP = frozenset({"training_dummy"})
# Stems that need a viewport PNG at assets/exports/pets/basic/{stem}_basic.png.
# The matching export dir also holds {stem}.png — that file is the MESH TEXTURE for FBX upload,
# not a contact-sheet preview (see manifest_2026-06-14_pet_models.txt vs desert batch).
EARTH_ENEMY_PREVIEW_STEMS = (
    "cube_dog",
    "raven",
    "grumpy_cat",
    "jackalope",
)
# Enemy config id -> exported mesh stem; preview PNG must live at basic/{stem}_basic.png.
ENEMY_PREVIEW_STEMS: dict[str, str] = {
    "rabid_dog": "cube_dog",
    "murder_crow": "raven",
    "vicious_cat": "grumpy_cat",
    "rabid_bunny": "jackalope",
    "raging_bear": "bear",
    "dire_bear": "bear",
    "sand_jackal": "sand_jackal",
    "carrion_vulture": "carrion_vulture",
    "golden_scarab": "golden_scarab",
    "dune_tortoise": "dune_tortoise",
    "sand_scorpion": "sand_scorpion",
    "frost_fox": "frost_fox",
    "snowy_owl": "snowy_owl",
    "aurora_seal": "aurora_seal",
    "glacial_mammoth": "glacial_mammoth",
    "glacial_leviathan": "glacial_leviathan",
    "lava_imp": "cinder_whelp",
    "ember_brute": "molten_rhino",
    "ember_acolyte": "ember_moth",
    "infernal_boss": "magma_wyrm",
}

# Fallback repo assets when a pet is not in the Downloads Basic folder.
SUPPLEMENTS: dict[str, list[Path]] = {
    "cobra": [ROOT / "assets/source/references/pets/cobra_basic.png"],
    "elephant": [
        ROOT / "assets/exports/pets/elephant_basic_preview.png",
        ROOT / "assets/source/references/pets/elephant_basic.png",
    ],
    "giraffe": [ROOT / "assets/source/references/pets/giraffe_basic.png"],
    "hippo": [ROOT / "assets/source/references/pets/hippo_basic.png"],
    "lion": [ROOT / "assets/source/references/pets/lion_basic.png"],
    "rhino": [ROOT / "assets/source/references/pets/rhino_basic.png"],
    "tiger": [ROOT / "assets/source/references/pets/tiger_basic.png"],
    "water_buffalo": [ROOT / "assets/source/references/pets/water_buffalo_basic.png"],
    "zebra": [
        ROOT / "assets/exports/pets/zebra_basic_preview.png",
        ROOT / "assets/source/references/pets/zebra_basic.png",
    ],
}

PET_SECTIONS: list[tuple[str, list[str]]] = [
    ("Starter", ["bear", "bunny", "doggy", "dragon", "kitty", "colorado"]),
    ("Lava", ["emberling", "emberfox", "emberimp", "emberowl", "emberlion"]),
    ("Ice", ["snowflakeowl", "snowfox", "penguin", "snowleopard", "polarbear"]),
    ("Desert", ["fennec", "camel", "meerkat", "desertiguana", "scorpion"]),
    (
        "Safari",
        [
            "cobra",
            "elephant",
            "giraffe",
            "hippo",
            "lion",
            "rhino",
            "tiger",
            "water_buffalo",
            "zebra",
        ],
    ),
    ("Guardians", ["colossus", "djinn"]),
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build basic pet model contact sheet.")
    parser.add_argument(
        "--basic-dir",
        default=str(Path.home() / "Downloads/PetImages/Basic"),
        help="Folder with basic pet model PNGs (default: ~/Downloads/PetImages/Basic)",
    )
    parser.add_argument(
        "--output-dir",
        default=str(OUT_DIR),
        help="Where to copy normalized {pet}_basic.png files",
    )
    parser.add_argument(
        "--gold-dir",
        default=str(Path.home() / "Downloads/PetImages/Gold"),
        help="Folder with golden pet model PNGs (default: ~/Downloads/PetImages/Gold)",
    )
    parser.add_argument(
        "--sheet",
        default=str(SHEET_PATH),
        help="Basic master contact sheet output path",
    )
    parser.add_argument(
        "--gold-sheet",
        default=str(GOLD_SHEET_PATH),
        help="Golden master contact sheet output path",
    )
    parser.add_argument(
        "--basic-only",
        action="store_true",
        help="Build only the basic contact sheet",
    )
    parser.add_argument("--columns", type=int, default=6)
    parser.add_argument("--thumb-size", type=int, default=280)
    parser.add_argument("--label-height", type=int, default=44)
    parser.add_argument("--padding", type=int, default=20)
    parser.add_argument("--section-gap", type=int, default=12)
    parser.add_argument(
        "--from-config",
        action="store_true",
        help="Build contact sheets for all pets in configs/pets.lua using repo preview PNGs",
    )
    parser.add_argument(
        "--config",
        default=str(PETS_CONFIG),
        help="Pet config path for --from-config (default: configs/pets.lua)",
    )
    parser.add_argument(
        "--basic-too",
        action="store_true",
        help="With --from-config, also build the basic contact sheet (gold only by default)",
    )
    parser.add_argument(
        "--combined",
        action="store_true",
        help="With --from-config, build a combined basic+gold sheet (same 2×5 taxonomy; enemies basic-only)",
    )
    parser.add_argument(
        "--skip-pet",
        action="append",
        default=[],
        metavar="ID",
        help="Extra pet ids to omit (defaults skip homeworld grass starters)",
    )
    parser.add_argument(
        "--no-enemies",
        action="store_true",
        help="With --from-config, omit combat enemies from the catalog sheet",
    )
    parser.add_argument(
        "--include-pets-home",
        action="store_true",
        help="Include Pets Home block (bear/bunny/doggy/kitty) on the catalog sheet",
    )
    parser.add_argument(
        "--block-columns",
        type=int,
        default=2,
        help="Pets per block column for --from-config layout (default: 2 columns of 5)",
    )
    parser.add_argument(
        "--block-rows",
        type=int,
        default=5,
        help="Rows per block column for --from-config layout (default: 5)",
    )
    parser.add_argument(
        "--pair-stacks",
        type=int,
        default=2,
        help="How many vertical stacks of paired section blocks (default: 2, halves sheet height)",
    )
    return parser.parse_args()


@dataclass(frozen=True)
class GamePet:
    pet_id: str
    display_name: str
    category: str
    realm: str | None
    origin: str | None
    section: str


@dataclass(frozen=True)
class GameEnemy:
    enemy_id: str
    display_name: str
    role: str
    section: str


@dataclass(frozen=True)
class CatalogEntry:
    entry_id: str
    label: str
    section: str
    preview_variant: str
    preview_stem: str | None = None
    has_gold: bool = True


def pet_to_entry(pet: GamePet, variant: str, section_label: str | None = None) -> CatalogEntry:
    return CatalogEntry(
        entry_id=pet.pet_id,
        label=pet.pet_id,
        section=section_label or pet.section,
        preview_variant=variant,
    )


def enemy_to_entry(enemy: GameEnemy) -> CatalogEntry:
    return CatalogEntry(
        entry_id=enemy.enemy_id,
        label=enemy.enemy_id,
        section=enemy.section,
        preview_variant="basic",
        preview_stem=ENEMY_PREVIEW_STEMS.get(enemy.enemy_id, enemy.enemy_id),
        has_gold=False,
    )


def is_section_header(line: str, label: str) -> bool:
    if not label or label.startswith("="):
        return False
    if re.search(r"={3,}", line):
        return True
    if label.startswith("---"):
        return True
    if "FAMILY" in label.upper():
        return True
    if re.match(r"heaven 2 ·", label, re.I):
        return True
    if re.match(r"hell 2 ·", label, re.I):
        return True
    if re.match(r"HEAVEN 1 ROSTER|LAYER 2|REALM PETS", label, re.I):
        return True
    if re.match(r"--- HEAVEN ", label, re.I):
        return True
    if re.match(
        r"Heaven Desert origin|Hell (Fire|Desert|Ice|Earth) origin",
        label,
        re.I,
    ):
        return True
    return False


def parse_game_pets(config_path: Path) -> list[GamePet]:
    text = config_path.read_text(encoding="utf-8")
    match = re.search(r"\n\s+pets\s*=\s*\{", text)
    if not match:
        raise ValueError(f"No pets table found in {config_path}")

    start = match.end()
    depth = 1
    index = start
    while index < len(text) and depth:
        if text[index] == "{":
            depth += 1
        elif text[index] == "}":
            depth -= 1
        index += 1
    block = text[start : index - 1]

    current_section = "Pets"
    pets: list[GamePet] = []
    for line in block.splitlines():
        comment = re.match(r"\s*--\s*(=+)?\s*(.*?)\s*(=+)?\s*$", line)
        if comment and comment.group(2):
            label = comment.group(2).strip()
            if is_section_header(line, label):
                current_section = label
            continue

        pet_match = re.match(r"^\s{8}([a-z][a-z0-9_]*)\s*=\s*\{", line)
        if not pet_match:
            continue

        pet_id = pet_match.group(1)
        offset = block.find(line)
        chunk = block[offset : offset + 1200]

        def grab(key: str) -> str | None:
            field = re.search(rf"{key}\s*=\s*\"([^\"]+)\"", chunk)
            return field.group(1) if field else None

        pets.append(
            GamePet(
                pet_id=pet_id,
                display_name=grab("display_name") or pet_id,
                category=grab("category") or "?",
                realm=grab("realm"),
                origin=grab("origin"),
                section=current_section,
            )
        )
    return pets


def is_enemy_section_header(line: str, label: str) -> bool:
    return bool(re.search(r"={3,}", line) and re.search(r"\bFACTION\b", label.upper()))


def parse_enemies(config_path: Path) -> list[GameEnemy]:
    text = config_path.read_text(encoding="utf-8")
    match = re.search(r"\n\s+enemies\s*=\s*\{", text)
    if not match:
        raise ValueError(f"No enemies table found in {config_path}")

    start = match.end()
    depth = 1
    index = start
    while index < len(text) and depth:
        if text[index] == "{":
            depth += 1
        elif text[index] == "}":
            depth -= 1
        index += 1
    block = text[start : index - 1]

    current_section = "Enemies"
    enemies: list[GameEnemy] = []
    for line in block.splitlines():
        comment = re.match(r"\s*--\s*(=+)?\s*(.*?)\s*(=+)?\s*$", line)
        if comment and comment.group(2):
            label = comment.group(2).strip()
            if is_enemy_section_header(line, label):
                current_section = label
            continue

        enemy_match = re.match(r"^\s{8}([a-z][a-z0-9_]*)\s*=\s*\{", line)
        if not enemy_match:
            continue

        enemy_id = enemy_match.group(1)
        if enemy_id in ENEMY_SKIP:
            continue
        offset = block.find(line)
        chunk = block[offset : offset + 800]
        role_match = re.search(r'role\s*=\s*"([^"]+)"', chunk)
        name_match = re.search(r'display_name\s*=\s*"([^"]+)"', chunk)
        enemies.append(
            GameEnemy(
                enemy_id=enemy_id,
                display_name=name_match.group(1) if name_match else enemy_id,
                role=role_match.group(1) if role_match else "?",
                section=current_section,
            )
        )
    return enemies


def preview_path(pet_id: str, variant: str) -> Path | None:
    """Return a viewport/contact-sheet PNG, never a mesh UV texture from an export folder."""
    suffix = "basic" if variant == "basic" else "gold"
    token = f"{pet_id}_{suffix}"
    candidates = [
        EXPORTS_PETS / suffix / f"{token}.png",
        EXPORTS_PETS / f"{pet_id}_{suffix}_preview.png",
        ROOT / f"assets/source/references/pets/{token}.png",
    ]
    if variant == "basic":
        candidates.extend(SUPPLEMENTS.get(pet_id, []))
    return first_existing(candidates)


def mesh_texture_path(pet_id: str, variant: str = "basic") -> Path | None:
    """FBX mesh texture co-located with decimated exports (not for contact sheets)."""
    token = f"{pet_id}_{variant}"
    candidates = [
        EXPORTS_PETS / f"{pet_id}_{variant}" / f"{token}.png",
    ]
    hit = first_existing(candidates)
    if hit is not None:
        return hit
    for path in sorted(EXPORTS_PETS.rglob(f"{token}.png")):
        if path.is_file() and ".fbm" not in path.parts:
            return path
    return None


def catalog_preview_path(entry: CatalogEntry) -> Path | None:
    stem = entry.preview_stem or entry.entry_id
    return preview_path(stem, entry.preview_variant)


def catalog_basic_gold_paths(entry: CatalogEntry) -> tuple[Path | None, Path | None]:
    stem = entry.preview_stem or entry.entry_id
    basic = preview_path(stem, "basic")
    gold = preview_path(stem, "gold") if entry.has_gold else None
    return basic, gold


def group_entries_by_section(
    entries: list[CatalogEntry],
) -> list[tuple[str, list[CatalogEntry]]]:
    groups: list[tuple[str, list[CatalogEntry]]] = []
    for entry in entries:
        if groups and groups[-1][0] == entry.section:
            groups[-1][1].append(entry)
        else:
            groups.append((entry.section, [entry]))
    return groups


def group_pets_by_section(pets: list[GamePet], skip: frozenset[str]) -> list[tuple[str, list[GamePet]]]:
    groups: list[tuple[str, list[GamePet]]] = []
    for pet in pets:
        if pet.pet_id in skip:
            continue
        if groups and groups[-1][0] == pet.section:
            groups[-1][1].append(pet)
        else:
            groups.append((pet.section, [pet]))
    return groups


def pop_matching_group(
    groups: list[tuple[str, list[CatalogEntry]]],
    predicate,
) -> tuple[str, list[CatalogEntry]] | None:
    for index, group in enumerate(groups):
        if predicate(group[0]):
            return groups.pop(index)
    return None


def pair_enemy_faction_groups(
    groups: list[tuple[str, list[CatalogEntry]]],
) -> list[tuple[tuple[str, list[CatalogEntry]] | None, tuple[str, list[CatalogEntry]] | None]]:
    remaining = list(groups)
    rows: list[tuple[tuple[str, list[CatalogEntry]] | None, tuple[str, list[CatalogEntry]] | None]] = []
    for left_key, right_key in (("earth", "desert"), ("ice", "lava")):
        left = pop_matching_group(remaining, lambda name, key=left_key: key in name.lower())
        right = pop_matching_group(remaining, lambda name, key=right_key: key in name.lower())
        if left or right:
            rows.append((left, right))
    while remaining:
        left = remaining.pop(0)
        right = remaining.pop(0) if remaining else None
        rows.append((left, right))
    return rows


def pair_section_groups(
    groups: list[tuple[str, list[CatalogEntry]]],
) -> list[tuple[tuple[str, list[CatalogEntry]] | None, tuple[str, list[CatalogEntry]] | None]]:
    remaining = list(groups)
    rows: list[tuple[tuple[str, list[CatalogEntry]] | None, tuple[str, list[CatalogEntry]] | None]] = []

    for element in ("fire", "ice", "grass", "desert"):
        heaven = pop_matching_group(
            remaining,
            lambda name, el=element: "heaven 2" in name.lower() and el in name.lower(),
        )
        hell = pop_matching_group(
            remaining,
            lambda name, el=element: "hell 2" in name.lower() and el in name.lower(),
        )
        if heaven or hell:
            rows.append((heaven, hell))

    ember = pop_matching_group(remaining, lambda name: "EMBER FAMILY" in name.upper())
    ice = pop_matching_group(remaining, lambda name: "ICE FAMILY" in name.upper())
    if ember or ice:
        rows.append((ember, ice))

    sand = pop_matching_group(remaining, lambda name: "SAND FAMILY" in name.upper())
    if sand:
        rows.append((sand, None))

    heaven1_elements = ("FIRE", "ICE", "GRASS")
    for element in heaven1_elements:
        heaven = pop_matching_group(
            remaining,
            lambda name, el=element: f"HEAVEN {el}" in name.upper(),
        )
        hell = pop_matching_group(
            remaining,
            lambda name, el=element: f"HELL {el}" in name.upper(),
        )
        if heaven or hell:
            rows.append((heaven, hell))

    while remaining:
        left = remaining.pop(0)
        right = remaining.pop(0) if remaining else None
        rows.append((left, right))

    return rows


def origin_from_section(section: str) -> str | None:
    upper = section.upper()
    if re.search(r"HEAVEN 2 · FIRE|HELL 2 · FIRE", upper):
        return "Lava"
    if re.search(r"HEAVEN 2 · ICE|HELL 2 · ICE", upper):
        return "Ice"
    if re.search(r"HEAVEN 2 · GRASS|HELL 2 · GRASS", upper):
        return "Grass"
    if re.search(r"HEAVEN 2 · DESERT|HELL 2 · DESERT", upper):
        return "Desert"
    if "HEAVEN FIRE" in upper or "HELL FIRE ORIGIN" in upper:
        return "Lava"
    if "HEAVEN ICE" in upper or "HELL ICE ORIGIN" in upper:
        return "Ice"
    if "HEAVEN GRASS" in upper or "HELL EARTH ORIGIN" in upper:
        return "Grass"
    if "HEAVEN DESERT ORIGIN" in upper or "HELL DESERT ORIGIN" in upper:
        return "Desert"
    if re.search(r"\bEMBER FAMILY\b", upper):
        return "Lava"
    if re.search(r"\bICE FAMILY\b", upper):
        return "Ice"
    if re.search(r"\bSAND FAMILY\b", upper):
        return "Desert"
    if re.search(r"\bBEAR FAMILY\b|\bBUNNY FAMILY\b", upper):
        return "Grass"
    return None


def classify_pet(pet: GamePet) -> tuple[str, str | None]:
    """Map a pet to (layer-or-special-bucket, origin)."""
    if pet.pet_id in SPECIAL_ONE_OFF_PETS:
        return ("Special One-Off Pets", None)
    if pet.pet_id in PETS_HOME_IDS:
        return ("Pets Home", "Grass")

    section = pet.section
    section_lower = section.lower()
    if "heaven 2 ·" in section_lower:
        layer = "Heaven2"
    elif "hell 2 ·" in section_lower:
        layer = "Hell2"
    elif pet.realm == "heaven":
        layer = "Heaven1"
    elif pet.realm == "hell":
        layer = "Hell1"
    else:
        layer = "Home"

    if pet.origin:
        origin = ORIGIN_ALIASES.get(pet.origin, pet.origin.title())
    else:
        origin = origin_from_section(section)
    if not origin and pet.category:
        origin = ORIGIN_ALIASES.get(pet.category)
    return (layer, origin)


def catalog_block(
    layer: str,
    origin: str,
    entries: list[CatalogEntry],
) -> tuple[str, list[CatalogEntry]] | None:
    if not entries:
        return None
    return (f"{layer} · {origin}", entries)


def build_taxonomy_pair_rows(
    pets: list[GamePet],
    *,
    skip_sheet: frozenset[str],
    variant: str,
    include_enemies: bool,
    include_pets_home: bool,
) -> list[tuple[tuple[str, list[CatalogEntry]] | None, tuple[str, list[CatalogEntry]] | None]]:
    buckets: dict[tuple[str, str], list[CatalogEntry]] = {}
    special: list[CatalogEntry] = []
    pets_home: list[CatalogEntry] = []

    for pet in pets:
        layer, origin = classify_pet(pet)
        entry = pet_to_entry(pet, variant)
        if layer == "Special One-Off Pets":
            special.append(entry)
            continue
        if layer == "Pets Home":
            pets_home.append(entry)
            continue
        if pet.pet_id in skip_sheet or not origin:
            continue
        buckets.setdefault((layer, origin), []).append(entry)

    rows: list[tuple[tuple[str, list[CatalogEntry]] | None, tuple[str, list[CatalogEntry]] | None]] = []

    for left_origin, right_origin in (("Lava", "Ice"), ("Desert", "Grass")):
        left = catalog_block("Home", left_origin, buckets.get(("Home", left_origin), []))
        right = catalog_block("Home", right_origin, buckets.get(("Home", right_origin), []))
        if left or right:
            rows.append((left, right))

    for origin in CATALOG_ORIGINS:
        left = catalog_block("Heaven1", origin, buckets.get(("Heaven1", origin), []))
        right = catalog_block("Hell1", origin, buckets.get(("Hell1", origin), []))
        if left or right:
            rows.append((left, right))

    for origin in CATALOG_ORIGINS:
        left = catalog_block("Heaven2", origin, buckets.get(("Heaven2", origin), []))
        right = catalog_block("Hell2", origin, buckets.get(("Hell2", origin), []))
        if left or right:
            rows.append((left, right))

    if include_enemies:
        enemy_entries = [enemy_to_entry(enemy) for enemy in parse_enemies(ENEMIES_CONFIG)]
        enemy_groups = group_entries_by_section(enemy_entries)
        rows.extend(pair_enemy_faction_groups(enemy_groups))

    if special:
        rows.append((("Special One-Off Pets", special), None))

    if include_pets_home and pets_home:
        rows.append((("Pets Home", pets_home), None))

    return rows


def build_catalog_pair_rows(
    pets: list[GamePet],
    *,
    skip: frozenset[str],
    variant: str,
    include_enemies: bool,
    include_pets_home: bool = False,
) -> list[tuple[tuple[str, list[CatalogEntry]] | None, tuple[str, list[CatalogEntry]] | None]]:
    return build_taxonomy_pair_rows(
        pets,
        skip_sheet=skip,
        variant=variant,
        include_enemies=include_enemies,
        include_pets_home=include_pets_home,
    )


def draw_pet_cell(
    sheet: Image.Image,
    draw: ImageDraw.ImageDraw,
    *,
    x0: int,
    y0: int,
    thumb_size: int,
    label_height: int,
    pet_id: str,
    path: Path | None,
    label_font,
    note_font,
) -> None:
    if path is not None:
        fitted = fit_image(Image.open(path).convert("RGBA"), thumb_size)
        paste_x = x0 + (thumb_size - fitted.width) // 2
        paste_y = y0 + (thumb_size - fitted.height) // 2
        sheet.paste(fitted, (paste_x, paste_y), fitted)
    else:
        draw.rectangle(
            [x0, y0, x0 + thumb_size, y0 + thumb_size],
            outline=(90, 90, 90, 255),
            fill=(32, 32, 32, 255),
        )
        draw.text(
            (x0 + thumb_size / 2, y0 + thumb_size / 2),
            "missing",
            fill=(120, 120, 120, 255),
            font=note_font,
            anchor="mm",
        )

    draw.text(
        (x0 + thumb_size / 2, y0 + thumb_size + 8),
        pet_id,
        fill=(235, 235, 235, 255),
        font=label_font,
        anchor="ma",
    )


def draw_combined_pet_cell(
    sheet: Image.Image,
    draw: ImageDraw.ImageDraw,
    *,
    x0: int,
    y0: int,
    thumb_size: int,
    variant_gap: int,
    pet_id: str,
    basic_path: Path | None,
    gold_path: Path | None,
    has_gold: bool,
    label_font,
    note_font,
    tag_font,
) -> None:
    if has_gold:
        variant_thumb = (thumb_size - variant_gap) // 2
        for tag, path, y_off in (
            ("basic", basic_path, 0),
            ("gold", gold_path, variant_thumb + variant_gap),
        ):
            y_slot = y0 + y_off
            if path is not None:
                fitted = fit_image(Image.open(path).convert("RGBA"), variant_thumb)
                paste_x = x0 + (thumb_size - fitted.width) // 2
                paste_y = y_slot + (variant_thumb - fitted.height) // 2
                sheet.paste(fitted, (paste_x, paste_y), fitted)
            else:
                draw.rectangle(
                    [x0, y_slot, x0 + thumb_size, y_slot + variant_thumb],
                    outline=(90, 90, 90, 255),
                    fill=(32, 32, 32, 255),
                )
                draw.text(
                    (x0 + thumb_size / 2, y_slot + variant_thumb / 2),
                    "missing",
                    fill=(120, 120, 120, 255),
                    font=note_font,
                    anchor="mm",
                )
            draw.text(
                (x0 + 4, y_slot + 2),
                tag,
                fill=(180, 180, 180, 200),
                font=tag_font,
                anchor="la",
            )
    elif basic_path is not None:
        fitted = fit_image(Image.open(basic_path).convert("RGBA"), thumb_size)
        paste_x = x0 + (thumb_size - fitted.width) // 2
        paste_y = y0 + (thumb_size - fitted.height) // 2
        sheet.paste(fitted, (paste_x, paste_y), fitted)
    else:
        draw.rectangle(
            [x0, y0, x0 + thumb_size, y0 + thumb_size],
            outline=(90, 90, 90, 255),
            fill=(32, 32, 32, 255),
        )
        draw.text(
            (x0 + thumb_size / 2, y0 + thumb_size / 2),
            "missing",
            fill=(120, 120, 120, 255),
            font=note_font,
            anchor="mm",
        )

    visual_h = thumb_size + variant_gap if has_gold else thumb_size
    draw.text(
        (x0 + thumb_size / 2, y0 + visual_h + 8),
        pet_id,
        fill=(235, 235, 235, 255),
        font=label_font,
        anchor="ma",
    )


def block_size(
    pet_count: int,
    block_columns: int,
    block_rows: int,
    cell_w: int,
    cell_h: int,
    header_h: int,
) -> tuple[int, int]:
    if pet_count <= 0:
        return (block_columns * cell_w, header_h)
    cols_used = min(block_columns, math.ceil(pet_count / block_rows))
    rows_used = min(block_rows, math.ceil(pet_count / cols_used))
    return (cols_used * cell_w, header_h + rows_used * cell_h)


def build_paired_section_sheet(
    pets: list[GamePet],
    variant: str,
    output_path: Path,
    title: str,
    *,
    skip: frozenset[str],
    thumb_size: int,
    label_height: int,
    padding: int,
    block_columns: int,
    block_rows: int,
    pair_gap: int = 28,
    row_gap: int = 36,
    pair_stacks: int = 2,
    include_enemies: bool = False,
    include_pets_home: bool = False,
    combined: bool = False,
) -> tuple[list[str], list[str], list[tuple[str, str, Path | None, str]]]:
    paired_rows = build_catalog_pair_rows(
        pets,
        skip=skip,
        variant=variant if not combined else "basic",
        include_enemies=include_enemies,
        include_pets_home=include_pets_home,
    )

    variant_gap = 6
    visual_thumb_h = thumb_size if not combined else thumb_size + variant_gap
    cell_w = thumb_size + padding * 2
    cell_h = visual_thumb_h + label_height + padding * 2
    block_header_h = 34
    title_h = 48
    stack_gap = 40

    def row_metrics(left, right):
        left_count = len(left[1]) if left else 0
        right_count = len(right[1]) if right else 0
        left_w, left_h = block_size(left_count, block_columns, block_rows, cell_w, cell_h, block_header_h)
        right_w, right_h = block_size(right_count, block_columns, block_rows, cell_w, cell_h, block_header_h)
        width = left_w + (pair_gap + right_w if right else 0)
        height = max(left_h, right_h if right else 0)
        return width, height

    stacks: list[list[tuple]] = [[] for _ in range(max(pair_stacks, 1))]
    for index, row in enumerate(paired_rows):
        stacks[index % len(stacks)].append(row)

    stack_sizes: list[tuple[int, int]] = []
    for stack in stacks:
        if not stack:
            stack_sizes.append((0, 0))
            continue
        widths = [row_metrics(left, right)[0] for left, right in stack]
        heights = [row_metrics(left, right)[1] for left, right in stack]
        stack_sizes.append(
            (
                max(widths),
                sum(heights) + row_gap * max(len(heights) - 1, 0),
            )
        )

    sheet_w = sum(width for width, _ in stack_sizes if width) + stack_gap * (len(stacks) - 1)
    sheet_h = title_h + max((height for _, height in stack_sizes), default=0)
    sheet = Image.new("RGBA", (max(sheet_w, 1), max(sheet_h, 1)), (48, 48, 48, 255))
    draw = ImageDraw.Draw(sheet)
    title_font = load_font(24)
    section_font = load_font(15)
    label_font = load_font(14)
    note_font = load_font(11)
    tag_font = load_font(10)

    draw.text(
        (sheet_w / 2, title_h / 2),
        title,
        fill=(235, 235, 235, 255),
        font=title_font,
        anchor="mm",
    )

    missing: list[str] = []
    missing_gold: list[str] = []
    manifest_rows: list[tuple[str, str, Path | None, str]] = []
    x_stack = 0

    for stack_index, stack in enumerate(stacks):
        if not stack:
            continue
        y_cursor = title_h
        for row_index, (left, right) in enumerate(stack):
            _, row_h = row_metrics(left, right)
            x_cursor = x_stack

            for block in (left, right):
                if block is None:
                    continue
                section_name, section_entries = block
                block_w, _ = block_size(
                    len(section_entries), block_columns, block_rows, cell_w, cell_h, block_header_h
                )
                draw.text(
                    (x_cursor + 8, y_cursor + 6),
                    section_name,
                    fill=(160, 200, 255, 255),
                    font=section_font,
                    anchor="la",
                )

                for index, entry in enumerate(section_entries):
                    col = index // block_rows
                    row = index % block_rows
                    x0 = x_cursor + col * cell_w + padding
                    y0 = y_cursor + block_header_h + row * cell_h + padding
                    if combined:
                        basic_path, gold_path = catalog_basic_gold_paths(entry)
                        if basic_path is None:
                            missing.append(entry.entry_id)
                        if entry.has_gold and gold_path is None and entry.entry_id not in missing_gold:
                            missing_gold.append(entry.entry_id)
                        kind = "combined"
                        manifest_rows.append(
                            (section_name, entry.entry_id, basic_path or gold_path, kind)
                        )
                        draw_combined_pet_cell(
                            sheet,
                            draw,
                            x0=x0,
                            y0=y0,
                            thumb_size=thumb_size,
                            variant_gap=variant_gap,
                            pet_id=entry.label,
                            basic_path=basic_path,
                            gold_path=gold_path,
                            has_gold=entry.has_gold,
                            label_font=label_font,
                            note_font=note_font,
                            tag_font=tag_font,
                        )
                    else:
                        path = catalog_preview_path(entry)
                        if path is None:
                            missing.append(entry.entry_id)
                            kind = "missing"
                        else:
                            kind = "preview"
                        manifest_rows.append((section_name, entry.entry_id, path, kind))
                        draw_pet_cell(
                            sheet,
                            draw,
                            x0=x0,
                            y0=y0,
                            thumb_size=thumb_size,
                            label_height=label_height,
                            pet_id=entry.label,
                            path=path,
                            label_font=label_font,
                            note_font=note_font,
                        )

                x_cursor += block_w + pair_gap

            y_cursor += row_h + (row_gap if row_index < len(stack) - 1 else 0)

        x_stack += stack_sizes[stack_index][0] + stack_gap

    output_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output_path, format="PNG", optimize=True, compress_level=9)
    return missing, missing_gold, manifest_rows


def build_config_variant_sheet(
    pets: list[GamePet],
    variant: str,
    output_path: Path,
    title: str,
    columns: int,
    thumb_size: int,
    label_height: int,
    padding: int,
    section_gap: int,
) -> tuple[list[str], list[tuple[str, str, Path | None, str]]]:
    imported: dict[str, tuple[Path, str]] = {}
    rows: list[tuple[str, str, Path | None, str]] = []
    missing: list[str] = []

    last_section = ""
    for pet in pets:
        if pet.section != last_section and rows:
            pad = (-len(rows)) % columns
            rows.extend([("", "", None, "pad")] * pad)
        last_section = pet.section

        path = preview_path(pet.pet_id, variant)
        if path is not None:
            imported[pet.pet_id] = (path, "preview")
            rows.append((pet.section, pet.pet_id, path, "preview"))
        else:
            missing.append(pet.pet_id)
            rows.append((pet.section, pet.pet_id, None, "missing"))

    cell_w = thumb_size + padding * 2
    cell_h = thumb_size + label_height + padding * 2
    header_h = 40
    grid_rows = math.ceil(len(rows) / columns) if rows else 1
    sheet = Image.new(
        "RGBA",
        (columns * cell_w, header_h + grid_rows * cell_h + section_gap),
        (48, 48, 48, 255),
    )
    draw = ImageDraw.Draw(sheet)
    title_font = load_font(22)
    label_font = load_font(14)
    note_font = load_font(11)

    draw.text(
        (columns * cell_w / 2, header_h / 2),
        title,
        fill=(235, 235, 235, 255),
        font=title_font,
        anchor="mm",
    )

    for index, (section, pet_id, path, kind) in enumerate(rows):
        if kind == "pad":
            continue
        col = index % columns
        row = index // columns
        x0 = col * cell_w + padding
        y0 = header_h + row * cell_h + padding

        prev_section = rows[index - 1][0] if index > 0 else ""
        if section and section != prev_section:
            draw.text((4, y0 - 4), section, fill=(160, 200, 255, 255), font=note_font, anchor="ls")

        if path is not None:
            fitted = fit_image(Image.open(path).convert("RGBA"), thumb_size)
            paste_x = x0 + (thumb_size - fitted.width) // 2
            paste_y = y0 + (thumb_size - fitted.height) // 2
            sheet.paste(fitted, (paste_x, paste_y), fitted)
        else:
            draw.rectangle(
                [x0, y0, x0 + thumb_size, y0 + thumb_size],
                outline=(90, 90, 90, 255),
                fill=(32, 32, 32, 255),
            )
            draw.text(
                (x0 + thumb_size / 2, y0 + thumb_size / 2),
                "missing",
                fill=(120, 120, 120, 255),
                font=note_font,
                anchor="mm",
            )

        draw.text(
            (x0 + thumb_size / 2, y0 + thumb_size + 8),
            pet_id,
            fill=(235, 235, 235, 255),
            font=label_font,
            anchor="ma",
        )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output_path, format="PNG", optimize=True, compress_level=9)
    return missing, rows


def write_config_manifest(
    manifest_path: Path,
    pets: list[GamePet],
    enemies: list[GameEnemy],
    variant: str,
    basic_sheet: Path,
    gold_sheet: Path,
    missing_basic: list[str],
    missing_gold: list[str],
    combined_sheet: Path | None = None,
) -> None:
    lines = [
        f"# Game catalog — pets + combat enemies ({variant} manifest section)",
        "# Taxonomy: Home | Heaven1 | Hell1 | Heaven2 | Hell2 × Grass/Lava/Ice/Desert",
        "#            + Enemies + Special One-Off Pets + Pets Home",
        f"# Pets: configs/pets.lua ({len(pets)} total)",
        f"# Enemies: configs/enemies.lua ({len(enemies)} combat enemies)",
        "# Preview PNGs: assets/exports/pets/{basic|gold}/{stem}_{variant}.png",
        "",
        f"basic_contact_sheet: {basic_sheet.relative_to(ROOT)}",
        f"gold_contact_sheet: {gold_sheet.relative_to(ROOT)}",
    ]
    if combined_sheet is not None:
        lines.append(f"combined_contact_sheet: {combined_sheet.relative_to(ROOT)}")
    lines.extend(["", "kind\tid\tdisplay_name\tlayer\torigin\tsection\tpreview"])
    for pet in pets:
        layer, origin = classify_pet(pet)
        preview = preview_path(pet.pet_id, "gold")
        lines.append(
            "\t".join(
                [
                    "pet",
                    pet.pet_id,
                    pet.display_name,
                    layer,
                    origin or "-",
                    pet.section,
                    str(preview.relative_to(ROOT)) if preview else "MISSING",
                ]
            )
        )
    for enemy in enemies:
        entry = enemy_to_entry(enemy)
        preview = catalog_preview_path(entry)
        lines.append(
            "\t".join(
                [
                    "enemy",
                    enemy.enemy_id,
                    enemy.display_name,
                    enemy.section,
                    str(preview.relative_to(ROOT)) if preview else "MISSING",
                ]
            )
        )
    if missing_basic:
        lines.extend(["", f"# Missing basic previews ({len(missing_basic)}):", *[f"#   {p}" for p in missing_basic]])
    if missing_gold:
        lines.extend(["", f"# Missing gold previews ({len(missing_gold)}):", *[f"#   {p}" for p in missing_gold]])
    missing_earth_previews = [
        stem for stem in EARTH_ENEMY_PREVIEW_STEMS if preview_path(stem, "basic") is None
    ]
    if missing_earth_previews:
        lines.extend(
            [
                "",
                "# Earth-enemy preview cleanup (copy Meshy viewport PNG -> assets/exports/pets/basic/{stem}_basic.png):",
                *[f"#   {stem}_basic.png  (mesh texture is at assets/exports/pets/{stem}_basic/{stem}_basic.png)" for stem in missing_earth_previews],
            ]
        )
    manifest_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def build_from_config(args: argparse.Namespace) -> int:
    config_path = Path(args.config).expanduser().resolve()
    pets = parse_game_pets(config_path)
    skip = HOMEWORLD_GRASS_PETS | frozenset(args.skip_pet)
    include_enemies = not args.no_enemies
    enemies = parse_enemies(ENEMIES_CONFIG) if include_enemies else []
    enemy_count = len(enemies)
    date_stamp = date.today().isoformat()
    gold_sheet = ROOT / f"assets/exports/pets/all_game_catalog_{date_stamp}_gold_contact_sheet.png"
    basic_sheet = ROOT / f"assets/exports/pets/all_game_catalog_{date_stamp}_basic_contact_sheet.png"
    combined_sheet = ROOT / f"assets/exports/pets/all_game_catalog_{date_stamp}_combined_contact_sheet.png"
    manifest_path = ROOT / f"assets/ui/imports/manifest_{date_stamp}_all_game_catalog.txt"

    included_on_sheet = (
        len([p for p in pets if p.pet_id not in skip or p.pet_id in SPECIAL_ONE_OFF_PETS])
        + (len(PETS_HOME_IDS) if args.include_pets_home else 0)
    )
    title_count = f"{included_on_sheet} pets"
    if include_enemies:
        title_count += f" + {enemy_count} enemies"
    missing_gold, _, _ = build_paired_section_sheet(
        pets,
        "gold",
        gold_sheet,
        f"Game catalog — gold ({title_count}, 2×5 blocks)",
        skip=skip,
        thumb_size=args.thumb_size,
        label_height=args.label_height,
        padding=args.padding,
        block_columns=args.block_columns,
        block_rows=args.block_rows,
        pair_stacks=args.pair_stacks,
        include_enemies=include_enemies,
        include_pets_home=args.include_pets_home,
    )
    missing_basic: list[str] = []
    if args.basic_too:
        missing_basic, _, _ = build_paired_section_sheet(
            pets,
            "basic",
            basic_sheet,
            f"Game catalog — basic ({title_count}, 2×5 blocks)",
            skip=skip,
            thumb_size=args.thumb_size,
            label_height=args.label_height,
            padding=args.padding,
            block_columns=args.block_columns,
            block_rows=args.block_rows,
            pair_stacks=args.pair_stacks,
            include_enemies=include_enemies,
            include_pets_home=args.include_pets_home,
        )

    combined_path: Path | None = None
    if args.combined:
        missing_basic_combined, missing_gold_combined, _ = build_paired_section_sheet(
            pets,
            "gold",
            combined_sheet,
            f"Game catalog — basic + gold ({title_count}, 2×5 blocks)",
            skip=skip,
            thumb_size=args.thumb_size,
            label_height=args.label_height,
            padding=args.padding,
            block_columns=args.block_columns,
            block_rows=args.block_rows,
            pair_stacks=args.pair_stacks,
            include_enemies=include_enemies,
            include_pets_home=args.include_pets_home,
            combined=True,
        )
        missing_basic = sorted(set(missing_basic) | set(missing_basic_combined))
        missing_gold = sorted(set(missing_gold) | set(missing_gold_combined))
        combined_path = combined_sheet

    write_config_manifest(
        manifest_path,
        pets,
        enemies,
        "gold",
        basic_sheet if args.basic_too else gold_sheet,
        gold_sheet,
        missing_basic,
        missing_gold,
        combined_path,
    )

    print(f"Game pets in config: {len(pets)} (on sheet: {included_on_sheet}, Pets Home omitted unless --include-pets-home)")
    if include_enemies:
        print(f"Combat enemies: {enemy_count}")
    print(f"Gold contact sheet -> {gold_sheet}")
    if args.basic_too:
        print(f"Basic contact sheet -> {basic_sheet}")
    if args.combined:
        print(f"Combined contact sheet -> {combined_sheet}")
    print(f"Manifest -> {manifest_path}")
    if missing_gold:
        print(f"Missing gold previews ({len(missing_gold)}): {', '.join(missing_gold)}")
    if missing_basic:
        print(f"Missing basic previews ({len(missing_basic)}): {', '.join(missing_basic)}")
    return 0


def load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for path in (
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ):
        if Path(path).exists():
            return ImageFont.truetype(path, size=size)
    return ImageFont.load_default()


def fit_image(image: Image.Image, max_size: int) -> Image.Image:
    scale = min(max_size / image.width, max_size / image.height, 1.0)
    return image.resize(
        (max(1, int(image.width * scale)), max(1, int(image.height * scale))),
        Image.Resampling.LANCZOS,
    )


def first_existing(paths: list[Path]) -> Path | None:
    for path in paths:
        if path.is_file():
            return path
    return None


def resolve_source(
    pet_id: str,
    basic_dir: Path,
    download_by_pet: dict[str, Path],
) -> tuple[Path | None, str]:
    if pet_id in download_by_pet:
        return download_by_pet[pet_id], "download"

    supplement = first_existing(SUPPLEMENTS.get(pet_id, []))
    if supplement is not None:
        kind = "preview" if "preview" in supplement.name else "reference"
        return supplement, kind

    return None, "missing"


def download_by_pet_from(source_dir: Path, suffix: str) -> dict[str, Path]:
    found: dict[str, Path] = {}
    token = f"_{suffix}"
    for path in sorted(source_dir.glob("*.png")):
        stem = path.stem
        if not stem.endswith(token):
            continue
        pet_id = stem[: -len(token)]
        if pet_id:
            found[pet_id] = path
    return found


def import_images(
    source_dir: Path,
    output_dir: Path,
    suffix: str,
    *,
    use_supplements: bool = False,
) -> dict[str, tuple[Path, str]]:
    download_by_pet = download_by_pet_from(source_dir, suffix)
    output_dir.mkdir(parents=True, exist_ok=True)
    imported: dict[str, tuple[Path, str]] = {}

    for _section, pets in PET_SECTIONS:
        for pet_id in pets:
            if use_supplements:
                source, kind = resolve_source(pet_id, source_dir, download_by_pet)
            elif pet_id in download_by_pet:
                source, kind = download_by_pet[pet_id], "download"
            else:
                continue
            if source is None:
                continue
            destination = output_dir / f"{pet_id}_{suffix}.png"
            shutil.copy2(source, destination)
            imported[pet_id] = (destination, kind)

    return imported


def build_sheet(
    imported: dict[str, tuple[Path, str]],
    output_path: Path,
    title: str,
    columns: int,
    thumb_size: int,
    label_height: int,
    padding: int,
    section_gap: int,
) -> list[str]:
    entries: list[tuple[str, str, Path | None, str]] = []
    missing: list[str] = []

    for section_index, (section, pets) in enumerate(PET_SECTIONS):
        if section_index > 0 and entries:
            pad = (-len(entries)) % columns
            for _ in range(pad):
                entries.append(("", "", None, "pad"))

        for pet_id in pets:
            if pet_id in imported:
                path, kind = imported[pet_id]
                entries.append((section, pet_id, path, kind))
            else:
                entries.append((section, pet_id, None, "missing"))
                missing.append(pet_id)

    rows = math.ceil(len(entries) / columns)
    cell_w = thumb_size + padding * 2
    cell_h = thumb_size + label_height + padding * 2
    header_h = 40
    sheet_h = header_h + rows * cell_h + section_gap
    sheet = Image.new("RGBA", (columns * cell_w, sheet_h), (48, 48, 48, 255))
    draw = ImageDraw.Draw(sheet)
    title_font = load_font(22)
    label_font = load_font(16)
    note_font = load_font(12)

    draw.text(
        (columns * cell_w / 2, header_h / 2),
        title,
        fill=(235, 235, 235, 255),
        font=title_font,
        anchor="mm",
    )

    for index, (section, pet_id, path, kind) in enumerate(entries):
        if kind == "pad":
            continue

        col = index % columns
        row = index // columns
        x0 = col * cell_w + padding
        y0 = header_h + row * cell_h + padding

        prev_section = entries[index - 1][0] if index > 0 else ""
        if section and section != prev_section:
            draw.text(
                (4, y0 - 6),
                section,
                fill=(160, 200, 255, 255),
                font=note_font,
                anchor="ls",
            )

        if path is not None:
            fitted = fit_image(Image.open(path).convert("RGBA"), thumb_size)
            paste_x = x0 + (thumb_size - fitted.width) // 2
            paste_y = y0 + (thumb_size - fitted.height) // 2
            sheet.paste(fitted, (paste_x, paste_y), fitted)
        else:
            draw.rectangle(
                [x0, y0, x0 + thumb_size, y0 + thumb_size],
                outline=(90, 90, 90, 255),
                fill=(32, 32, 32, 255),
            )
            draw.text(
                (x0 + thumb_size / 2, y0 + thumb_size / 2),
                "missing",
                fill=(120, 120, 120, 255),
                font=note_font,
                anchor="mm",
            )

        suffix = "" if kind == "download" else f" ({kind})"
        draw.text(
            (x0 + thumb_size / 2, y0 + thumb_size + 10),
            f"{pet_id}{suffix}" if pet_id else "",
            fill=(235, 235, 235, 255),
            font=label_font,
            anchor="ma",
        )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output_path, format="PNG", optimize=True, compress_level=9)
    return missing


def write_manifest(
    output_dir: Path,
    imported: dict[str, tuple[Path, str]],
    missing: list[str],
    sheet_path: Path,
    *,
    variant: str,
) -> None:
    lines = [
        f"# {variant.capitalize()} pet model images.",
        f"# Master contact sheet: {sheet_path.relative_to(ROOT)}",
        "",
        "pet\tsource\tkind\tfile",
    ]
    for _section, pets in PET_SECTIONS:
        for pet_id in pets:
            if pet_id in imported:
                path, kind = imported[pet_id]
                lines.append(f"{pet_id}\timported\t{kind}\t{path.name}")
            else:
                lines.append(f"{pet_id}\tmissing\t-\t-")
    if missing:
        lines.extend(
            ["", f"# Missing {variant} model images:", *[f"#   {pet}" for pet in missing]]
        )
    (output_dir / "manifest.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")


def build_variant_sheet(
    source_dir: Path,
    output_dir: Path,
    sheet_path: Path,
    suffix: str,
    title: str,
    variant: str,
    args: argparse.Namespace,
    *,
    use_supplements: bool = False,
) -> list[str]:
    imported = import_images(
        source_dir,
        output_dir,
        suffix,
        use_supplements=use_supplements,
    )
    missing = build_sheet(
        imported,
        sheet_path,
        title,
        args.columns,
        args.thumb_size,
        args.label_height,
        args.padding,
        args.section_gap,
    )
    write_manifest(output_dir, imported, missing, sheet_path, variant=variant)
    print(f"Imported {len(imported)} {variant} pet images -> {output_dir}")
    print(f"Contact sheet -> {sheet_path}")
    if missing:
        print(f"Missing ({len(missing)}): {', '.join(missing)}")
    return missing


def main() -> int:
    args = parse_args()
    if args.from_config:
        return build_from_config(args)

    basic_dir = Path(args.basic_dir).expanduser().resolve()
    output_dir = Path(args.output_dir).expanduser().resolve()
    sheet_path = Path(args.sheet).expanduser().resolve()

    if not basic_dir.is_dir():
        raise SystemExit(f"Basic image folder not found: {basic_dir}")

    build_variant_sheet(
        basic_dir,
        output_dir,
        sheet_path,
        "basic",
        "Basic pet models",
        "basic",
        args,
        use_supplements=True,
    )

    if not args.basic_only:
        gold_dir = Path(args.gold_dir).expanduser().resolve()
        gold_output = Path(GOLD_OUT_DIR).expanduser().resolve()
        gold_sheet = Path(args.gold_sheet).expanduser().resolve()
        if not gold_dir.is_dir():
            raise SystemExit(f"Gold image folder not found: {gold_dir}")
        build_variant_sheet(
            gold_dir,
            gold_output,
            gold_sheet,
            "gold",
            "Golden pet models",
            "gold",
            args,
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
