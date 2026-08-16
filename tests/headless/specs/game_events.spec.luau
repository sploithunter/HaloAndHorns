--[[
    GameEvents config integrity — [unit] guardrail for configs/game_events.lua.
    Run: mise run test-headless

    The dispatcher (src/Client/Systems/GameEvents.lua) is instance-heavy (Sounds/VFX), so it can't
    run headless — but the CONFIG is pure data. This pins the contract so a typo (unknown reaction
    kind, or a `sound` pointing at a missing sounds.lua key) fails the gate instead of going silent
    in-game.
]]

local gameEvents = loadModule("configs/game_events.lua")
local sounds = loadModule("configs/sounds.lua")

-- Reaction kinds the dispatcher knows how to apply. Keep in sync with GameEvents REACTIONS.
local KNOWN_KINDS = {
    sound = true,
    vfx = true,
    float = true,
    banner = true, -- lingering screen-center card (achievements etc.)
    world_visual = true, -- ANNOTATION, not a reaction: the world itself is the visual
    world_sound = true, -- SERVER-side positional sound at the player (everyone nearby hears)
    world_sound_range = true, -- optional RollOffMaxDistance for world_sound (studs)
    fanfare = true, -- local non-interrupting world celebration around the player (sparkles + glow)
    ascension = true, -- altar claim ceremony: visual avatar lift/spin/rings, no gameplay mutation
    effect_transfer = true, -- consumable icon blooms center, then flies to its affected HUD target(s)
}

return function()
    describe("game_events config", function()
        it("is a table of event -> reactions tables", function()
            expect(type(gameEvents)).to.equal("table")
            for name, entry in pairs(gameEvents) do
                expect(type(name)).to.equal("string")
                expect(type(entry)).to.equal("table")
            end
        end)

        it("NEVER plays a sound without a visual (Jason's rule)", function()
            for name, entry in pairs(gameEvents) do
                if entry.sound then
                    local visual = entry.vfx
                        or entry.float
                        or entry.banner
                        or entry.effect_transfer
                        or entry.world_visual
                    if not visual then
                        error(
                            (
                                "event '%s' has a sound but NO visual — add vfx/float/banner/"
                                .. "effect_transfer (or world_visual=true if the world itself shows it)"
                            ):format(name)
                        )
                    end
                end
            end
        end)

        it("only uses reaction kinds the dispatcher implements", function()
            for name, entry in pairs(gameEvents) do
                for kind in pairs(entry) do
                    if not KNOWN_KINDS[kind] then
                        error(
                            ("event '%s' uses unknown reaction kind '%s'"):format(
                                name,
                                tostring(kind)
                            )
                        )
                    end
                end
            end
        end)

        it("every `sound` reaction points at a real sounds.lua entry with an id", function()
            for name, entry in pairs(gameEvents) do
                local key = entry.sound
                if type(key) == "table" then
                    key = key.key -- { key, volume } per-event volume form
                end
                if key ~= nil then
                    expect(type(key)).to.equal("string")
                    local def = sounds[key]
                    if not (type(def) == "table" and def.id) then
                        error(
                            ("event '%s' sound '%s' has no sounds.lua entry with an id"):format(
                                name,
                                tostring(key)
                            )
                        )
                    end
                end
            end
        end)

        it("keeps earned feedback light and reserves the epic ceremony for Ascend", function()
            expect(type(gameEvents.level_up)).to.equal("table")
            expect(type(gameEvents.level_up.vfx)).to.equal("table")
            expect(type(gameEvents.level_earned.vfx)).to.equal("table")
            expect(gameEvents.level_earned.world_sound).to.equal(nil)
            expect(gameEvents.level_claimed.world_sound).to.equal("level_up_epic")
            expect(type(gameEvents.level_claimed.ascension)).to.equal("table")
            expect(gameEvents.level_claimed.ascension.seconds).to.equal(7.5)
            expect(gameEvents.level_up.sound).to.equal(nil)
            expect(gameEvents.level_up.world_sound).to.equal(nil)
        end)

        it(
            "implements Ascend as a visual clone so it cannot teleport the real character",
            function()
                local presentation = readFile("src/Client/Systems/AscensionPresentation.lua")
                expect(presentation:find('clone.Name = "AscensionAvatar"', 1, true) ~= nil).to.equal(
                    true
                )
                expect(presentation:find("clone:PivotTo", 1, true) ~= nil).to.equal(true)
                expect(presentation:find("character:PivotTo", 1, true)).to.equal(nil)
                expect(presentation:find("LocalTransparencyModifier", 1, true) ~= nil).to.equal(
                    true
                )
            end
        )

        it("routes consumable activation visuals to the affected HUD surface", function()
            local dispatcher = readFile("src/Client/Systems/GameEvents.lua")
            local potionService = readFile("src/Server/Services/PotionService.lua")
            local economyService = readFile("src/Server/Services/EconomyService.lua")
            local items = loadModule("configs/items.lua")
            local itemById = {}
            for _, item in ipairs(items) do
                itemById[item.id] = item
            end

            expect(type(gameEvents.potion_used.effect_transfer)).to.equal("table")
            expect(gameEvents.potion_used.sound).to.equal("power_up_stronger")
            expect(type(gameEvents.future_call_used.effect_transfer)).to.equal("table")
            expect(type(gameEvents.consumable_used.effect_transfer)).to.equal("table")
            expect(gameEvents.consumable_used.sound).to.equal("power_up_stronger")
            expect(type(gameEvents.health_potion_used.effect_transfer)).to.equal("table")
            expect(gameEvents.health_potion_used.sound).to.equal("power_up_stronger")
            expect(dispatcher:find("REACTIONS.effect_transfer", 1, true)).to.be.ok()
            expect(dispatcher:find('scope == "pets"', 1, true)).to.be.ok()
            expect(dispatcher:find('FindFirstChild("PlayerPets")', 1, true)).never.to.be.ok()
            expect(dispatcher:find('FindFirstChild("TeamHandle", true)', 1, true)).to.be.ok()
            expect(dispatcher:find('scope == "enemy"', 1, true)).to.be.ok()
            expect(potionService:find('targetScope = "enemy"', 1, true)).to.be.ok()
            expect(economyService:find('fireGameEvent(player, "consumable_used"', 1, true)).to.be.ok()
            expect(itemById.double_xp_token.use_feedback.destination_attr).to.equal("XpProductBuff")
            expect(itemById.double_coins_token.use_feedback.destination_attr).to.equal(
                "CoinProductBuff"
            )
            expect(itemById.titan_team_token.use_feedback.target_scope).to.equal("pets")
        end)
    end)
end
