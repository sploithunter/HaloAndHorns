--[[
    Sound catalog integrity — [unit] guardrails for configs/sounds.lua.
]]

local sounds = loadModule("configs/sounds.lua")
local REJECTED_HELL_COMBAT_ID = "rbxassetid://105132281703189"

local function assertMusicKey(key, context)
    local definition = sounds.music and sounds.music[key]
    if not (type(definition) == "table" and type(definition.id) == "string") then
        error(("%s references missing music key '%s'"):format(context, tostring(key)))
    end
end

local function containsValue(node, wanted, visited)
    if type(node) ~= "table" then
        return node == wanted
    end
    visited = visited or {}
    if visited[node] then
        return false
    end
    visited[node] = true
    for _, value in pairs(node) do
        if containsValue(value, wanted, visited) then
            return true
        end
    end
    return false
end

return function()
    describe("sounds config", function()
        it("keeps every combat pool on a real catalog entry", function()
            for _, key in ipairs(sounds.combat_music or {}) do
                assertMusicKey(key, "combat_music")
            end
            for realm, pool in pairs(sounds.combat_music_by_realm or {}) do
                for _, key in ipairs(pool) do
                    assertMusicKey(key, "combat_music_by_realm." .. tostring(realm))
                end
            end
            for _, key in ipairs(sounds.prologue_combat_music or {}) do
                assertMusicKey(key, "prologue_combat_music")
            end
        end)

        it("does not consume the Roblox-rejected Hell combat upload", function()
            expect(containsValue(sounds, REJECTED_HELL_COMBAT_ID)).to.equal(false)
        end)
    end)
end
