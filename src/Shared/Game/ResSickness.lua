--[[
    ResSickness — the post-revive HEAL CLAMP (Jason 2026-07-02: "make it unhealable or otherwise
    leave it low for a bit — otherwise we could just do a 100% res").

    PetRevive stamps ResSicknessFloor (the damage-taken floor = the missing health from
    revive.health_frac) + ResSicknessUntil (now + revive.sickness_seconds) on every partial
    revive. While the window is live NO heal may take CombatDamageTaken below the floor — the
    genie's arrival burst, HoTs, regen and support auras all top the pet up only to its res
    health until the sickness passes. Damage still stacks normally; when the window lapses,
    every heal path works as usual (the attributes just read as expired).

    Pure + Roblox-free: pass pet:GetAttributes() (or any table) + os.time().
]]

local ResSickness = {}

-- The damage-taken FLOOR while the sickness window is live; 0 once it lapses / was never set.
function ResSickness.floorFor(attrs, now)
    if (tonumber(attrs and attrs.ResSicknessUntil) or 0) <= (tonumber(now) or 0) then
        return 0
    end
    return tonumber(attrs.ResSicknessFloor) or 0
end

-- Clamp a post-heal damage-taken value against the sickness floor. Apply at EVERY heal write.
function ResSickness.clampTaken(attrs, newTaken, now)
    return math.max(tonumber(newTaken) or 0, ResSickness.floorFor(attrs, now))
end

return ResSickness
