--!strict

-- Pure one-pass planner for the Merge Egg floor Equip Best control. The same plan drives both the
-- server action and the green/gray availability signal, so presentation cannot advertise an egg
-- that the deployment rules will reject.

local MergeEggEquipBest = {}

export type Team = {
    id: number,
    tier: number?,
    available: boolean?,
}

export type Step = {
    teamId: number,
    sourceTier: number,
}

function MergeEggEquipBest.plan(args: {
    maximumTier: number?,
    inventory: { [number]: number }?,
    teams: { Team }?,
}): { Step }
    local maximumTier = math.max(0, math.floor(tonumber(args.maximumTier) or 0))
    local inventory = type(args.inventory) == "table" and args.inventory or {}
    local teams = type(args.teams) == "table" and args.teams or {}
    local plan: { Step } = {}
    local remaining: { [number]: number } = {}
    local touched: { [number]: boolean } = {}

    for tier = 1, maximumTier do
        remaining[tier] = math.max(0, math.floor(tonumber(inventory[tier]) or 0))
    end

    local function available(team: Team): boolean
        return team.available ~= false and not touched[team.id]
    end
    local function tierOf(team: Team): number
        return math.clamp(math.floor(tonumber(team.tier) or 0), 0, maximumTier)
    end
    local function strongestRemainingTier(): number?
        for tier = maximumTier, 1, -1 do
            if (remaining[tier] or 0) > 0 then
                return tier
            end
        end
        return nil
    end
    local function assign(team: Team, sourceTier: number?)
        if not available(team) or sourceTier == nil or (remaining[sourceTier] or 0) <= 0 then
            return
        end
        remaining[sourceTier] -= 1
        touched[team.id] = true
        plan[#plan + 1] = {
            teamId = team.id,
            sourceTier = sourceTier,
        }
    end

    -- Empty hatchers receive the strongest available eggs first.
    for _, team in ipairs(teams) do
        if available(team) and tierOf(team) == 0 then
            assign(team, strongestRemainingTier())
        end
    end

    -- Occupied hatchers advance only from an equal-tier board egg, once per pass.
    local occupied = table.clone(teams)
    table.sort(occupied, function(a, b)
        local tierA = tierOf(a)
        local tierB = tierOf(b)
        return tierA == tierB and a.id < b.id or tierA < tierB
    end)
    for _, team in ipairs(occupied) do
        local tier = tierOf(team)
        if available(team) and tier > 0 and tier < maximumTier then
            assign(team, tier)
        end
    end

    return plan
end

return MergeEggEquipBest
