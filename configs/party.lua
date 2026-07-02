--[[
    Party / Group play — Halo & Horns [PROTOTYPE] (Feature 18).

    Up to `max_size` players; each keeps their own active squad. Cross-player
    support powers default on. Enemy difficulty scales with party size (the curve
    is shared with combat — configs/combat.lua group_scaling). Loot is split per
    `loot_rule`. Pure math: `src/Shared/Game/PartyMath.lua`.
]]

return {
    max_size = 4,
    cross_player_support = true,
    loot_rule = "split_equally",
    mvp_bonus_percent = 10, -- extra share to the top damage contributor
}
