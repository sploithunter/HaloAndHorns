--[[
    showcase — the BUILDER'S CUT place overlay (Jason 2026-07-09: "publish a
    second version of the game and make it trivial to progress... the builders
    version").

    Same repo, same code, published to a SECOND place: at config load, when
    game.PlaceId matches place_ids, apply(configs) mutates the loaded config
    tables into museum rules so a map builder can tour EVERYTHING in minutes —
    no grind, no combat pressure, no branch to drift.

    HARD RULE: the showcase place must live in its OWN experience (a fresh
    universe from File → Publish As). DataStores are universe-scoped — a
    trivial-progression place sharing the live universe would contaminate real
    player profiles.

    To activate: Publish As → new experience → paste the new PlaceId into
    place_ids below → publish BOTH places. The live game never matches, so it
    is untouched by construction; ConfigLoader WARNS loudly when the overlay
    is active so a misconfigured id can't hide.
]]

return {
    -- The Builder's Cut place id(s). EMPTY = overlay never applies anywhere.
    place_ids = {
        -- e.g. 1234567890,
    },

    -- Mutates the fully-loaded config tables (called once, before validation).
    apply = function(configs)
        -- 1. Every zone unlocked from the start (hub + spokes + realm origins).
        local areas = configs.areas
        if areas and areas.zones then
            for _, zone in pairs(areas.zones) do
                if type(zone.unlock) == "table" then
                    zone.unlock.unlocked_by_default = true
                end
            end
        end

        -- 2. Realm travel open at level 1 — the whole heaven/hell ladder is
        -- walkable immediately (geometry permitting).
        local layers = configs.layers
        if layers and layers.access then
            for _, access in pairs(layers.access) do
                if type(access) == "table" and access.requires_level ~= nil then
                    access.requires_level = 1
                end
            end
        end

        -- 3. MUSEUM MODE: enemies spawn, loiter, and look scary — but the
        -- combat onramp threshold is unreachable, so nothing ever aggresses.
        -- Builders tour deep hell in peace; the darkness still reads.
        local combat = configs.combat
        if combat and combat.engagement then
            combat.engagement.min_engage_level = 1000
        end

        -- 4. Eggs hatch FREE so the pet/hatch mechanics are one click to see.
        -- (fixed_odds exclusives keep their stated odds — cost is not odds.)
        local pets = configs.pets
        if pets and pets.egg_sources then
            for _, egg in pairs(pets.egg_sources) do
                if type(egg) == "table" and tonumber(egg.cost) then
                    egg.cost = 0
                end
            end
        end
    end,
}
