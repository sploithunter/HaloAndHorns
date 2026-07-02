--[[
    Pet Power pipeline (Pet Realm) — config-as-code knobs for how a pet's dev-set base power
    becomes the TWO numbers shown on the inventory card (⛏ Mining / ⚔ Combat) and the live damage
    it deals. Resolved by the pure src/Shared/Game/PetPower.lua; assembled from configs by the
    shared PetPowerView so the inventory display and the dealt damage use the SAME math.

    Layers (each a multiplicative knob — add a term to add a future multiplier):
      base            — the dev knob (pets.lua base_power / huge_base_power; the pet's Power value)
      × base_scale    — global tuning lever (1 = base power maps 1:1 to pre-multiplier damage)
      × element_mult  — INTRINSIC element flat attack (configs/combat_fx.lua origin.element_stats)
      × variant_mult  — INTRINSIC golden/rainbow power bump (below)
      × aptitude      — INTRINSIC role/pet mining-vs-combat skill (pet_roles.lua mining_mult /
                        combat_mult, overridable per pet in pets.lua) -> this split is what makes a
                        pet better at MINING vs COMBAT (and drives trading)
      × context       — CONTEXTUAL: player level, boosts, gamepasses... (all default 1; built later)

    INTRINSIC layers (everything except context) = the "base calculated power" shown on the card:
    deterministic per pet, identical for everyone, so it's the fair trade-comparison number.
    CONTEXTUAL layers = the live "effective" power for a specific owner at a specific moment.
]]

return {
    -- Global lever: dev base_power -> pre-multiplier power. 1.0 keeps the current 1:1 mapping.
    base_scale = 1.0,

    -- VARIANT POWER LIVES ONCE in pets.lua variants.power_multiplier (x1 / x1.5 / x2),
    -- already baked into the pet's Power value that feeds `base` here. These knobs are
    -- NEUTRAL by design — they MULTIPLY ON TOP of that law, so any non-1.0 value
    -- double-counts the variant (the 2026-06-12 bug: golden displayed x2.25, rainbow
    -- x5, while the eternal baseline only saw the first multiplier). Only diverge
    -- these if you deliberately want display/damage to outpace the baseline law.
    variant_mult = {
        basic = 1.0,
        golden = 1.0,
        rainbow = 1.0,
    },
    default_variant_mult = 1.0,

    -- Contextual multiplier DEFAULTS (the framework for "player levels, boosts, things"). Each is
    -- a number knob; 1.0 = no effect. PetPowerView fills real values later (level curve, the
    -- active-mining Boost, gamepasses). Listed here so every contextual lever has a config home.
    context_defaults = {
        level_mult = 1.0, -- scales with player/pet level (curve wired later)
        boost_mult = 1.0, -- active-mining boost + temp buffs
        gamepass_mult = 1.0, -- premium multipliers
    },

    -- How the card ROUNDS the displayed numbers (damage keeps its own floor in PetCombat).
    display_round = "round", -- "round" | "floor" | "ceil"

    -- HARD CEILING on any pet's resolved power. The Creator-class apex (Creator Rainbow Colorado)
    -- sits exactly here; NOTHING — huge / titanic / colossal / future tiers — can ever exceed it,
    -- because PetPower.resolveProfile clamps to it. A guarantee, not a convention. Tune at balance.
    max_pet_power = 1000000,

    -- Geometric tier ladder — the bounded "pets are stars" curve. tierBase(tier) =
    -- starter_base * step^(tier-1), clamped to max_pet_power. ~25-35 tiers carry ~1000 -> the
    -- ceiling, each a clear upgrade. Pet definitions adopt tiers at the balance pass (S2b);
    -- existing pets keep their base_power until then, so this is currently live-neutral.
    tier_curve = {
        starter_base = 1000,
        step = 1.4,
    },

    -- Shiny — the 5th pet axis. COSMETIC prestige, power-NEUTRAL by default (1.0). The only source
    -- today is the Meet-the-Creator egg (always shiny). Keep at 1.0 to stay out of the balance math.
    shiny_mult = 1.0,
}
