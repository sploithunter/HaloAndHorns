--[[
    pet_origin_integrity — every HATCH pet (one that appears in an egg's pet_weights) must carry a
    static `origin` field matching the egg's area (egg_sources.pet_weights + realm_area_eggs are the
    SSOT). Catches the recurring "new pets imported without an origin" gap. Pets not in any egg
    (Creator Colorado + OG template animals) are exempt.
]]

local pets = loadModule("configs/pets.lua")

-- every realm_area_eggs area key (base earth/ember/sand + heaven/hell egg-named aliases) normalized
-- to the canonical origin vocabulary
local AREA_ALIAS = {
    grass = "grass",
    earth = "grass",
    bloom = "grass",
    blight = "grass",
    lava = "lava",
    ember = "lava",
    fire = "lava",
    solar = "lava",
    infernal = "lava",
    ice = "ice",
    aurora = "ice",
    black_ice = "ice",
    desert = "desert",
    sand = "desert",
    gilded = "desert",
    guilded = "desert",
    ash = "desert",
}

return function()
    describe("pet origin integrity (every hatch pet has the right origin)", function()
        local cfg = pets
        local eggs = cfg.egg_sources or {}
        local rae = cfg.realm_area_eggs or {}
        local petDefs = cfg.pets or {}

        -- egg -> canonical area
        local eggToArea = {}
        for _, areas in pairs(rae) do
            for areaKey, eggName in pairs(areas) do
                local canon = AREA_ALIAS[areaKey]
                if canon then
                    eggToArea[eggName] = canon
                end
            end
        end
        -- pet -> derived area (via its egg's pet_weights)
        local petToArea = {}
        for eggName, egg in pairs(eggs) do
            if type(egg) == "table" and type(egg.pet_weights) == "table" then
                local area = eggToArea[eggName]
                if area then
                    for petKey in pairs(egg.pet_weights) do
                        petToArea[petKey] = area
                    end
                end
            end
        end

        -- Every pet in an egg pool must have an origin. Exclusive/non-area eggs (e.g. colorado_egg)
        -- use the "creator" origin (own identity, matchup-neutral — no resonance row), so there's no
        -- per-pet exemption: a new exclusive without an origin SHOULD fail here and force the decision.
        it("every pet that appears in ANY egg pool has an origin", function()
            local missing = {}
            for eggName, egg in pairs(eggs) do
                if type(egg) == "table" and type(egg.pet_weights) == "table" then
                    for petKey in pairs(egg.pet_weights) do
                        local pet = petDefs[petKey]
                        if type(pet) == "table" and pet.origin == nil then
                            missing[#missing + 1] = `{petKey} (egg={eggName})`
                        end
                    end
                end
            end
            if #missing > 0 then
                error(`hatch pets missing origin: {table.concat(missing, ", ")}`)
            end
            expect(#missing).to.equal(0)
        end)

        it("every pet in an area-mapped egg carries origin == its egg's area", function()
            local missing, wrong = {}, {}
            for petKey, area in pairs(petToArea) do
                local pet = petDefs[petKey]
                if type(pet) == "table" then
                    if pet.origin == nil then
                        missing[#missing + 1] = petKey
                    elseif pet.origin ~= area then
                        wrong[#wrong + 1] = `{petKey}={pet.origin}~={area}`
                    end
                end
            end
            if #missing > 0 then
                error(`hatch pets missing origin: {table.concat(missing, ", ")}`)
            end
            if #wrong > 0 then
                error(`hatch pets with wrong origin: {table.concat(wrong, ", ")}`)
            end
            expect(#missing).to.equal(0)
            expect(#wrong).to.equal(0)
        end)
    end)
end
