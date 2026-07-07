--[[
    PowerService — Feature 14 (Power Selection at Level-Up).

    Owns profile.Powers (ordered list of selected power ids). At each selection
    level the player picks ONE power from their archetype's pool; selections
    accumulate + persist. Pure rules: `src/Shared/Game/PowerSelection.lua`;
    archetype gating via `ArchetypeLogic`. Respec (ArchetypeService) clears the list.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)
local PetRevive = require(script.Parent.Parent.PetRevive)
local Enhancements = require(ReplicatedStorage.Shared.Game.Enhancements)
local PowerSelection = require(ReplicatedStorage.Shared.Game.PowerSelection)
local ArchetypeLogic = require(ReplicatedStorage.Shared.Game.ArchetypeLogic)
local AmplifiedBurst = require(ReplicatedStorage.Shared.Game.AmplifiedBurst)
local PowerRegistry = require(ReplicatedStorage.Shared.Game.PowerRegistry)
local PowerStats = require(ReplicatedStorage.Shared.Game.PowerStats)
local Accuracy = require(ReplicatedStorage.Shared.Game.Accuracy)
local CombatRoll = require(ReplicatedStorage.Shared.Game.CombatRoll)
local PetCombat = require(ReplicatedStorage.Shared.Game.PetCombat)
local VulnMark = require(ReplicatedStorage.Shared.Game.VulnMark) -- additive vulnerability marks (SSOT)
local ResSickness = require(ReplicatedStorage.Shared.Game.ResSickness) -- post-revive heal clamp
local AdminPowerPalette = require(ReplicatedStorage.Shared.Game.AdminPowerPalette)
local FocusUpkeep = require(ReplicatedStorage.Shared.Game.FocusUpkeep)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local PET_ROLES = require(ReplicatedStorage.Configs:WaitForChild("pet_roles"))
local RunService = game:GetService("RunService")

-- Admin gate for the power-bar test remotes: the server-set IsAdmin attribute, or Studio.
local function adminAllowed(player)
    return player:GetAttribute("IsAdmin") == true or RunService:IsStudio()
end

-- Placeholder cast VFX colour per effect family (swap for real art later).
local FAMILY_COLOR = {
    heal = Color3.fromRGB(90, 210, 110),
    buff = Color3.fromRGB(235, 150, 60),
    defense_buff = Color3.fromRGB(235, 200, 70),
    absorb = Color3.fromRGB(235, 200, 70),
    root = Color3.fromRGB(90, 200, 235),
    vulnerable = Color3.fromRGB(235, 90, 90),
}

-- Archetype → CombatFX element (the per-element colour/look). Mirrors combat_fx.lua archetype_element.
-- Drives the cast/impact VFX so a power reads as its origin (pyro=lava, cryo=ice, …). Generic/white
-- powers have no archetype → they keep the neutral placeholder burst.
local ARCHETYPE_ELEMENT = {
    geomancer = "grass",
    pyromancer = "lava",
    cryomancer = "ice",
    sandwalker = "desert",
}

-- Temporary burst around the caster so AoE powers are visible (expands + fades, ~0.7s).
local function spawnCastVisual(player, family)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return
    end
    local fx = Instance.new("Part")
    fx.Name = "PowerCastFX"
    fx.Shape = Enum.PartType.Ball
    fx.Material = Enum.Material.Neon
    fx.Color = FAMILY_COLOR[family] or Color3.fromRGB(220, 220, 220)
    fx.Transparency = 0.45
    fx.Anchored = true
    fx.CanCollide = false
    fx.CanQuery = false
    fx.Massless = true
    fx.Size = Vector3.new(3, 3, 3)
    fx.CFrame = CFrame.new(hrp.Position)
    fx.Parent = Workspace
    TweenService:Create(
        fx,
        TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = Vector3.new(26, 26, 26), Transparency = 1 }
    ):Play()
    Debris:AddItem(fx, 0.8)
end

local PowerService = {}
PowerService.__index = PowerService

function PowerService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._dataService = self._modules and self._modules.DataService
    self._powersConfig = self._configLoader:LoadConfig("powers")
    self._archetypesConfig = self._configLoader:LoadConfig("archetypes")
    self._combatConfig = self._configLoader:LoadConfig("combat") -- accuracy curve for P4 to-hit
    self._enhConfig = self._configLoader:LoadConfig("enhancements") -- slotted-enhancement boosts

    self._cooldowns = setmetatable({}, { __mode = "k" }) -- player -> { powerId -> expiry (os.time) }
    -- player -> { [powerId]=true }: the always-on toggles currently RUNNING (draining focus_upkeep).
    -- The upkeep loop sums their rates against the Focus pool and crashes (detoggles) them when it
    -- can't pay the tick. Owned passives default ON (re-stamped in _applyOwnedPassives).
    self._activeToggles = setmetatable({}, { __mode = "k" })

    -- Re-stamp PASSIVE (always-on) buffs whenever a player joins / respawns, since their buff
    -- attributes don't survive a rejoin. (In-session picks re-stamp via Select.)
    Players.PlayerAdded:Connect(function(plr)
        self:_watchPlayer(plr)
    end)
    for _, plr in ipairs(Players:GetPlayers()) do
        self:_watchPlayer(plr)
    end

    -- ADMIN POWER BAR (test surface). Both remotes are IsAdmin/Studio gated and route through the
    -- normal pipelines — Cast respects focus + cooldown; the passive stamp is transient — granting and
    -- saving NOTHING. The client renders the tabbed bar; these just execute the cast / toggle.
    Signals.Admin_CastPower.OnServerEvent:Connect(function(player, payload)
        if not adminAllowed(player) or type(payload) ~= "table" then
            return
        end
        self:AdminCast(player, payload.powerId, payload.mode)
    end)
    Signals.Admin_TogglePassive.OnServerEvent:Connect(function(player, payload)
        if not adminAllowed(player) or type(payload) ~= "table" then
            return
        end
        self:AdminTogglePassive(player, payload.powerId, payload.on == true, payload.mode)
    end)

    -- PLAYER HUD toggle badge — turn an OWNED always-on power on/off. Owned-gated (no admin bypass);
    -- ON re-stamps the buff + starts its upkeep drain, OFF clears it (the badge greys out).
    Signals.Power_ToggleActive.OnServerEvent:Connect(function(player, payload)
        if type(payload) ~= "table" then
            return
        end
        self:ToggleActive(player, payload.powerId, payload.on == true)
    end)

    self:_startUpkeepLoop()
end

-- Families whose `passive = true` powers apply permanently by OWNERSHIP. Each maps to its single
-- axis attribute (sole-occupant — no overwrite). Shared-axis families (coin_yield/luck) wait for
-- additive BuffStack (#169).
-- recharge (Hasten) is NO LONGER here — it's a TIMED click now, applied via _setAxisBuff with a
-- duration, not stamped permanently by ownership. Leaving it would let _applyOwnedPassives' reset loop
-- wipe an ACTIVE Hasten on respawn/respec, and would keep the recharge enhancement excluded from it.
local PASSIVE_ATTR = {
    magnet = "MagnetBuff",
    move_speed = "MoveSpeedBuff",
    xp = "XpBuff",
}
local PASSIVE_UNTIL = 4102444800 -- year 2100 — "always on" (same sentinel as the toggle buffs)

function PowerService:_watchPlayer(plr)
    plr.CharacterAdded:Connect(function()
        self:_reapplyPassivesSoon(plr)
    end)
    self:_reapplyPassivesSoon(plr)
end

-- Wait (briefly) for the profile to load, then re-stamp the player's owned passive buffs.
function PowerService:_reapplyPassivesSoon(plr)
    task.spawn(function()
        local deadline = os.clock() + 8
        while os.clock() < deadline do
            if self._dataService and self._dataService:GetData(plr) then
                break
            end
            task.wait(0.25)
        end
        if plr.Parent then
            self:_applyOwnedPassives(plr)
        end
    end)
end

-- Clear every managed passive axis, then re-apply the ones the player currently OWNS (permanent,
-- no timer). Idempotent: call after pick / respec / grant / spawn. Respec (owned empty) clears all.
function PowerService:_applyOwnedPassives(player)
    for _, attr in pairs(PASSIVE_ATTR) do
        player:SetAttribute(attr, nil)
        player:SetAttribute(attr .. "Until", 0)
        player:SetAttribute(attr .. "Toggle", nil)
        player:SetAttribute(attr .. "PowerId", nil)
        player:SetAttribute(attr .. "Owned", nil) -- forget the owned-toggle marker; re-stamp re-sets it
    end
    if self._activeToggles then
        self._activeToggles[player] = {} -- reset the running set; owned passives re-activate (default ON) below
    end
    local data = self._dataService and self._dataService:GetData(player)
    if not data or type(data.Powers) ~= "table" then
        return
    end
    for _, powerId in ipairs(data.Powers) do
        local slots = (type(data.Slots) == "table" and data.Slots[tostring(powerId)]) or {}
        self:_stampPassive(player, powerId, slots)
    end
end

-- Stamp ONE passive power's buff attribute at a given enhancement slotting. The per-power body shared
-- by _applyOwnedPassives AND the admin passive toggle — ONE resolver, no drift. `slots` = the slot
-- list to fold (the player's real Slots, or an admin MIN/MAX override). No-op (returns nil) for a
-- non-passive power.
function PowerService:_stampPassive(player, powerId, slots)
    local kinds = self._powersConfig.effect_kinds or {}
    local def = self._powersConfig.powers[tostring(powerId)]
    local kind = def and def.effect and kinds[def.effect]
    local attr = kind and kind.passive and PASSIVE_ATTR[kind.family]
    if not attr then
        return nil
    end
    -- POTENCY enhancements scale a passive's magnitude (this stamp IS the passive's "cast", so the slot
    -- fold happens here — Swift runs faster). ONE resolver (PowerStats), shared with the ENHANCE
    -- preview so the two can't drift; radius/damage/heal-as-magnitude families fold their axis in.
    local enhAxes = Enhancements.aggregate(
        self._enhConfig,
        slots or {},
        tonumber(player:GetAttribute("Level")) or 1
    )
    local record = PowerRegistry.record(tostring(powerId), self._powersConfig)
    local eff = PowerStats.resolveEffective(record, {
        casterLevel = tonumber(player:GetAttribute("Level")) or 1,
        scaling = self._powersConfig.scaling,
        enhancements = enhAxes,
        radiusMagnitude = (self._enhConfig.radius_families or {})[kind.family] == true,
        damageIsMagnitude = (self._enhConfig.damage_as_magnitude_families or {})[kind.family]
            == true,
        healIsMagnitude = (self._enhConfig.heal_as_magnitude_families or {})[kind.family] == true,
    })
    player:SetAttribute(attr, eff.magnitude)
    player:SetAttribute(attr .. "Until", PASSIVE_UNTIL)
    player:SetAttribute(attr .. "Toggle", true) -- permanent: HUDs show no countdown
    player:SetAttribute(attr .. "PowerId", powerId)
    -- Owned marker: persists across on/off so the HUD keeps a (greyed) toggle badge when this is
    -- turned off. Carries the powerId so the badge knows what to re-toggle. Mark it RUNNING so the
    -- upkeep loop drains its focus_upkeep.
    player:SetAttribute(attr .. "Owned", tostring(powerId))
    local active = self._activeToggles and self._activeToggles[player]
    if active then
        active[tostring(powerId)] = true
    end
    return attr
end

-- Turn ONE always-on power OFF: clear its buff attribute + stop its upkeep drain. By default this is a
-- TOGGLE-OFF — the `Owned` marker stays so the HUD keeps a greyed badge to re-toggle (player toggle OFF
-- and the upkeep CRASH both use this). Pass `forget = true` to also drop the owned marker (respec /
-- non-owned cleanup / admin test off → no lingering badge). No-op for a non-passive power.
function PowerService:_clearPassive(player, powerId, forget)
    local kinds = self._powersConfig.effect_kinds or {}
    local def = self._powersConfig.powers[tostring(powerId)]
    local kind = def and def.effect and kinds[def.effect]
    local attr = kind and kind.passive and PASSIVE_ATTR[kind.family]
    if not attr then
        return
    end
    player:SetAttribute(attr, nil)
    player:SetAttribute(attr .. "Until", 0)
    player:SetAttribute(attr .. "Toggle", nil)
    player:SetAttribute(attr .. "PowerId", nil)
    if forget then
        player:SetAttribute(attr .. "Owned", nil)
    end
    local active = self._activeToggles and self._activeToggles[player]
    if active then
        active[tostring(powerId)] = nil
    end
end

-- Public re-stamp (called after respec / admin grant from other services).
function PowerService:ReapplyPassives(player)
    self:_applyOwnedPassives(player)
end

-- ADMIN POWER BAR — cast any power at MIN (bare) or MAX (single-origin full slotting), through the
-- REAL pipeline (adminBypass skips ownership; focus + cooldown still apply). Grants/saves nothing.
function PowerService:AdminCast(player, powerId, mode)
    if not adminAllowed(player) then
        return { ok = false, reason = "not_admin" }
    end
    local slots = {}
    if mode == "max" then
        slots = AdminPowerPalette.maxSlots(self._powersConfig, self._enhConfig, powerId)
    end
    return self:Cast(player, powerId, { adminBypass = true, slotsOverride = slots })
end

-- ADMIN POWER BAR — transiently stamp (on) or clear (off) an always-on power's buff at MIN/MAX
-- slotting, so its effect on OTHER powers (e.g. Hasten → every cooldown) can be balanced without
-- owning or saving it. No-op for a non-passive power (returns ok=false).
function PowerService:AdminTogglePassive(player, powerId, on, mode)
    if not adminAllowed(player) then
        return { ok = false, reason = "not_admin" }
    end
    if on then
        local slots = (mode == "max")
                and AdminPowerPalette.maxSlots(self._powersConfig, self._enhConfig, powerId)
            or {}
        local attr = self:_stampPassive(player, powerId, slots)
        return { ok = attr ~= nil, attr = attr }
    end
    self:_clearPassive(player, powerId, true) -- forget: a transient admin test leaves no greyed badge
    return { ok = true }
end

-- PLAYER HUD toggle — turn an OWNED always-on power on/off. Owned + always-on only (no admin bypass):
-- this is the player's control, so it can't be used to run a power they don't have. ON re-stamps at the
-- player's real slotting and starts the upkeep drain; OFF clears the buff but KEEPS the owned marker so
-- the HUD shows a greyed badge to flip back on.
function PowerService:ToggleActive(player, powerId, on)
    local data = self._dataService and self._dataService:GetData(player)
    local owns = false
    if data and type(data.Powers) == "table" then
        for _, p in ipairs(data.Powers) do
            if tostring(p) == tostring(powerId) then
                owns = true
                break
            end
        end
    end
    if not owns then
        return { ok = false, reason = "not_owned" }
    end
    local kinds = self._powersConfig.effect_kinds or {}
    local def = self._powersConfig.powers[tostring(powerId)]
    local kind = def and def.effect and kinds[def.effect]
    if not (kind and kind.passive and PASSIVE_ATTR[kind.family]) then
        return { ok = false, reason = "not_toggle" }
    end
    if on then
        local slots = (type(data.Slots) == "table" and data.Slots[tostring(powerId)]) or {}
        local attr = self:_stampPassive(player, powerId, slots)
        return { ok = attr ~= nil, on = true }
    end
    self:_clearPassive(player, powerId) -- keep the owned marker → badge greys to OFF
    return { ok = true, on = false }
end

-- Sum the per-second focus_upkeep of a player's RUNNING toggles, each lowered by its own slotted
-- `focus` enhancements (the `focus` axis = drain reduction). A toggle with Focus enhancements drains
-- less; enough of them make it free (effectiveRate clamps reduction to 1).
function PowerService:_activeUpkeepRate(player, active)
    local data = self._dataService and self._dataService:GetData(player)
    local level = tonumber(player:GetAttribute("Level")) or 1
    local rates = {}
    for powerId in pairs(active or {}) do
        local def = self._powersConfig.powers[tostring(powerId)]
        local base = def and tonumber(def.focus_upkeep)
        if base and base > 0 then
            local slots = (data and type(data.Slots) == "table" and data.Slots[tostring(powerId)])
                or {}
            local reduction = Enhancements.aggregate(self._enhConfig, slots, level).focus or 0
            rates[#rates + 1] = FocusUpkeep.effectiveRate(base, reduction)
        end
    end
    return FocusUpkeep.total(rates)
end

-- CoH crash: the pool couldn't pay this tick → drop EVERY running toggle. They stay off (no auto-
-- resume) until the player re-toggles from the HUD; the owned markers persist so the badges grey out.
function PowerService:_detoggleAll(player)
    local active = self._activeToggles and self._activeToggles[player]
    if not active then
        return
    end
    local ids = {}
    for powerId in pairs(active) do
        ids[#ids + 1] = powerId
    end
    for _, powerId in ipairs(ids) do
        self:_clearPassive(player, powerId) -- keep owned marker → greyed badge
    end
    if #ids > 0 then
        -- Route the crash through the GameEvents bus so a sound / VFX can hook it config-only
        -- (configs/game_events.lua → toggle_crash). No-op if no row is configured.
        fireGameEvent(player, "toggle_crash", { count = #ids })
    end
end

-- The always-on UPKEEP loop: every tick, drain each player's running toggles' focus_upkeep from their
-- Focus pool; if the pool can't cover the tick, crash (detoggle) them. Pure in-memory + the Focus
-- attribute — no datastore. Runs forever (mirrors FocusService's regen loop).
function PowerService:_startUpkeepLoop()
    local TICK = 0.5
    task.spawn(function()
        while true do
            task.wait(TICK)
            local focusSvc = self._moduleLoader and self._moduleLoader:Get("FocusService")
            if focusSvc then
                for player, active in pairs(self._activeToggles) do
                    if player.Parent and next(active) ~= nil then
                        local rate = self:_activeUpkeepRate(player, active)
                        if rate > 0 then
                            local st = focusSvc:Get(player)
                            local focus = (st and st.focus) or 0
                            local res = FocusUpkeep.step(focus, rate, TICK)
                            if res.drained > 0 then
                                focusSvc:Drain(player, res.drained)
                            end
                            if res.crashed then
                                self:_detoggleAll(player)
                            end
                        end
                    end
                end
            end
        end
    end)
end

local function enemiesAlive()
    local game = Workspace:FindFirstChild("Game")
    local folder = game and game:FindFirstChild("Enemies")
    local out = {}
    if folder then
        for _, m in ipairs(folder:GetChildren()) do
            if m:IsA("Model") and (m:GetAttribute("HP") or 0) > 0 then
                out[#out + 1] = m
            end
        end
    end
    return out
end

-- All alive farm nodes (crystals/ore) — Models under Game.Breakables/<type>/<world> with HP > 0.
-- These are NOT enemies (no EnemyId); a target-strength debuff (vulnerable) speeds mining the same
-- way it speeds combat. #174: farming powers reach crystals through the pets, just like enemies.
local function breakablesAlive()
    local game = Workspace:FindFirstChild("Game")
    local root = game and game:FindFirstChild("Breakables")
    local out = {}
    if root then
        for _, desc in ipairs(root:GetDescendants()) do
            if
                desc:IsA("Model")
                and (desc:GetAttribute("HP") or 0) > 0
                and not desc:GetAttribute("EnemyId")
            then
                out[#out + 1] = desc
            end
        end
    end
    return out
end

-- Is the player's squad engaged with an enemy? Gates offensive powers — see Cast. Friendly powers
-- don't call this. Primary signal: a pet is actively attacking an ENEMY (its TargetID is set and
-- TargetType == "Enemy") — literally "the pet is targeting something", robust to boss size and
-- distance. Fallback: an alive enemy within engage_radius of the squad (covers the brief window
-- after an assist target before a pet has latched on).
function PowerService:_hasEngagedEnemy(player)
    local pets = Workspace:FindFirstChild("PlayerPets")
        and Workspace.PlayerPets:FindFirstChild(player.Name)

    -- (a) any pet attacking an enemy
    if pets then
        for _, pet in ipairs(pets:GetChildren()) do
            if pet:IsA("Model") and not pet:GetAttribute("CombatDowned") then
                local tid = pet:FindFirstChild("TargetID")
                local ttype = pet:FindFirstChild("TargetType")
                if tid and tid.Value ~= 0 and ttype and tostring(ttype.Value) == "Enemy" then
                    return true
                end
            end
        end
    end

    -- (b) fallback: an alive enemy near the squad
    local enemies = enemiesAlive()
    if #enemies == 0 then
        return false
    end
    local sx, sz, n = 0, 0, 0
    if pets then
        for _, pet in ipairs(pets:GetChildren()) do
            if pet:IsA("Model") and not pet:GetAttribute("CombatDowned") and pet.PrimaryPart then
                sx, sz, n = sx + pet.PrimaryPart.Position.X, sz + pet.PrimaryPart.Position.Z, n + 1
            end
        end
    end
    local squadPos
    if n > 0 then
        squadPos = Vector3.new(sx / n, 0, sz / n)
    else
        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then
            return false
        end
        squadPos = Vector3.new(hrp.Position.X, 0, hrp.Position.Z)
    end
    local engageR = tonumber(self._powersConfig.engage_radius) or 60
    for _, e in ipairs(enemies) do
        local pp = e.PrimaryPart or e:FindFirstChildWhichIsA("BasePart")
        if
            pp
            and (Vector3.new(pp.Position.X, 0, pp.Position.Z) - squadPos).Magnitude <= engageR
        then
            return true
        end
    end
    return false
end

-- The single ENEMY the squad is actually fighting — for single-target powers (Wildfire's seed,
-- single-target DoT/debuff). Position-independent: resolves a targetId to a model via the enemy's
-- `BreakableID` child (the same id pets store in TargetID and the player stores in CombatAssistTarget).
-- Priority: the player's assist target (their directed pick) → else the enemy the MOST pets are
-- attacking. nil if the squad isn't engaged with any enemy.
function PowerService:_engagedEnemy(player)
    local function modelForId(id)
        if not id or id == 0 then
            return nil
        end
        for _, e in ipairs(enemiesAlive()) do
            local bid = e:FindFirstChild("BreakableID")
            if bid and bid.Value == id then
                return e
            end
        end
        return nil
    end

    -- 1) player-directed assist target always wins (the one they selected)
    local assisted = modelForId(player:GetAttribute("CombatAssistTarget"))
    if assisted then
        return assisted
    end

    -- 2) else the enemy the most pets are currently attacking
    local pets = Workspace:FindFirstChild("PlayerPets")
        and Workspace.PlayerPets:FindFirstChild(player.Name)
    if not pets then
        return nil
    end
    local counts = {}
    for _, pet in ipairs(pets:GetChildren()) do
        if pet:IsA("Model") and not pet:GetAttribute("CombatDowned") then
            local tid = pet:FindFirstChild("TargetID")
            local tt = pet:FindFirstChild("TargetType")
            if tid and tid.Value ~= 0 and tt and tostring(tt.Value) == "Enemy" then
                counts[tid.Value] = (counts[tid.Value] or 0) + 1
            end
        end
    end
    local bestId, bestN
    for id, n in pairs(counts) do
        if not bestN or n > bestN then
            bestId, bestN = id, n
        end
    end
    return modelForId(bestId)
end

-- Crystals the squad is engaged with (#174). Mirrors _hasEngagedEnemy's primary signal: a pet whose
-- TargetID is set and TargetType is NOT "Enemy" is mining that exact node. We resolve those ids to
-- crystal Models by their `BreakableID` child — position-INDEPENDENT, because pets are moved on the
-- client (RenderStepped), so their server-side PrimaryPart.Position is unreliable for a proximity
-- check. Returns exactly the crystals the squad's pets are mining (so the debuff lands on them).
function PowerService:_engagedBreakables(player)
    local pets = Workspace:FindFirstChild("PlayerPets")
        and Workspace.PlayerPets:FindFirstChild(player.Name)
    if not pets then
        return {}
    end
    -- collect the target ids of every pet currently mining a node (non-enemy target)
    local wanted = {}
    local anyMining = false
    for _, pet in ipairs(pets:GetChildren()) do
        if pet:IsA("Model") and not pet:GetAttribute("CombatDowned") then
            local tid = pet:FindFirstChild("TargetID")
            local ttype = pet:FindFirstChild("TargetType")
            if tid and tid.Value ~= 0 and ttype and tostring(ttype.Value) ~= "Enemy" then
                wanted[tid.Value] = true
                anyMining = true
            end
        end
    end
    if not anyMining then
        return {}
    end
    -- resolve those ids to the alive crystal Models (BreakableID child, or BreakableId attribute)
    local out = {}
    for _, c in ipairs(breakablesAlive()) do
        local idChild = c:FindFirstChild("BreakableID")
        local cid = (idChild and idChild.Value)
            or c:GetAttribute("BreakableId")
            or c:GetAttribute("BreakableID")
        if cid and wanted[cid] then
            out[#out + 1] = c
        end
    end
    return out
end

-- True when a farm-targeting power may fire: the squad is mining crystals (#174). Cheap wrapper.
function PowerService:_hasEngagedFarmTarget(player)
    return #self:_engagedBreakables(player) > 0
end

-- Apply a cast power's SUPPORT effect (no direct damage — see configs/powers.lua). `powerId` is
-- stamped onto each buff it applies (CombatShieldPowerId / DefenseBuffPowerId / PetDamageBuffPowerId)
-- so every UI surface resolves the SAME icon for it via PetBadge.forPower (no generic fallbacks).
-- Which of the player's pets a buff applies to. Squad-wide by default; a power whose def carries
-- target="single_pet" applies to ONE pet — the player's selected squad card (CombatBuffTarget = a
-- PositionNumber), falling back to the first non-downed pet when nothing is selected (quick test).
-- CombatBuffTarget == -1 is the TEAM sentinel (the player picked the squad-strip TEAM header card):
-- a single_pet power then applies to the WHOLE squad, so you can shield/heal/buff everyone on demand.
function PowerService:_targetPets(player, powerId)
    -- CAST-THROUGH-PLAYER (docs/TEAMING.md): a selected TEAMMATE (CombatBuffTargetPlayer
    -- attribute) redirects support families to THEIR squad, resolved by the pure TeamCast
    -- core (heal -> most hurt, absorb -> aggro holder/tank, buffs -> squad). Team-verified.
    local redirected = self:_teamTargetPets(player, powerId)
    if redirected then
        return redirected
    end
    local folder = Workspace:FindFirstChild("PlayerPets")
        and Workspace.PlayerPets:FindFirstChild(player.Name)
    if not folder then
        return {}
    end
    local live = {}
    for _, pet in ipairs(folder:GetChildren()) do
        if pet:IsA("Model") and not pet:GetAttribute("CombatDowned") then
            live[#live + 1] = pet
        end
    end
    local def = self._powersConfig.powers and self._powersConfig.powers[powerId]
    if not (def and def.target == "single_pet") then
        -- Squad-wide SUPPORT casts cover the whole TEAM's pets when teamed (Jason: bastion
        -- was buffing only the caster's squad). Non-support families stay own-squad.
        return self:_withTeamPets(player, powerId, live)
    end
    local sel = player:GetAttribute("CombatBuffTarget")
    -- SLOT-COLLISION guard (live-caught: taunt at a teammate's Ent landed on the caster's
    -- same-numbered Ent): a selection pointing at ANOTHER player's pet carries THEIR
    -- PositionNumber — never match it against our own squad. A cast that reaches here with
    -- a mate selected (family not redirectable) falls to the default pick instead.
    local mateSel = player:GetAttribute("CombatBuffTargetPlayer")
    if type(mateSel) == "string" and mateSel ~= "" and mateSel ~= player.Name then
        sel = 0
    end
    if sel == -1 then
        -- TEAM scope (header card): the whole squad — and the whole TEAM when teamed.
        return self:_withTeamPets(player, powerId, live)
    end
    if sel and sel ~= 0 then
        for _, pet in ipairs(live) do
            local pn = pet:FindFirstChild("PositionNumber")
            if pn and pn.Value == sel then
                return { pet }
            end
        end
    end
    return live[1] and { live[1] } or {} -- fallback: first non-downed pet
end

-- Lazy teaming deps (config + pure cores). Shared by every team-cast path below.
function PowerService:_teamingInit()
    if not self._teamingConfig then
        local ok, cfg = pcall(function()
            return require(ReplicatedStorage.Configs:WaitForChild("teaming"))
        end)
        self._teamingConfig = ok and cfg or { support_families = {} }
        self._teamCast = require(ReplicatedStorage.Shared.Game.TeamCast)
        self._petEndurance = require(ReplicatedStorage.Shared.Game.PetEndurance)
    end
    return self._teamingConfig
end

-- The power's support family (heal/absorb/defense_buff/...), or nil when it isn't one that
-- may cross player boundaries (configs/teaming.lua support_families).
function PowerService:_supportFamily(powerId)
    local cfg = self:_teamingInit()
    local def = self._powersConfig.powers and self._powersConfig.powers[powerId]
    local kind = def
        and self._powersConfig.effect_kinds
        and self._powersConfig.effect_kinds[def.effect]
    local family = kind and kind.family
    return (family and cfg.support_families[family]) and family or nil
end

-- Squad-wide team cover (docs/TEAMING.md): extend a squad-wide SUPPORT cast's target list
-- with every TEAMMATE's live pets, SameTeam-gated per member. Non-support powers (or an
-- unteamed caster) get the caster's own list back untouched.
function PowerService:_withTeamPets(player, powerId, live)
    -- [TeamCast] TEMPORARY traces (teaming live-verify): one line per TEAMED squad-wide
    -- cast saying what the team extension decided. Strip after TM6.
    local members = player:GetAttribute("TeamMembers")
    local teamed = type(members) == "string" and members ~= ""
    if not self:_supportFamily(powerId) then
        if teamed then
            print(
                string.format(
                    "[TeamCast] %s cast %s squad-wide: NOT a support family -> own squad only",
                    player.Name,
                    tostring(powerId)
                )
            )
        end
        return live
    end
    if not teamed then
        return live
    end
    local partySvc = _G.RBXTemplateServices
        and select(
            2,
            pcall(function()
                return _G.RBXTemplateServices:Get("PartyService")
            end)
        )
    if not (partySvc and partySvc.SameTeam) then
        print("[TeamCast] " .. player.Name .. " PartyService unavailable -> own squad only")
        return live
    end
    local before = #live
    local pp = Workspace:FindFirstChild("PlayerPets")
    for name in members:gmatch("[^,]+") do
        if name ~= player.Name then
            local mate = Players:FindFirstChild(name)
            local folder = mate and pp and pp:FindFirstChild(name)
            if mate and folder and partySvc:SameTeam(player, mate) then
                for _, pet in ipairs(folder:GetChildren()) do
                    if pet:IsA("Model") and not pet:GetAttribute("CombatDowned") then
                        live[#live + 1] = pet
                    end
                end
            else
                print(
                    string.format(
                        "[TeamCast] %s mate %s skipped (present=%s folder=%s sameTeam=%s)",
                        player.Name,
                        name,
                        tostring(mate ~= nil),
                        tostring(folder ~= nil),
                        tostring(mate ~= nil and partySvc:SameTeam(player, mate))
                    )
                )
            end
        end
    end
    print(
        string.format(
            "[TeamCast] %s cast %s squad-wide: own=%d +team=%d",
            player.Name,
            tostring(powerId),
            before,
            #live - before
        )
    )
    return live
end

-- Resolve a cross-player support cast (docs/TEAMING.md), or nil to fall through to the
-- caster's own squad. Requires: a CombatBuffTargetPlayer selection, same team (PartyService,
-- located via the runtime registry — the loader only injects DECLARED deps), and a power
-- family listed in configs/teaming.lua support_families. TeamCast (pure) picks the pets.
function PowerService:_teamTargetPets(player, powerId)
    local targetName = player:GetAttribute("CombatBuffTargetPlayer")
    if type(targetName) ~= "string" or targetName == "" or targetName == player.Name then
        return nil
    end
    self:_teamingInit()
    -- [TeamCast] TEMPORARY trace: fires on every cast made with a player selected. Strip
    -- after TM6.
    local family = self:_supportFamily(powerId)
    if not family then
        print(
            string.format(
                "[TeamCast] %s cast %s at %s: NOT a support family -> falls to own squad",
                player.Name,
                tostring(powerId),
                targetName
            )
        )
        return nil
    end
    local target = Players:FindFirstChild(targetName)
    if not target then
        print("[TeamCast] " .. player.Name .. " target " .. targetName .. " not present")
        return nil
    end
    -- SELECTABLE = AFFECTABLE (Jason, CoH-style): an EXPLICITLY selected player's pets take
    -- support casts teamed or NOT — drive-by heals/shields on strangers are the point. No
    -- SameTeam gate here; the support_families check above is the safety (only friendly
    -- effects ever cross player boundaries). Teaming's perk stays the roster conveniences:
    -- the HUD cards and whole-team AoE buffs (_withTeamPets IS SameTeam-gated).
    local folder = Workspace:FindFirstChild("PlayerPets")
        and Workspace.PlayerPets:FindFirstChild(targetName)
    if not folder then
        return nil
    end
    -- EXPLICIT teammate-pet pick (Jason: clicking a teammate's pet card should select IT):
    -- the client sends the pet's PositionNumber alongside playerName, stamped as
    -- CombatBuffTarget. When set, the cast lands on that exact pet — TeamCast auto-pick is
    -- the fallback for the header-card (whole-player) selection.
    local sel = tonumber(player:GetAttribute("CombatBuffTarget")) or 0
    if sel > 0 then
        for _, pet in ipairs(folder:GetChildren()) do
            if pet:IsA("Model") then
                local pn = pet:FindFirstChild("PositionNumber")
                if pn and pn.Value == sel then
                    print(
                        string.format(
                            "[TeamCast] %s cast %s -> %s's pet slot %d (%s) EXPLICIT",
                            player.Name,
                            tostring(powerId),
                            targetName,
                            sel,
                            tostring(pet:GetAttribute("PetType"))
                        )
                    )
                    return { pet }
                end
            end
        end
        print(
            string.format(
                "[TeamCast] %s slot %d not found in %s's folder -> auto-pick",
                player.Name,
                sel,
                targetName
            )
        )
    end
    local states = {}
    for _, pet in ipairs(folder:GetChildren()) do
        if pet:IsA("Model") then
            local taken = tonumber(pet:GetAttribute("CombatDamageTaken")) or 0
            local power = tonumber(pet:GetAttribute("EffectivePower"))
                or (pet:FindFirstChild("Power") and tonumber(pet.Power.Value))
                or 1
            local okMax, max = pcall(self._petEndurance.maxEndurance, power, nil)
            max = (okMax and tonumber(max)) or math.max(power * 10, 1)
            states[#states + 1] = {
                key = pet,
                enduranceFrac = math.clamp(1 - taken / math.max(max, 1), 0, 1),
                downed = pet:GetAttribute("CombatDowned") == true,
                hasAggro = false, -- aggro introspection is a TM2 follow-up; tank fallback covers it
                isTank = pet:GetAttribute("PetRole") == "tank",
            }
        end
    end
    local picked = self._teamCast.pick(family, states)
    if #picked == 0 then
        print(
            string.format(
                "[TeamCast] %s cast %s at %s: TeamCast picked NOTHING (%d states) -> own squad",
                player.Name,
                tostring(powerId),
                targetName,
                #states
            )
        )
        return nil -- nothing appropriate on their side: fall back to own squad
    end
    local pets = {}
    for _, state in ipairs(picked) do
        pets[#pets + 1] = state.key
    end
    print(
        string.format(
            "[TeamCast] %s cast %s -> %s x%d pets (family=%s AUTO)",
            player.Name,
            tostring(powerId),
            targetName,
            #pets,
            family
        )
    )
    return pets
end

-- Who soaks the aggro a TAUNT pulls. Player intent first: an explicitly SELECTED squad card
-- (CombatBuffTarget) takes it, ANY role — the player's call. Otherwise it auto-routes to the
-- deployed TANK(s), weighted by their role Defense so a sturdier tank holds proportionally more of
-- the pull. No selection AND no tank => empty => Cast refuses (never burns focus for nothing).
-- Returns { { pet = <model>, weight = <number> }, … }.
function PowerService:_tauntHolders(player)
    local folder = Workspace:FindFirstChild("PlayerPets")
        and Workspace.PlayerPets:FindFirstChild(player.Name)
    if not folder then
        return {}
    end
    local live = {}
    for _, pet in ipairs(folder:GetChildren()) do
        if pet:IsA("Model") and not pet:GetAttribute("CombatDowned") then
            live[#live + 1] = pet
        end
    end
    -- explicit SINGLE-pet selection wins — the taunt goes exactly where the player pointed it.
    -- The TEAM sentinel (-1) is NOT a single pet: it falls through to the tank auto-route below, so
    -- "team selected" taunt = all your tanks hold aggro (the sensible whole-team read for a taunt).
    local sel = player:GetAttribute("CombatBuffTarget")
    if sel and sel ~= 0 and sel ~= -1 then
        for _, pet in ipairs(live) do
            local pn = pet:FindFirstChild("PositionNumber")
            if pn and pn.Value == sel then
                return { { pet = pet, weight = 1 } }
            end
        end
    end
    -- else the tanks (implicit_taunt role), weighted by their role Defense
    local roles = PET_ROLES.roles or {}
    local byType = PET_ROLES.by_type or {}
    local holders = {}
    for _, pet in ipairs(live) do
        local roleId = pet:GetAttribute("PetRole")
            or byType[pet:GetAttribute("PetType")]
            or PET_ROLES.default
        local def = roles[roleId]
        if def and def.implicit_taunt == true then
            holders[#holders + 1] = { pet = pet, weight = math.max(1, tonumber(def.defense) or 1) }
        end
    end
    return holders
end

-- A cast that COULDN'T fire (no target / no tank / not enough focus). Fires the shared
-- "power_cast_failed" game event so the client plays the flub buzzer + a small red puff (the generic
-- "that didn't work" feedback, reusable from any un-castable path — Jason), then returns the refusal
-- envelope. Extra fields (e.g. remaining focus) merge into the returned table.
function PowerService:_flub(player, reason, extra)
    fireGameEvent(player, "power_cast_failed", { reason = reason })
    local out = { ok = false, reason = reason }
    if type(extra) == "table" then
        for k, v in pairs(extra) do
            out[k] = v
        end
    end
    return out
end

-- A player-wide AXIS buff (coin_yield / mining / luck / move_speed / recharge / xp). Stored as a
-- FRACTION (+0.5 = +50%) + a timer + the power id (for the badge). Consumers sum it via BuffStack
-- alongside any aura on the same axis (additive, never compounding — docs Part E).
function PowerService:_setAxisBuff(player, attr, frac, now, dur, powerId)
    player:SetAttribute(attr, frac)
    player:SetAttribute(attr .. "Until", now + (dur or 0))
    player:SetAttribute(attr .. "PowerId", powerId)
end

-- #180: a TOGGLE buff (Hasten / Super Speed) — cast to turn ON (permanent, no countdown), cast again
-- to turn OFF. The `*Toggle` flag marks it permanent so HUDs show no timer; `*Until` is set far in the
-- future so the same `Until > now` consumers keep applying it without any other change.
local TOGGLE_PERMANENT_UNTIL = 4102444800 -- year 2100 — effectively "on until toggled off"
function PowerService:_toggleAxisBuff(player, attr, frac, powerId)
    if player:GetAttribute(attr .. "Toggle") == true then
        player:SetAttribute(attr, nil)
        player:SetAttribute(attr .. "Until", 0)
        player:SetAttribute(attr .. "Toggle", nil)
        player:SetAttribute(attr .. "PowerId", nil)
    else
        player:SetAttribute(attr, frac)
        player:SetAttribute(attr .. "Until", TOGGLE_PERMANENT_UNTIL)
        player:SetAttribute(attr .. "Toggle", true)
        player:SetAttribute(attr .. "PowerId", powerId)
    end
end

-- Teleport the player's character to `pos` (a Vector3) or, if nil, the world spawn (World Travel /
-- recall fallback). A small lift keeps them above the floor.
function PowerService:_teleportPlayer(player, pos)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return
    end
    local target = pos
    if typeof(target) ~= "Vector3" then
        local spawn = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
        target = spawn and spawn.Position
    end
    if typeof(target) == "Vector3" then
        hrp.CFrame = CFrame.new(target + Vector3.new(0, 4, 0))
    end
end

-- Heal one pet by `amount` endurance (shared by heal / fortify / heal_blind / summon families).
function PowerService:_healPet(player, pet, amount, now)
    if not (pet and pet:IsA("Model")) or pet:GetAttribute("CombatDowned") then
        return
    end
    amount = tonumber(amount) or 0
    local taken = pet:GetAttribute("CombatDamageTaken") or 0
    if amount <= 0 or taken <= 0 then
        return
    end
    -- res-sickness clamp: a freshly revived pet can't be healed past its res floor (window-gated)
    local newTaken = ResSickness.clampTaken(pet:GetAttributes(), math.max(0, taken - amount), now)
    local healed = math.max(0, taken - newTaken)
    pet:SetAttribute("CombatDamageTaken", newTaken)
    pet:SetAttribute("HealFxUntil", now + 3)
    if healed >= 1 then
        -- shared world effect (Jason: team effect game) — every nearby client sees the +N
        Signals.Combat_Heal:FireAllClients({ target = pet, amount = math.floor(healed + 0.5) })
    end
end

-- Shared GROUND RUNE for player AoE powers: the uploaded MagicCircle symbol on a flat shared-world
-- slab, tinted to the ACTION's color (color carries meaning — green heal, yellow farm-boost, …).
-- Timing via opts: fade_in / hold / fade_out (sec), `bright` = peak opacity (0 = fully bright), `spin`
-- = slow rotation over its life. Used by both the persistent Healing Field (long hold) and momentary
-- casts like Resonance (bright flash → fade). Returns the marker part.
-- Public alias: other services borrow the same telegraph primitive (EnemyService's arch-villain
-- slam marks its impact zone with it — one rune path, no parallel visual).
function PowerService:SpawnGroundRune(center, radius, color, opts)
    return self:_spawnGroundRune(center, radius, color, opts)
end

function PowerService:_spawnGroundRune(center, radius, color, opts)
    opts = opts or {}
    local fadeIn = tonumber(opts.fade_in) or 0.35
    local hold = math.max(0, tonumber(opts.hold) or 0)
    local fadeOut = tonumber(opts.fade_out) or 0.6
    local bright = tonumber(opts.bright) or 0.05
    local lifetime = fadeIn + hold + fadeOut
    -- The MagicCircle texture's visible ring sits at ~RING_FRAC of the image (the art has margin), so
    -- the slab is upsized by 1/RING_FRAC → the VISIBLE gold ring lands exactly at `radius`. Pass the
    -- power's EFFECTIVE (post-enhancement) AoE radius and the circle reads as the true area. The sand
    -- fill defaults to RING_FRAC so it matches the gold ring (= radius) too.
    local RING_FRAC = 0.88
    local slabRadius = radius / RING_FRAC
    -- Sit the rune on the REAL floor under the centre (raycast down), like the pet aura fields — so it
    -- doesn't float or clip into uneven ground. Exclude pets / enemies / players / FX so the ray finds
    -- the map terrain.
    local floorY = center.Y - 2.4
    do
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        rp.IgnoreWater = true
        local excl = {}
        local pets = Workspace:FindFirstChild("PlayerPets")
        if pets then
            excl[#excl + 1] = pets
        end
        local gameF = Workspace:FindFirstChild("Game")
        local enemies = gameF and gameF:FindFirstChild("Enemies")
        if enemies then
            excl[#excl + 1] = enemies
        end
        for _, fn in ipairs({ "CombatFXFields", "Effects" }) do
            local f = Workspace:FindFirstChild(fn)
            if f then
                excl[#excl + 1] = f
            end
        end
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then
                excl[#excl + 1] = p.Character
            end
        end
        rp.FilterDescendantsInstances = excl
        local hit = Workspace:Raycast(center + Vector3.new(0, 6, 0), Vector3.new(0, -200, 0), rp)
        if hit then
            floorY = hit.Position.Y
        end
    end
    local marker = Instance.new("Part")
    marker.Name = opts.name or "PowerRune"
    marker.Anchored = true
    marker.CanCollide = false
    marker.CanQuery = false
    marker.CastShadow = false
    marker.Transparency = 1 -- invisible slab; the SurfaceGui image IS the rune
    marker.Size = Vector3.new(slabRadius * 2, 0.1, slabRadius * 2)
    marker.CFrame = CFrame.new(center.X, floorY + 0.1, center.Z)
    marker.Parent = Workspace
    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Top
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 10
    gui.Parent = marker
    local fades = {} -- { {imageLabel, peakTransparency}, … } — all fade together

    -- Optional textured FILL UNDER the rune: a circular-clipped, tiled texture (e.g. a sand tile) tinted
    -- to give the disc a "modeled" ground look behind the symbol. opts.fill_texture / fill_color /
    -- fill_bright (peak opacity) / fill_tiles (tiles across the disc).
    if opts.fill_texture then
        local fill = Instance.new("ImageLabel")
        -- centered + scaled to match the magic-circle's VISIBLE diameter (the rune texture has margin,
        -- so a full-slab fill reads bigger than the circle). fill_scale tunes the match.
        local fscale = tonumber(opts.fill_scale) or RING_FRAC
        fill.AnchorPoint = Vector2.new(0.5, 0.5)
        fill.Position = UDim2.fromScale(0.5, 0.5)
        fill.Size = UDim2.fromScale(fscale, fscale)
        fill.BackgroundTransparency = 1
        fill.ScaleType = Enum.ScaleType.Tile
        local tiles = tonumber(opts.fill_tiles) or 4
        fill.TileSize = UDim2.fromScale(1 / tiles, 1 / tiles)
        local ftex = tostring(opts.fill_texture)
        if not ftex:match("^rbxassetid://") then
            ftex = "rbxassetid://" .. ftex
        end
        fill.Image = ftex
        fill.ImageColor3 = opts.fill_color or color
        fill.ImageTransparency = 1
        fill.ZIndex = 1
        fill.Parent = gui
        -- UICorner ON THE IMAGE clips the tiled fill to a CIRCLE. (A parent Frame's ClipsDescendants
        -- only clips to the RECTANGLE, which left the square sand patch — confirmed + fixed live.)
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0.5, 0)
        corner.Parent = fill
        fades[#fades + 1] = { fill, tonumber(opts.fill_bright) or 0.45 }
    end

    local rune = Instance.new("ImageLabel")
    rune.Size = UDim2.fromScale(1, 1)
    rune.BackgroundTransparency = 1
    rune.Image = "rbxassetid://136557266765344" -- MagicCircle (uploaded)
    rune.ImageColor3 = color
    rune.ImageTransparency = 1
    rune.ZIndex = 2 -- the symbol sits ON TOP of the fill
    rune.Parent = gui
    fades[#fades + 1] = { rune, bright }

    for _, f in ipairs(fades) do
        TweenService:Create(f[1], TweenInfo.new(fadeIn), { ImageTransparency = f[2] }):Play()
    end
    if opts.spin then
        TweenService
            :Create(marker, TweenInfo.new(lifetime, Enum.EasingStyle.Linear), {
                CFrame = marker.CFrame * CFrame.Angles(0, math.rad(opts.spin_deg or 60), 0),
            })
            :Play()
    end
    task.delay(fadeIn + hold, function()
        for _, f in ipairs(fades) do
            if f[1] and f[1].Parent then
                TweenService:Create(f[1], TweenInfo.new(fadeOut), { ImageTransparency = 1 }):Play()
            end
        end
    end)
    Debris:AddItem(marker, lifetime + 0.3)
    return marker
end

-- Heal-over-time: heal the WHOLE squad `perTick` every `tickSeconds` for `totalSeconds`. Re-resolves
-- the squad each tick so it heals whoever is alive (Living Mountain's standing aura, Oasis's tail).
-- Healing Field — a STATIONARY heal zone dropped at the player's feet (kind.field). Unlike the
-- squad-wide heal, this anchors at the cast position and only heals pets standing within
-- `field_radius` of that fixed spot, each `hot_tick` for `hot_seconds`. You position the zone by
-- WALKING your (invulnerable spirit) onto the squad — no aim reticle, identical on desktop/mobile.
-- A shared-world ground disc marks it so every nearby client sees where the sustain is.
-- perTick + totalSeconds are the EFFECTIVE (enhancement-scaled) magnitude + duration from the cast,
-- so a `health`/`healing` enhancement raises the per-tick heal and (if ever slotted) duration extends
-- the zone — the same numbers the ENHANCE preview shows.
function PowerService:_healZone(player, kind, perTick, totalSeconds, powerId)
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return
    end
    local center = hrp.Position
    local radius = tonumber(kind.field_radius) or 28
    perTick = tonumber(perTick) or 0
    local tickSeconds = tonumber(kind.hot_tick) or 2
    totalSeconds = tonumber(totalSeconds) or 8
    if perTick <= 0 or totalSeconds <= 0 then
        return
    end

    -- Ground RUNE CIRCLE marking the heal zone for its WHOLE life (shared-world): a bright heal-green
    -- MagicCircle that fades in, holds the field's duration, then fades out. Replaces the old neon disc.
    self:_spawnGroundRune(center, radius, Color3.fromRGB(85, 255, 130), {
        name = "HealZone",
        fade_in = 0.35,
        hold = math.max(0.1, totalSeconds - 0.95),
        fade_out = 0.6,
    })

    task.spawn(function()
        local pfs = self._moduleLoader and self._moduleLoader:Get("PetFollowService")
        local elapsed = 0
        while elapsed < totalSeconds do
            task.wait(tickSeconds)
            elapsed += tickSeconds
            if not player.Parent then
                return
            end
            -- BATTLEFIELD PRINCIPLE (Jason, CoH-style): once placed, the field is a battlefield
            -- entity, not a roster query — EVERY friendly standing in it gets the tick. Friendly
            -- = any player's pets (player pets never fight each other), teamed or NOT, so you
            -- can drop a heal field under a stranger's squad. Radius-gated against the FIXED
            -- centre; pet positions come from the replicated report the aggro system trusts
            -- (server pivots are stale for client-driven pets), falling back to the pivot.
            local pp = Workspace:FindFirstChild("PlayerPets")
            for _, folder in ipairs(pp and pp:GetChildren() or {}) do
                for _, pet in ipairs(folder:GetChildren()) do
                    if pet:IsA("Model") and not pet:GetAttribute("CombatDowned") then
                        local reported = pfs
                            and pfs.GetReportedPosition
                            and pfs:GetReportedPosition(pet)
                        local pos = (reported and reported.Position) or pet:GetPivot().Position
                        if (pos - center).Magnitude <= radius then
                            self:_healPet(player, pet, perTick, os.time())
                        end
                    end
                end
            end
        end
    end)
end

function PowerService:_healOverTime(player, perTick, tickSeconds, totalSeconds)
    perTick = tonumber(perTick) or 0
    tickSeconds = tonumber(tickSeconds) or 2
    totalSeconds = tonumber(totalSeconds) or 0
    if perTick <= 0 or totalSeconds <= 0 then
        return
    end
    task.spawn(function()
        local elapsed = 0
        while elapsed < totalSeconds do
            task.wait(tickSeconds)
            elapsed += tickSeconds
            if not player.Parent then
                return
            end
            local pets = Workspace:FindFirstChild("PlayerPets")
                and Workspace.PlayerPets:FindFirstChild(player.Name)
            if pets then
                local nowT = os.time()
                for _, pet in ipairs(pets:GetChildren()) do
                    if pet:IsA("Model") then
                        self:_healPet(player, pet, perTick, nowT)
                    end
                end
            end
        end
    end)
end

-- Ramp a vulnerability mark UPWARD from `fromMag` to `toMag` over `totalSeconds` (Inferno Brand:
-- the longer it burns, the deeper it bites). Re-stamps only enemies still carrying THIS brand.
function PowerService:_rampVulnerable(player, fromMag, toMag, totalSeconds, powerId)
    fromMag = tonumber(fromMag) or 1
    toMag = tonumber(toMag) or fromMag
    totalSeconds = tonumber(totalSeconds) or 0
    if toMag <= fromMag or totalSeconds <= 0 then
        return
    end
    task.spawn(function()
        local elapsed = 0
        while elapsed < totalSeconds do
            task.wait(1)
            elapsed += 1
            if not player.Parent then
                return
            end
            local m = fromMag + (toMag - fromMag) * math.min(1, elapsed / totalSeconds)
            local nowT = os.time()
            for _, enemy in ipairs(enemiesAlive()) do
                -- Ramp the power's OWN VulnMark channel while it's live (additive model: this only
                -- moves inferno's contribution; other marks are untouched). Gating on the channel —
                -- not DebuffPowerId — so another power stamping the badge can't stall the ramp.
                if (enemy:GetAttribute(VulnMark.untilAttr(powerId)) or 0) > nowT then
                    enemy:SetAttribute(VulnMark.attr(powerId), math.max(0, m - 1))
                end
            end
        end
    end)
end

-- Summon-guardian capstones (Gaia's Colossus / Genie of the Dunes) — delegate to SummonService,
-- which spawns the guardian model, applies its standing squad buffs / revive+heal, trails the
-- player and despawns. Resolved at runtime so PowerService doesn't hard-depend on it.
function PowerService:_summonGuardian(player, kind, now, powerId)
    local summon = self._moduleLoader and self._moduleLoader:Get("SummonService")
    if summon and summon.Summon then
        summon:Summon(player, kind, now, powerId)
    end
end

-- Damage-over-time: the power itself chips `perTick` HP off enemies every `interval` for
-- `totalSeconds` — independent of pet damage. Reduces the enemy's HP directly; EnemyService's
-- HP-changed watcher handles death + loot when it crosses 0, and we credit this player's Contrib
-- ledger so a DoT kill still pays out (same ledger PetFollowService:_mine writes).
--
-- Damage is a FLOAT and is deliberately NOT floored: a "minor" DoT (per_tick < 1) chips enemies
-- down a fraction of an HP per tick instead of rounding to zero. HP is a Roblox number attribute
-- (a double), so fractional HP is fine and the watcher still fires at <= 0.
--
-- aoe=true ticks every alive enemy (an AoE burn field); aoe=false ticks the single primary target
-- (a targeted brand). Re-resolves the target set each tick, so it burns whoever is alive now.
-- P5: the per-tick crit chance, source-agnostic — the power's own critBase PLUS the live
-- player CritBuff (Critical Strike) PLUS pet CritAura (a crit-buffer pet). The same channels the
-- pet-attack crit sums (PetFollowService), so a DoT crits whenever the squad's crit is up. Read
-- fresh each tick so a buff that expires mid-burn stops boosting. 0 by default ⇒ no crit ⇒ ×1.
function PowerService:_dotCritChance(player, critBase, now)
    local add = tonumber(critBase) or 0
    if (player:GetAttribute("CritBuffUntil") or 0) > now then
        add = add + (player:GetAttribute("CritBuff") or 0)
    end
    if (player:GetAttribute("CritAuraUntil") or 0) > now then
        add = add + (player:GetAttribute("CritAura") or 0)
    end
    return math.clamp(add, 0, 0.9)
end

function PowerService:_damageOverTime(
    player,
    perTick,
    interval,
    totalSeconds,
    aoe,
    powerId,
    critBase
)
    perTick = tonumber(perTick) or 0
    interval = math.max(0.1, tonumber(interval) or 1)
    totalSeconds = tonumber(totalSeconds) or 0
    if perTick <= 0 or totalSeconds <= 0 then
        return
    end
    -- Bound the AoE DoT (aoe=true "hits every alive enemy") to enemies near the caster, not every
    -- enemy in every realm. Shadows the file-global for the tick loop's enemiesAlive() calls.
    local enemiesAlive = function()
        return self:_enemiesInRange(player, tonumber(self._powersConfig.engage_radius))
    end
    local critMult = (
        self._combatConfig
        and self._combatConfig.rolls
        and self._combatConfig.rolls.pet_attack
        and self._combatConfig.rolls.pet_attack.crit_mult
    ) or 2.0
    task.spawn(function()
        local elapsed = 0
        while elapsed < totalSeconds do
            task.wait(interval)
            elapsed += interval
            if not player.Parent then
                return
            end
            local targets
            if aoe then
                targets = enemiesAlive()
                -- #174 extension (Jason: "powers should be beneficial in both farming and
                -- combat, maybe not symmetrically"): DoT ticks also chip the crystals the
                -- squad is actively mining. _dotHit is target-agnostic (HP attribute +
                -- Contrib ledger — breakables have both, and BreakableSpawner's HP watcher
                -- owns the payout), so crediting/loot just works. The asymmetry is
                -- structural: a DoT is a FLAT total per recharge while pet mining DPS is
                -- the scaling axis — strong vs same-scale enemy HP, a sprinkle on crystals.
                for _, c in ipairs(self:_engagedBreakables(player)) do
                    targets[#targets + 1] = c
                end
            else
                -- single-target DoT burns the ENEMY THE SQUAD IS FIGHTING (assist target /
                -- most-targeted) first; a squad that is MINING (no engaged enemy) burns its
                -- crystal instead. Only then fall back to an arbitrary alive enemy.
                local primary = self:_engagedEnemy(player)
                    or self:_engagedBreakables(player)[1]
                    or enemiesAlive()[1]
                targets = primary and { primary } or {}
            end
            local now = os.time()
            local critChance = self:_dotCritChance(player, critBase, now)
            for _, enemy in ipairs(targets) do
                self:_dotHit(
                    player,
                    enemy,
                    perTick,
                    critChance,
                    critMult,
                    now,
                    powerId,
                    math.ceil(interval) + 1
                )
            end
        end
    end)
end

-- Apply ONE DoT tick to a single enemy: per-tick crit roll (×1 / ×crit_mult), FLOAT damage (minor
-- DoT <1 still chips), Contrib credit, crit tell, and keep the debuff badge lit. Shared by the
-- generic DoT loop and the wildfire burn so damage application stays identical.
function PowerService:_dotHit(player, enemy, perTick, critChance, critMult, now, powerId, badgeSecs)
    if not (enemy and enemy.Parent) then
        return
    end
    local hp = enemy:GetAttribute("HP") or 0
    if hp <= 0 then
        return
    end
    local roll = CombatRoll.resolve(
        { hit_chance = 1, crit_chance = critChance, crit_mult = critMult },
        0,
        math.random()
    )
    local tick = perTick * roll.multiplier
    -- SPARK procs (slotted on this power): chance per hit to surge it for +bonus of its
    -- damage. The first proc enhancement — establishes the mechanics (Jason); rare
    -- specialty drops later ride the same Enhancements.procs path.
    local data = self._dataService and self._dataService:GetData(player)
    local slots = data and type(data.Slots) == "table" and data.Slots[tostring(powerId)]
    if slots then
        for _, proc in
            ipairs(
                Enhancements.procs(
                    self._enhConfig,
                    slots,
                    tonumber(player:GetAttribute("Level")) or 1
                )
            )
        do
            if proc.trigger == "hit" and math.random() < proc.chance then
                tick = tick * (1 + proc.bonus)
                enemy:SetAttribute("CritFxUntil", now + 1) -- surge tell (own VFX later)
            end
        end
    end
    local newHp = math.max(0, hp - tick) -- EnemyService HP-watcher -> death + loot
    enemy:SetAttribute("HP", newHp)
    self:_creditDot(enemy, player, hp - newHp)
    if roll.crit then
        enemy:SetAttribute("CritFxUntil", now + 1) -- crit tell (client, P6)
    end
    enemy:SetAttribute("DebuffPowerId", powerId)
    enemy:SetAttribute("DebuffUntil", now + (badgeSecs or 2))
end

-- Record DoT damage in the enemy's Contrib ledger (a NumberValue per UserId under the model) so the
-- kill credits this player for loot — the same ledger pet damage writes to in PetFollowService:_mine.
function PowerService:_creditDot(enemy, player, amount)
    if amount <= 0 then
        return
    end
    local contrib = enemy:FindFirstChild("Contrib")
    if not contrib then
        return
    end
    local key = tostring(player.UserId)
    local nv = contrib:FindFirstChild(key)
    if not nv then
        nv = Instance.new("NumberValue")
        nv.Name = key
        nv.Parent = contrib
    end
    nv.Value = nv.Value + amount
end

-- THIS PLAYER'S COMBAT SET — the enemies a player-cast AoE / control / debuff should hit: the fight
-- the squad is actually in, NOT every enemy in every realm (the unbounded enemiesAlive() loop reached
-- enemies 2000+ studs away in other realm worlds, Home ±2000 Y — Jason: "I can bomb them from very far
-- away / my powers work in hell 2 while I'm in hell 1"). Two inclusion paths, both bounded to this
-- player + realm:
--   (1) AggroOwner == player.Name — enemies ENGAGED with this player's squad, wherever they are. This
--       is the PRIMARY path: pets fight at range while the player stands back, so the enemies under
--       attack are routinely well past a body-centered radius. An enemy in another realm can't be
--       aggro'd to this player, so this never leaks cross-realm. (Reliable: an attribute, not a
--       client-driven model pivot — enemy/pet model positions read stale server-side.)
--   (2) within `radius` studs of the caster — a proximity fallback for an OPENER on enemies not yet
--       aggro'd but standing near you (their model pivot is ~accurate while they're not mid-chase).
-- radius defaults to powers.engage_radius.
function PowerService:_enemiesInRange(player, radius)
    radius = tonumber(radius) or (tonumber(self._powersConfig.engage_radius) or 60)
    local r2 = radius * radius
    local name = player.Name
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local cx, cz = hrp and hrp.Position.X, hrp and hrp.Position.Z
    local out, seen = {}, {}
    for _, e in ipairs(enemiesAlive()) do
        local include = e:GetAttribute("AggroOwner") == name
        if not include and hrp then
            local pp = e.PrimaryPart or e:FindFirstChildWhichIsA("BasePart")
            if pp then
                local dx, dz = pp.Position.X - cx, pp.Position.Z - cz
                include = dx * dx + dz * dz <= r2
            end
        end
        if include and not seen[e] then
            seen[e] = true
            out[#out + 1] = e
        end
    end
    return out
end

-- BADGE SSOT: stamp a generic per-power marker so EVERY badge surface (world billboards, HUD card,
-- enemy nameplate) renders from one place. Keyed by power id with an absolute expiry: a power's badge
-- is "active" iff Power_<id>_Until is in the future. One read path = a power can't show on one surface
-- and be missed on another. Only stamps when untilTime is in the future (instant effects don't badge).
function PowerService:_stampPowerBadge(entity, powerId, untilTime)
    if not (entity and powerId) then
        return
    end
    local t = tonumber(untilTime)
    if t and t > os.time() then
        entity:SetAttribute("Power_" .. tostring(powerId) .. "_Until", t)
    end
end

function PowerService:_applyEffect(player, kind, now, powerId)
    local family = kind.family
    local mag = kind.magnitude or 0
    local dur = kind.duration or 0
    -- Shadow the file-global enemiesAlive() with a CASTER-BOUNDED version for the whole family
    -- if/elseif below, so every enemy-targeting family (root / vulnerable / root_guard / heal_blind /
    -- …) hits enemies near the caster instead of globally. radius = the power's own `radius` or
    -- engage_radius. (_burnSpread / _amplifiedBurst already distance-filter inline, so they're fine.)
    local enemiesAlive = function()
        return self:_enemiesInRange(player, tonumber(kind.radius))
    end
    -- TRUE SINGLE-TARGET (2026-07-02 audit, Jason: "single target is supposed to be single
    -- target"). A target="single" power used to hit the WHOLE combat set — the label only drove
    -- the ring icon/tooltip — and with no radius of its own it defaulted to the WIDEST reach in
    -- the game (engage_radius 60 vs Quicksand's 34), so the cheap "focused" powers were secretly
    -- the biggest AoEs (Strike strictly beat Eruption). Now the family loops see exactly ONE
    -- enemy: the one the squad is actually fighting (assist target / most-attacked — the same
    -- picker the single-DoT uses), else the nearest in range so an opener still works.
    local powerDef = self._powersConfig.powers and self._powersConfig.powers[powerId]
    if powerDef and powerDef.target == "single" then
        local one = self:_engagedEnemy(player)
        if not one then
            local all = enemiesAlive()
            local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local bestD2
                for _, e in ipairs(all) do
                    local mt = e:GetAttribute("MoveTarget")
                    local pos
                    if typeof(mt) == "Vector3" then
                        pos = mt -- live client-interpolated position, not the stale spawn pivot
                    else
                        local pp = e.PrimaryPart or e:FindFirstChildWhichIsA("BasePart")
                        pos = pp and pp.Position
                    end
                    if pos then
                        local dx, dz = pos.X - hrp.Position.X, pos.Z - hrp.Position.Z
                        local d2 = dx * dx + dz * dz
                        if not bestD2 or d2 < bestD2 then
                            one, bestD2 = e, d2
                        end
                    end
                end
            else
                one = all[1]
            end
        end
        enemiesAlive = function()
            return one and { one } or {}
        end
    end
    -- INSTRUMENTATION ([PowerCast]): one line per cast — proves the cast REACHED _applyEffect, names
    -- the family, and reports how many enemies the combat-set gate (AggroOwner / in-range) resolved.
    -- The usual "nothing happened" culprit is targets=0 (gate found nobody). TEMPORARY debug — remove
    -- once player-power targeting is settled.
    print(
        string.format(
            "[PowerCast] %s cast %s family=%s targets=%d dur=%.1f mag=%.2f",
            player.Name,
            tostring(powerId),
            tostring(family),
            #enemiesAlive(),
            dur,
            mag
        )
    )
    -- A `dot` block layers damage-over-time on top of whatever the family does (a vulnerable MARK
    -- that also burns, an ice HOLD that chips). Generic — any power opts in via config. aoe=true
    -- hits every alive enemy; aoe=false the single primary target. Fires alongside the family below.
    -- EXCEPTION: burn_spread (Wildfire) owns its own burn INSIDE _burnSpread, gated to the enemies
    -- actually on fire (contagion) rather than every enemy — so the damage follows the visible spread.
    if kind.dot and family ~= "burn_spread" then
        self:_damageOverTime(
            player,
            kind.dot.per_tick,
            kind.dot.interval or 1,
            kind.dot.duration or dur,
            kind.dot.aoe,
            powerId,
            kind._critBase -- P5: power's own crit chance (+ live CritBuff/CritAura per tick)
        )
    end
    if family == "heal" then
        if kind.field then
            -- Healing Field: a STATIONARY heal zone dropped at the player's feet. Your player's
            -- position is server-reliable (only PETS are client-driven/stale), so we anchor the
            -- zone there and heal pets standing within `field_radius` of the cast spot each tick.
            -- You position by WALKING the (invulnerable spirit) onto your squad — no aim reticle.
            self:_healZone(player, kind, mag, dur, powerId)
        else
            -- Respect the power's targeting RING (like absorb): single_pet -> the selected squad
            -- card only (the pet you AIMED at, not the most-hurt); otherwise squad-wide
            -- (team_aoe — pets cluster, so squad-wide reads as the around-you AoE).
            -- _targetPets already drops downed pets.
            for _, pet in ipairs(self:_targetPets(player, powerId)) do
                local taken = pet:GetAttribute("CombatDamageTaken") or 0
                if taken > 0 then
                    -- res-sickness clamp: can't heal a fresh revive past its res floor
                    local newTaken =
                        ResSickness.clampTaken(pet:GetAttributes(), math.max(0, taken - mag), now)
                    local healed = math.max(0, taken - newTaken)
                    pet:SetAttribute("CombatDamageTaken", newTaken)
                    -- Instant-effect tell: blinking heal badge on the card (3s, mirrors
                    -- combat.engagement.instant_fx_seconds) — same feedback as auto-heal.
                    pet:SetAttribute("HealFxUntil", now + 3)
                    if healed >= 1 then
                        Signals.Combat_Heal:FireAllClients({
                            target = pet,
                            amount = math.floor(healed + 0.5),
                        })
                    end
                end
            end
            -- Oasis: a heal-over-time tail follows the big upfront pulse (`hot`/tick for `hot_seconds`).
            if tonumber(kind.hot) then
                self:_healOverTime(player, kind.hot, kind.hot_tick or 2, kind.hot_seconds or dur)
            end
        end
    elseif family == "buff" then
        player:SetAttribute("PetDamageBuff", mag)
        player:SetAttribute("PetDamageBuffUntil", now + dur)
        player:SetAttribute("PetDamageBuffPowerId", powerId)
    elseif family == "absorb" then
        -- shield: add an absorption pool the pet soaks damage with before endurance. With a
        -- duration it ALSO times out (no permanent armor): stamp CombatShieldUntil + schedule a
        -- clear; a re-cast pushes the stamp later so an older timer won't drop a fresh shield.
        -- Squad-wide unless the power is single_pet (-> the selected pet only).
        local evadeHeal = tonumber(kind.evade_heal)
        for _, pet in ipairs(self:_targetPets(player, powerId)) do
            -- Tag the power BEFORE CombatShield. The client resolves the LOOK (bubble vs dodge) from
            -- CombatShieldPowerId's combat_vfx config and reacts to the CombatShield change — so the
            -- id must already be present, else the look resolves wrong for a frame. (The on-hit
            -- "Dodge!" is also config-driven from combat_vfx.on_hit, read server-side in EnemyService.)
            pet:SetAttribute("CombatShieldPowerId", powerId)
            pet:SetAttribute("CombatShield", (pet:GetAttribute("CombatShield") or 0) + mag)
            self:_stampPowerBadge(pet, powerId, now + dur)
            if dur and dur > 0 then
                pet:SetAttribute("CombatShieldUntil", now + dur)
                -- Mirage Veil: while the veil is up, each blow it turns aside also heals the pet a
                -- little (heal-on-evade). EnemyService reads MirageHeal* in its shield-absorb path.
                if evadeHeal then
                    pet:SetAttribute("MirageHealAmt", evadeHeal)
                    pet:SetAttribute("MirageHealUntil", now + dur)
                end
                task.delay(dur, function()
                    if pet.Parent and (pet:GetAttribute("CombatShieldUntil") or 0) <= os.time() then
                        pet:SetAttribute("CombatShield", 0)
                        pet:SetAttribute("CombatShieldUntil", 0)
                    end
                end)
            end
        end
    elseif family == "evade" then
        -- TRUE EVASION (Mirage Step): grant the target pet a CHANCE to negate each incoming hit — NO
        -- absorb pool. EnemyService rolls EvadeChance per hit while EvadeUntil is live. Reuse the
        -- CombatShield* BADGE channel (CombatShieldPowerId + CombatShieldUntil) so the squad card shows
        -- the dodge badge + countdown, but DON'T set CombatShield → the absorb path soaks nothing (no
        -- double-dip). Single-ally unless the power targets the squad. mag = the avoidance fraction.
        for _, pet in ipairs(self:_targetPets(player, powerId)) do
            pet:SetAttribute("CombatShieldPowerId", powerId) -- dodge badge/look resolves from this
            pet:SetAttribute("EvadeChance", mag)
            pet:SetAttribute("EvadeUntil", now + dur)
            pet:SetAttribute("CombatShieldUntil", now + dur) -- card badge timing only (no pool)
            self:_stampPowerBadge(pet, powerId, now + dur)
            task.delay(dur, function()
                if pet.Parent and (pet:GetAttribute("EvadeUntil") or 0) <= os.time() then
                    pet:SetAttribute("EvadeChance", 0)
                    pet:SetAttribute("EvadeUntil", 0)
                end
            end)
        end
    elseif family == "defense_buff" then
        -- armor: temporary +Defense (damage reduction on the armor curve). Squad-wide (Bulwark)
        -- unless the power is single_pet (-> the selected pet only).
        for _, pet in ipairs(self:_targetPets(player, powerId)) do
            pet:SetAttribute("DefenseBuff", mag)
            pet:SetAttribute("DefenseBuffUntil", now + dur)
            pet:SetAttribute("DefenseBuffPowerId", powerId)
            self:_stampPowerBadge(pet, powerId, now + dur)
        end
    elseif family == "coin_yield" then
        self:_setAxisBuff(player, "CoinYieldPower", mag, now, dur, powerId)
    elseif family == "drop_rate" then
        -- Windfall: +mag drop-table chance (loot, not coins). Consumed by DropService
        -- (enhancement drops) + BreakableSpawner (premium gem bonus) via DropRateBuff.
        self:_setAxisBuff(player, "DropRateBuff", mag, now, dur, powerId)
    elseif family == "crit" then
        self:_setAxisBuff(player, "CritBuff", mag, now, dur, powerId) -- +crit chance on pet hits (Critical Strike)
    elseif family == "luck" then
        self:_setAxisBuff(player, "LuckBuff", mag, now, dur, powerId)
    elseif family == "move_speed" then
        if kind.toggle then -- Super Speed: permanent toggle
            self:_toggleAxisBuff(player, "MoveSpeedBuff", mag, powerId)
        else
            self:_setAxisBuff(player, "MoveSpeedBuff", mag, now, dur, powerId)
        end
    elseif family == "recharge" then
        if kind.toggle then -- Hasten: permanent toggle
            self:_toggleAxisBuff(player, "RechargeBuff", mag, powerId)
        else
            self:_setAxisBuff(player, "RechargeBuff", mag, now, dur, powerId)
        end
    elseif family == "xp" then
        self:_setAxisBuff(player, "XpBuff", mag, now, dur, powerId)
    elseif family == "revive" then
        -- Revive: instantly bring a DOWNED pet back, ignoring its recharge cooldown (the tactical
        -- "summon before the clock" power, EnemyService:_revivePet's clears). Prefers the selected
        -- squad pet (CombatBuffTarget), else the first downed pet.
        local pets = Workspace:FindFirstChild("PlayerPets")
            and Workspace.PlayerPets:FindFirstChild(player.Name)
        if pets then
            local sel = player:GetAttribute("CombatBuffTarget")
            local target, firstDowned
            for _, pet in ipairs(pets:GetChildren()) do
                if pet:IsA("Model") and pet:GetAttribute("CombatDowned") then
                    firstDowned = firstDowned or pet
                    local pn = pet:FindFirstChild("PositionNumber")
                    if sel and sel ~= 0 and pn and pn.Value == sel then
                        target = pet
                    end
                end
            end
            target = target or firstDowned
            if target then
                -- ResurrectPet releases the #179 lockout ledger BEFORE reviving — PetRevive alone
                -- gets held right back down by the lockout enforcement ("up for a split second").
                local enemyService = self._moduleLoader and self._moduleLoader:Get("EnemyService")
                if enemyService and enemyService.ResurrectPet then
                    enemyService:ResurrectPet(target, player)
                else
                    PetRevive.revive(target, player)
                end
                fireGameEvent(player, "pet_revive", { pet = target.Name })
            end
        end
    elseif family == "recall" then
        -- Recall: teleport to the player's saved spot (RecallPoint, stamped on each hatch), else
        -- the world spawn — the AFK-farmer "get back to where I was" QoL.
        self:_teleportPlayer(player, player:GetAttribute("RecallPoint"))
    elseif family == "world_travel" then
        self:_teleportPlayer(player, nil) -- to the world hub (spawn)
    elseif family == "magnet" then
        -- #167: widen the drop auto-collect radius by `magnitude` studs for `duration`s. DropService's
        -- collect loop reads MagnetBuff while MagnetBuffUntil is live (a flat studs bonus, not an axis).
        player:SetAttribute("MagnetBuff", mag)
        player:SetAttribute("MagnetBuffUntil", now + dur)
        player:SetAttribute("MagnetBuffPowerId", powerId)
    elseif family == "root" then
        for _, enemy in ipairs(enemiesAlive()) do
            if self:_accuracyHit(player, enemy, kind) then -- P4: a hold can be resisted (per target)
                enemy:SetAttribute("RootedUntil", now + dur)
                -- stamp WHICH power debuffed it, so the client can show the matching badge above it
                -- (alongside the aura) instead of leaving you to decode the particle colour.
                enemy:SetAttribute("DebuffPowerId", powerId)
                enemy:SetAttribute("DebuffUntil", now + dur)
            end
        end
    elseif family == "blind" then
        -- BLIND (Sandstorm): cut the enemies' to-hit so they WHIFF on the squad — pet protection by
        -- denying the attacker, the mirror of pet evasion. `mag` is the accuracy REDUCTION fraction;
        -- stamped on BlindUntil/BlindMagnitude and read in EnemyService:_hitPet's to-hit roll. Rolls
        -- to land per target (like the other debuffs) so accuracy enhancements help it stick.
        for _, enemy in ipairs(enemiesAlive()) do
            if self:_accuracyHit(player, enemy, kind) then
                enemy:SetAttribute("BlindUntil", now + dur)
                enemy:SetAttribute("BlindMagnitude", mag)
                enemy:SetAttribute("DebuffPowerId", powerId)
                enemy:SetAttribute("DebuffUntil", now + dur)
            end
        end
        -- Sandstorm cast tell: an INDIRECT targeted AoE — a momentary YELLOW rune over a tiled-SAND
        -- disc, centered on the enemy the squad's pet is fighting (its target), not the player. Flashes
        -- in bright and fades over ~1.3s, like Resonance. Falls back to the squad centre if nothing's
        -- engaged so the cast still reads while testing.
        local foe = self:_engagedEnemy(player)
        local fp = foe and (foe.PrimaryPart or foe:FindFirstChildWhichIsA("BasePart"))
        local center = (fp and fp.Position) or self:_squadCenter(player)
        if center then
            self:_spawnGroundRune(
                center,
                tonumber(kind.radius) or 18,
                Color3.fromRGB(255, 215, 55),
                {
                    name = "SandstormRune",
                    fade_in = 0.15,
                    hold = 0.25,
                    fade_out = 1.6, -- ~2s total (Jason): bright flash, lingers a bit longer than Resonance
                    bright = 0,
                    spin = true,
                    spin_deg = 90,
                    fill_texture = "78509147193799", -- sandfloor_tile (alpha), tiled under the rune
                    fill_color = Color3.fromRGB(235, 205, 120),
                    fill_bright = 0.4,
                    -- fill_scale defaults to the rune's RING_FRAC, so the sand matches the gold ring (= radius)
                }
            )
        end
    elseif family == "taunt" then
        -- TAUNT is a PET-CENTERED AoE (Jason): each HOLDER pet (the selected pet, else the deployed
        -- tanks) casts its OWN rune at its feet and taunts whatever enemies are within `radius` of
        -- THAT pet — with a per-enemy accuracy roll, so a taunt can miss. It needs no engaged enemy:
        -- an opener with nothing in range simply grabs nobody. Each grabbed enemy's target is FORCED
        -- to that pet for the duration (a hard lock over the threat table) via EnemyService:ApplyTaunt.
        -- The no-holder case is refused in Cast before focus is charged; guard here too.
        local holders = self:_tauntHolders(player)
        local enemyService = self._moduleLoader and self._moduleLoader:Get("EnemyService")
        local pfs = self._moduleLoader and self._moduleLoader:Get("PetFollowService")
        local radius = tonumber(kind.radius) or 18
        local r2 = radius * radius
        local candidates = enemiesAlive() -- caster-bounded (this player's fight / near the caster)
        local grabbed = 0
        -- VISUAL PASS: each HOLDER pet plants its OWN green earth rune at its feet + wears the taunt
        -- badge (Jason: focus the ring on the casting pets, not the player; show it on the pet HUD).
        -- Capture each holder's LIVE center for the grab pass below (same space we measure enemies in).
        local centers = {}
        for i, h in ipairs(holders) do
            -- pet position: pets are ANCHORED + client-interpolated, so the server pivot reads stale —
            -- use the replicated report the aggro system trusts (a CFrame), falling back to the pivot.
            local reported = pfs and pfs.GetReportedPosition and pfs:GetReportedPosition(h.pet)
            local center = (reported and reported.Position) or h.pet:GetPivot().Position
            centers[i] = center
            self:_spawnGroundRune(center, radius, Color3.fromRGB(120, 235, 130), {
                name = "TauntRune",
                fade_in = 0.12,
                hold = math.max(0.2, dur - 1.2), -- hold roughly the taunt's life so the rune reads as its duration
                fade_out = 1.1,
                bright = 0,
                spin = true,
                spin_deg = 120,
            })
            h.pet:SetAttribute("TauntingPowerId", powerId)
            h.pet:SetAttribute("TauntingUntil", now + dur)
            self:_stampPowerBadge(h.pet, powerId, now + dur) -- world-billboard SSOT too
        end
        -- GRAB PASS: per-pet radius check — but against the enemy's LIVE position, NOT its model pivot.
        -- Enemies are ANCHORED and client-interpolated toward their MoveTarget attribute (a Vector3);
        -- the PrimaryPart sits at the SPAWN CFrame server-side, so a PrimaryPart distance check reads
        -- garbage. THAT was the "grabbed=0 on every cast" bug: the pet center was live-reported but the
        -- enemy was measured at its stale spawn pivot — two different coordinate truths. MoveTarget is
        -- the SAME live source the mining-distance gate + combat math (entry.pos) trust. Each enemy is
        -- pulled by the NEAREST holder whose rune (radius) actually covers it; radius is now a real knob.
        if enemyService and enemyService.ApplyTaunt and #holders > 0 then
            for _, enemy in ipairs(candidates) do
                local mt = enemy:GetAttribute("MoveTarget")
                local epos
                if typeof(mt) == "Vector3" then
                    epos = mt
                else
                    local pp = enemy.PrimaryPart or enemy:FindFirstChildWhichIsA("BasePart")
                    epos = pp and pp.Position
                end
                if epos then
                    local bestPet, bestD2
                    for i = 1, #centers do
                        local c = centers[i]
                        local dx, dz = epos.X - c.X, epos.Z - c.Z
                        local d2 = dx * dx + dz * dz
                        if d2 <= r2 and (not bestD2 or d2 < bestD2) then
                            bestPet, bestD2 = holders[i].pet, d2
                        end
                    end
                    if bestPet and self:_accuracyHit(player, enemy, kind) then -- P4: the taunt can miss
                        enemyService:ApplyTaunt(enemy, bestPet, now + dur)
                        -- BADGE: the taunt disc over the pulled enemy — the SAME channel root/vulnerable
                        -- use (EnemyHud "hex" entry resolves it via PetBadge), so "which enemies got
                        -- taunted" reads at a glance (Jason).
                        enemy:SetAttribute("DebuffPowerId", powerId)
                        enemy:SetAttribute("DebuffUntil", now + dur)
                        self:_stampPowerBadge(enemy, powerId, now + dur)
                        grabbed += 1
                    end
                end
            end
        end
        -- INSTRUMENTATION ([PowerCast]): how many enemies the taunt actually locked (across all
        -- holders). 0 with candidates>0 = all out of the per-pet radius or accuracy-missed. Balance
        -- trace (combat.combat_trace).
        if self._combatConfig and self._combatConfig.combat_trace then
            print(
                string.format(
                    "[PowerCast] taunt holders=%d candidates=%d grabbed=%d",
                    #holders,
                    #candidates,
                    grabbed
                )
            )
        end
    elseif family == "rage" then
        -- RAGE (tank self-buff, Jason): a flat `base` pet-damage bonus PLUS a "critical" bonus that
        -- GROWS as the pet's HP drops below `enrage_below` — harder the lower it gets, with NO ceiling
        -- (Jason: no hidden caps; it's bounded naturally by the pet reaching its down threshold). Applies
        -- to the SAME holder set as taunt — the selected pet, else all tanks. TIMED (not a toggle): we
        -- stamp a window + the curve knobs on each holder, and PetFollowService computes the LIVE bonus
        -- per swing (SupportAura.rageRampFraction) on its own additive pet_damage channel, so it stacks
        -- with the bear's passive rage. mag (resolved, enhancement-scaled) = the critical GROWTH RATE,
        -- NOT a max — it's slotted to grow; base + enrage_below are raw config (survive _effectiveKind).
        -- NOTE(future): a post-rage weakness debuff could follow the window (CoH-style crash); left OUT
        -- for v1 — no downside yet, per Jason.
        local holders = self:_tauntHolders(player)
        local base = tonumber(kind.base) or 0
        local below = tonumber(kind.enrage_below) or 0.5
        local pfs = self._moduleLoader and self._moduleLoader:Get("PetFollowService")
        for _, h in ipairs(holders) do
            local pet = h.pet
            pet:SetAttribute("RagePowerUntil", now + dur)
            pet:SetAttribute("RagePowerBase", base)
            pet:SetAttribute("RagePowerRate", mag) -- resolved critical GROWTH rate (enh-scaled; no cap)
            pet:SetAttribute("RagePowerBelow", below)
            pet:SetAttribute("RagePowerPowerId", powerId)
            -- BADGE: reuse the bear's RageFxUntil channel — SquadHud's "rage" entry lights the fire/rage
            -- disc for the window (same visual meaning). Plus the generic PowerBadge SSOT for billboards.
            pet:SetAttribute("RageFxUntil", now + dur)
            self:_stampPowerBadge(pet, powerId, now + dur)
            -- a small RED rune at the raging pet's feet — the visual tell, mirroring taunt's green rune.
            local reported = pfs and pfs.GetReportedPosition and pfs:GetReportedPosition(pet)
            local center = (reported and reported.Position) or pet:GetPivot().Position
            self:_spawnGroundRune(center, 6, Color3.fromRGB(235, 80, 60), {
                name = "RageRune",
                fade_in = 0.1,
                hold = math.max(0.2, dur - 1.0),
                fade_out = 0.8,
                bright = 0,
                spin = true,
                spin_deg = 90,
            })
        end
        -- INSTRUMENTATION ([PowerCast]): who's raging + the curve. Balance trace (combat.combat_trace).
        if self._combatConfig and self._combatConfig.combat_trace then
            print(
                string.format(
                    "[PowerCast] rage holders=%d base=%.2f rate=%.2f below=%.2f dur=%.1f",
                    #holders,
                    base,
                    mag,
                    below,
                    dur
                )
            )
        end
    elseif family == "fear" then
        -- FEAR (Phase 2 aggro, Jason: "no dead powers"): NEGATIVE aggro. Each landed mark forces
        -- the enemy's threat toward the caster's whole squad to a deterministic negative
        -- (EnemyService:ApplyFear → configs/aggro.lua fear.magnitude), so the focus rule's "attack
        -- top-of-table" inverts into a FLEE from the most-feared pet for the duration, then it
        -- recovers (negatives snap to 0 on lapse). Per-target accuracy — terror can miss.
        local enemyService = self._moduleLoader and self._moduleLoader:Get("EnemyService")
        local applied, missed = 0, 0
        if enemyService and enemyService.ApplyFear then
            for _, enemy in ipairs(enemiesAlive()) do
                if self:_accuracyHit(player, enemy, kind) then
                    if enemyService:ApplyFear(enemy, player, now + dur) then
                        -- badge: same Debuff channel root/vulnerable use (EnemyHud resolves the
                        -- fear disc via PetBadge.forPower) + the generic PowerBadge SSOT.
                        enemy:SetAttribute("DebuffPowerId", powerId)
                        enemy:SetAttribute("DebuffUntil", now + dur)
                        self:_stampPowerBadge(enemy, powerId, now + dur)
                        applied += 1
                    end
                else
                    missed += 1
                end
            end
        end
        if self._combatConfig and self._combatConfig.combat_trace then
            print(
                string.format(
                    "[PowerCast]   %s fear → %d fleeing, %d missed (dur=%.1f)",
                    tostring(powerId),
                    applied,
                    missed,
                    dur
                )
            )
        end
    elseif family == "vulnerable" then
        -- Shatter: x`frozen_bonus` again on FROZEN (rooted) targets — the freeze->shatter payoff.
        local frozenBonus = tonumber(kind.frozen_bonus)
        local applied, missed = 0, 0
        local lastStack -- the last applied enemy's TOTAL (trace: proves marks ADD, not clobber)
        for _, enemy in ipairs(enemiesAlive()) do
            if self:_accuracyHit(player, enemy, kind) then -- P4: the mark can miss (per target)
                local m = mag
                if frozenBonus and (enemy:GetAttribute("RootedUntil") or 0) > now then
                    m = mag * frozenBonus
                end
                -- ADDITIVE marks (Jason: the glass cannon's damage IS its marks — they must ADD).
                -- Each power writes its OWN VulnMark channel; the damage reader totals every live
                -- one. Re-casting the same power refreshes its channel (never self-stacks).
                VulnMark.apply(enemy, powerId, m, now + dur)
                enemy:SetAttribute("DebuffPowerId", powerId)
                enemy:SetAttribute("DebuffUntil", now + dur)
                lastStack = VulnMark.multiplier(enemy:GetAttributes(), now)
                applied += 1
            else
                missed += 1
            end
        end
        -- INSTRUMENTATION ([PowerCast]): vulnerable outcome — applied vs accuracy-missed. targets=0 on
        -- the cast line above + 0/0 here = gate found nobody; >0 missed = accuracy rolls. TEMP debug.
        -- Balance trace (combat.combat_trace): `stack=` is the last applied enemy's TOTAL multiplier
        -- across ALL its live marks — watch it climb as the kit layers (eruption then strike = x2.5+,
        -- not the old clobbered x1.5).
        if self._combatConfig and self._combatConfig.combat_trace then
            print(
                string.format(
                    "[PowerCast]   %s vulnerable → %d applied, %d missed (mag=%.2f dur=%.1f stack=x%.2f)",
                    tostring(powerId),
                    applied,
                    missed,
                    mag,
                    dur,
                    lastStack or 1
                )
            )
        end
        -- Inferno Brand: ramp the mark upward over its lifetime (1.9 -> ramp_to).
        if tonumber(kind.ramp_to) then
            self:_rampVulnerable(player, mag, kind.ramp_to, dur, powerId)
        end
        -- #174: a target-strength debuff also applies to FARMING. Mark the crystals the squad is
        -- mining so pets shred them x`mag` faster (PetFollowService:_mine totals the VulnMark stack
        -- on any breakable). Only families flagged farm_targeted reach crystals (root/disarm don't).
        local farmTargeted = self._powersConfig.farm_targeted_families
            and self._powersConfig.farm_targeted_families[family]
        if farmTargeted then
            for _, crystal in ipairs(self:_engagedBreakables(player)) do
                VulnMark.apply(crystal, powerId, mag, now + dur) -- additive with any other live marks
                crystal:SetAttribute("DebuffPowerId", powerId)
                crystal:SetAttribute("DebuffUntil", now + dur)
            end
        end
    elseif family == "root_guard" then
        -- Seismic Event (geomancer signature): KNOCKBACK + short root + harden the squad. Jason's
        -- knockback spec (2026-07-02): "push back the targets away from the attacking pet and then
        -- root them for a very small amount of time" — the shove + the pin reads as a knockdown
        -- (fall-over animations are future polish). `knockback` = shove studs (EnemyService moves
        -- the real server position, grounded + leashed), `duration` = the root, `magnitude` = the
        -- squad +Defense. Rolls to-hit like every other control (was the one auto-lander).
        local enemyService = self._moduleLoader and self._moduleLoader:Get("EnemyService")
        local knocked, missed = 0, 0
        for _, enemy in ipairs(enemiesAlive()) do
            if self:_accuracyHit(player, enemy, kind) then
                if enemyService and enemyService.ApplyKnockback then
                    enemyService:ApplyKnockback(enemy, player, tonumber(kind.knockback))
                end
                enemy:SetAttribute("RootedUntil", now + dur)
                enemy:SetAttribute("DebuffPowerId", powerId)
                enemy:SetAttribute("DebuffUntil", now + dur)
                knocked += 1
            else
                missed += 1
            end
        end
        -- balance trace parity with the other control families (combat.combat_trace)
        if self._combatConfig and self._combatConfig.combat_trace then
            print(
                string.format(
                    "[PowerCast]   %s root_guard → %d knocked, %d missed (dur=%.1f)",
                    tostring(powerId),
                    knocked,
                    missed,
                    dur
                )
            )
        end
        for _, pet in ipairs(self:_targetPets(player, powerId)) do
            pet:SetAttribute("DefenseBuff", mag)
            pet:SetAttribute("DefenseBuffUntil", now + dur)
            pet:SetAttribute("DefenseBuffPowerId", powerId)
            self:_stampPowerBadge(pet, powerId, now + dur)
        end
    elseif family == "fortify" then
        -- Living Mountain (geomancer signature): big squad +Defense + a heal-over-time. `magnitude`=
        -- +Defense, `heal`=hp per pulse, `hot_tick`=seconds between pulses across the duration.
        local healAmt = tonumber(kind.heal) or 0
        for _, pet in ipairs(self:_targetPets(player, powerId)) do
            pet:SetAttribute("DefenseBuff", mag)
            pet:SetAttribute("DefenseBuffUntil", now + dur)
            pet:SetAttribute("DefenseBuffPowerId", powerId)
            self:_healPet(player, pet, healAmt, now) -- upfront pulse
        end
        if tonumber(kind.hot_tick) then
            self:_healOverTime(player, healAmt, kind.hot_tick, dur)
        end
    elseif family == "heal_blind" then
        -- Simoom (sandwalker signature): heal the squad AND blind + soften enemies caught in the
        -- storm (heal identity + a touch of control). `magnitude`=heal, `vuln`=enemy vulnerability
        -- mult, `blind`=to-hit reduction. The blind is REAL now (2026-07-02 audit: the family said
        -- "blind" but only the vuln was applied) — same Blind* channel Sandstorm uses, read in
        -- EnemyService:_hitPet's to-hit roll.
        for _, pet in ipairs(self:_targetPets(player, powerId)) do
            self:_healPet(player, pet, mag, now)
        end
        local vuln = tonumber(kind.vuln) or 1
        local blind = tonumber(kind.blind)
        for _, enemy in ipairs(enemiesAlive()) do
            -- the debuff half rolls to-hit like every other control (the heal above always lands)
            if self:_accuracyHit(player, enemy, kind) then
                VulnMark.apply(enemy, powerId, vuln, now + dur) -- additive with any other live marks
                if blind then
                    enemy:SetAttribute("BlindUntil", now + dur)
                    enemy:SetAttribute("BlindMagnitude", blind)
                end
                enemy:SetAttribute("DebuffPowerId", powerId)
                enemy:SetAttribute("DebuffUntil", now + dur)
            end
        end
    elseif family == "summon" then
        -- Gaia's Colossus / Genie of the Dunes (capstones): call a temporary guardian pet via
        -- SummonService (live — the guardian fights beside the squad for `duration`s).
        self:_summonGuardian(player, kind, now, powerId)
    elseif family == "amplified_burst" then
        self:_amplifiedBurst(player, kind, now)
    elseif family == "burn_spread" then
        self:_burnSpread(player, kind, now, powerId)
    elseif family == "team_cleave" then
        -- Firestorm: for `duration`s every pet swing also splashes x`magnitude` to other enemies
        -- within `cleave_radius` (applied in PetFollowService:_mine). Fire a nova so it reads as on.
        player:SetAttribute("TeamCleaveUntil", now + dur)
        player:SetAttribute("TeamCleaveFrac", mag)
        player:SetAttribute("TeamCleaveRadius", tonumber(kind.cleave_radius) or 8)
        local center = self:_squadCenter(player)
        if center then
            Signals.Power_AreaFx:FireAllClients({
                element = "lava",
                variant = "self",
                center = center,
                pit = false,
                hits = {},
            })
        end
    elseif family == "farm_boost" then
        -- Resonance (innate, docs/INNATE_RESONANCE_POWER.md): an AoE boost-pulse around the player.
        -- Bump the Boost attribute on every alive breakable within `radius` toward its MaxBoost,
        -- reusing the configs/breakables.lua M.boost SSOT — pet-damage amplification + Boost decay
        -- already live there, and BreakableSpawner shows the boost bar while Boost > 0. `mag` = Boost
        -- added per cast (full = slams to max); `radius` = the AoE (range-enhanceable via radiusBase).
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local center = (hrp and hrp.Position) or self:_squadCenter(player)
        local radius = tonumber(kind.radius) or 25
        if center then
            for _, crystal in ipairs(breakablesAlive()) do
                local ok, pos = pcall(function()
                    return crystal:GetPivot().Position
                end)
                if ok and (pos - center).Magnitude <= radius then
                    local maxBoost = tonumber(crystal:GetAttribute("MaxBoost")) or 100
                    local cur = tonumber(crystal:GetAttribute("Boost")) or 0
                    crystal:SetAttribute("Boost", math.min(maxBoost, cur + mag))
                end
            end
            -- Cast tell: a momentary YELLOW rune (matches the crystals' yellow boost bars) that flashes
            -- in BRIGHT and fades away over ~1.3s — long enough to read, gone before the next cast.
            self:_spawnGroundRune(center, radius, Color3.fromRGB(255, 215, 55), {
                name = "ResonanceRune",
                fade_in = 0.12,
                hold = 0.1,
                fade_out = 1.15,
                bright = 0, -- start fully bright
                spin = true,
                spin_deg = 90,
            })
        end
    else
        -- DEAD-POWER GUARD (2026-07-02 audit): an unknown family used to no-op SILENTLY — the cast
        -- played its FX and spent focus while doing nothing. That's exactly how fear and Armor Field
        -- shipped dead. A config'd family with no branch is a wiring bug; say so loudly.
        warn(
            ("[PowerService] %s cast %s: NO effect branch for family '%s' — the power did nothing"):format(
                player.Name,
                tostring(powerId),
                tostring(family)
            )
        )
    end
end

-- Squad centroid (living pets), else the player's HRP. nil if neither is available.
function PowerService:_squadCenter(player)
    local pets = Workspace:FindFirstChild("PlayerPets")
        and Workspace.PlayerPets:FindFirstChild(player.Name)
    local sx, sy, sz, n = 0, 0, 0, 0
    if pets then
        for _, pet in ipairs(pets:GetChildren()) do
            if pet:IsA("Model") and not pet:GetAttribute("CombatDowned") and pet.PrimaryPart then
                local p = pet.PrimaryPart.Position
                sx, sy, sz, n = sx + p.X, sy + p.Y, sz + p.Z, n + 1
            end
        end
    end
    if n > 0 then
        return Vector3.new(sx / n, sy / n, sz / n)
    end
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.Position or nil
end

-- Wildfire: mark the squad's engaged enemy with a burn (vulnerability), which then CONTAGIONS to
-- nearby enemies every `spread_interval`s for `duration`s. The debuff aura is shown by the client's
-- CombatAuraController (it reacts to VulnerableUntil), so this only needs to set the attributes.
function PowerService:_burnSpread(player, kind, now, powerId)
    local mag = tonumber(kind.magnitude) or 1.5
    local dur = tonumber(kind.duration) or 8
    local spreadR = tonumber(kind.spread_radius) or 14
    local perTick = (kind.dot and tonumber(kind.dot.per_tick)) or 0
    local critBase = kind._critBase
    local critMult = (
        self._combatConfig
        and self._combatConfig.rolls
        and self._combatConfig.rolls.pet_attack
        and self._combatConfig.rolls.pet_attack.crit_mult
    ) or 2.0
    -- tick cadence: the burn damage interval (falls back to spread_interval). Spread happens on the
    -- same beat — an enemy on fire ignites its unlit neighbours each tick.
    local interval = math.max(
        0.5,
        (kind.dot and tonumber(kind.dot.interval)) or tonumber(kind.spread_interval) or 1
    )
    local element = "lava" -- Wildfire = pyromancer; the only burn_spread power today

    local function partOfEnemy(e)
        return e.PrimaryPart or e:FindFirstChildWhichIsA("BasePart")
    end
    local function isBurning(e, t)
        return (e:GetAttribute("BurnUntil") or 0) > t
    end
    -- Catch an enemy on fire: vulnerability mark (pets hit harder) + the burn flag (BurnUntil) that
    -- gates damage AND drives the client fire visual + the debuff badge. Lasts `dur` from ignition.
    local function ignite(enemy, untilT)
        VulnMark.apply(enemy, powerId, mag, untilT) -- one channel per power: hops refresh, never self-stack
        enemy:SetAttribute("BurnUntil", untilT)
        enemy:SetAttribute("BurnElement", element)
        enemy:SetAttribute("DebuffPowerId", powerId)
        enemy:SetAttribute("DebuffUntil", untilT)
    end

    -- SEED on the enemy the squad is actually fighting (single-target start), not the enemy nearest
    -- the squad centroid — Wildfire is a single-target contagion, not an AoE. Falls back to the
    -- centroid-nearest only if no engaged target can be resolved.
    local seed = self:_engagedEnemy(player)
    if not seed then
        local center = self:_squadCenter(player)
        local bestD
        for _, e in ipairs(enemiesAlive()) do
            local pp = partOfEnemy(e)
            if pp and center then
                local d = (pp.Position - center).Magnitude
                if not bestD or d < bestD then
                    bestD, seed = d, e
                end
            end
        end
    end
    if not seed then
        return
    end
    ignite(seed, now + dur)

    -- One loop drives BOTH damage and contagion. Each tick: burn every enemy currently on fire, then
    -- spread to unlit neighbours within spreadR. Spreading only happens during the first `dur` window;
    -- damage keeps going until each enemy's own burn expires (a late-caught enemy still burns its full
    -- time). No re-ignition of a still-burning enemy ⇒ the wave passes through the pack and dies out.
    local total = dur * 2 -- covers an enemy lit right at the end of the spread window
    local ticks = math.ceil(total / interval)
    for i = 1, ticks do
        task.delay(i * interval, function()
            if not player.Parent then
                return
            end
            local t = os.time()
            local live = enemiesAlive()
            local burning = {}
            for _, e in ipairs(live) do
                if isBurning(e, t) then
                    burning[#burning + 1] = e
                end
            end
            -- damage everything on fire
            if perTick > 0 then
                local critChance = self:_dotCritChance(player, critBase, t)
                for _, e in ipairs(burning) do
                    self:_dotHit(
                        player,
                        e,
                        perTick,
                        critChance,
                        critMult,
                        t,
                        powerId,
                        math.ceil(interval) + 1
                    )
                end
            end
            -- spread the fire (only while still within the ignition window)
            if (i * interval) <= dur then
                for _, m in ipairs(burning) do
                    local mp = partOfEnemy(m)
                    if mp then
                        for _, u in ipairs(live) do
                            if not isBurning(u, t) then
                                local up = partOfEnemy(u)
                                if up and (up.Position - mp.Position).Magnitude <= spreadR then
                                    ignite(u, t + dur)
                                end
                            end
                        end
                    end
                end
            end
        end)
    end
end

-- Cataclysm-style "damage" power (firewall-safe, §16.5/§17.8): a burst that lands on the squad's
-- engagement and whose size is an AMPLIFICATION of the squad's own attack power, credited to the
-- pets (HP + Contrib, exactly like a pet swing). Then a molten pool lingers as vulnerability.
function PowerService:_amplifiedBurst(player, kind, now)
    local pets = Workspace:FindFirstChild("PlayerPets")
        and Workspace.PlayerPets:FindFirstChild(player.Name)

    -- Squad attack total + centroid (living, non-downed pets).
    local squadAttack, sx, sz, n = 0, 0, 0, 0
    if pets then
        for _, pet in ipairs(pets:GetChildren()) do
            if pet:IsA("Model") and not pet:GetAttribute("CombatDowned") and pet.PrimaryPart then
                local p = pet.PrimaryPart.Position
                sx, sz, n = sx + p.X, sz + p.Z, n + 1
                local pw = pet:FindFirstChild("Power")
                squadAttack = squadAttack + (tonumber(pw and pw.Value) or 0)
            end
        end
    end
    local squadPos
    if n > 0 then
        squadPos = Vector3.new(sx / n, 0, sz / n)
    else
        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        squadPos = (hrp and Vector3.new(hrp.Position.X, 0, hrp.Position.Z)) or Vector3.new(0, 0, 0)
    end

    -- Gather alive enemies with their flat distance to the squad.
    local engaged = {}
    for _, e in ipairs(enemiesAlive()) do
        local pp = e.PrimaryPart or e:FindFirstChildWhichIsA("BasePart")
        if pp then
            local d = (Vector3.new(pp.Position.X, 0, pp.Position.Z) - squadPos).Magnitude
            engaged[#engaged + 1] = { model = e, pos = pp.Position, d = d }
        end
    end

    -- Engagement centre: centroid of enemies near the squad, else the nearest enemy, else the squad.
    local engageR = tonumber(kind.engage_radius) or 60
    local near = {}
    for _, it in ipairs(engaged) do
        if it.d <= engageR then
            near[#near + 1] = it
        end
    end
    local center
    if #near > 0 then
        local cx, cy, cz = 0, 0, 0
        for _, it in ipairs(near) do
            cx, cy, cz = cx + it.pos.X, cy + it.pos.Y, cz + it.pos.Z
        end
        center = Vector3.new(cx / #near, cy / #near, cz / #near)
    elseif #engaged > 0 then
        table.sort(engaged, function(a, b)
            return a.d < b.d
        end)
        center = engaged[1].pos
    else
        center = Vector3.new(squadPos.X, 3, squadPos.Z) -- no enemies: visual only
    end

    -- Apply the pet-scaled burst to enemies in radius (HP + Contrib), then drop the molten pool.
    local radius = tonumber(kind.radius) or 14
    local hits = {}
    for _, it in ipairs(engaged) do
        local dist = (it.pos - center).Magnitude
        if dist <= radius then
            local dmg =
                AmplifiedBurst.atDistance(squadAttack, kind.magnitude, dist, radius, kind.falloff)
            if dmg > 0 then
                local hp = it.model:GetAttribute("HP") or 0
                local applied = PetCombat.applyDamage(hp, dmg)
                it.model:SetAttribute("HP", applied.hp)
                local contrib = it.model:FindFirstChild("Contrib")
                if contrib then
                    local key = tostring(player.UserId)
                    local nv = contrib:FindFirstChild(key)
                    if not nv then
                        nv = Instance.new("NumberValue")
                        nv.Name = key
                        nv.Parent = contrib
                    end
                    nv.Value += applied.contributed
                end
                -- molten pool: lingering vulnerability so pets keep shredding the survivors.
                -- Fixed "pit" channel (this fn has no powerId; cataclysm is the only amplified_burst)
                -- — additive with the caster's other marks.
                VulnMark.apply(
                    it.model,
                    "pit",
                    tonumber(kind.pit_vulnerable) or 1.5,
                    now + (tonumber(kind.pit_duration) or 4)
                )
                hits[#hits + 1] = { pos = it.pos, amount = applied.contributed }
            end
        end
    end

    -- shared world effect (Jason: team effect game) — the blast renders for everyone
    Signals.Power_AreaFx:FireAllClients({
        element = "lava",
        variant = "targeted",
        center = center,
        radius = radius,
        pit = true,
        hits = hits,
    })
end

-- Cast a power: enforce its cooldown, apply the support effect, tell the client when
-- it recharges (for the hotbar edge-clock). `powerId` matches configs/powers.lua.
-- Build the `kind` table the effect router consumes from the raw effect_kind, with the SCALABLE
-- axes (magnitude / duration / DoT per-tick + interval) replaced by the resolved EFFECTIVE values.
-- A shallow clone so the shared config table is never mutated; all exotic fields (ramp_to, radius,
-- spread_radius, guardian…) carry through untouched. With no scaling configured, effective == base,
-- so the result is identical to the raw effect_kind (behaviour-neutral until P3 supplies a curve).
function PowerService:_effectiveKind(rawKind, effective)
    local out = {}
    for k, v in pairs(rawKind) do
        out[k] = v
    end
    out.magnitude = effective.magnitude
    out.duration = effective.duration
    -- carry the enhanced radius so a `range` enhancement actually widens the area at cast (the
    -- preview already resolves this). Powers whose area knob is cleave_radius/spread_radius scale
    -- by the SAME range factor (effective.radius / radiusBase) so range widens those AoEs too.
    if effective.radius and effective.radius > 0 then
        out.radius = effective.radius
        local base = tonumber(rawKind.radius)
        local factor = (base and base > 0) and (effective.radius / base) or 1
        if factor ~= 1 then
            if rawKind.cleave_radius then
                out.cleave_radius = rawKind.cleave_radius * factor
            end
            if rawKind.spread_radius then
                out.spread_radius = rawKind.spread_radius * factor
            end
        end
    end
    if rawKind.dot then
        out.dot = {
            per_tick = effective.damage,
            interval = effective.tick,
            aoe = rawKind.dot.aoe,
        }
    end
    return out
end

-- P4 accuracy: does this hostile application LAND on `enemy`? Rolls accuracyBase × the level-diff
-- to-hit curve (the same Accuracy core pet/enemy attacks use); a boss (Level reads +rank_offset) is
-- harder to hit. On a miss, stamps a transient MissFxUntil for the client tell and returns false so
-- the caller skips this enemy. Crystals never call this (no Level → mining exemption preserved).
function PowerService:_accuracyHit(player, enemy, kind)
    local accBase = tonumber(kind._accuracyBase) or 1
    local casterLevel = tonumber(kind._casterLevel) or 1
    local enemyLevel = tonumber(enemy:GetAttribute("Level")) or casterLevel
    local accCfg = self._combatConfig and self._combatConfig.accuracy
    local chance = math.clamp(accBase * Accuracy.toHit(casterLevel, enemyLevel, accCfg), 0, 1)
    local res = CombatRoll.resolve({ hit_chance = chance }, math.random())
    if not res.hit then
        enemy:SetAttribute("MissFxUntil", os.time() + 2) -- client surfaces the "Miss" tell (P6)
        return false
    end
    return true
end

function PowerService:Cast(player, powerId, opts)
    local def = self._powersConfig.powers and self._powersConfig.powers[tostring(powerId)]
    if not def then
        return { ok = false, reason = "unknown_power" }
    end
    -- OWNERSHIP GATE: a player may only cast a power they OWN (data.Powers). This is the chokepoint
    -- that closes the exploit surface — Hotbar_Rebind never validates ownership, and the `power.cast`
    -- bus command takes a client-supplied powerId; BOTH funnel through here, so one check covers them.
    -- ADMINS bypass entirely: the admin power-bar passes opts.adminBypass, and the server-set IsAdmin
    -- attribute / Studio also bypass (test surface — if an admin is exploiting, ownership is the least
    -- of it, per Jason). Bound-but-unowned powers (the rebind exploit) are NOT in data.Powers, so they
    -- get refused here even though the slot "exists".
    local adminBypass = (opts and opts.adminBypass == true)
        or player:GetAttribute("IsAdmin") == true
        or RunService:IsStudio()
    -- INNATE powers (e.g. Resonance) are owned by EVERYONE by default — they're never written to
    -- data.Powers (so they don't consume a level-grant slot or appear in the picker), so the
    -- owned-list gate would wrongly refuse them. Skip the gate for innate; cooldown/focus still apply.
    if not adminBypass and not def.innate then
        local data = self._dataService and self._dataService:GetData(player)
        local owned = (data and type(data.Powers) == "table") and data.Powers or {}
        local has = false
        for _, id in ipairs(owned) do
            if tostring(id) == tostring(powerId) then
                has = true
                break
            end
        end
        if not has then
            return { ok = false, reason = "not_owned" }
        end
    end
    local now = os.time()
    local cds = self._cooldowns[player]
    if not cds then
        cds = {}
        self._cooldowns[player] = cds
    end
    if cds[powerId] and now < cds[powerId] then
        return { ok = false, reason = "on_cooldown", remaining = cds[powerId] - now }
    end

    local rawKind = (
        self._powersConfig.effect_kinds and self._powersConfig.effect_kinds[def.effect]
    ) or { family = "heal", magnitude = 0, duration = 0 }

    -- Route the cast through the unified record (PowerRegistry) → resolved effective stats
    -- (PowerStats). The effect router then consumes RESOLVED values, so P3 scaling / P4 accuracy
    -- slot in here with no further router changes. Today scaling is absent ⇒ effective == base ⇒
    -- `kind` is identical to the raw effect_kind.
    local kind = rawKind
    local record = PowerRegistry.record(tostring(powerId), self._powersConfig)
    -- Slotted ENHANCEMENTS on the cast power -> per-axis bonus fractions (additive within an
    -- axis; single > dual). Feeds resolveEffective + the cooldown stamp below.
    local data = self._dataService and self._dataService:GetData(player)
    -- Enhancement slots feeding the cast: the admin power-bar passes opts.slotsOverride to test a
    -- power at a fixed slotting (MIN = {} bare, MAX = a full single-origin set) WITHOUT touching the
    -- player's saved Slots; everyone else reads their real slotted enhancements.
    local castSlots = (opts and opts.slotsOverride)
        or (data and type(data.Slots) == "table" and data.Slots[tostring(powerId)])
        or {}
    local enhAxes = Enhancements.aggregate(
        self._enhConfig,
        castSlots,
        tonumber(player:GetAttribute("Level")) or 1 -- CoH scaling: +2 stronger, -3 dead
    )
    if record then
        local casterLevel = tonumber(player:GetAttribute("Level")) or 1
        local effective = PowerStats.resolveEffective(record, {
            casterLevel = casterLevel,
            scaling = self._powersConfig.scaling, -- nil today ⇒ identity; P3 fills it
            enhancements = enhAxes,
            -- radius-magnitude families fold range INTO magnitude (only Magnet today, and it's
            -- passive — harmless here, but keeps every cast path on the one rule)
            radiusMagnitude = (self._enhConfig.radius_families or {})[rawKind.family] == true,
            damageIsMagnitude = (self._enhConfig.damage_as_magnitude_families or {})[rawKind.family]
                == true,
            healIsMagnitude = (self._enhConfig.heal_as_magnitude_families or {})[rawKind.family]
                == true,
        })
        kind = self:_effectiveKind(rawKind, effective)
        -- carry the accuracy inputs so the per-enemy to-hit roll (P4) can resolve in _applyEffect.
        -- Use the RESOLVED accuracy (record.accuracyBase × the slotted `accuracy` enhancement boost,
        -- clamped) — NOT the raw base — so an accuracy enhancement actually improves the to-hit roll.
        kind._accuracyBase = effective.accuracy
        kind._casterLevel = casterLevel
        kind._critBase = record.critBase -- P5: per-power crit chance for DoT ticks
        -- STRONGER GUARDIAN: the potency (magnitude axis) boost FRACTION, so SummonService can scale a
        -- summon's gcfg-sourced strength (Colossus squad defense/damage, Djinn HoT) — those don't live
        -- in kind.magnitude, so effective.magnitude can't carry them (Colossus magnitudeBase = 0).
        kind._strengthMult = 1 + (enhAxes.magnitude or 0)
    end

    -- Target gate: an offensive power reaches the enemy THROUGH the pets, so it can't fire unless
    -- the squad is engaged with one (the pet is fighting something). Friendly powers (heal/buff/
    -- shield) target your own pets and skip the gate. Refused casts don't spend the cooldown.
    local enemyTargeted = self._powersConfig.enemy_targeted_families
        and self._powersConfig.enemy_targeted_families[kind.family]
    if enemyTargeted and not self:_hasEngagedEnemy(player) then
        -- #174: a farm-targeted debuff (vulnerable) may also fire when the squad is mining crystals,
        -- not just fighting enemies — the pet still has a target, it's just a node.
        local farmTargeted = self._powersConfig.farm_targeted_families
            and self._powersConfig.farm_targeted_families[kind.family]
        if not (farmTargeted and self:_hasEngagedFarmTarget(player)) then
            return self:_flub(player, "no_target")
        end
    end

    -- TAUNT needs a HOLDER — the selected pet, else a deployed tank. With neither the AoE lands on
    -- nobody, so refuse BEFORE the focus charge below: a power that eats focus and does nothing is
    -- worse than no power (Jason). This is taunt's ONLY refusal — it needs no engaged enemy (a
    -- pet-centred AoE fires whether or not anything's in range).
    -- RAGE shares taunt's holder rule (selected pet, else tanks), so it flubs the same way when
    -- there's nothing to rage — no pet selected AND no tanks deployed.
    if (kind.family == "taunt" or kind.family == "rage") and #self:_tauntHolders(player) == 0 then
        return self:_flub(player, "no_tank")
    end

    -- FOCUS COST: the cast COMMITS here — every refusal gate above (cooldown / no_target) has passed,
    -- so spending focus now means a refused cast never charges it. FocusService:Cast checks
    -- affordability AND deducts atomically; an empty pool refuses the whole cast (no effect, no
    -- cooldown stamp). `focus_cost` is per-power in configs/powers.lua — it was configured but never
    -- charged until now (the gate was never wired into the cast path). Cost 0 (most powers) = no-op.
    local focusCost = tonumber(def.focus_cost) or 0
    if focusCost > 0 then
        -- a slotted `focus` enhancement makes the power cheaper to cast (same axis that lowers toggle
        -- upkeep) — enhAxes.focus is the summed reduction fraction, clamped inside effectiveRate.
        focusCost = FocusUpkeep.effectiveRate(focusCost, enhAxes.focus)
    end
    if focusCost > 0 then
        local focusSvc = self._moduleLoader and self._moduleLoader:Get("FocusService")
        if focusSvc and focusSvc.Cast then
            local fres = focusSvc:Cast(player, focusCost)
            if not (fres and fres.ok) then
                return self:_flub(player, "not_enough_focus", { focus = fres and fres.focus })
            end
        end
    end

    self:_applyEffect(player, kind, now, tostring(powerId))
    -- Cast VFX. amplified_burst / team_cleave fire their own bespoke area FX inside _applyEffect.
    -- Archetype powers play a caster cast-tell (small `cast_emit` body emission for single-target,
    -- the `cast_burst` ring for AoE powers) and, if hostile, a targeted strike on each engaged enemy
    -- (= registry `eruption`) — same AreaFX the FX-probe previews, element-coloured. Generic/white
    -- powers keep the neutral placeholder ball.
    -- Cast VFX. amplified_burst / team_cleave fire their own bespoke area FX inside _applyEffect.
    -- Everything else resolves per-FAMILY (powers.lua family_fx) → a registry primitive: a `source`
    -- effect on the caster + a `target` effect on each engaged enemy (hostile families). The client
    -- renders via PowerFXRender (element-coloured), with floating "(effect TBD)"/"(sound TBD)" where a
    -- mapping or sound is missing. This is what makes a shield read as a shield, a buff as a buff, etc.
    local family = kind.family
    -- taunt owns ALL its own VFX (a rune per casting PET, spawned in _applyEffect) — skip the generic
    -- caster/target burst so no player-centred ring appears (Jason: focus the ring on the pets).
    if family ~= "amplified_burst" and family ~= "team_cleave" and family ~= "taunt" then
        local element = (def.archetype and ARCHETYPE_ELEMENT[def.archetype]) or "neutral"
        local generic = def.archetype == nil
        local fx = self._powersConfig.family_fx and self._powersConfig.family_fx[family]
        -- Caster cast-tell resolution (priority order):
        --   1. per-power override (def.fx.source) — hand-authored look for a specific power
        --   2. generic/white powers ⇒ "tbd" placeholder (no element-themed visual yet)
        --   3. friendly family source (heal_nova / aura / shield_bubble) — those read by family, not AoE
        --   4. hostile default by AoE-ness: AoE powers get the `cast_burst` RING (reads as AoE);
        --      single-target ones get the small `cast_emit` body emission ("emits from the player").
        local isAoe = def.target == "targeted_aoe" or def.target == "team_aoe"
        local sourcePrim = (def.fx and def.fx.source)
            or (generic and "tbd")
            or (fx and fx.source)
            or (isAoe and "cast_burst")
            or "cast_emit"
        Signals.Power_AreaFx:FireAllClients({
            primId = sourcePrim,
            element = element,
            kind = "source",
        })
        if not generic and self._powersConfig.enemy_targeted_families[family] then
            local targetPrim = (def.fx and def.fx.target) or (fx and fx.target) or "eruption"
            -- AoE powers land the impact on EVERY enemy; single-target ones land ONLY on the enemy
            -- the squad is fighting (so it doesn't read as an AoE). For Wildfire the seed burns there
            -- and the spread shows via the per-enemy fire as it catches.
            local impactFoes
            if isAoe then
                impactFoes = enemiesAlive()
            else
                local foe = self:_engagedEnemy(player)
                impactFoes = foe and { foe } or {}
            end
            for _, foe in ipairs(impactFoes) do
                if foe.PrimaryPart or foe:FindFirstChildWhichIsA("BasePart") then
                    Signals.Power_AreaFx:FireAllClients({
                        primId = targetPrim,
                        element = element,
                        kind = "target",
                        target = foe,
                    })
                end
            end
        end
    end

    local cd = tonumber(def.cooldown_seconds) or 0
    -- Slotted RECHARGE enhancements shorten THIS power's cooldown: cd / (1 + Σ values).
    if (enhAxes.recharge or 0) > 0 then
        cd = cd / (1 + enhAxes.recharge)
    end
    -- Hasten (recharge axis): the player's recharge buff shortens every power's cooldown by its
    -- fraction (clamped so a cooldown never hits zero).
    if (player:GetAttribute("RechargeBuffUntil") or 0) > now then
        local r = math.clamp(player:GetAttribute("RechargeBuff") or 0, 0, 0.9)
        cd = cd * (1 - r)
    end
    cds[powerId] = now + cd
    Signals.Power_Cooldown:FireClient(
        player,
        { power = powerId, untilTime = now + cd, cooldown = cd }
    )
    if self._logger then
        self._logger:Info(
            "Power cast",
            { power = powerId, effect = def.effect, family = kind.family }
        )
    end
    fireGameEvent(player, "power_cast", { power = powerId }) -- bus source (tutorial etc.)
    pcall(function() -- mission counter (quest chain "Cast 5 powers")
        _G.RBXTemplateServices:Get("StatsService"):Increment(player, "powers_cast", 1)
    end)
    return { ok = true, power = powerId, cooldown = cd }
end

function PowerService:_level(player, override)
    if override then
        return math.max(1, math.floor(override))
    end
    local locator = _G.RBXTemplateServices
    local ok, progression = pcall(function()
        return locator and locator:Get("PlayerProgressionService")
    end)
    if ok and progression and progression.GetLevel then
        return progression:GetLevel(player)
    end
    return 1
end

local function powersList(data)
    if type(data.Powers) ~= "table" then
        data.Powers = {}
    end
    return data.Powers
end

-- Count of owned powers that consume a level-up PICK. INNATE powers (granted free for everyone —
-- Resonance and any future innate) are NEVER counted against the selection budget, so they can't
-- steal a pick even if one somehow ends up in data.Powers. (Jason: build it general for any innate.)
local function pickedCount(selected, powersConfig)
    local powers = (powersConfig and powersConfig.powers) or {}
    local n = 0
    for _, id in ipairs(selected or {}) do
        local def = powers[tostring(id)]
        if not (def and def.innate) then
            n += 1
        end
    end
    return n
end

function PowerService:GetState(player, levelOverride)
    local data = self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded" }
    end
    local selected = powersList(data)
    local level = self:_level(player, levelOverride)
    local levels = self._powersConfig.selection_levels
    local available = ArchetypeLogic.availablePowers(data.Archetype, self._archetypesConfig)
    -- Surface INNATE powers (Resonance) to the menu as OWNED so they render as slottable rows — WITHOUT
    -- writing them to data.Powers. `pending` (the pick budget) stays on the raw #selected, so an innate
    -- never steals a level-up pick; the menu reads this `powers` list as the owned set. (task Resonance)
    local ownedForDisplay = {}
    local seen = {}
    for _, s in ipairs(selected) do
        ownedForDisplay[#ownedForDisplay + 1] = s
        seen[s] = true
    end
    for id, def in pairs(self._powersConfig.powers or {}) do
        if def.innate and not seen[id] then
            ownedForDisplay[#ownedForDisplay + 1] = id
            seen[id] = true
        end
    end
    return {
        ok = true,
        powers = ownedForDisplay,
        pending = PowerSelection.pendingSelections(
            level,
            pickedCount(selected, self._powersConfig),
            levels
        ),
        available = available,
    }
end

-- Pure pre-check: COULD this power be selected AT `level` right now (no mutation)? Used by the
-- atomic levelup.commit to validate the pick BEFORE claiming the level, so claim+select are
-- all-or-nothing. Returns (ok, reason).
function PowerService:CanSelectAtLevel(player, powerId, level)
    local data = self._dataService:GetData(player)
    if not data then
        return false, "data_not_loaded"
    end
    -- INNATE powers (Resonance, any future innate) are owned-free and live in the pool only so they
    -- render as slottable rows — they are NEVER pickable (picking would add them to data.Powers and
    -- steal a level-up pick). Reject here so the atomic commit can't grant one.
    local idef = self._powersConfig.powers and self._powersConfig.powers[tostring(powerId)]
    if idef and idef.innate then
        return false, "innate_not_selectable"
    end
    local available = ArchetypeLogic.availablePowers(data.Archetype, self._archetypesConfig)
    local decision = PowerSelection.canSelect(
        powerId,
        available,
        powersList(data),
        math.max(1, math.floor(tonumber(level) or 1)),
        self._powersConfig.selection_levels
    )
    return decision.ok == true, decision.reason
end

function PowerService:Select(player, powerId, levelOverride)
    local data = self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded" }
    end
    -- NOTE: no early no_archetype gate — NATURAL/generic powers are pickable BEFORE the L5 origin
    -- choice. availablePowers(nil) returns just the generic pool, so canSelect accepts generic and
    -- still rejects origin powers (not_in_archetype_pool) until an origin is chosen.
    -- INNATE powers are owned-free + unpickable (see CanSelectAtLevel) — reject so an innate can't be
    -- added to data.Powers (which would count against the pick budget).
    local idef = self._powersConfig.powers and self._powersConfig.powers[tostring(powerId)]
    if idef and idef.innate then
        return { ok = false, reason = "innate_not_selectable" }
    end
    local selected = powersList(data)
    local level = self:_level(player, levelOverride)
    local available = ArchetypeLogic.availablePowers(data.Archetype, self._archetypesConfig)
    local decision = PowerSelection.canSelect(
        powerId,
        available,
        selected,
        level,
        self._powersConfig.selection_levels
    )
    if not decision.ok then
        return { ok = false, reason = decision.reason }
    end
    table.insert(selected, powerId)
    -- Every picked power comes with one FREE inherent slot (flagged so it doesn't draw from the
    -- granted pool — see AugmentationService.allocatedCount). Level grants add the rest, up to 6.
    if type(data.Slots) ~= "table" then
        data.Slots = {}
    end
    if data.Slots[powerId] == nil then
        data.Slots[powerId] = { { inherent = true } }
    end
    self._dataService:RequestSave(player, "power_select", { critical = true })
    self:_applyOwnedPassives(player) -- a passive pick (Magnet/Swift/Hasten/XP) turns on immediately
    -- AUTO-BIND castable picks: a new ACTIVE power lands in the first empty hotbar
    -- slot (Jason: "I would have expected it to go into 1") — passives stay off the
    -- bar (they're always-on; the 10 slots are for casts). Players can still rebind.
    pcall(function()
        local kind = self._powersConfig.effect_kinds[self._powersConfig.powers[powerId].effect]
        local isPassive = kind and (kind.passive == true or kind.toggle == true)
        if not isPassive then
            local locator = _G.RBXTemplateServices
            local hotbar = locator and locator:Get("HotbarService")
            if hotbar and hotbar.GetState and hotbar.Rebind then
                local state = hotbar:GetState(player)
                local binds = (state and state.hotbar) or {}
                local slotCount = (state and state.slot_count) or 10
                local alreadyBound = false
                for _, bind in pairs(binds) do
                    if type(bind) == "table" and bind.target == powerId then
                        alreadyBound = true
                    end
                end
                if not alreadyBound then
                    for i = 1, slotCount do
                        if binds[tostring(i)] == nil then
                            hotbar:Rebind(player, i, { type = "power", target = powerId })
                            break
                        end
                    end
                end
            end
        end
    end)
    -- The hotbar's assign palette is owned-powers; re-push it so the fresh pick shows up in the
    -- Edit picker immediately (it was only pushed on join/rebind, so new picks were missing
    -- until rejoin).
    pcall(function()
        local locator = _G.RBXTemplateServices
        local hotbar = locator and locator:Get("HotbarService")
        if hotbar and hotbar._pushState then
            hotbar:_pushState(player)
        end
    end)
    fireGameEvent(player, "power_selected", { power = powerId }) -- bus source (tutorial etc.)
    return { ok = true, powers = selected }
end

return PowerService
