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
                    local visual = entry.vfx or entry.float or entry.banner or entry.world_visual
                    if not visual then
                        error(
                            (
                                "event '%s' has a sound but NO visual — add vfx/float/banner "
                                .. "(or world_visual=true if the world itself shows it)"
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

        it("level_up keeps the visual; the world jingle is on level_EARNED", function()
            -- Jason: the public moment is the bar filling ("when the bar changes to
            -- the blinking arrow"), NOT the claim — the epic animation + sound land
            -- on level_earned; the client-fired level_up row keeps the burst visual.
            expect(type(gameEvents.level_up)).to.equal("table")
            expect(type(gameEvents.level_up.vfx)).to.equal("table")
            -- the epic level-up theme rides level_earned (a real world_sound); level_up has no sound
            expect(gameEvents.level_earned.world_sound).to.equal("level_up_epic")
            expect(gameEvents.level_up.sound).to.equal(nil)
            expect(gameEvents.level_up.world_sound).to.equal(nil)
        end)
    end)
end
