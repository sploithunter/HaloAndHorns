#!/usr/bin/env python3
"""
Offline team power calculator for early pet balance work.

The script intentionally reads the current Lua configs instead of keeping a
separate spreadsheet of pet values. It mirrors the current in-game team power
rules closely enough for rough tuning:

- variant power comes from configs/pets.lua
- pet level power scaling comes from configs/pet_progression.lua
- player level power scaling comes from configs/player_progression.lua
- eternal pets use the average of the top team-size base powers
- huge eternal pets clamp to at least 100% of that top-team average

Example:
    python3 scripts/balance_team_power.py --player-level 15 --team-size 3 \
        --pet bear:rainbow:10 --pet doggy:golden:5 --pet colorado:rainbow:1:huge
"""

from __future__ import annotations

import argparse
import dataclasses
import math
import re
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]
PETS_CONFIG = ROOT / "configs" / "pets.lua"
PET_PROGRESSION_CONFIG = ROOT / "configs" / "pet_progression.lua"
PLAYER_PROGRESSION_CONFIG = ROOT / "configs" / "player_progression.lua"


@dataclasses.dataclass(frozen=True)
class PetFamily:
    pet_id: str
    display_name: str
    rarity: str
    base_power: int
    eternal_enabled: bool = False
    eternal_percent: float = 0.0


@dataclasses.dataclass(frozen=True)
class PetVariant:
    pet_id: str
    variant: str
    display_name: str
    rarity: str
    power: int
    health: int
    eternal_enabled: bool = False
    eternal_percent: float = 0.0


@dataclasses.dataclass(frozen=True)
class ProgressionConfig:
    default_max_level: int
    max_level_by_rarity: dict[str, int]
    percent_per_level: float
    max_bonus_percent: float


@dataclasses.dataclass(frozen=True)
class PlayerProgressionConfig:
    start_level: int
    percent_per_level: float
    max_bonus_percent: float


@dataclasses.dataclass(frozen=True)
class TeamPet:
    pet_id: str
    variant: str
    level: int = 1
    huge: bool = False


@dataclasses.dataclass(frozen=True)
class ResolvedPet:
    spec: TeamPet
    display_name: str
    rarity: str
    configured_power: int
    leveled_power: int
    eternal_percent: float
    effective_power: int


def strip_lua_comments(source: str) -> str:
    source = re.sub(r"--\[\[.*?\]\]", "", source, flags=re.DOTALL)
    return re.sub(r"--[^\n]*", "", source)


def find_table(source: str, name: str) -> str:
    match = re.search(rf"\b{name}\s*=\s*\{{", source)
    if not match:
        raise ValueError(f"Could not find table {name!r}")
    open_index = source.find("{", match.start())
    close_index = find_matching_brace(source, open_index)
    return source[open_index + 1 : close_index]


def find_named_table(source: str, name: str) -> str | None:
    match = re.search(rf"\b{name}\s*=\s*\{{", source)
    if not match:
        return None
    open_index = source.find("{", match.start())
    close_index = find_matching_brace(source, open_index)
    return source[open_index + 1 : close_index]


def find_matching_brace(source: str, open_index: int) -> int:
    depth = 0
    quote: str | None = None
    escaped = False
    for index in range(open_index, len(source)):
        char = source[index]
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
            continue

        if char in ('"', "'"):
            quote = char
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return index
    raise ValueError("Unmatched Lua table brace")


def iter_child_tables(table_body: str) -> Iterable[tuple[str, str]]:
    index = 0
    while index < len(table_body):
        match = re.search(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*=\s*\{", table_body[index:])
        if not match:
            return
        key = match.group(1)
        open_index = index + match.end() - 1
        close_index = find_matching_brace(table_body, open_index)
        yield key, table_body[open_index + 1 : close_index]
        index = close_index + 1


def scalar_string(table_body: str, key: str, default: str = "") -> str:
    match = re.search(rf"\b{key}\s*=\s*\"([^\"]*)\"", table_body)
    return match.group(1) if match else default


def scalar_number(table_body: str, key: str, default: float = 0) -> float:
    match = re.search(rf"\b{key}\s*=\s*(-?\d+(?:\.\d+)?)", table_body)
    return float(match.group(1)) if match else default


def scalar_bool(table_body: str, key: str, default: bool = False) -> bool:
    match = re.search(rf"\b{key}\s*=\s*(true|false)", table_body)
    if not match:
        return default
    return match.group(1) == "true"


def load_pets() -> dict[tuple[str, str], PetVariant]:
    source = strip_lua_comments(PETS_CONFIG.read_text())
    global_variants_body = find_table(source, "variants")
    variant_multipliers: dict[str, tuple[float, float]] = {}
    for variant_id, variant_body in iter_child_tables(global_variants_body):
        variant_multipliers[variant_id] = (
            scalar_number(variant_body, "power_multiplier", 1),
            scalar_number(variant_body, "health_multiplier", 1),
        )

    pets_body = find_table(source, "pets")
    variants: dict[tuple[str, str], PetVariant] = {}

    for pet_id, pet_body in iter_child_tables(pets_body):
        eternal_body = find_named_table(pet_body, "eternal") or ""
        family = PetFamily(
            pet_id=pet_id,
            display_name=scalar_string(pet_body, "display_name", pet_id.title()),
            rarity=scalar_string(pet_body, "rarity", "common"),
            base_power=int(scalar_number(pet_body, "base_power", 1)),
            eternal_enabled=scalar_bool(eternal_body, "enabled", False),
            eternal_percent=scalar_number(eternal_body, "power_percent", 0),
        )

        variants_body = find_named_table(pet_body, "variants")
        if not variants_body:
            continue

        for variant_id, variant_body in iter_child_tables(variants_body):
            power_multiplier, health_multiplier = variant_multipliers.get(variant_id, (1, 1))
            variants[(pet_id, variant_id)] = PetVariant(
                pet_id=pet_id,
                variant=variant_id,
                display_name=scalar_string(variant_body, "display_name", family.display_name),
                rarity=family.rarity,
                power=int(scalar_number(variant_body, "power", round(family.base_power * power_multiplier))),
                health=int(scalar_number(variant_body, "health", round(scalar_number(pet_body, "base_health", 1) * health_multiplier))),
                eternal_enabled=family.eternal_enabled,
                eternal_percent=family.eternal_percent,
            )

    return variants


def load_progression() -> ProgressionConfig:
    source = strip_lua_comments(PET_PROGRESSION_CONFIG.read_text())
    max_level_body = find_named_table(source, "max_level_by_rarity") or ""
    max_levels: dict[str, int] = {}
    for rarity, value in re.findall(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(\d+)", max_level_body):
        max_levels[rarity] = int(value)

    power_body = find_named_table(source, "power_scaling") or ""
    return ProgressionConfig(
        default_max_level=int(scalar_number(source, "default_max_level", 1)),
        max_level_by_rarity=max_levels,
        percent_per_level=scalar_number(power_body, "percent_per_level", 0),
        max_bonus_percent=scalar_number(power_body, "max_bonus_percent", 0),
    )


def load_player_progression() -> PlayerProgressionConfig:
    if not PLAYER_PROGRESSION_CONFIG.exists():
        return PlayerProgressionConfig(start_level=1, percent_per_level=0.0, max_bonus_percent=0.0)

    source = strip_lua_comments(PLAYER_PROGRESSION_CONFIG.read_text())
    team_power_body = find_named_table(source, "team_power") or ""
    return PlayerProgressionConfig(
        start_level=int(scalar_number(team_power_body, "start_level", 1)),
        percent_per_level=scalar_number(team_power_body, "percent_per_level", 0),
        max_bonus_percent=scalar_number(team_power_body, "max_bonus_percent", 0),
    )


def parse_team_pet(raw: str) -> TeamPet:
    parts = raw.split(":")
    if len(parts) < 2:
        raise argparse.ArgumentTypeError("pets must look like pet:variant[:level][:huge]")
    level = 1
    huge = False
    for extra in parts[2:]:
        if extra.lower() == "huge":
            huge = True
        else:
            try:
                level = int(extra)
            except ValueError as exc:
                raise argparse.ArgumentTypeError(f"invalid pet level in {raw!r}") from exc
    return TeamPet(parts[0].lower(), parts[1].lower(), max(1, level), huge)


def power_multiplier(level: int, progression: ProgressionConfig) -> float:
    bonus = min(progression.max_bonus_percent, max(0.0, (level - 1) * progression.percent_per_level))
    return 1.0 + bonus


def player_power_multiplier(player_level: int, start_level: int, rate: float, cap: float) -> float:
    bonus = min(cap, max(0.0, (player_level - start_level) * rate))
    return 1.0 + bonus


def level_from_xp(xp: int, base: int, growth: float) -> int:
    xp = max(0, xp)
    base = max(1, base)
    growth = max(1.0, growth)
    level = 1
    remaining = xp
    while True:
        required = math.floor(base * (growth ** (level - 1)))
        if remaining < required:
            return level
        remaining -= required
        level += 1


def resolve_team(
    team: list[TeamPet],
    pet_configs: dict[tuple[str, str], PetVariant],
    progression: ProgressionConfig,
    team_size: int,
    player_level: int,
    player_progression: PlayerProgressionConfig,
) -> list[ResolvedPet]:
    p_mult = player_power_multiplier(
        player_level,
        player_progression.start_level,
        player_progression.percent_per_level,
        player_progression.max_bonus_percent,
    )

    first_pass: list[tuple[TeamPet, PetVariant, int]] = []
    for spec in team:
        config = pet_configs.get((spec.pet_id, spec.variant))
        if not config:
            raise KeyError(f"Unknown pet variant: {spec.pet_id}:{spec.variant}")
        max_level = progression.max_level_by_rarity.get(config.rarity, progression.default_max_level)
        level = min(spec.level, max_level)
        leveled = max(1, math.floor(config.power * power_multiplier(level, progression)))
        first_pass.append((spec, config, leveled))

    top_values = sorted((power for _, _, power in first_pass), reverse=True)
    limit = min(max(1, team_size), len(top_values))
    top_team_average = sum(top_values[:limit]) / limit if top_values else 1

    resolved: list[ResolvedPet] = []
    for spec, config, leveled_power in first_pass:
        eternal_percent = config.eternal_percent if config.eternal_enabled else 0
        if spec.huge:
            eternal_percent = max(100, eternal_percent)
        eternal_power = round(top_team_average * eternal_percent / 100) if eternal_percent > 0 else 0
        effective = math.floor(max(leveled_power, eternal_power) * p_mult)
        name_prefix = "Huge " if spec.huge else ""
        resolved.append(
            ResolvedPet(
                spec=spec,
                display_name=f"{name_prefix}{config.display_name}",
                rarity="huge" if spec.huge else config.rarity,
                configured_power=config.power,
                leveled_power=leveled_power,
                eternal_percent=eternal_percent,
                effective_power=effective,
            )
        )
    return resolved


def print_team(title: str, resolved: list[ResolvedPet]) -> None:
    print(f"\n{title}")
    print("-" * len(title))
    print(f"{'Pet':28} {'Lvl':>4} {'Rarity':>10} {'Base':>6} {'Leveled':>8} {'Eternal':>8} {'Final':>7}")
    for row in sorted(resolved, key=lambda pet: pet.effective_power, reverse=True):
        eternal = f"{row.eternal_percent:.0f}%" if row.eternal_percent > 0 else "-"
        print(
            f"{row.display_name[:28]:28} {row.spec.level:>4} {row.rarity:>10} "
            f"{row.configured_power:>6} {row.leveled_power:>8} {eternal:>8} {row.effective_power:>7}"
        )
    print(f"{'Team total':28} {'':>4} {'':>10} {'':>6} {'':>8} {'':>8} {sum(p.effective_power for p in resolved):>7}")


def default_scenarios() -> list[tuple[str, list[TeamPet], int, int]]:
    return [
        (
            "Starter team, player level 1",
            [
                TeamPet("bear", "basic", 1),
                TeamPet("bunny", "basic", 1),
                TeamPet("doggy", "basic", 1),
            ],
            3,
            1,
        ),
        (
            "Early lucky team, player level 10",
            [
                TeamPet("bear", "rainbow", 1),
                TeamPet("doggy", "golden", 1),
                TeamPet("bunny", "basic", 1),
            ],
            3,
            10,
        ),
        (
            "Creator reward team, player level 15",
            [
                TeamPet("colorado", "basic", 1),
                TeamPet("bear", "rainbow", 1),
                TeamPet("doggy", "golden", 1),
            ],
            3,
            15,
        ),
        (
            "Huge eternal pressure test, player level 15",
            [
                TeamPet("colorado", "rainbow", 1, huge=True),
                TeamPet("bear", "rainbow", 1),
                TeamPet("doggy", "golden", 1),
            ],
            3,
            15,
        ),
        (
            "Leveled special pressure test, player level 40",
            [
                TeamPet("colorado", "rainbow", 50, huge=True),
                TeamPet("dragon", "rainbow", 25),
                TeamPet("bear", "rainbow", 1),
            ],
            3,
            40,
        ),
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description="Calculate rough pet team power from config.")
    parser.add_argument("--team-size", type=int, default=3)
    parser.add_argument("--player-level", type=int)
    parser.add_argument("--player-xp", type=int, help="Optional player XP. Used to estimate level when --player-level is omitted.")
    parser.add_argument("--player-xp-base", type=int, default=100)
    parser.add_argument("--player-xp-growth", type=float, default=1.15)
    parser.add_argument("--pet", action="append", type=parse_team_pet, help="Pet spec: pet:variant[:level][:huge]. Repeat for team.")
    parser.add_argument("--list-pets", action="store_true", help="List configured pet variants and exit.")
    args = parser.parse_args()

    pet_configs = load_pets()
    progression = load_progression()
    player_progression = load_player_progression()
    player_level = args.player_level
    if player_level is None:
        player_level = level_from_xp(args.player_xp, args.player_xp_base, args.player_xp_growth) if args.player_xp is not None else 1

    if args.list_pets:
        print(f"{'Pet spec':24} {'Rarity':>10} {'Power':>6} {'Eternal':>8}")
        for key in sorted(pet_configs):
            pet = pet_configs[key]
            eternal = f"{pet.eternal_percent:.0f}%" if pet.eternal_enabled else "-"
            print(f"{pet.pet_id + ':' + pet.variant:24} {pet.rarity:>10} {pet.power:>6} {eternal:>8}")
        return 0

    print("Config snapshot")
    print("---------------")
    print(f"Loaded pet variants: {len(pet_configs)}")
    print(
        "Pet progression: "
        f"+{progression.percent_per_level * 100:.1f}% power/level, "
        f"cap +{progression.max_bonus_percent * 100:.0f}%"
    )
    if player_progression.percent_per_level > 0:
        print(
            "Player progression: "
            f"level {player_level}, +{player_progression.percent_per_level * 100:.1f}%/level "
            f"after level {player_progression.start_level}, "
            f"cap +{player_progression.max_bonus_percent * 100:.0f}%"
        )
    else:
        detail = f"level {player_level}"
        if args.player_xp is not None and args.player_level is None:
            detail += f" estimated from {args.player_xp} XP"
        print(f"Player level assumption: {detail}; no direct power bonus configured")

    if args.pet:
        resolved = resolve_team(
            args.pet,
            pet_configs,
            progression,
            args.team_size,
            player_level,
            player_progression,
        )
        print_team(f"Custom team, player level {player_level}, team size {args.team_size}", resolved)
        return 0

    for title, team, team_size, player_level in default_scenarios():
        resolved = resolve_team(
            team,
            pet_configs,
            progression,
            team_size,
            player_level,
            player_progression,
        )
        print_team(f"{title}, team size {team_size}", resolved)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
