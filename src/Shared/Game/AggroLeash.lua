--[[
    AggroLeash — pure persistence math for enemy aggro (Halo & Horns combat).

    The threat table (src/Shared/Game/AggroTable) decides WHO an enemy is angry at. This module
    decides HOW LONG it stays angry as that target moves away. The model is PURE DECAY (Jason): an
    enemy never "hard locks" onto you — it stays engaged only while its threat is above the disengage
    threshold, and threat bleeds faster the farther you run, so if you keep your distance it falls to
    zero and the enemy gives up. There is exactly ONE hard cutoff, purely to defeat teleports.

    Distance is measured to the NEAREST LIVE PET (combat is vs pets, and pets follow the player):

      dist <= decay_start_range            threat decays at the BASE rate (you're "in the fight").
      decay_start_range < dist <= give_up  threat decays chase_decay_mult× faster (and
                                           leave_area_decay_mult× once the target has left the enemy's
                                           home area) -> a fleeing target bleeds the enemy's interest
                                           and it quits after a short chase.
      dist > give_up_range                 DROP immediately. The ONLY hard leash — teleport / world-
                                           hop insurance (the whole squad leaves range at once).

    Initial aggro (acquiring a target from zero) is a SEPARATE concern handled by perception/proximity
    in EnemyService — this module only governs letting go once already engaged.

    CC effects (taunt / fear / daze) layer ON TOP of this, they don't change the decay math:
      * taunt — force the enemy's target to a chosen pet for a duration (overrides table top).
      * fear  — the enemy flees the source for a duration (target preserved, movement inverted).
      * daze / stun — action-lock (can't move or attack) while the threat table is preserved.
    The table + decay own "who / how long"; CC owns "what it does right now."

    Pure + Roblox-free: dist is a number; cfg is the engagement.aggro config table.
]]

local AggroLeash = {}

local DEFAULTS = {
    decay_start_range = 90, -- beyond this, threat starts bleeding faster (you're fleeing)
    give_up_range = 300, -- the ONE hard cutoff: teleport / far side of map / new world
    chase_decay_mult = 3, -- threat bleeds this much faster once past decay_start_range
    leave_area_decay_mult = 6, -- ...and this much faster if the target left the enemy's home area
}

local function num(cfg, key)
    local v = cfg and cfg[key]
    return (type(v) == "number") and v or DEFAULTS[key]
end

-- Threat-decay multiplier for the current target distance. 1× while you're close (within
-- decay_start_range); chase_decay_mult× once you run past it; leave_area_decay_mult× (the larger of
-- the two) once you've left the enemy's home area entirely, so a target fleeing into the next biome
-- is forgotten quickly. This is the whole leash — there is no "locked on forever" zone.
function AggroLeash.decayMult(dist, inTerritory, cfg)
    local mult = 1
    if dist > num(cfg, "decay_start_range") then
        mult = num(cfg, "chase_decay_mult")
    end
    if not inTerritory then
        mult = math.max(mult, num(cfg, "leave_area_decay_mult"))
    end
    return mult
end

-- Should the enemy let go of aggro entirely? Yes if the squad has teleported past give_up_range
-- (the hard cutoff), OR threat has bled below the disengage threshold so there's no valid target
-- left (hasThreatTarget = false). Everything between those is governed by the decay above — the
-- enemy keeps chasing as long as some threat remains.
function AggroLeash.shouldDrop(dist, hasThreatTarget, cfg)
    if dist > num(cfg, "give_up_range") then
        return true
    end
    return not hasThreatTarget
end

return AggroLeash
