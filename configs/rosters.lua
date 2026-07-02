--[[
    Roster system — Halo & Horns [PROTOTYPE] (Feature 17).

    Player-defined named teams: { name, ordered_pets, max_to_deploy, injury_rule }.
    Invoking a roster replaces the active squad with up to max_to_deploy pets,
    chosen per the injury_rule. max_to_deploy is clamped to the active-squad
    capacity (configs/squad.lua). Pure rules: `src/Shared/Game/RosterLogic.lua`.
]]

return {
    injury_rules = { "ready_only", "best_available", "deploy_anyway" },
    default_injury_rule = "ready_only",
}
