--[[
    Squad Diversity — team-composition bonus (Jason). Rewards fielding a VARIED active squad:
    one bonus axis for distinct ARCHETYPES (tank/melee/blaster/buffer) and one for distinct
    ORIGINS (the biome elements). The bonus scales with DISTINCT categories present — duplicates
    earn nothing, so a second Blaster contributes 0 to diversity (pure opportunity cost). A full-set
    kicker rewards covering every category.

    Why: makes every archetype/origin matter (your best *support* is valuable even if it isn't your
    strongest pet), and the spread-vs-power tension grows with squad slots (4 slots forces a choice;
    10 slots let you cover diversity AND stack power). Drives players to collect more pets.

    Pure math lives in src/Shared/Game/SquadDiversity.lua; this is just the tunable knobs. The two
    axis bonuses ADD into one team multiplier (1 + archetypeBonus + originBonus), clamped to max_mult.
    Applied to BOTH mining and combat output via the resolver contextMult (PetFollowService).
]]

return {
    enabled = true,

    archetype = {
        -- The categories that count (matches pet_roles role ids). Add new archetypes here.
        categories = { "tank", "melee", "ranged", "support" },
        per_distinct = 0.05, -- +5% per distinct archetype fielded
        full_set_bonus = 0.10, -- extra +10% for covering ALL of them (4/4)
    },

    origin = {
        -- Biome element ids (combat_fx origin.pettype_element values). A 5th "exclusive" / no-origin
        -- class can drop in here later (Jason: undecided) — the math doesn't change.
        categories = { "lava", "ice", "grass", "desert" },
        per_distinct = 0.05, -- +5% per distinct origin fielded
        full_set_bonus = 0.10, -- extra +10% for covering ALL of them (4/4)
    },

    -- Hard ceiling on the combined team multiplier so origin-RPS × realm-resonance × diversity can't
    -- run away at the top end. Full diverse squad with defaults = 1 + 0.30 + 0.30 = 1.60x.
    max_mult = 2.0,
}
