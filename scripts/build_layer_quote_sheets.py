#!/usr/bin/env python3
"""Contact sheets from local HaloAndHorns textures only. No CDN thumbs."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs/art/quote_refs"
HEAVEN = ROOT / "assets/concepts/layer_3_review/heaven"
HELL = ROOT / "assets/concepts/layer_3_review/hell"
DECOR = ROOT / "assets/exports/props/meshy_mission_decor"
EXISTING = ROOT / "assets/concepts/layer_3_review"

CELL = 260
LABEL_H = 34
GAP = 12
PAD = 24
HEADER_H = 88
COLS = 4

SHEETS = [
    {
        "file": "01_heaven_flora_fauna.jpg",
        "title": "Heaven flora & fauna (local painted kit)",
        "subtitle": "assets/concepts/layer_3_review/heaven — moths/butterflies + pearl snail",
        "items": [
            (HEAVEN / "flora_luminous_canopy_tree.png", "luminous canopy tree"),
            (HEAVEN / "flora_halo_fern.png", "halo fern"),
            (HEAVEN / "flora_wingleaf_reed.png", "wingleaf reed"),
            (HEAVEN / "flora_celestial_bellgrass.png", "celestial bellgrass"),
            (HEAVEN / "flora_moonpetal_bush.png", "moonpetal bush"),
            (HEAVEN / "flora_lumen_moss_cushion.png", "lumen moss"),
            (HEAVEN / "flora_pearlroot_anemone.png", "pearlroot anemone"),
            (HEAVEN / "flora_emerald_ribbon_shrub.png", "emerald ribbon shrub"),
            (HEAVEN / "flora_jade_lantern_bloom.png", "jade lantern bloom"),
            (HEAVEN / "cactus_empyrean_bloom.png", "empyrean bloom cactus"),
            (HEAVEN / "rock_pearlroot_boulder.png", "pearlroot boulder"),
            (HEAVEN / "fauna_bloomwing_butterfly.png", "bloomwing butterfly"),
            (HEAVEN / "fauna_pearlback_snail.png", "pearlback snail"),
        ],
    },
    {
        "file": "02_hell_flora_fauna.jpg",
        "title": "Hell flora & fauna (local painted kit)",
        "subtitle": "assets/concepts/layer_3_review/hell — beetles + hornback lizard",
        "items": [
            (HELL / "flora_dreadthorn_tree.png", "dreadthorn tree"),
            (HELL / "cactus_dreadspire_thorn.png", "dreadspire thorn cactus"),
            (HELL / "flora_dreadspire_ribbon_grass.png", "ribbon grass"),
            (HELL / "flora_ember_thorn_cluster.png", "ember thorn"),
            (HELL / "flora_blood_reed.png", "blood reed"),
            (HELL / "flora_razorleaf_fan.png", "razorleaf fan"),
            (HELL / "flora_gloom_pitcher.png", "gloom pitcher"),
            (HELL / "flora_crimson_watcher_bloom.png", "crimson watcher"),
            (HELL / "flora_violet_hook_bloom.png", "violet hook bloom"),
            (HELL / "flora_obsidian_spike_plant.png", "obsidian spike"),
            (HELL / "rock_dreadspire_faultstone.png", "faultstone"),
            (HELL / "fauna_dreadwing_beetle.png", "dreadwing beetle"),
            (HELL / "fauna_obsidian_hornback_lizard.png", "hornback lizard"),
        ],
    },
    {
        "file": "03_heaven_ceremonial.jpg",
        "title": "Heaven ceremonial (local previews)",
        "subtitle": "assets/exports/props/meshy_mission_decor — altars, fountain, thrones",
        "items": [
            (DECOR / "heaven_diamond_altar/heaven_diamond_altar_preview.png", "diamond altar"),
            (DECOR / "heaven_star_fountain/heaven_star_fountain_preview.png", "star fountain"),
            (DECOR / "heaven_golden_codex/heaven_golden_codex_preview.png", "golden codex"),
            (DECOR / "heaven_ivory_throne/heaven_ivory_throne_preview.png", "ivory throne"),
            (DECOR / "heaven_marble_throne/heaven_marble_throne_preview.png", "marble throne"),
            (DECOR / "heaven_golden_throne/heaven_golden_throne_preview.png", "golden throne"),
            (DECOR / "heaven_golden_guardian/heaven_golden_guardian_preview.png", "golden guardian"),
            (DECOR / "heaven_archive/heaven_archive_preview.png", "heaven archive"),
        ],
    },
    {
        "file": "04_hell_ceremonial.jpg",
        "title": "Hell ceremonial (local previews)",
        "subtitle": "assets/exports/props/meshy_mission_decor — fountain, thrones, lantern",
        "items": [
            (DECOR / "hell_infernal_fountain/hell_infernal_fountain_preview.png", "infernal fountain"),
            (DECOR / "hell_infernal_throne/hell_infernal_throne_preview.png", "infernal throne"),
            (DECOR / "hell_infernal_throne_flat/hell_infernal_throne_flat_preview.png", "throne relief"),
            (DECOR / "hell_skull_lantern/hell_skull_lantern_preview.png", "skull lantern"),
            (DECOR / "hell_infernal_archive/hell_infernal_archive_preview.png", "infernal archive"),
            (DECOR / "hell_infernal_crest/hell_infernal_crest_preview.png", "infernal crest"),
            (DECOR / "hell_gate_of_damned/hell_gate_of_damned_preview.png", "gate of the damned"),
            (DECOR / "hell_skull_sconce/hell_skull_sconce_preview.png", "skull sconce"),
        ],
    },
]


def font(size: int):
    for candidate in (
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ):
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size)
    return ImageFont.load_default()


def fit_card(im: Image.Image, size: int) -> Image.Image:
    card = Image.new("RGB", (size, size), (236, 232, 226))
    src = im.convert("RGB")
    src.thumbnail((size - 10, size - 10), Image.Resampling.LANCZOS)
    card.paste(src, ((size - src.width) // 2, (size - src.height) // 2))
    return card


def build_sheet(spec: dict) -> Path:
    items = [(p, name) for p, name in spec["items"] if p.is_file()]
    missing = [name for p, name in spec["items"] if not p.is_file()]
    if missing:
        print(f"  missing: {', '.join(missing)}")
    rows = max(1, (len(items) + COLS - 1) // COLS)
    width = PAD * 2 + COLS * CELL + (COLS - 1) * GAP
    height = HEADER_H + PAD + rows * (CELL + LABEL_H + GAP) + PAD
    sheet = Image.new("RGB", (width, height), (18, 16, 20))
    draw = ImageDraw.Draw(sheet)
    draw.text((PAD, 18), spec["title"], font=font(26), fill=(246, 239, 232))
    draw.text((PAD, 54), spec["subtitle"], font=font(14), fill=(168, 162, 172))
    for i, (path, name) in enumerate(items):
        c, r = i % COLS, i // COLS
        x = PAD + c * (CELL + GAP)
        y = HEADER_H + r * (CELL + LABEL_H + GAP)
        with Image.open(path) as im:
            sheet.paste(fit_card(im, CELL), (x, y))
        bbox = draw.textbbox((0, 0), name, font=font(13))
        tw = bbox[2] - bbox[0]
        draw.text((x + (CELL - tw) / 2, y + CELL + 8), name, font=font(13), fill=(210, 204, 214))
    dest = OUT / spec["file"]
    sheet.save(dest, "JPEG", quality=90, optimize=True)
    return dest


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for spec in SHEETS:
        dest = build_sheet(spec)
        print(f"wrote {dest}")
    for src_name, dest_name in (
        ("layer_3_flora_fauna_expansion_contact_card.png", "00_layer3_flora_fauna_card.png"),
        ("layer_3_contact_card.png", "00_layer3_kit_card.png"),
    ):
        src = EXISTING / src_name
        if src.is_file():
            dest = OUT / dest_name
            dest.write_bytes(src.read_bytes())
            print(f"copied {dest}")


if __name__ == "__main__":
    main()
