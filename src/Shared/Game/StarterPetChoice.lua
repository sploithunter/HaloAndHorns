--!strict

-- Pure rules for the one-time first-companion selector. The server remains authoritative;
-- the client receives only stateFor's display projection.
local StarterPetChoice = {}

local function petItems(data)
    local inventory = type(data) == "table" and data.Inventory
    local pets = type(inventory) == "table" and inventory.pets
    return type(pets) == "table" and pets.items or nil
end

function StarterPetChoice.choiceById(config, petType)
    if type(config) ~= "table" or type(petType) ~= "string" then
        return nil
    end
    for _, choice in ipairs(config.choices or {}) do
        if choice.id == petType then
            return choice
        end
    end
    return nil
end

function StarterPetChoice.findGrantedStarter(data)
    for _, record in pairs(petItems(data) or {}) do
        if type(record) == "table" and record.grant_source == "starter_choice" then
            return record
        end
    end
    return nil
end

function StarterPetChoice.hasOwnedPet(data)
    return next(petItems(data) or {}) ~= nil
end

function StarterPetChoice.isEligible(config, data)
    if type(config) ~= "table" or config.enabled ~= true or type(data) ~= "table" then
        return false
    end
    local state = data.StarterPet
    if type(state) == "table" and type(state.choice) == "string" and state.choice ~= "" then
        return false
    end
    if StarterPetChoice.findGrantedStarter(data) then
        return false
    end

    -- Admin reset explicitly re-arms the selector even when valuable huges remain protected.
    if type(state) == "table" and state.forceOffer == true then
        return true
    end

    local stats = data.Stats
    local claimed = type(stats) == "table" and tonumber(stats.ClaimedLevel or stats.Level) or 1
    if (claimed or 1) > 1 or StarterPetChoice.hasOwnedPet(data) then
        return false
    end
    local tutorial = data.Tutorial
    if
        type(tutorial) == "table" and (tutorial.done == true or (tonumber(tutorial.step) or 1) > 1)
    then
        return false
    end
    return true
end

function StarterPetChoice.stateFor(config, data)
    local saved = type(data) == "table" and data.StarterPet or nil
    return {
        version = tonumber(config and config.version) or 1,
        eligible = StarterPetChoice.isEligible(config, data),
        selected = type(saved) == "table" and saved.choice or nil,
        choices = (config and config.choices) or {},
        grantVariant = (config and config.grant and config.grant.variant) or "basic",
    }
end

return StarterPetChoice
