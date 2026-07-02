--[[
    Studio smoke test for map marker contract readiness.

    Run in play mode:

    return require(game:GetService("ReplicatedStorage").Tests.studio.MapContractSmoke).runText()
]]

local MapContractSmoke = {}

local CollectionService = game:GetService("CollectionService")

local DEFAULT_EXPECTED_COUNTS = {
    Zone = 5,
    AreaZone = 2,
    SpawnZone = 2,
    EggStand = 1,
    PODPodium = 2,
    TeleportPad = 2,
    Portal = 2,
}

local REQUIRED_ATTRIBUTES = {
    Zone = { "ZoneId", "Kind" },
    AreaZone = { "AreaId" },
    SpawnZone = { "AreaId", "SpawnerId" },
    EggStand = { "EggId" },
    PODPodium = {},
    TeleportPad = { "AreaId", "TargetZoneId" },
    Portal = { "ZoneId", "TargetZoneId" },
}

local function inspectTag(tagName)
    local count = 0
    local authored = 0
    local synthetic = 0
    local missing = {}

    for _, instance in ipairs(CollectionService:GetTagged(tagName)) do
        if instance:IsDescendantOf(workspace) then
            count += 1
            if instance:GetAttribute("Synthetic") == true then
                synthetic += 1
            else
                authored += 1
            end

            for _, attributeName in ipairs(REQUIRED_ATTRIBUTES[tagName] or {}) do
                if instance:GetAttribute(attributeName) == nil then
                    table.insert(missing, instance:GetFullName() .. "." .. attributeName)
                end
            end
        end
    end

    return {
        count = count,
        authored = authored,
        synthetic = synthetic,
        missing = missing,
    }
end

function MapContractSmoke.run(options)
    options = options or {}

    local expectedCounts = options.expectedCounts or DEFAULT_EXPECTED_COUNTS
    local requireAuthored = options.requireAuthored == true
    local allowSynthetic = options.allowSynthetic ~= false
    local tags = options.tags
        or { "Zone", "AreaZone", "SpawnZone", "EggStand", "PODPodium", "TeleportPad", "Portal" }

    local summary = {}
    local totalAuthored = 0
    local totalSynthetic = 0

    for _, tagName in ipairs(tags) do
        local tagSummary = inspectTag(tagName)
        summary[tagName] = tagSummary
        totalAuthored += tagSummary.authored
        totalSynthetic += tagSummary.synthetic

        local expected = expectedCounts[tagName]
        if expected and tagSummary.count < expected then
            error(
                string.format(
                    "MapContractSmoke expected at least %d %s hooks, found %d",
                    expected,
                    tagName,
                    tagSummary.count
                )
            )
        end

        if #tagSummary.missing > 0 then
            error(
                tagName .. " hooks missing attributes: " .. table.concat(tagSummary.missing, ", ")
            )
        end
    end

    if requireAuthored and totalAuthored == 0 then
        error("MapContractSmoke required authored hooks, but all live hooks are synthetic")
    end

    if not allowSynthetic and totalSynthetic > 0 then
        error("MapContractSmoke disallowed synthetic hooks, but found " .. tostring(totalSynthetic))
    end

    return {
        ok = true,
        summary = summary,
        totalAuthored = totalAuthored,
        totalSynthetic = totalSynthetic,
    }
end

function MapContractSmoke.runText(options)
    local result = MapContractSmoke.run(options)
    local parts = {}
    for tagName, tagSummary in pairs(result.summary) do
        table.insert(
            parts,
            string.format(
                "%s=%d(a%d/s%d)",
                tagName,
                tagSummary.count,
                tagSummary.authored,
                tagSummary.synthetic
            )
        )
    end
    table.sort(parts)

    return string.format(
        "MapContractSmoke passed: authored=%d synthetic=%d %s",
        result.totalAuthored,
        result.totalSynthetic,
        table.concat(parts, " ")
    )
end

return MapContractSmoke
