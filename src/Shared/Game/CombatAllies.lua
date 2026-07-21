--[[
    CombatAllies — pure csv/name helpers for a player's COMBAT ALLIES: formal teammates
    (TeamMembers csv) ∪ temporary-alliance partners (AllianceWith csv, docs/TEAMING.md).
    Introduced when alliances became mutual GROUPS (Jason 2026-07-08: "heals and shields
    should apply to each other") so every consumer parses the same way — exact name match,
    never substring (a "Bob" must not match "Bobby").
]]

local CombatAllies = {}

-- Exact-membership test in a comma-separated name list.
function CombatAllies.csvHas(csv, name)
    if type(csv) ~= "string" or csv == "" or type(name) ~= "string" then
        return false
    end
    for entry in csv:gmatch("[^,]+") do
        if entry == name then
            return true
        end
    end
    return false
end

-- Unique ally names from the two csvs, excluding selfName. Order: first occurrence.
function CombatAllies.names(teamCsv, allianceCsv, selfName)
    local out, seen = {}, {}
    for _, csv in ipairs({ teamCsv, allianceCsv }) do
        if type(csv) == "string" and csv ~= "" then
            for entry in csv:gmatch("[^,]+") do
                if entry ~= selfName and not seen[entry] then
                    seen[entry] = true
                    out[#out + 1] = entry
                end
            end
        end
    end
    return out
end

return CombatAllies
