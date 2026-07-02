--[[
    HotbarService — Feature 16 (Hotbar / Command Bar).

    Owns profile.Hotbar (string slot index -> bind { type, target }). New players
    are initialized with archetype defaults on first read. Rebinds persist. Pure
    rules: `src/Shared/Game/HotbarLogic.lua`. (Key-press firing is client/[studio].)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HotbarLogic = require(ReplicatedStorage.Shared.Game.HotbarLogic)
local ArchetypeLogic = require(ReplicatedStorage.Shared.Game.ArchetypeLogic)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)

local HotbarService = {}
HotbarService.__index = HotbarService

function HotbarService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._dataService = self._modules and self._modules.DataService
    self._config = self._configLoader:LoadConfig("hotbar")
    self._archetypesConfig = self._configLoader:LoadConfig("archetypes")
    self._powersConfig = self._configLoader:LoadConfig("powers") -- innate powers are bindable but not in data.Powers

    -- Client fires a slot (1-20); we resolve the bind authoritatively + execute.
    Signals.Hotbar_Activate.OnServerEvent:Connect(function(player, payload)
        pcall(function()
            self:Activate(player, payload)
        end)
    end)
    -- Client asks for its bindings to draw the command bar.
    Signals.Hotbar_RequestState.OnServerEvent:Connect(function(player)
        self:_pushState(player)
    end)
    -- Client assigns / clears a slot (the assignment UI).
    Signals.Hotbar_Rebind.OnServerEvent:Connect(function(player, payload)
        pcall(function()
            if type(payload) ~= "table" then
                return
            end
            local bind = payload.bind -- nil clears
            self:Rebind(player, tonumber(payload.slot), bind)
            self:_pushState(player) -- echo the authoritative result
        end)
    end)
    -- Admin testing: grant + bind the CURRENT area's full power set to the hotbar.
    Signals.Admin_GrantAreaPowers.OnServerEvent:Connect(function(player)
        -- SECURITY: this GRANTS + persists a whole area's power set (bypassing the pick-10), so it
        -- must be admin-only. It was ungated — any client could fire it and grant themselves every
        -- power permanently. Server-set IsAdmin attribute / Studio only.
        if
            not (player:GetAttribute("IsAdmin") == true or game:GetService("RunService"):IsStudio())
        then
            return
        end
        pcall(function()
            self:AdminGrantArea(player)
        end)
    end)
end

-- Area -> archetype (the element pool for that biome). Matches CombatOrigin / ZoneService areas.
local AREA_ARCHETYPE = {
    Grass = "geomancer",
    Earth = "geomancer",
    Meadow = "geomancer",
    Spawn = "geomancer",
    Beach = "sandwalker",
    Desert = "sandwalker",
    Ice = "cryomancer",
    Lava = "pyromancer",
}

-- Admin/Studio only: set the player's archetype to the current area's element, mark every power in that
-- pool as owned (bypassing the pick-10), and bind them all onto the hotbar so every area's powers can
-- be cast for testing. Re-run after switching area to get that area's set.
function HotbarService:AdminGrantArea(player)
    local RunService = game:GetService("RunService")
    if not (player:GetAttribute("IsAdmin") or RunService:IsStudio()) then
        return { ok = false, reason = "not_admin" }
    end
    local data = self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded" }
    end
    local area = player:GetAttribute("CurrentArea") or player:GetAttribute("HomeArea") or "Grass"
    local archetype = AREA_ARCHETYPE[area] or "geomancer"
    data.Archetype = archetype

    local available = ArchetypeLogic.availablePowers(archetype, self._archetypesConfig) or {}
    -- mark all owned (admin bypass of the pick-10 cap) so selection-gated UI/paths pass
    data.Powers = {}
    for _, powerId in ipairs(available) do
        table.insert(data.Powers, powerId)
    end

    -- clear the bar then bind the powers in order (slot 1..N, capped at the slot count)
    local slotCount = (self._config and self._config.slot_count) or 20
    for i = 1, slotCount do
        self:Rebind(player, i, nil)
    end
    local slot = 1
    for _, powerId in ipairs(available) do
        if slot > slotCount then
            break
        end
        self:Rebind(player, slot, { type = "power", target = powerId })
        slot += 1
    end

    if self._dataService.RequestSave then
        self._dataService:RequestSave(player, "admin_grant_powers", { critical = true })
    end
    self:_pushState(player)
    if self._logger then
        self._logger:Info(
            "Admin granted area powers",
            { area = area, archetype = archetype, count = #available }
        )
    end
    return { ok = true, archetype = archetype, powers = available }
end

-- The things a player may bind: the powers they actually OWN (not the whole archetype pool) + the
-- tactical commands. Pet-summons are added client-side from the equipped squad (the client owns that).
function HotbarService:_assignablePalette(player)
    local data = self._dataService:GetData(player)
    local powers = {}
    local seen = {}
    for _, id in ipairs((data and data.Powers) or {}) do
        powers[#powers + 1] = id -- owned powers only — you can't bind what you haven't picked
        seen[id] = true
    end
    -- INNATE powers (Resonance) are owned-free and NOT written to data.Powers, but they're castable and
    -- MUST be bindable from the Edit picker (the tutorial teaches binding Resonance there). Surface them.
    for id, def in pairs((self._powersConfig and self._powersConfig.powers) or {}) do
        if def.innate and not seen[id] then
            powers[#powers + 1] = id
            seen[id] = true
        end
    end
    -- Potions the player OWNS (drinkable consumables you can bind to a slot like a power).
    -- PotionService is the SSOT for owned counts; an empty list if it's not up yet.
    local potions = {}
    local potionSvc = self:_service("PotionService")
    if potionSvc and potionSvc.GetState then
        local ok, st = pcall(function()
            return potionSvc:GetState(player)
        end)
        if ok and type(st) == "table" and type(st.potions) == "table" then
            potions = st.potions -- { { id, count, meter, icon, name } }
        end
    end

    return {
        powers = powers,
        tacticals = self._config.tactical_commands or {},
        potions = potions,
    }
end

-- Push the player's current hotbar + the assignable palette to their client.
function HotbarService:_pushState(player)
    local state = self:GetState(player)
    if not state.ok then
        return
    end
    Signals.Hotbar_State:FireClient(player, {
        hotbar = state.hotbar,
        slot_count = state.slot_count,
        available = self:_assignablePalette(player),
    })
end

-- Resolve another service at runtime (avoids boot-order cycles).
function HotbarService:_service(name)
    local locator = _G.RBXTemplateServices
    if not locator then
        return nil
    end
    local ok, service = pcall(function()
        return locator:Get(name)
    end)
    return ok and service or nil
end

local function isEmptyMap(t)
    if type(t) ~= "table" then
        return true
    end
    for _ in pairs(t) do
        return false
    end
    return true
end

-- Apply archetype defaults into a string-keyed hotbar exactly ONCE (a brand-new player). After that
-- we respect the player's bar verbatim — INCLUDING a fully-cleared bar — so clearing slots in Edit
-- mode sticks instead of repopulating on the next state read.
function HotbarService:_ensureDefaults(data)
    if type(data.Hotbar) ~= "table" then
        data.Hotbar = {}
    end
    if not data.HotbarInitialized then
        if isEmptyMap(data.Hotbar) and data.Archetype then
            -- Bind only the powers the player actually OWNS (picked via level-up) — a clean character
            -- owns none, so the power slots stay EMPTY until they pick. No auto-granted default powers.
            -- (Roster/tactical command defaults still populate from defaultBindings.)
            local owned = (type(data.Powers) == "table") and data.Powers or {}
            for index, bind in pairs(HotbarLogic.defaultBindings(owned, self._config)) do
                data.Hotbar[tostring(index)] = bind
            end
        end
    end
    data.HotbarInitialized = true -- defaults are a one-time seed; never auto-repopulate again

    -- NOTE: Resonance (innate) is intentionally NOT auto-bound. The tutorial teaches the player to bind
    -- it themselves (the hotbar Edit → pick → slot flow — a skill they'll reuse for every power), and a
    -- player's binding choice is then theirs to keep. Owned innate powers are always castable from the
    -- POWERS menu regardless, so a skipped tutorial never leaves Resonance unusable.
    return data.Hotbar
end

function HotbarService:GetState(player)
    local data = self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded" }
    end
    return { ok = true, hotbar = self:_ensureDefaults(data), slot_count = self._config.slot_count }
end

-- Rebind a slot. `bind` is { type, target } or nil to clear.
function HotbarService:Rebind(player, index, bind)
    local data = self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded" }
    end
    local decision = HotbarLogic.canRebind(index, bind, self._config)
    if not decision.ok then
        return { ok = false, reason = decision.reason }
    end
    local hotbar = self:_ensureDefaults(data)
    hotbar[tostring(index)] = bind -- nil clears
    self._dataService:RequestSave(player, "hotbar_rebind", { critical = false })
    -- Bus source: a POWER landed on a slot. The tutorial's "set your power" step completes on this,
    -- and a bind sound/FX can hook it config-only (docs/GAME_EVENTS.md). Only powers fire it (not
    -- clears or pet/tactical/potion binds) so the cue means "you bound a castable power".
    if type(bind) == "table" and bind.type == "power" and bind.target then
        fireGameEvent(player, "power_bound", { power = bind.target, slot = index })
    end
    return { ok = true, hotbar = hotbar }
end

-- Fire the bind on a hotbar slot. `payload` is the slot index (1-20) or { slot = n }.
-- Authoritative: we read the player's own binding and dispatch by type. Tactical
-- commands run on the squad now; power/roster/pet effects land when those systems do.
function HotbarService:Activate(player, payload)
    local slot = tonumber(type(payload) == "table" and payload.slot or payload)
    if not slot or not HotbarLogic.isValidSlot(slot, self._config) then
        return { ok = false, reason = "invalid_slot" }
    end
    local data = self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded" }
    end
    local bind = HotbarLogic.bindAt(self:_ensureDefaults(data), slot)
    if not bind then
        return { ok = false, reason = "empty_slot" }
    end

    if bind.type == "tactical" then
        local enemy = self:_service("EnemyService")
        if enemy and enemy.ExecuteTactical then
            enemy:ExecuteTactical(player, bind.target)
            return { ok = true, type = "tactical", command = bind.target }
        end
        return { ok = false, reason = "tactical_unavailable" }
    elseif bind.type == "pet" then
        -- Summon/redeploy the bound pet slot (re-uses the squad summon path).
        local enemy = self:_service("EnemyService")
        if enemy and enemy.SummonPet then
            enemy:SummonPet(player, { slot = tonumber(bind.target) })
            return { ok = true, type = "pet", target = bind.target }
        end
        return { ok = false, reason = "summon_unavailable" }
    elseif bind.type == "power" then
        local power = self:_service("PowerService")
        if power and power.Cast then
            return power:Cast(player, bind.target)
        end
        return { ok = false, reason = "power_unavailable" }
    elseif bind.type == "potion" then
        -- Drink one from the bound potion (consumes from inventory + sips the meter). A slot can
        -- stay bound to a potion you've run out of — Drink just no-ops with reason "none_left".
        local potionSvc = self:_service("PotionService")
        if potionSvc and potionSvc.Drink then
            local result = potionSvc:Drink(player, bind.target)
            -- echo so the slot's count badge updates immediately (Drink already pushed PotionUpdate)
            self:_pushState(player)
            return result
        end
        return { ok = false, reason = "potion_unavailable" }
    end

    -- roster: deploy effects not wired yet.
    if self._logger then
        self._logger:Info("Hotbar activate (no effect yet)", {
            type = bind.type,
            target = bind.target,
            slot = slot,
        })
    end
    return { ok = false, reason = "not_implemented", type = bind.type, target = bind.target }
end

return HotbarService
