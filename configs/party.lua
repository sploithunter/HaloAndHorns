--[[
    Party / Group play — Halo & Horns [PROTOTYPE] (Feature 18).

    Up to `max_size` players; each keeps their own active squad. Cross-player
    support powers default on. Enemy difficulty scales with party size (the curve
    is shared with combat — configs/combat.lua group_scaling). Loot is split per
    `loot_rule`. Pure math: `src/Shared/Game/PartyMath.lua`.
]]

return {
    -- DUO CAP for now (Jason 2026-07-07): the TeamPanel has no invite-while-teamed flow, so a
    -- third member was never actually reachable — make the config match the truth. POSTPONED
    -- 4-player design (docs/TEAMING.md): invite from the teamed roster + click a teammate's
    -- rail card to expand their pets while the other members' groups collapse (the >2 collapse
    -- behaviour already exists in SquadHud). Raise this back to 4 when that ships.
    max_size = 2,
    cross_player_support = true,
    loot_rule = "split_equally",
    mvp_bonus_percent = 10, -- extra share to the top damage contributor
}
