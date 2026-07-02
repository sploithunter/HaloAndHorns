--[[
    Stacked pet pool — Halo & Horns [PROTOTYPE] (Feature 8).

    Stacked common pets use a token-bucket model: a `ready_count` that depletes
    when a pet is downed and refills lazily over time. Read by
    `src/Shared/Game/StackPool.lua`.

    contribution_curve: "linear" (ready/total) or "sqrt_diminishing"
    (sqrt(ready)/sqrt(total)).
]]

return {
    recharge_per_instance_seconds = 300,
    contribution_curve = "linear",
}
