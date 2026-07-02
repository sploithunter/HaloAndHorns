--[[
    ArchetypeService — Feature 13 (Halo & Horns).

    Owns profile.Archetype (lazy-init nil = unselected). The archetype gates the
    power pool (Feature 14) and is orthogonal to Soul/alignment. It can only change
    via the respec ritual, which also resets profile.Powers + profile.Slots
    (Features 14/15). Pure rules live in `src/Shared/Game/ArchetypeLogic.lua`.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ArchetypeLogic = require(ReplicatedStorage.Shared.Game.ArchetypeLogic)

local ArchetypeService = {}
ArchetypeService.__index = ArchetypeService

-- Origin theme -> HUD HomeArea key (UITheme keys off HomeArea). The archetype config's `theme`
-- string maps to an area palette: earth=Grass, desert=Desert, ice=Ice, lava=Lava.
local THEME_TO_AREA = {
    earth = "Grass",
    desert = "Desert",
    ice = "Ice",
    lava = "Lava",
}

function ArchetypeService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._dataService = self._modules and self._modules.DataService
    self._config = self._configLoader:LoadConfig("archetypes")
end

-- The player's HOME AREA is their ORIGIN's biome: choosing Sandwalker themes the whole HUD desert
-- (yellow), regardless of which area they're standing in. HomeArea drives the UI theme only (not
-- spawns). nil archetype clears both attributes (-> theme falls back to CurrentArea).
function ArchetypeService:_homeAreaFor(archetype)
    local cfg = archetype and self._config.archetypes and self._config.archetypes[archetype]
    local theme = cfg and cfg.theme
    return theme and THEME_TO_AREA[theme] or nil
end

function ArchetypeService:_applyThemeAttrs(player, archetype)
    player:SetAttribute("Archetype", archetype) -- nil clears
    player:SetAttribute("HomeArea", self:_homeAreaFor(archetype)) -- nil clears
end

function ArchetypeService:Start()
    -- Re-stamp the origin theme attributes from saved data on join (returning players).
    local function stampSoon(player)
        task.spawn(function()
            for _ = 1, 100 do
                local data = self._dataService:GetData(player)
                if data then
                    self:_applyThemeAttrs(player, data.Archetype)
                    return
                end
                task.wait(0.2)
            end
        end)
    end
    Players.PlayerAdded:Connect(stampSoon)
    for _, player in ipairs(Players:GetPlayers()) do
        stampSoon(player)
    end
end

function ArchetypeService:GetState(player)
    local data = self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded" }
    end
    return {
        ok = true,
        archetype = data.Archetype,
        available = ArchetypeLogic.availablePowers(data.Archetype, self._config),
    }
end

function ArchetypeService:List()
    return { ok = true, archetypes = ArchetypeLogic.list(self._config) }
end

-- Select an archetype. One-time: once set, only the respec ritual can change it.
function ArchetypeService:Select(player, archetype)
    local data = self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded" }
    end
    if data.Archetype then
        return { ok = false, reason = "already_selected", archetype = data.Archetype }
    end
    if not ArchetypeLogic.isValid(archetype, self._config) then
        return { ok = false, reason = "invalid_archetype" }
    end
    data.Archetype = archetype
    self:_applyThemeAttrs(player, archetype) -- HUD now themes to the chosen origin's biome
    self._dataService:RequestSave(player, "archetype_select", { critical = true })
    return { ok = true, archetype = archetype }
end

-- Respec ritual: reset powers + augmentation slots, and (optionally) pick a new
-- archetype. Without newArchetype, clears the selection so the player re-picks.
function ArchetypeService:Respec(player, newArchetype)
    local data = self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded" }
    end
    if newArchetype ~= nil and not ArchetypeLogic.isValid(newArchetype, self._config) then
        return { ok = false, reason = "invalid_archetype" }
    end
    data.Powers = {}
    data.Slots = {}
    data.Hotbar = {} -- fresh hotbar for the new archetype (re-defaults on next read)
    data.Archetype = newArchetype -- nil => must re-select
    self:_applyThemeAttrs(player, newArchetype) -- re-theme (or clear -> falls back to CurrentArea)
    self._dataService:RequestSave(player, "archetype_respec", { critical = true })
    return { ok = true, archetype = data.Archetype }
end

return ArchetypeService
