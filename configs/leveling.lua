--[[
    Leveling / difficulty scaling — Halo & Horns [PROTOTYPE].

    Combat numbers stay in a tight ~100 band; LEVEL DIFFERENCE does the scaling (see
    src/Shared/Game/LevelScale). Pets level up to out-level enemies (tougher without HP
    inflation); enemies show a difficulty colour relative to YOUR level.
]]

return {
    -- XP rewards: EVERYTHING you do grants XP, not just quests. Mining a node and defeating an
    -- enemy both feed the level bar; quests/daily/achievements add bigger chunks via RewardService.
    -- XP = max(min, floor(value * per_value)) where `value` is the activity's reward magnitude
    -- (ore Value for mining, loot total for combat). All knobs — tune to taste.
    -- per_value = XP as a FRACTION of the activity's coin magnitude (so "5% of the coins
    -- you earned"). Lowered 10x from the first pass (mining 0.5->0.05) because leveling was
    -- far too fast. min = 1 guarantees any successful action grants at least 1 XP, so small
    -- shares that floor to 0 still tick the bar (the "integer" floor — intentional). Tune
    -- freely; raise per_value to level faster, or raise player_progression.xp.per_level to
    -- make each level cost more (slows leveling without touching the per-action grant).
    xp_rewards = {
        mining = { per_value = 0.05, min = 1 }, -- ~5% of the ore's coin share (split per contributor)
        combat = { per_value = 0.1, min = 1 }, -- LEGACY (superseded by combat_xp below); kept for ref
    },

    -- COMBAT XP scales off the enemy's effective LEVEL + rank, NOT its (arbitrary) coin drop. The old
    -- "10% of loot total" tied XP to the coin economy: two level-21 enemies paid 1 vs 10 XP purely on
    -- their unrelated coin figures, and level never entered it. Now a kill's XP tracks CHALLENGE and
    -- carries a risk PREMIUM over farming. Empirically calibrated (Jason): active combat measured
    -- ~75-93 XP/min vs ~195 XP/min mining — backwards. xp_per_level = 2.0 → a level-21 trash kill ≈
    -- 42 XP → ~378 XP/min at ~9 kills/min ≈ 2× farming. rank_xp_mult pays lieutenants/bosses extra ON
    -- TOP of their level offset (rank_offset). Still passes through LevelDiffYield.xp (xp_level_scale)
    -- so over-leveling a weak mob is diminished — no farming trivial enemies. Floors at 1 (always ticks).
    combat_xp = {
        xp_per_level = 2.0,
        -- lieutenant / boss / ARCH-VILLAIN premium (archvillain = the super-boss tier above boss)
        rank_xp_mult = { trash_mob = 1.0, mid_tier = 1.6, boss = 3.0, archvillain = 6.0 },
    },

    -- COMBAT COINS for def-less kills (Jason: "you should drill coins also"). Pet-INVADERS
    -- (petinv_*, the realm population) have no static drop_table, so they'd pay ZERO coins even
    -- though killing a level-21 realm enemy should pay like farming there. This is the FALLBACK
    -- coin for a kill with no drop_table: coins = enemy effective level × coins_per_level × rank,
    -- paid in the player's CURRENT-AREA coin (RewardService:_resolveAreaCoin — desert/lava/ice/…).
    -- Scales off the enemy's level (realm depth already lifts it), rank pays lieutenants/bosses
    -- extra. NO diminish (coins stay flat by design — payout_level_scale is neutral; coins fund
    -- hatching). Enemies WITH a real drop_table keep it untouched; this only fills the gap.
    -- coins_per_level = 1.0 → a level-21 trash invader ≈ 21 coins (≈ 2× a Home enemy's ~10),
    -- a fair premium for a high-level realm kill without inflating the economy.
    combat_coins = {
        coins_per_level = 1.0,
        rank_coin_mult = { trash_mob = 1.0, mid_tier = 1.6, boss = 3.0, archvillain = 6.0 },
    },

    -- DIMINISHING XP vs out-leveled targets (Jason: "nobody should be able to put on an
    -- auto clicker... and wake up 10-20 levels ahead"). Applied via LevelDiffYield.xp to
    -- mining (crystal MiningLevel) and combat (enemy Level). At/above your level = full
    -- XP; below = -45%/level, floored at 10% (-1 -> 55%, -2 -> the floor). With the
    -- homeworld banded 1-4 (desert larges = 6), a level-7 player is near the floor on
    -- everything but larges and a level-9 is floored everywhere (Jason's targets) —
    -- heaven/hell realm bands (5+) are where leveling continues.
    xp_level_scale = { per_level_down = 0.45, floor = 0.10 },

    -- COIN payout vs level — a tuning SEAM shipped NEUTRAL (exactly x1 at any diff).
    -- Jason: money stays full at any level because coins fund hatching (more eggs =
    -- the actual game); this lever exists in case income inflation ever needs a brake.
    payout_level_scale = { per_level = 0, min = 1, max = 1 },

    -- Damage multiplier per level of (attacker - defender), clamped. +8% dmg per level up.
    scale = { per_level = 0.08, min = 0.3, max = 2.5 },

    -- ABSOLUTE enemy damage growth (Jason 2026-07-09: 'right amount of time,
    -- not the right amount of damage' — L50 packs dealt starter-meadow bites):
    -- enemy damage grows +5%/level of the ENEMY's own level, because pet
    -- endurance pools grow with level while enemy defs are static. Level-1
    -- content is untouched (curve starts at zero); an L50 minion bites ~3.5x
    -- its def value. Relative scale above stacks on top (rank/± difficulty).
    enemy_damage_growth = { per_level = 0.05, max_mult = 5 },

    -- Elite rank adds to an enemy's effective level vs its base (keyed by enemies.lua tier):
    -- a lieutenant reads one level higher, a boss one above that.
    rank_offset = {
        trash_mob = 0, -- standard
        mid_tier = 1, -- lieutenant
        boss = 2, -- boss
        archvillain = 3, -- arch-villain (the capital baddie reads three levels up)
    },

    -- Difficulty label colour by (enemy effective level - your level). Keys = LevelScale.tier.
    -- {r,g,b}; the client builds the Color3.
    tier_colors = {
        purple = { 180, 95, 230 }, -- +3 or more (deadly)
        red = { 225, 70, 70 }, -- +2
        yellow = { 235, 210, 70 }, -- +1
        white = { 245, 245, 245 }, -- even
        blue = { 95, 170, 235 }, -- -1
        green = { 110, 205, 110 }, -- -2
        gray = { 150, 150, 160 }, -- -3 or less (trivial)
    },
}
