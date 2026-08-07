-- Named-trial milestone eggs.
--
-- One track awards exactly one provenance-bound egg. The held egg evolves only while it is
-- owned by the account that earned it. Hatching is final: the resulting pet never participates
-- in this ladder. Quest claims, rather than displayed trial sequence numbers, drive progress.

local function track(realm, element)
    local prefix = realm .. "_" .. element
    local celestial = realm == "heaven"
    return {
        award_id = "trial_egg:" .. prefix,
        display_name = (realm:gsub("^%l", string.upper)) .. " " .. (element:gsub(
            "^%l",
            string.upper
        )) .. " Trial Egg",
        egg_id = celestial and "celestial_egg" or "obsidian_egg",
        huge_egg_id = celestial and "huge_celestial_egg" or "huge_obsidian_egg",
        milestones = {
            {
                clears = 10,
                quest_id = prefix .. "_10",
                stage = "basic",
                forced_variant = "basic",
                huge_chance = 0.05,
            },
            {
                clears = 25,
                quest_id = prefix .. "_25",
                stage = "golden",
                forced_variant = "golden",
                huge_chance = 0.05,
            },
            {
                clears = 50,
                quest_id = prefix .. "_50",
                stage = "rainbow",
                forced_variant = "rainbow",
                huge_chance = 0.05,
            },
            {
                clears = 90,
                quest_id = prefix .. "_90",
                stage = "charged",
                forced_variant = "rainbow",
                huge_chance = 0.10,
            },
            {
                clears = 100,
                quest_id = prefix .. "_100",
                stage = "huge",
                huge_chance = 1.0,
                minimum_level = 50,
            },
        },
    }
end

return {
    version = 1,
    tracks = {
        hell_lava = track("hell", "lava"),
        heaven_lava = track("heaven", "lava"),
        hell_ice = track("hell", "ice"),
        heaven_ice = track("heaven", "ice"),
        hell_grass = track("hell", "grass"),
        heaven_grass = track("heaven", "grass"),
        hell_desert = track("hell", "desert"),
        heaven_desert = track("heaven", "desert"),
    },
}
