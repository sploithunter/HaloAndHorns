--!strict

-- Pure priority seam for the paid Merge auto-merge loop. The server recomputes the line plan after
-- every mutation, so an egg produced by a board merge is offered to the frontline before it can
-- cascade into another board tier.

local MergeEggAutoMergePriority = {}

export type LineStep = {
    teamId: number,
    sourceTier: number,
}

export type Action = {
    kind: "line" | "board",
    teamId: number?,
    sourceTier: number,
}

function MergeEggAutoMergePriority.nextAction(args: {
    linePlan: { LineStep }?,
    inventory: { [number]: number }?,
    maximumTier: number?,
    mergeRatio: number?,
}): Action?
    local linePlan = type(args.linePlan) == "table" and args.linePlan or {}
    local first = linePlan[1]
    if type(first) == "table" then
        local teamId = math.floor(tonumber(first.teamId) or 0)
        local sourceTier = math.floor(tonumber(first.sourceTier) or 0)
        if teamId > 0 and sourceTier > 0 then
            return {
                kind = "line",
                teamId = teamId,
                sourceTier = sourceTier,
            }
        end
    end

    local inventory = type(args.inventory) == "table" and args.inventory or {}
    local maximumTier = math.max(0, math.floor(tonumber(args.maximumTier) or 0))
    local mergeRatio = math.max(2, math.floor(tonumber(args.mergeRatio) or 2))
    for tier = 1, math.max(0, maximumTier - 1) do
        if math.max(0, math.floor(tonumber(inventory[tier]) or 0)) >= mergeRatio then
            return {
                kind = "board",
                sourceTier = tier,
            }
        end
    end
    return nil
end

return MergeEggAutoMergePriority
