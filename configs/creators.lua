--[[
    Creators — the registry of TOP-TIER creators (Jason + invited collaborators) and
    the Meet-The-Creator mechanic.

    Each registered creator has their OWN creator-pet species. The species is theirs
    exclusively as the APEX (creator-class grants only ever go to the creator
    themselves — colorado is Jason's, period). Other players obtain the SPECIES
    (never the apex class) through Meet-The-Creator:

        The FIRST time you are in the same server as a registered creator — and only
        that once, ever — you receive their creator EGG in your eggs inventory. The
        egg hatches a creator-species pet at the configured variant odds.

    Persisted per player in data.MetCreators[creatorUserId] = os.time().
]]

return {
    creators = {
        -- userId (string keys: JSON-safe) -> identity
        ["3200870803"] = {
            name = "ColoradoPlays",
            pet = "colorado", -- the species their egg hatches
            egg_id = "colorado_egg", -- eggs-bucket item id
            egg_name = "Colorado Egg",
            -- group-owned assets (scripts/egg_assets.json is the manifest)
            egg_icon = "rbxassetid://120328710003120", -- inventory card image
            egg_model_asset = 94487781424433, -- 3D egg (PlaceAssets-cached; AssetFetch id)
            -- hatch odds live on the EGG (configs/pets.lua colorado_egg): standard
            -- golden/rainbow channels + slim huge chance — normal mechanics, luck
            -- applies; this registry only names the egg.
        },
    },

    -- LUCKY SERVER (Jason): while a registered creator is in the server, EVERYONE
    -- EXCEPT creators gets bonus hatch luck. Creators are excluded on purpose —
    -- "it makes it difficult to do playtesting for balance if they're not like a
    -- regular player." mult is the HatchLuckBuff-style multiplier (1.25 = +25%).
    server_luck = {
        enabled = true,
        mult = 2.0, -- Jason: "2x to start with for balance"
        -- STUDIO multi-client test: Player1/Player2 have NEGATIVE fake UserIds, so no
        -- real creator can be present — these ids count as creators IN STUDIO ONLY,
        -- making the mechanic testable (Player1 = creator/excluded, Player2 = buffed).
        studio_test_creator_ids = { "-1" },
        -- DISPLAY (Active Buffs row): each presence buff styles ITSELF — purple, not
        -- the clover green (Jason: "creator luck auras should not be the green look").
        -- Future presence mechanics follow this same shape (attr/label/color).
        display = {
            attr = "ServerLuckBuff",
            label = "👑 Creator Luck",
            color = { 170, 90, 255 },
        },
    },

    meet = {
        enabled = true,
        -- once per (player, creator) pair, forever. Creators DO meet themselves
        -- (Jason: "that would include myself" — in a server with the creator is in a
        -- server with the creator) — which also makes the mechanic solo-testable.
        check_delay = 8, -- seconds after a join before scanning (lets data load)
    },
}
