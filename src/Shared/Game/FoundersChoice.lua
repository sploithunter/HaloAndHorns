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

function FoundersChoice.isTestUser(config, userId)
    local feature = config and config.founders_choice or {}
    userId = tonumber(userId)
    for _, configuredId in ipairs(feature.test_user_ids or {}) do
        if userId and tonumber(configuredId) == userId then
            return true
        end
    end
    return false
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
        legacyUnlocked = raw.legacyUnlocked == true,
        legacyUnlockedAt = math.max(0, math.floor(tonumber(raw.legacyUnlockedAt) or 0)),
        legacyCatalogVersion = math.max(0, math.floor(tonumber(raw.legacyCatalogVersion) or 0)),
    }
end

function FoundersChoice.ownsEveryEligiblePass(config, ownedPasses)
    ownedPasses = type(ownedPasses) == "table" and ownedPasses or {}
    local feature = config and config.founders_choice or {}
    local count = 0
    for _, passId in ipairs(feature.eligible_passes or {}) do
        count += 1
        if ownedPasses[passId] ~= true then
            return false
        end
    end
    return count > 0
end

function FoundersChoice.canUnlockLegacy(config, state, ownedPasses)
    local feature = config and config.founders_choice or {}
    local legacy = feature.legacy or {}
    state = FoundersChoice.normalizeState(state, feature.cohort_id)
    return legacy.enabled == true
        and state.eligible == true
        and state.legacyUnlocked ~= true
        and FoundersChoice.ownsEveryEligiblePass(config, ownedPasses)
end

function FoundersChoice.effectivePasses(
    configuredPasses,
    sourceSets,
    founderPassId,
    suppressNonFounder
)
    local result = {}
    local sources = {}
    sourceSets = type(sourceSets) == "table" and sourceSets or {}

    for _, pass in ipairs(configuredPasses or {}) do
        local passId = type(pass) == "table" and pass.id or nil
        if type(passId) == "string" then
            local passSources = {}
            if not suppressNonFounder then
                for sourceName, owned in pairs(sourceSets) do
                    if type(owned) == "table" and owned[passId] == true then
                        passSources[sourceName] = true
                    end
                end
            end
            -- The creator/test pass gate suppresses Marketplace, creator, and Studio test grants,
            -- but the explicitly selected Founder benefit remains. This is the repeatable test
            -- workflow: Admin Reset = no passes; choose once = exactly that one benefit.
            if passId == founderPassId then
                passSources.founder = true
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
    return state.eligible and not state.legacyUnlocked and state.selectedPassId == ""
end

-- Re-arm only the profile-side choice. The production cohort roster is deliberately untouched;
-- explicit test accounts reserve ordinal 0 and can replay eligibility after tutorial completion.
function FoundersChoice.resetTestState(cohortId)
    return FoundersChoice.normalizeState({
        cohortId = cohortId,
        eligibilityDecided = false,
        eligible = false,
        claimNumber = 0,
        selectedPassId = "",
        selectedAt = 0,
        reselections = 0,
        legacyUnlocked = false,
        legacyUnlockedAt = 0,
        legacyCatalogVersion = 0,
    }, cohortId)
end

return FoundersChoice
