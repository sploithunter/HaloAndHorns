-- Activity worlds retain their own target folder while sharing a configured area's mining gate.
local BreakableWorld = {}
function BreakableWorld.area(config, world)
    local activity = config.activity_worlds and config.activity_worlds[world]
    return activity and activity.mining_area or world
end
function BreakableWorld.isManaged(config, world)
    return world:sub(1, 8) == "mission_"
        or (config.activity_worlds ~= nil and config.activity_worlds[world] ~= nil)
end
return BreakableWorld
