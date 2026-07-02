--[[
    EggStandResolver — pure resolution of WHICH egg an authored egg-hatcher stand should display,
    from the realm it lives in and its own name. No Roblox APIs (headlessly tested).

    The unified rule (replaces the old name->egg `egg_stand_placements` table + fabricated stands):
      • realm = the stand's world, resolved by the caller via WorldContext (Home -> "base",
                Heaven_1 -> "heaven", Hell_1 -> "hell"). Passed in here.
      • area  = the matrix area key the stand NAME contains, case-insensitive (a stand named "Lava"
                -> lava, "Ice" -> ice). Longest match wins (deterministic, order-independent).
      • egg   = matrix[realm][area]

    `matrix` is configs/pets.lua `realm_area_eggs`. Returns eggId, area (both nil if unresolved).
    The world->realm walk (WorldContext.of) and instance handling live in EggStandPlacement; this
    module is just the lookup so it can be tested without a DataModel.
]]

local EggStandResolver = {}

-- eggId, area for a stand named `standName` in realm `realm`, or nil if none matches. Area match is
-- "name contains the area key" so authored names can carry prefixes/suffixes ("HeavenLavaStand",
-- "Ice_2") and still resolve; the LONGEST matching key wins so overlaps are deterministic.
function EggStandResolver.eggFor(realm, standName, matrix)
    if type(realm) ~= "string" or type(standName) ~= "string" or type(matrix) ~= "table" then
        return nil
    end
    local areas = matrix[realm]
    if type(areas) ~= "table" then
        return nil
    end
    local lname = string.lower(standName)
    local bestArea, bestEgg, bestLen
    for area, eggId in pairs(areas) do
        if string.find(lname, area, 1, true) and (not bestLen or #area > bestLen) then
            bestArea, bestEgg, bestLen = area, eggId, #area
        end
    end
    return bestEgg, bestArea
end

return EggStandResolver
