--[[
    FoundersChoice — Roblox-free rules for the launch cohort's permanent pass benefit.

    Marketplace ownership and the promotional choice remain different sources. The effective
    entitlement set is their union, deduplicated by pass id; UI can therefore describe the source
    honestly while every gameplay consumer continues reading one effective OwnedPasses list.
]]

local FoundersChoice = {}

function FoundersChoice.eligibleSet(config)
    local result = {}
    local feature = config and config.founders_choice or {}
    for _, passId in ipairs(feature.eligible_passes or {}) do
        if type(passId) == "string" and passId ~= "" then
            result[passId] = true
        end
    end
    return result
end

function FoundersChoice.isEligiblePass(config, passId)
    return type(passId) == "string" and FoundersChoice.eligibleSet(config)[passId] == true
end

function FoundersChoice.normalizeState(raw, cohortId)
    raw = type(raw) == "table" and raw or {}
    return {
        cohortId = type(raw.cohortId) == "string" and raw.cohortId or cohortId or "",
        eligibilityDecided = raw.eligibilityDecided == true,
        eligible = raw.eligible == true,
        claimNumber = math.max(0, math.floor(tonumber(raw.claimNumber) or 0)),
        selectedPassId = type(raw.selectedPassId) == "string" and raw.selectedPassId or "",
        selectedAt = math.max(0, math.floor(tonumber(raw.selectedAt) or 0)),
        reselections = math.max(0, math.floor(tonumber(raw.reselections) or 0)),
    }
end

function FoundersChoice.effectivePasses(configuredPasses, sourceSets, founderPassId, suppressAll)
    local result = {}
    local sources = {}
    sourceSets = type(sourceSets) == "table" and sourceSets or {}

    for _, pass in ipairs(configuredPasses or {}) do
        local passId = type(pass) == "table" and pass.id or nil
        if type(passId) == "string" then
            local passSources = {}
            if not suppressAll then
                for sourceName, owned in pairs(sourceSets) do
                    if type(owned) == "table" and owned[passId] == true then
                        passSources[sourceName] = true
                    end
                end
                if passId == founderPassId then
                    passSources.founder = true
                end
            end
            if next(passSources) ~= nil then
                result[#result + 1] = passId
                sources[passId] = passSources
            end
        end
    end

    return result, sources
end

function FoundersChoice.canChoose(state)
    state = FoundersChoice.normalizeState(state)
    return state.eligible and state.selectedPassId == ""
end

return FoundersChoice
