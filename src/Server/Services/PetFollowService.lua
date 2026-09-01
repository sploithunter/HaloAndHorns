--[[
    PetFollowService — server authority for the pet work loop (issue #4 retry).

    Responsibilities (SERVER ONLY):
      - Make pets non-falling: ANCHOR each pet's parts. Anchored parts obey no
        gravity/physics, so a pet can never drift or fall off the map (the bug the
        legacy teleport-watchdog existed to patch). The client positions them
        kinematically via PivotTo (see PetFollowController).
      - Mining damage tick: read each pet's TargetID, apply damage to the breakable
        via CombatService:ResolvePetDamage + PetCombat (Contrib ledger).
      - Target leash: clear TargetID when the player walks beyond leash_distance so
        the pet returns to following (BreakableService re-assigns when near).

    Movement/visualisation is CLIENT-side (src/Client/Systems/PetFollowController.lua),
    which sets each pet's CFrame every RenderStepped for smooth, never-falling
    motion. Damage stays server-authoritative. Multiplayer position replication
    (other clients seeing a player's pets move) is a documented follow-up.

    Gated on configs/pet_follow.lua `service_owned`.
]]

local Players = game:GetService("Players")
local ElementResonance = require(game:GetService("ReplicatedStorage").Shared.Game.ElementResonance)
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PetFormation = require(ReplicatedStorage.Shared.Game.PetFormation)
local Principal = require(ReplicatedStorage.Shared.Game.Principal)
-- Lookup surface for Principal (injected so the module headless-specs). Level is nil here on
-- purpose: the tick only needs identity + pet folder, and resolving every player's earned
-- level 4x/sec would be pure waste — the anchor path in PlayerProgressionService does that.
local PRINCIPAL_CTX = {
    players = function()
        return Players:GetPlayers()
    end,
}
local CombatMath = require(ReplicatedStorage.Shared.Game.CombatMath)
local CombatCadence = require(ReplicatedStorage.Shared.Game.CombatCadence)
local CombatRoll = require(ReplicatedStorage.Shared.Game.CombatRoll)
local Accuracy = require(ReplicatedStorage.Shared.Game.Accuracy)
local LevelScale = require(ReplicatedStorage.Shared.Game.LevelScale)
local PetPowerView = require(ReplicatedStorage.Shared.Game.PetPowerView)
local MergeEggDamageScope = require(ReplicatedStorage.Shared.Game.MergeEggDamageScope)
local BuffStack = require(ReplicatedStorage.Shared.Game.BuffStack)
local BreakableBoost = require(ReplicatedStorage.Shared.Game.BreakableBoost)
local EffectiveStats = require(ReplicatedStorage.Shared.Game.EffectiveStats)
local SupportAura = require(ReplicatedStorage.Shared.Game.SupportAura) -- cast-Rage HP-inverse math (SSOT)
local PetEndurance = require(ReplicatedStorage.Shared.Game.PetEndurance) -- live pet HP fraction for Rage
local DamageOverTime = require(ReplicatedStorage.Shared.Game.DamageOverTime)
local OnHitEffects = require(ReplicatedStorage.Shared.Game.OnHitEffects)
local MovingTargetPosition = require(ReplicatedStorage.Shared.Game.MovingTargetPosition)
local VulnMark = require(ReplicatedStorage.Shared.Game.VulnMark) -- additive vulnerability marks (SSOT)
local CrowdControl = require(ReplicatedStorage.Shared.Game.CrowdControl)
local FocusFire = require(ReplicatedStorage.Shared.Game.FocusFire)
local SquadDiversity = require(ReplicatedStorage.Shared.Game.SquadDiversity)
local FarmTargetRetention = require(ReplicatedStorage.Shared.Game.FarmTargetRetention)
local PetAbilityRuntime = require(ReplicatedStorage.Shared.Game.PetAbilityRuntime)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local CombatApplication = require(script.Parent.Parent.CombatApplication)

local PetFollowService = {}
PetFollowService.__index = PetFollowService

function PetFollowService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._combatServiceInstance = nil
    self._enemyServiceInstance = nil
    self._enchantServiceInstance = nil
    self._config = self._configLoader:LoadConfig("pet_follow")
    self._combatConfig = self._configLoader:LoadConfig("combat")
    self._autoSystemsConfig = self._configLoader:LoadConfig("auto_systems")
    self._petRoles = self._configLoader:LoadConfig("pet_roles")
    self._petsConfig = self._configLoader:LoadConfig("pets")
    self._levelingConfig = self._configLoader:LoadConfig("leveling")
    self._buffsConfig = self._configLoader:LoadConfig("buffs") or {}
    self._squadDiversityConfig = self._configLoader:LoadConfig("squad_diversity") or {}
    self._diversityCache = setmetatable({}, { __mode = "k" }) -- [player]={mult,t}; weak so leavers GC
    self._nextHit = {} -- pet model -> os.clock() of next allowed mining hit
    -- Ordinary pets are reported by their owning client. NPC-principal pets have no owning client,
    -- so the same gate stores a bounded server simulation for them (source = "npc").
    self._petPos = setmetatable({}, { __mode = "k" }) -- pet -> { cf, t, source? }
    self._abilityProfiles = setmetatable({}, { __mode = "k" })
    self._abilityNext = setmetatable({}, { __mode = "k" })

    -- Owning client reports its pet positions; we use them to gate mining on distance to target.
    Signals.PetReportPositions.OnServerEvent:Connect(function(player, report)
        self:_onPetPositions(player, report)
    end)

    -- Preload any model-based ranged FX (rock throw, future cactus) so the client can use them
    -- (InsertService is server-only). Sanitized templates land in ReplicatedStorage.RangedFXAssets.
    self:_preloadFxAssets()
end

function PetFollowService:BindPeerServices(services)
    self._combatServiceInstance = services.CombatService
    self._enemyServiceInstance = services.EnemyService
    self._enchantServiceInstance = services.EnchantService
end

-- Encounter handoff: proximity-triggered cave waves call this once after a real group spawns.
-- Clear only mining work; a pet already assigned to an enemy remains untouched. Include manifested
-- NPC principals owned by the player (Future Self) so the whole authored squad answers the cave.
function PetFollowService:ReleaseMiningTargets(player)
    if not player then
        return 0
    end
    local root = Workspace:FindFirstChild("PlayerPets")
    if not root then
        return 0
    end
    local cleared = 0
    local visited = {}
    for _, principal in ipairs(Principal.all(PRINCIPAL_CTX)) do
        if principal.instance == player or principal.owner == player then
            local folderName = Principal.petFolderName(principal)
            if folderName and not visited[folderName] then
                visited[folderName] = true
                local folder = root:FindFirstChild(folderName)
                for _, pet in ipairs(folder and folder:GetChildren() or {}) do
                    local targetType = pet:FindFirstChild("TargetType")
                    local targetId = pet:FindFirstChild("TargetID")
                    if
                        targetType
                        and string.lower(tostring(targetType.Value)) == "crystals"
                        and targetId
                        and targetId.Value ~= 0
                    then
                        targetId.Value = 0
                        cleared += 1
                    end
                end
            end
        end
    end
    return cleared
end

-- Load model_asset ids referenced by ranged_bolt (rock + projectile themes) and stash a
-- sanitized single-part template per id in ReplicatedStorage.RangedFXAssets[tostring(id)],
-- which replicates to clients for RangedFX to clone. Failures are logged + skipped (the
-- client falls back to a procedural block).
function PetFollowService:_preloadFxAssets()
    local bolt = (self._config and self._config.ranged_bolt) or {}
    local ids = {}
    if bolt.rock and bolt.rock.model_asset then
        ids[bolt.rock.model_asset] = true
    end
    if type(bolt.projectile) == "table" then
        for _, theme in pairs(bolt.projectile) do
            if type(theme) == "table" and theme.model_asset then
                ids[theme.model_asset] = true
            end
        end
    end
    -- Thrown-boulder variants (asteroid / boulder / ice_boulder) each carry their own mesh.
    if type(bolt.boulders) == "table" then
        for _, theme in pairs(bolt.boulders) do
            if type(theme) == "table" and theme.model_asset then
                ids[theme.model_asset] = true
            end
        end
    end
    if next(ids) == nil then
        return
    end
    local folder = ReplicatedStorage:FindFirstChild("RangedFXAssets")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "RangedFXAssets"
        folder.Parent = ReplicatedStorage
    end

    local AssetFetch = require(ReplicatedStorage.Shared.Utils.AssetFetch)
    for id in pairs(ids) do
        local name = tostring(id)
        if not folder:FindFirstChild(name) then
            task.spawn(function()
                local ok, container = pcall(function()
                    return AssetFetch.load(id)
                end)
                if ok and container then
                    local part = container:FindFirstChildWhichIsA("BasePart", true)
                    if part then
                        part = part:Clone()
                        part.Anchored = true
                        part.CanCollide = false
                        part.CanQuery = false
                        part.CastShadow = false
                        part.Name = name
                        part.Parent = folder
                    elseif self._logger then
                        self._logger:Warn("RangedFX asset has no BasePart", { asset = id })
                    end
                    container:Destroy()
                elseif self._logger then
                    self._logger:Warn("RangedFX asset load failed", { asset = id })
                end
            end)
        end
    end
end

-- Store reported positions for the player's OWN pets only (ignore anything else — anti-grief).
function PetFollowService:_onPetPositions(player, report)
    if type(report) ~= "table" then
        return
    end
    local folder = Workspace:FindFirstChild("PlayerPets")
        and Workspace.PlayerPets:FindFirstChild(player.Name)
    if not folder then
        return
    end
    local now = os.clock()
    local valid = {}
    for _, entry in ipairs(report) do
        local pet = type(entry) == "table" and entry.pet
        local cf = type(entry) == "table" and entry.cf
        if typeof(pet) == "Instance" and pet:IsDescendantOf(folder) and typeof(cf) == "CFrame" then
            self._petPos[pet] = { cf = cf, t = now } -- for the mining gate
            valid[#valid + 1] = entry
        end
    end

    -- Relay to OTHER clients only — they render this player's pets from the server. The owning
    -- client positions its OWN pets locally and is never sent / never applies the server copy,
    -- so its own view stays smooth (no PivotTo here = no stale server transform fighting it).
    if #valid > 0 then
        for _, other in ipairs(Players:GetPlayers()) do
            if other ~= player then
                Signals.PetPositionsRelay:FireClient(other, valid)
            end
        end
    end
end

-- The latest authoritative combat CFrame for a pet. Player pets arrive from their owner client;
-- NPC-principal pets use the server's bounded movement simulation below. EnemyService consumes the
-- same seam, so attack range and enemy pursuit agree with the damage gate.
function PetFollowService:GetReportedPosition(pet)
    local rec = self._petPos[pet]
    return rec and rec.cf or nil
end

local targetPosition

local function approachPosition(current, goal, maxStep)
    local delta = goal - current
    if delta.Magnitude <= maxStep or delta.Magnitude <= 0.001 then
        return goal
    end
    return current + delta.Unit * maxStep
end

-- A small authoritative counterpart to the client's rich NPC-pet presentation. It does not try to
-- reproduce gait or exact attack-ring choreography; it answers the gameplay question "has this pet
-- physically reached its target?" with the same travel-speed cap and a stable formation goal.
function PetFollowService:_stepNpcCombatPosition(principal, pet, anchorRoot, breakable)
    local now = os.clock()
    local rec = self._petPos[pet]
    local current = rec and rec.cf and rec.cf.Position or pet:GetPivot().Position
    local goal

    if breakable then
        local target = targetPosition(breakable)
        local towardAnchor =
            Vector3.new(anchorRoot.Position.X - target.X, 0, anchorRoot.Position.Z - target.Z)
        if towardAnchor.Magnitude <= 0.001 then
            towardAnchor = Vector3.new(0, 0, 1)
        end
        local stopDistance = math.max(1, self:_attackRange(pet) * 0.7)
        goal = target + towardAnchor.Unit * stopDistance
    else
        local formation = self._config.formation or {}
        local risers = formation.risers or {}
        local perRow = math.max(1, math.floor(tonumber(risers.per_row or formation.per_row) or 3))
        local positionNumber = pet:FindFirstChild("PositionNumber")
        local index =
            math.max(1, math.floor(tonumber(positionNumber and positionNumber.Value) or 1))
        local row = math.floor((index - 1) / perRow)
        local column = (index - 1) % perRow
        local columnSpacing = tonumber(risers.col_spacing or formation.col_spacing) or 4
        local rowSpacing = tonumber(risers.row_gap or formation.row_spacing) or 4
        local followDistance = tonumber(formation.follow_distance) or 6
        local height = tonumber(formation.height) or 2
        local x = (column - (perRow - 1) * 0.5) * columnSpacing
        goal = (anchorRoot.CFrame * CFrame.new(x, height, followDistance + row * rowSpacing)).Position
    end

    local movement = self._config.movement or {}
    local moveSpeedMult = tonumber(pet:GetAttribute("MoveSpeedMult")) or 1
    if (tonumber(pet:GetAttribute("PetSlowUntil")) or 0) > os.time() then
        moveSpeedMult *= math.clamp(tonumber(pet:GetAttribute("PetSlowFactor")) or 1, 0.05, 1)
    end
    local speed = PetFormation.moveSpeedMultiplier(
        principal.instance:GetAttribute("PetMoveSpeed"),
        moveSpeedMult,
        movement.speed
    )
    local dt = rec and math.clamp(now - rec.t, 0, 0.25)
        or math.max(0.01, tonumber(self._config.update_interval) or 0.1)
    local maxStep = math.max(0.01, tonumber(movement.max_travel_speed) or 26) * speed * dt
    local position = approachPosition(current, goal, maxStep)
    self._petPos[pet] = { cf = CFrame.new(position), t = now, source = "npc" }
    pet:SetAttribute("NpcCombatPosition", position)
end

-- Drop stale reports so combat falls back to the owner until the client
-- reports the pets at their new place (gauntlet restamp / entrance warp).
function PetFollowService:ClearReportedPositions(player)
    local folder = Workspace:FindFirstChild("PlayerPets")
        and Workspace.PlayerPets:FindFirstChild(player.Name)
    if not folder then
        return
    end
    for _, pet in ipairs(folder:GetChildren()) do
        if pet:IsA("Model") then
            self._petPos[pet] = nil
        end
    end
end

-- One authoritative position path for anything a pet works on. Moving enemies publish the
-- server-owned EnemyService entry.pos through MoveTarget because their anchored model pivot stays
-- at spawn while clients render motion. Static crystals have no MoveTarget and use their model.
-- Never substitute the pet's client-reported position here: clients may present pet movement, but
-- they do not get to choose damage geometry.
targetPosition = function(target)
    local published = target:GetAttribute("MoveTarget")
    if typeof(published) ~= "Vector3" then
        published = nil
    end
    local primary = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
    local primaryPosition = primary and primary.Position
    local pivotPosition = if not published and not primaryPosition
        then target:GetPivot().Position
        else nil
    return MovingTargetPosition.resolve(published, primaryPosition, pivotPosition)
end

function PetFollowService:_combatService()
    return self._combatServiceInstance
end

function PetFollowService:_enemyService()
    return self._enemyServiceInstance
end

function PetFollowService:Start()
    if not self._config.service_owned then
        if self._logger then
            self._logger:Info("PetFollowService inert (pet_follow.service_owned=false)")
        end
        return
    end
    _G.PetFollowServiceOwned = true -- legacy cloned scripts stand down
    if self._logger then
        self._logger:Info(
            "PetFollowService active — anchored pets, client-driven movement, server damage"
        )
    end
    local accum = 0
    RunService.Heartbeat:Connect(function(dt)
        accum += dt
        if accum < self._config.update_interval then
            return
        end
        accum = 0
        pcall(function()
            self:_tick()
        end)
        pcall(function()
            self:_stampPetSyncDiag()
        end)
    end)
end

-- ADMIN DIAGNOSTIC: stamp each pet with what the SERVER knows about its position, so the client
-- PetSyncDiag overlay can show the client<->server gap live (no MCP archaeology mid-fight). Pets are
-- client-moved + anchored at origin server-side; combat reads GetReportedPosition (client report),
-- falling back to the owner. We stamp the gate's view + report age so a desync is VISIBLE:
--   DiagGatePos    (Vector3) — the position server combat would use for this pet RIGHT NOW
--   DiagReportAge  (number)  — seconds since the client last reported (or -1 = never -> on fallback)
function PetFollowService:_stampPetSyncDiag()
    local petsRoot = Workspace:FindFirstChild("PlayerPets")
    if not petsRoot then
        return
    end
    local now = os.clock()
    for _, folder in ipairs(petsRoot:GetChildren()) do
        local owner = Players:FindFirstChild(folder.Name)
        local hrp = owner and owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
        for _, pet in ipairs(folder:GetChildren()) do
            if pet:IsA("Model") then
                local rec = self._petPos[pet]
                local gatePos
                if rec and rec.cf then
                    gatePos = rec.cf.Position
                    pet:SetAttribute("DiagReportAge", now - rec.t)
                else
                    gatePos = hrp and hrp.Position or pet:GetPivot().Position
                    pet:SetAttribute("DiagReportAge", -1) -- no report -> combat is on the owner fallback
                end
                pet:SetAttribute("DiagGatePos", gatePos)
            end
        end
    end
end

-- One anchored assembly so client PivotTo cannot leave packaged-avatar
-- pieces (Kade's head) at the last replicated CFrame. Weld everyone to
-- PrimaryPart, then anchor only that part — welds stay live.
local function weldToPrimary(pet)
    local primary = pet.PrimaryPart
    if not primary then
        return
    end
    local weldedToPrimary = {}
    for _, d in ipairs(pet:GetDescendants()) do
        if d:IsA("WeldConstraint") then
            if d.Part0 == primary and d.Part1 then
                weldedToPrimary[d.Part1] = true
            elseif d.Part1 == primary and d.Part0 then
                weldedToPrimary[d.Part0] = true
            end
        end
    end
    for _, d in ipairs(pet:GetDescendants()) do
        if d:IsA("BasePart") and d ~= primary then
            if not weldedToPrimary[d] then
                local weld = Instance.new("WeldConstraint")
                weld.Part0 = primary
                weld.Part1 = d
                weld.Parent = primary
            end
            d.Anchored = false
        end
    end
    primary.Anchored = true
end

-- Anchor the pet so it can't fall/drift (the client moves it via PivotTo).
-- Strips any stale movement constraints from earlier builds. Once per pet.
function PetFollowService:_prepPet(pet)
    if pet:GetAttribute("PetFollowPrepped") then
        return
    end
    for _, name in ipairs({ "_FollowAlign", "_FollowAlignO", "align", "alignO" }) do
        local c = pet:FindFirstChild(name)
        if c then
            c:Destroy()
        end
    end
    weldToPrimary(pet)
    for _, d in ipairs(pet:GetDescendants()) do
        if d:IsA("BasePart") and d ~= pet.PrimaryPart then
            d.Anchored = false
        elseif d:IsA("BasePart") then
            d.Anchored = true
        end
    end
    pet:SetAttribute("PetFollowPrepped", true)
end

-- Locate a target Model by id. Enemies (TargetType "Enemy") live under Game.Enemies; breakables
-- under Game.Breakables/<type>/<world>. Both carry a BreakableID — the generic target id.
function PetFollowService:_findBreakable(targetType, world, id)
    local game = Workspace:FindFirstChild("Game")
    if not game then
        return nil
    end
    if targetType == "Enemy" then
        local enemies = game:FindFirstChild("Enemies")
        if not enemies then
            return nil
        end
        for _, desc in ipairs(enemies:GetDescendants()) do
            if desc.Name == "BreakableID" and desc:IsA("NumberValue") and desc.Value == id then
                return desc.Parent
            end
        end
        return nil
    end
    local breakables = game:FindFirstChild("Breakables")
    if not breakables then
        return nil
    end
    local typeFolder = breakables:FindFirstChild(targetType)
    local scope = typeFolder and (typeFolder:FindFirstChild(world) or typeFolder)
    if not scope then
        return nil
    end
    for _, desc in ipairs(scope:GetDescendants()) do
        if desc.Name == "BreakableID" and desc:IsA("NumberValue") and desc.Value == id then
            return desc.Parent
        end
    end
    return nil
end

function PetFollowService:_releaseMiningTarget(player, breakable)
    local character = player and player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local targetPos = targetPosition(breakable)
    local autoTarget = self._autoSystemsConfig and self._autoSystemsConfig.auto_target or {}
    local distance = root and targetPos and (root.Position - targetPos).Magnitude or nil
    return FarmTargetRetention.shouldRelease({
        inCombat = player and player:GetAttribute("InCombat") == true,
        distance = distance,
        maxDistance = autoTarget.max_target_distance,
    })
end

-- A pet's effective attack range (mining-gate distance), by combat role: PetRole attr
-- -> pet_roles.by_type[PetType] -> default. Ranged pets reach much further than melee,
-- so they can deal damage from their standoff. Falls back to mining.range.
function PetFollowService:_attackRange(pet)
    local roles = self._petRoles
    local fallback = (self._config.mining and self._config.mining.range) or 9
    if not roles then
        return fallback
    end
    local id = pet:GetAttribute("PetRole")
        or (roles.by_type and roles.by_type[pet:GetAttribute("PetType")])
        or roles.default
    local def = roles.roles and roles.roles[id]
    return (def and tonumber(def.attack_range)) or fallback
end

-- Does this pet KITE (ranged/support/control — holds position and shoots) vs CHASE (melee/tank)?
-- A kiter's reach is horizontal: it can hit a flyer perched above without closing the vertical gap.
function PetFollowService:_kites(pet)
    local roles = self._petRoles
    if not roles then
        return false
    end
    local id = pet:GetAttribute("PetRole")
        or (roles.by_type and roles.by_type[pet:GetAttribute("PetType")])
        or roles.default
    local def = roles.roles and roles.roles[id]
    return def ~= nil and (def.kite == true or (tonumber(def.standoff) or 0) > 0)
end

function PetFollowService:_abilityProfile(pet)
    local profile = self._abilityProfiles[pet]
    if not profile then
        profile = PetAbilityRuntime.resolve(
            self._petsConfig,
            pet:GetAttribute("PetType"),
            pet:GetAttribute("PetVariant") or "basic"
        )
        self._abilityProfiles[pet] = profile
    end
    return profile
end

-- Pack Leader is a squad passive. Multiple leaders do not multiply without
-- bound; the strongest equipped leader supplies the aura.
function PetFollowService:_packLeaderMult(pet)
    local best = 1
    local folder = pet and pet.Parent
    for _, ally in ipairs(folder and folder:GetChildren() or {}) do
        if not ally:GetAttribute("CombatDowned") then
            local passive = self:_abilityProfile(ally).passive or {}
            best = math.max(best, tonumber(passive.nearby_pet_damage) or 1)
        end
    end
    return best
end

-- One mining hit on the pet's current target (server-authoritative damage).

-- ZONE GATE (Jason's alt-account find: "unlocking from a single player perspective
-- apparently unlocks it for everybody"): ore SPAWNS are server-global (any present
-- unlocked player lights a biome), so per-MINER enforcement happens here. Reads the
-- published UnlockedAreasJson attribute with a per-player decode cache (hot path).
local HttpService = game:GetService("HttpService")
local _unlockCache = setmetatable({}, { __mode = "k" })
local function zoneUnlockedFor(player, zoneId)
    if not player or type(zoneId) ~= "string" or zoneId == "" then
        return true
    end
    -- Mission pseudo-worlds (mission_hell etc.): entering through the door IS
    -- the entitlement — mission debris is mineable by whoever is inside
    -- (docs/MISSION_WORLDGEN.md M5 farmable crates).
    if zoneId:sub(1, 8) == "mission_" then
        return true
    end
    local json = player:GetAttribute("UnlockedAreasJson")
    if json == nil then
        return true -- not published yet (boot grace) — never brick Spawn mining
    end
    local cache = _unlockCache[player]
    if not cache or cache.json ~= json then
        local set = {}
        local ok, arr = pcall(function()
            return HttpService:JSONDecode(json)
        end)
        if ok and type(arr) == "table" then
            for _, id in ipairs(arr) do
                set[tostring(id)] = true
            end
        end
        cache = { json = json, set = set }
        _unlockCache[player] = cache
    end
    return cache.set[zoneId] == true
end

-- Stamp a ticking burn (DoT) on an enemy, optionally CONTAGIOUS. One path for both the primary hit
-- and each AoE-splash target, so "AoE contagion" (splash ignites a cluster, each then spreads) is
-- just calling this per splashed enemy. Re-hit keeps the STRONGER per-tick and refreshes the window;
-- contagion arms ONCE (re-arming every swing pushed the spread timer back so it never fired). The
-- spread params (radius/interval/max) are carried onto the enemy as Contagion* so the spread pass —
-- and every subsequent hop — propagates with the originating pet's tuning, not a global default.
local function stampBurn(
    enemy,
    perTick,
    interval,
    duration,
    sourceUserId,
    spread,
    clk,
    element,
    playerPetKillUserId
)
    if perTick <= 0 or duration <= 0 then
        return
    end
    enemy:SetAttribute(
        "DotPerTick",
        math.max(tonumber(enemy:GetAttribute("DotPerTick")) or 0, perTick)
    )
    enemy:SetAttribute("DotInterval", interval)
    enemy:SetAttribute("DotNextTick", clk + interval)
    enemy:SetAttribute("DotExpireAt", clk + duration)
    enemy:SetAttribute("DotDuration", duration) -- window length, so contagion can re-arm the hop
    enemy:SetAttribute("DotSourceUserId", sourceUserId)
    enemy:SetAttribute("DotPlayerPetKillUserId", playerPetKillUserId)
    enemy:SetAttribute("BurnFxUntil", os.time() + math.ceil(duration)) -- enemy "on fire" tell
    if element then
        enemy:SetAttribute("BurnElement", element) -- themes the client burn fx (frost = blue, etc.)
    end
    if
        spread
        and (spread.max or 0) > 0
        and (tonumber(enemy:GetAttribute("ContagionSpreadAt")) or 0) <= 0
    then
        enemy:SetAttribute("ContagionSpreadAt", clk + math.max(0.2, spread.interval or 1.5))
        enemy:SetAttribute("ContagionLeft", math.floor(spread.max))
        enemy:SetAttribute("ContagionRadius", spread.radius or 8)
        enemy:SetAttribute("ContagionInterval", spread.interval or 1.5)
        enemy:SetAttribute("ContagionMax", math.floor(spread.max))
    end
end

-- Resolve a pet's burn+spread profile from its stamped attributes (per-pet, set at spawn from
-- attack_dot/attack_dot.spread) with the global pet_contagion block as the fallback default. Returns
-- nil when the pet has no burn. `spread` is present only when the burn is contagious — either an
-- explicit attack_dot.spread (DotSpreadMax > 0) OR the back-compat AttackTargeting == "contagion"
-- shorthand (= single geometry + global-default spread).
local function burnProfile(pet, contagionDefaults)
    local dotFrac = tonumber(pet:GetAttribute("DotFraction")) or 0
    local duration = tonumber(pet:GetAttribute("DotDuration")) or 0
    if dotFrac <= 0 or duration <= 0 then
        return nil
    end
    local cc = contagionDefaults or {}
    local profile = {
        fraction = dotFrac,
        interval = math.max(0.1, tonumber(pet:GetAttribute("DotTick")) or 1),
        duration = duration,
    }
    local sMax = tonumber(pet:GetAttribute("DotSpreadMax")) or 0
    local legacyContagion = pet:GetAttribute("AttackTargeting") == "contagion"
    if sMax > 0 or legacyContagion then
        local pr = tonumber(pet:GetAttribute("DotSpreadRadius")) or 0
        local pi = tonumber(pet:GetAttribute("DotSpreadInterval")) or 0
        profile.spread = {
            radius = pr > 0 and pr or (tonumber(cc.spread_radius) or 8),
            interval = pi > 0 and pi or (tonumber(cc.spread_interval) or 1.5),
            max = sMax > 0 and sMax or math.floor(tonumber(cc.max_spread) or 4),
        }
    end
    return profile
end

-- Apply a pet's ON-HIT enemy effects (control + shred) to one enemy. Orthogonal to geometry, so
-- this runs for the primary target AND each AoE-splash enemy — a targeted_aoe controller roots the
-- whole splash, an aoe shredder softens the cluster. Composes onto the SAME enemy attributes the
-- powers use (RootedUntil/HeldUntil, SlowUntil/SlowFactor, VulnerableMult/Until), so a downstream
-- consumer needs no special-casing. Refresh-to-longer / keep-stronger so a fresh weak hit never
-- shortens a lock or weakens a shred. nowT is os.time() (matches every *Until seam).
local function applyOnHit(enemy, pet, nowT)
    -- CONTROL (Anvil): slow / root / hold on hit.
    local ck = pet:GetAttribute("HitControlKind")
    if type(ck) == "string" and ck ~= "" then
        local dur = tonumber(pet:GetAttribute("HitControlDuration")) or 0
        if dur > 0 then
            local untilT = nowT + dur
            if ck == "hold" then
                enemy:SetAttribute(
                    "HeldUntil",
                    math.max(tonumber(enemy:GetAttribute("HeldUntil")) or 0, untilT)
                )
            elseif ck == "root" then
                enemy:SetAttribute(
                    "RootedUntil",
                    math.max(tonumber(enemy:GetAttribute("RootedUntil")) or 0, untilT)
                )
            elseif ck == "slow" then
                enemy:SetAttribute(
                    "SlowUntil",
                    math.max(tonumber(enemy:GetAttribute("SlowUntil")) or 0, untilT)
                )
                enemy:SetAttribute(
                    "SlowFactor",
                    tonumber(pet:GetAttribute("HitControlFactor")) or 1
                )
            end
        end
    end
    -- SHRED (Amplifier): a vulnerability debuff — enemy takes +X% from EVERYONE. Rides the ONE
    -- shared "shred" VulnMark channel: keep-the-stronger WITHIN the channel (shreds never compound
    -- with each other — OnHitEffects.vulnerable) while ADDING with power marks across channels
    -- (the additive vulnerability model — a per-hit shred can no longer clobber a caster's marks).
    local vuln = tonumber(pet:GetAttribute("HitVulnerable")) or 0
    if vuln > 0 then
        local dur = tonumber(pet:GetAttribute("HitDebuffDuration")) or 0
        if dur > 0 then
            local curFrac = VulnMark.liveFraction(
                enemy:GetAttribute(VulnMark.attr("shred")),
                enemy:GetAttribute(VulnMark.untilAttr("shred")),
                nowT
            )
            VulnMark.apply(
                enemy,
                "shred",
                OnHitEffects.vulnerable(1 + curFrac, curFrac > 0, vuln),
                nowT + dur
            )
        end
    end
end

-- CAST RAGE (the active Rage power, Jason): the LIVE additive pet_damage fraction for this pet while
-- its rage window is open (RagePowerUntil, stamped on the holders by PowerService). Computed per swing
-- from the pet's CURRENT HP — flat base + a "critical" bonus that ramps as HP drops below the
-- threshold (SupportAura.rageRampFraction, the one rage-math SSOT). 0 when not raging (the BuffStack
-- expiry gate also drops it, but returning 0 keeps the source cheap/inert).
function PetFollowService:_ragePowerFraction(pet)
    if (pet:GetAttribute("RagePowerUntil") or 0) <= os.time() then
        return 0
    end
    local powerNV = pet:FindFirstChild("Power")
    local power = (powerNV and tonumber(powerNV.Value)) or 0
    local factor = (self._combatConfig and self._combatConfig.pet_down_threshold_factor) or 1
    -- INTEGER endurance, floored at 1 point (Jason: "the lowest HP you can have in a fight is 1 —
    -- that's not a cap"). Endurance is discrete; a live pet always has >= 1 point, so the rage curve's
    -- divide-by-remaining is always finite (no infinite power, no divide-by-0) and its ceiling scales
    -- with the pet's OWN max endurance (a bigger tank rages harder) — bounded naturally, not clamped.
    local maxEnd = PetEndurance.maxEndurance(power, factor)
    local remaining = math.max(1, math.floor(maxEnd - (pet:GetAttribute("CombatDamageTaken") or 0)))
    local hpFrac = (maxEnd > 0) and (remaining / maxEnd) or 1
    return SupportAura.rageRampFraction(
        pet:GetAttribute("RagePowerBase"),
        pet:GetAttribute("RagePowerRate"),
        pet:GetAttribute("RagePowerBelow"),
        hpFrac
    )
end

function PetFollowService:_mine(player, pet, breakable)
    if pet:GetAttribute("CombatDowned") then
        return -- downed pets are out healing; they neither mine nor fight
    end
    if breakable:GetAttribute("SpawnAnimating") then
        return -- falling/materializing Hall rewards are not live mining targets yet
    end
    -- MEZ (#269): a HELD pet is fully controlled — no attacks, no mining, until the window
    -- lapses (root only stops movement; hold stops output too).
    if CrowdControl.isHeld(pet:GetAttribute("PetHeldUntil"), os.time()) then
        return
    end
    -- the SERVER enforcement: pets of a player who hasn't unlocked this node's
    -- zone do no damage and earn nothing (walking in is allowed; profiting isn't)
    local nodeWorld = breakable:GetAttribute("World")
    if nodeWorld and not zoneUnlockedFor(player, nodeWorld) then
        return
    end
    local now = os.clock()
    if self._nextHit[pet] and now < self._nextHit[pet] then
        return
    end
    local combat = self:_combatService()
    if not combat then
        return
    end
    local hp = breakable:GetAttribute("HP") or 0
    if hp <= 0 then
        return
    end

    -- Mining gate: only mine once the pet has reached the target (within mining.range), so move
    -- speed affects mining throughput (DPS ramps as pets arrive). Distance comes from the position
    -- the owning client reports; a missing/stale report falls back to "allow" so the gate can
    -- never break the legacy "near the ore = mines" behaviour.
    local rec = self._petPos[pet]
    local staleSeconds = (self._config.replication and self._config.replication.stale_seconds)
        or 0.5
    local dist
    if rec and (now - rec.t) <= staleSeconds then
        local targetPos = targetPosition(breakable)
        -- RANGED vs a flyer: a kiting pet shoots, so its reach is HORIZONTAL — it can hit an enemy
        -- perched up on a wall/ledge above it without the vertical gap pushing it out of range. Melee
        -- (and all crystal mining) use true 3D distance: they must physically reach the target.
        if breakable:GetAttribute("EnemyId") and self:_kites(pet) then
            local dx = rec.cf.Position.X - targetPos.X
            local dz = rec.cf.Position.Z - targetPos.Z
            dist = math.sqrt(dx * dx + dz * dz)
        else
            dist = (rec.cf.Position - targetPos).Magnitude
        end
    end
    local miningRange = self:_attackRange(pet)
    if not PetFormation.inMiningRange(dist, miningRange) then
        return -- pet is reported far from the target — hasn't arrived yet
    end

    local abilityProfile = self:_abilityProfile(pet)
    local abilityProc
    abilityProc, self._abilityNext[pet] =
        PetAbilityRuntime.activate(abilityProfile, self._abilityNext[pet], now)
    local abilityPassive = abilityProfile.passive or {}

    local powerNV = pet:FindFirstChild("Power")
    local ctx = {
        power = tonumber(powerNV and powerNV.Value) or 1,
        petId = pet:GetAttribute("PetType"),
        variant = pet:GetAttribute("PetVariant"),
        breakableId = breakable:GetAttribute("BreakableId"),
        currency = breakable:GetAttribute("Currency"),
    }
    -- DISPLAY = DEALT, structurally (#132): the pre-roll hit comes from the SAME resolver the
    -- inventory card runs (PetPowerView.profile) — element flat, variant bump, role/pet aptitude
    -- (mining vs combat) and the biome-RPS zone multiplier all live in ONE place. base = the
    -- enchant/modifier-resolved Power (ResolvePetDamage); a crystal swing is the card's ⛏ number,
    -- an enemy swing its ⚔. Everything below this point is contextual (level scale, buffs,
    -- vulnerability, armor, rolls) or pacing — never intrinsic.
    local originProgression =
        math.max(0, tonumber(pet:GetAttribute("OriginProgressionMultiplier")) or 1)
    -- Full-mode Merge Defense uses the player's durable pets, so they are not present in the
    -- prototype service's ephemeral record.playerUnits collection. Resolve the additive Gem +
    -- Rebirth multiplier contextually here instead: it applies only while the owner is inside Merge
    -- Defense. The two ephemeral NPC paths are excluded because MergeEggPrototypeService already
    -- stamps their model progression and applying this factor again would double their bonus.
    originProgression *= MergeEggDamageScope.playerPetMultiplier({
        inMergeDefense = player:GetAttribute("InMergeEggPrototype") == true,
        mode = player:GetAttribute("MergeEggPlayerCombatMode"),
        mergeNpcUnit = pet:GetAttribute("MergeEggUnit") == true,
        simpleReserveUnit = pet:GetAttribute("MergeEggPlayerReserveUnit") == true,
        managementDamageMultiplier = player:GetAttribute("MergeDefenseManagementDamageMultiplier"),
        rebirthDamageMultiplier = player:GetAttribute("MergeDefenseRebirthDamageMultiplier"),
    })
    local profile = PetPowerView.profile({
        base = combat:ResolvePetDamage(player, ctx),
        petType = pet:GetAttribute("PetType"),
        variant = pet:GetAttribute("PetVariant"),
        role = pet:GetAttribute("PetRole"),
        context = {
            zone = self:_zoneResonance(player, pet), -- biome RPS (pet element vs zone)
            realm = self:_realmResonance(player, pet), -- light/shadow vs current realm (cross-realm)
            diversity = self:_squadDiversity(player), -- team-comp bonus (distinct archetypes+origins)
            -- Runtime-only progression seam for modes such as Merge an Egg. The pet definition and
            -- saved Power stay immutable; an owning system may add a contextual origin multiplier.
            originProgression = originProgression,
        },
    })
    local dmg = breakable:GetAttribute("EnemyId") and profile.combatEffective
        or profile.miningEffective
    -- Configured variant abilities are real swing procs, not card decoration.
    -- Passives (loyalty/all-bonus/pack-leader) stay live on every relevant hit;
    -- cooldown abilities apply only when PetAbilityRuntime activates them.
    dmg = dmg * (tonumber(abilityPassive.all_bonus) or 1) * self:_packLeaderMult(pet)
    if breakable:GetAttribute("EnemyId") then
        dmg = dmg * (tonumber(abilityPassive.damage_to_owner_enemies) or 1)
    end
    if abilityProc then
        dmg = dmg * (tonumber(abilityProc.damage_multiplier) or 1)
    end
    -- AURA SPLIT (Jason "hit = hit - aura"): an aura pet's SINGLE-TARGET hit is reduced by the aura
    -- fraction, because its focus ALSO sits in the field and takes the aura tick — so the focus nets
    -- the full hit ((1-f) from the swing + f from the field), neighbors get the f as bonus AoE, and
    -- the focus is never double-counted. The crit roll below applies to this reduced hit; the field
    -- itself ticks flat (no crit). Only on ENEMY hits — mining is unaffected.
    if breakable:GetAttribute("EnemyId") and pet:GetAttribute("AttackTargeting") == "aura" then
        local f = tonumber(self._combatConfig.pet_aura and self._combatConfig.pet_aura.fraction)
            or 0.5
        dmg = dmg * math.max(0, 1 - f)
    end
    -- Level scaling vs ENEMIES only (crystals have no Level): out-level it -> hit harder.
    if breakable:GetAttribute("EnemyId") then
        -- Attacker fights at the owner's EFFECTIVE level (the teaming seam) — same value the
        -- accuracy curve below uses, so hit + damage scale together.
        local petLevel = pet:GetAttribute("PrincipalLevel")
            or player:GetAttribute("EffectiveLevel")
            or pet:GetAttribute("Level")
            or (player:GetAttribute("Level") or 1)
        local enemyLevel = breakable:GetAttribute("Level") or petLevel
        dmg = dmg * LevelScale.factor(petLevel, enemyLevel, self._levelingConfig.scale)
    end
    -- Support-power modifiers (Feature 14): the player's active damage buff and the
    -- target's vulnerability both scale pet damage (os.time-gated, set by PowerService).
    local nowT = os.time()
    -- PLAYER-LEVEL pet_damage sources come from THE registry (EffectiveStats): activated damage
    -- powers, potion, offense aura, and Overheat all ADD on the same capped axis. This is the same
    -- source list EffectiveStatsService publishes as Eff_Attack, so gameplay and the HUD cannot drift.
    local petDmgSources = EffectiveStats.AXES.pet_damage.sources(function(name)
        return player:GetAttribute(name)
    end)
    local petSpecificSources = {
        {
            -- RAGE (inherent self power, e.g. bear — pet_roles support_auras kind
            -- "rage"): a per-PET stamp from EnemyService:_supportPass while the pet is
            -- hurt past its enrage threshold. Same additive axis as the player buffs,
            -- so it ADDS under the pet_damage cap, never compounds.
            fraction = (pet:GetAttribute("RageDamageBuff") or 1) - 1,
            expiry = pet:GetAttribute("RageDamageBuffUntil") or 0,
        },
        {
            -- RAGE POWER (the active Rage cast — tank self-buff): flat base + HP-inverse "critical",
            -- computed LIVE per swing from THIS pet's current HP (harder as it drops). Its OWN channel
            -- so it ADDS to the bear's passive rage above under the pet_damage cap, never compounds.
            fraction = self:_ragePowerFraction(pet),
            expiry = pet:GetAttribute("RagePowerUntil") or 0,
        },
        {
            -- RAGE TIPPING POINT (aggro heat, Phase 2): EnemyService:_petAggroPass latches
            -- RageHeatFrac (= aggro.rage.amp − 1) on this pet while the total threat directed AT
            -- it sits past rage.pet.tip — the cornered pet "loses its mind and brawls". Rolling
            -- RageHeatUntil expiry (re-stamped while hot). Its OWN channel: adds to the bear rage
            -- and the Rage cast above, never compounds.
            fraction = tonumber(pet:GetAttribute("RageHeatFrac")) or 0,
            expiry = pet:GetAttribute("RageHeatUntil") or 0,
        },
        {
            -- WAR-CRY single/targeted_aoe (offense aura with targeting != "aura"): a per-PET damage
            -- buff stamped on the chosen carry(ies) by _auraScopedBuff. Same additive axis as the
            -- team War-Cry (PetTeamDamageBuff) — so a single-target War-Cry and a team one add, never
            -- compound. (The team variant rides PetTeamDamageBuff above.)
            fraction = (pet:GetAttribute("PetDamageBuffSelf") or 1) - 1,
            expiry = pet:GetAttribute("PetDamageBuffSelfUntil") or 0,
        },
        {
            -- EMPOWER (single-target damage buffer, e.g. carrion_scarab — pet_roles kind "empower"):
            -- a per-PET stamp from EnemyService:_supportPass on the squad's strongest ally. Same
            -- additive pet_damage axis as RAGE + the player buffs, so it ADDS under the cap, never
            -- compounds — and lifts this pet's mining AND combat together (it's the dmg axis).
            fraction = (pet:GetAttribute("EmpowerDamageBuff") or 1) - 1,
            expiry = pet:GetAttribute("EmpowerDamageBuffUntil") or 0,
        },
        {
            -- BERSERK CIRCLE (rage cannon landing): PotionService:SipBrewOn writes
            -- the brew stamp on THIS pet. Player flask still rides the player
            -- PetDamageBuffPotion axis above. Circle must not write the player
            -- or every pet inherits it.
            fraction = tonumber(pet:GetAttribute("PetDamageBuffPotion")) or 0,
            expiry = pet:GetAttribute("PetDamageBuffPotionUntil") or 0,
        },
    }
    for _, source in ipairs(petSpecificSources) do
        petDmgSources[#petDmgSources + 1] = source
    end
    dmg = dmg
        * BuffStack.multiplier(
            petDmgSources,
            nowT,
            self._buffsConfig.axes and self._buffsConfig.axes.pet_damage
        )
    -- Opposing support pets use the same authored curse aura, mirrored onto defending pets. The
    -- stamp lives on the pet (the damage dealer), so it reduces both mining and combat output for
    -- the aura window without changing the canonical pet definition.
    if (tonumber(pet:GetAttribute("EnemyCurseUntil")) or 0) > nowT then
        dmg *= math.clamp(tonumber(pet:GetAttribute("EnemyCurseMult")) or 1, 0, 1)
    end
    -- VULNERABILITY marks: ADDITIVE across sources (VulnMark — each power/shred writes its own
    -- channel, the total = 1 + Σ live fractions, uncapped). The glass cannon's layered marks
    -- finally STACK (eruption + strike = x2.5, not last-write x1.5). Still a SEPARATE axis from
    -- pet output (enemy weakness), so it multiplies across axes.
    local preVulnerabilityDmg = dmg
    local vulnerabilityMult = VulnMark.multiplier(breakable:GetAttributes(), nowT)
    dmg = dmg * vulnerabilityMult
    local postVulnerabilityDmg = dmg
    -- Defensive stat: an enemy's Armor mitigates pet damage on the armor curve
    -- (crystals have no Armor -> unchanged). Vulnerability above counteracts it.
    local armorIgnore = math.clamp(tonumber(abilityProc and abilityProc.armor_ignore) or 0, 0, 1)
    local armor = tonumber(breakable:GetAttribute("Armor")) or 0
    if (tonumber(breakable:GetAttribute("EnemyArmorBuffUntil")) or 0) > nowT then
        armor += math.max(0, tonumber(breakable:GetAttribute("EnemyArmorBuff")) or 0)
    end
    armor *= 1 - armorIgnore
    if armor > 0 then
        dmg = CombatMath.mitigate(dmg, armor, self._combatConfig.armor_curve_k or 100)
    end
    -- Hit / crit roll. Hit chance now comes from the level-diff Accuracy curve (vs the enemy's
    -- level, which bakes in rank); MINING never misses (crystals can't dodge — fixes the old 8%
    -- whiff). CombatRoll still owns the crit (chances from the pet_attack config).
    local accCfg = self._combatConfig.accuracy
    local petAtkRoll = self._combatConfig.engagement
        and self._combatConfig.engagement.rolls
        and self._combatConfig.engagement.rolls.pet_attack
    local hitChance
    if breakable:GetAttribute("EnemyId") then
        -- Manifested-principal pets fight at the authored principal level for BOTH halves of
        -- level scaling. Using it for damage but not accuracy made a manifested Future Call
        -- squad retain its lower-level summoner's miss chance.
        local atkLevel = pet:GetAttribute("PrincipalLevel")
            or player:GetAttribute("EffectiveLevel")
            or pet:GetAttribute("Level")
            or (player:GetAttribute("Level") or 1)
        local enemyLevel = breakable:GetAttribute("Level") or atkLevel
        hitChance = Accuracy.combatToHit(atkLevel, enemyLevel, accCfg)
        local keys = FocusFire.keys(player.UserId)
        hitChance = FocusFire.applyAccuracy(
            hitChance,
            breakable:GetAttribute(keys.accuracyBonus),
            breakable:GetAttribute(keys.untilTime),
            os.time(),
            accCfg and accCfg.cap
        )
    else
        hitChance = Accuracy.miningHitChance(accCfg)
    end
    -- Crit CHANCE buff (combat + mining), source-agnostic: a PLAYER power (Critical Strike, CritBuff)
    -- and a PET support aura (a crit-buffer pet, CritAura) are SEPARATE channels that ADD — same as
    -- offense (Mountain's Strength power + emberimp aura). Clamped < 1 so it never guarantees a crit.
    local critChance = (petAtkRoll and petAtkRoll.crit_chance) or 0
    local critAdd = 0
    if (player:GetAttribute("CritBuffUntil") or 0) > nowT then
        critAdd = critAdd + (player:GetAttribute("CritBuff") or 0)
    end
    if (player:GetAttribute("CritAuraUntil") or 0) > nowT then
        critAdd = critAdd + (player:GetAttribute("CritAura") or 0)
    end
    critChance = math.min(
        critChance + critAdd + (tonumber(abilityProc and abilityProc.crit_chance) or 0),
        0.9
    )
    local roll = CombatRoll.resolve({
        hit_chance = hitChance,
        crit_chance = critChance,
        crit_mult = petAtkRoll and petAtkRoll.crit_mult,
    }, math.random(), math.random())
    dmg = dmg * roll.multiplier
    pet:SetAttribute("LastHitCrit", roll.crit) -- for floating-text feedback (later)

    -- Fire-rate <-> damage pacing: harder hits on a slower cadence (or vice versa). damage_mult
    -- here, interval_mult on _nextHit below; equal values keep DPS constant.
    local pacing = self._combatConfig.pet_attack_pacing or {}
    dmg = dmg * (tonumber(pacing.damage_mult) or 1)

    -- Active-mining boost: the player builds a node's Boost by clicking it (BreakableSpawner),
    -- which amplifies their pets' damage on that node — rewards active over passive play.
    -- Firewall-clean: the player amplifies, the pets still deal. Decays when they stop clicking.
    dmg = dmg
        * BreakableBoost.multiplier(
            breakable:GetAttribute("Boost"),
            breakable:GetAttribute("MaxBoost"),
            breakable:GetAttribute("BoostDamageBonus")
        )

    dmg = math.floor(dmg + 0.5)

    -- Shatter damage proof: only logs while Shatter's own vulnerability channel is live, so the
    -- master combat trace shows the actual before/after damage without flooding every ordinary hit.
    if
        self._combatConfig
        and self._combatConfig.combat_trace
        and breakable:GetAttribute("EnemyId")
    then
        local shatterFraction = VulnMark.liveFraction(
            breakable:GetAttribute(VulnMark.attr("shatter")),
            breakable:GetAttribute(VulnMark.untilAttr("shatter")),
            nowT
        )
        if shatterFraction > 0 then
            local outcome = roll.hit
                    and string.format("final=%d%s", dmg, roll.crit and " CRIT" or "")
                or "MISS"
            print(
                string.format(
                    "[ShatterDamage] %s -> %s preVuln=%.1f shatter=x%.2f totalVuln=x%.2f postVuln=%.1f %s",
                    tostring(pet:GetAttribute("PetType") or pet.Name),
                    tostring(breakable:GetAttribute("EnemyId") or breakable.Name),
                    preVulnerabilityDmg,
                    1 + shatterFraction,
                    vulnerabilityMult,
                    postVulnerabilityDmg,
                    outcome
                )
            )
        end
    end

    -- [RageTrace] (Jason balance pass): while a pet is RAGING and hitting an ENEMY, log its endurance
    -- + this hit's damage, so we can watch the "critical" bonus climb as the pet drops. Gated on
    -- combat.combat_trace + RagePowerUntil + EnemyId so it never floods a normal run.
    if
        self._combatConfig
        and self._combatConfig.combat_trace
        and (pet:GetAttribute("RagePowerUntil") or 0) > nowT
        and breakable:GetAttribute("EnemyId")
    then
        local ragePowerNV = pet:FindFirstChild("Power")
        local ragePow = (ragePowerNV and tonumber(ragePowerNV.Value)) or 0
        local rageFactor = (self._combatConfig and self._combatConfig.pet_down_threshold_factor)
            or 1
        local rageTaken = pet:GetAttribute("CombatDamageTaken") or 0
        local rageMaxEnd = PetEndurance.maxEndurance(ragePow, rageFactor)
        local rageFrac = PetEndurance.healthFraction(rageTaken, ragePow, rageFactor)
        print(
            string.format(
                "[RageTrace] %s endurance=%d/%d (%.0f%%) rageBonus=+%.0f%% hit=%d%s",
                tostring(pet:GetAttribute("PetType") or pet.Name),
                math.floor(rageMaxEnd * rageFrac + 0.5),
                math.floor(rageMaxEnd + 0.5),
                rageFrac * 100,
                self:_ragePowerFraction(pet) * 100,
                dmg,
                roll.crit and " CRIT" or ""
            )
        )
    end

    local playerPetKillUserId = pet:GetAttribute("PetRecordKey") ~= nil and player.UserId or nil
    local applied = CombatApplication.ApplyHit(breakable, {
        outcome = roll.multiplier <= 0 and "miss" or "damage",
        amount = dmg,
        crit = roll.crit,
        source = pet,
        sourcePlayer = player,
        playerPetKillUserId = playerPetKillUserId,
        kind = "pet_attack",
    })

    -- Damage builds aggro: hurting an enemy makes it want to attack this pet (the threat
    -- table the enemy targets from) and engages the pet (InCombat / battle music). Only
    -- enemies carry an EnemyId; crystals don't. An absorb still connected — credit the
    -- swing so a shielded training dog keeps the fight on.
    local aggroCredit = applied.contributed
    if aggroCredit <= 0 and applied.outcome == "absorbed" then
        aggroCredit = dmg
    end
    if breakable:GetAttribute("EnemyId") and aggroCredit > 0 then
        local enemyService = self:_enemyService()
        if enemyService then
            local factor = (
                self._combatConfig.engagement
                and self._combatConfig.engagement.aggro
                and self._combatConfig.engagement.aggro.damage_factor
            ) or 1
            enemyService:AddAggro(breakable, pet, aggroCredit * factor)
        end
    end

    -- DoT (burn/poison/bleed): a pet with attack_dot stamps a ticking burn on the ENEMY it hit —
    -- orthogonal to targeting, so it rides on top of single/aoe alike. perTick = a fraction of THIS
    -- hit (DamageOverTime.perTick); EnemyService:_dotPass applies the ticks. Re-hit refreshes the
    -- window and keeps the STRONGER per-tick (a fresh weak hit never weakens an existing burn).
    -- Crystals don't burn (no EnemyId). Stored as flat attributes the dot pass reads.
    -- burnProfile resolves the pet's per-pet burn+spread tuning once; reused below to ignite the
    -- whole AoE-splash cluster (so an AoE-contagion pet lights every splashed enemy, each of which
    -- then spreads — the "AoE contagion" combo). spread present = contagious. CONTAGION arming is
    -- arm-once inside stampBurn: re-stamping every swing pushed the spread timer back so a
    -- continuously-hit primary almost never reached it (Jason: "1 in 20"); the spread pass zeroes
    -- ContagionSpreadAt after it fires, so a later hit re-arms it for the next hop.
    local burn = burnProfile(pet, self._combatConfig.pet_contagion)
    if not burn and abilityProc and abilityProc.damage_over_time == true then
        local abilityDot = self._combatConfig.pet_ability_runtime
                and self._combatConfig.pet_ability_runtime.reality_burn
            or {}
        burn = {
            fraction = tonumber(abilityDot.fraction) or 0.2,
            interval = tonumber(abilityDot.interval) or 1,
            duration = tonumber(abilityDot.duration) or 4,
        }
    end
    if breakable:GetAttribute("EnemyId") and applied.contributed > 0 and burn then
        local perTick = DamageOverTime.perTick(applied.contributed, burn.fraction)
        self:_ensureResonanceConfigs()
        local burnEl = self._petElementMap and self._petElementMap[pet:GetAttribute("PetType")]
        stampBurn(
            breakable,
            perTick,
            burn.interval,
            burn.duration,
            player.UserId,
            burn.spread,
            os.clock(),
            burnEl,
            playerPetKillUserId
        )
    end
    -- On-hit control/shred (orthogonal to the burn) on the primary target.
    if breakable:GetAttribute("EnemyId") and applied.contributed > 0 then
        applyOnHit(breakable, pet, nowT)
        local stun = tonumber(abilityProc and abilityProc.stun_duration) or 0
        if stun > 0 then
            breakable:SetAttribute(
                "HeldUntil",
                math.max(tonumber(breakable:GetAttribute("HeldUntil")) or 0, nowT + stun)
            )
        end
    end

    -- PET AoE (PetTargeting attack_targeting = "aoe" / "targeted_aoe"): an AoE pet's swing splashes
    -- x frac to OTHER targets near the primary — nearby enemies mid-fight, nearby crystals when
    -- mining. Driven by the pet's damage-targeting SSOT (the same value that rings its archetype
    -- badge), resolved into the AttackTargeting attribute at spawn. Candidate set = siblings in the
    -- primary's container (enemies→enemies, crystals→crystals). Credited to the pet (Contrib) so
    -- kills/payouts count; silent like the cleave (the HP drops are the AoE tell).
    local atkScope = pet:GetAttribute("AttackTargeting") or "single"
    if
        dmg > 0
        and (
            atkScope == "aoe"
            or atkScope == "targeted_aoe"
            or (abilityProc and abilityProc.area_damage == true)
        )
    then
        local aoeCfg = self._combatConfig.pet_aoe or {}
        -- Per-pet AoE override (attack_aoe, stamped at spawn) wins over the global pet_aoe default —
        -- the knob board for a wider/harder-splash pet. A stamped 0 means "unset → use the default".
        local pFrac = tonumber(pet:GetAttribute("AoeSplashFraction")) or 0
        local pRadius = tonumber(pet:GetAttribute("AoeSplashRadius")) or 0
        local pTargets = tonumber(pet:GetAttribute("AoeMaxTargets")) or 0
        local frac = pFrac > 0 and pFrac or (tonumber(aoeCfg.splash_fraction) or 0.5)
        local radius = pRadius > 0 and pRadius or (tonumber(aoeCfg.splash_radius) or 12)
        local maxTargets =
            math.floor(pTargets > 0 and pTargets or (tonumber(aoeCfg.max_targets) or 5))
        local splash = math.floor(dmg * frac + 0.5)
        local container = breakable.Parent
        local origin = targetPosition(breakable)
        -- AoE ATTACK VISUAL: an element-themed eruption at the cluster — reuses the power AreaFX
        -- channel (Power_AreaFx → AreaFX.Play + CombatFX.groundField burst). Pass the PET'S element so
        -- a grass/ice/desert AoE pet shows ITS burst (earth = green sphere, no orange explosion, no
        -- DoT), not the borrowed fire look. Falls back to lava only when a pet has no mapped element
        -- (the dragon breathes fire). The DoT burn is a SEPARATE layer (contagion arming below), so a
        -- non-fire AoE never ignites. Shared to the owner + nearby spectators.
        self:_ensureResonanceConfigs()
        local element = (self._petElementMap and self._petElementMap[pet:GetAttribute("PetType")])
            or "lava"
        Signals.Power_AreaFx:FireClient(
            player,
            { center = origin, variant = "self", radius = radius, element = element }
        )
        for _, sp in ipairs(Players:GetPlayers()) do
            if sp ~= player then
                local shrp = sp.Character and sp.Character:FindFirstChild("HumanoidRootPart")
                if shrp and (shrp.Position - origin).Magnitude <= 80 then
                    Signals.Power_AreaFx:FireClient(
                        sp,
                        { center = origin, variant = "self", radius = radius, element = element }
                    )
                end
            end
        end
        if splash > 0 and container then
            local hitN = 0
            for _, other in ipairs(container:GetChildren()) do
                if hitN >= maxTargets then
                    break
                end
                if
                    other ~= breakable
                    and other:IsA("Model")
                    and (other:GetAttribute("HP") or 0) > 0
                then
                    local otherPos = targetPosition(other)
                    if (otherPos - origin).Magnitude <= radius then
                        CombatApplication.ApplyDamage(other, splash, {
                            source = pet,
                            sourcePlayer = player,
                            playerPetKillUserId = playerPetKillUserId,
                            kind = "pet_aoe",
                            element = element,
                        })
                        -- AoE-CONTAGION: a splash target that's an enemy also catches the burn (scaled
                        -- off the SPLASH damage), and — if the burn is contagious — arms its own hop.
                        -- So the swing ignites the whole cluster and each ignited enemy then spreads.
                        if other:GetAttribute("EnemyId") then
                            if burn then
                                stampBurn(
                                    other,
                                    DamageOverTime.perTick(splash, burn.fraction),
                                    burn.interval,
                                    burn.duration,
                                    player.UserId,
                                    burn.spread,
                                    os.clock(),
                                    element, -- pet element (resolved for the AoE burst above)
                                    playerPetKillUserId
                                )
                            end
                            -- on-hit control/shred hits the whole splash cluster too (AoE control /
                            -- AoE shred when the pet has targeted_aoe geometry).
                            applyOnHit(other, pet, nowT)
                        end
                        hitN += 1
                    end
                end
            end
        end
    end

    -- Firestorm (team_cleave): while the player's TeamCleave is active, a pet's swing on an enemy
    -- also splashes x frac to OTHER enemies within cleave_radius of the target (credited to pets).
    if
        dmg > 0
        and breakable:GetAttribute("EnemyId")
        and (player:GetAttribute("TeamCleaveUntil") or 0) > os.time()
    then
        local frac = tonumber(player:GetAttribute("TeamCleaveFrac")) or 0.5
        local radius = tonumber(player:GetAttribute("TeamCleaveRadius")) or 8
        local splash = math.floor(dmg * frac + 0.5)
        local enemiesFolder = Workspace:FindFirstChild("Game")
            and Workspace.Game:FindFirstChild("Enemies")
        local tp = targetPosition(breakable)
        if splash > 0 and enemiesFolder then
            for _, e in ipairs(enemiesFolder:GetChildren()) do
                if e ~= breakable and e:IsA("Model") and (e:GetAttribute("HP") or 0) > 0 then
                    local enemyPos = targetPosition(e)
                    if (enemyPos - tp).Magnitude <= radius then
                        CombatApplication.ApplyDamage(e, splash, {
                            source = pet,
                            sourcePlayer = player,
                            playerPetKillUserId = playerPetKillUserId,
                            kind = "team_cleave",
                        })
                    end
                end
            end
        end
    end

    local hitInterval = combat:ResolvePetAttackInterval(player, ctx)
        * (tonumber(pacing.interval_mult) or 1)
    -- HASTE aura (efficiency-as-aura): a multiplier that SHORTENS the interval. Two channels — the
    -- TEAM buff (PetHasteBuff, player attr) and a per-PET buff (PetHasteBuffSelf, single/targeted_aoe
    -- variant from _auraScopedBuff) — combine, then the total is bounded to <=2.5x so a stack can't
    -- drive attacks to instant.
    local nowSec = os.time()
    local hasteMult = 1
    if (player:GetAttribute("PetHasteBuffUntil") or 0) > nowSec then
        hasteMult = hasteMult * (tonumber(player:GetAttribute("PetHasteBuff")) or 1)
    end
    if (pet:GetAttribute("PetHasteBuffSelfUntil") or 0) > nowSec then
        hasteMult = hasteMult * (tonumber(pet:GetAttribute("PetHasteBuffSelf")) or 1)
    end
    hitInterval = hitInterval / math.clamp(hasteMult, 1, 2.5)
    hitInterval = CombatCadence.interval(hitInterval, pet:GetAttribute("CombatCadenceMultiplier"))
    self._nextHit[pet] = now + hitInterval

    -- Drive the attack VISUAL off the real hit: tell the owning client to play this pet's
    -- effect (bolt/projectile for ranged, impact for melee) at this exact moment + target, so
    -- the animation, impact, sound, crit AND the floating damage number are the swing that
    -- actually happened — not a parallel client timer.
    local hit = {
        pet = pet,
        target = breakable,
        crit = roll.crit,
        amount = applied.contributed, -- actual authoritative HP delta (0 on a miss/overkill remainder)
        miss = roll.multiplier <= 0,
    }
    Signals.Combat_PetHit:FireClient(player, hit)
    -- SPECTATORS (Jason: "this is supposed to be a team effect game" — other players'
    -- pets mined in silence with no effects): fan the same hit out to every OTHER
    -- player near the target. The FULL presentation is shared — bolt/impact/sound AND
    -- the damage stream off the target; only private events (achievements, hatching)
    -- stay owner-only. foreign = true marks the copy for any future client-side needs.
    local bRange = tonumber(
        self._combatConfig.pet_hit_broadcast_range
            or (self._combatConfig.engagement and self._combatConfig.engagement.perception_range)
    ) or 80
    local tp = targetPosition(breakable)
    hit.foreign = true
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= player then
            local hrp = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
            if hrp and (hrp.Position - tp).Magnitude <= bRange then
                Signals.Combat_PetHit:FireClient(other, hit)
            end
        end
    end
end

-- Load + cache the resonance configs once (elements + combat_fx pettype_element + areas zones +
-- pets). Both resonance helpers call this, so neither can partial-load and leave the other blind.
function PetFollowService:_ensureResonanceConfigs()
    if self._elementsConfig ~= nil then
        return
    end
    local function tryReq(name)
        local ok, cfg = pcall(function()
            return require(game:GetService("ReplicatedStorage").Configs:WaitForChild(name))
        end)
        return ok and cfg or nil
    end
    local elements, fx, areas, pets =
        tryReq("elements"), tryReq("combat_fx"), tryReq("areas"), tryReq("pets")
    self._elementsConfig = elements or false
    self._petElementMap = (fx and fx.origin and fx.origin.pettype_element) or {}
    self._zonesConfig = (areas and areas.zones) or {}
    self._petsByType = (pets and pets.pets) or {}
end

-- Zone-resonance multiplier for a pet right now: biome RPS (its element vs the zone it stands in).
function PetFollowService:_zoneResonance(player, pet)
    self:_ensureResonanceConfigs()
    if not self._elementsConfig then
        return 1
    end
    local petElement = self._petElementMap[pet:GetAttribute("PetType")]
    local zone = self._zonesConfig[tostring(player:GetAttribute("CurrentArea"))]
    local zoneElement = zone and zone.element
    local homeWorldBonus = 0
    if self._enchantServiceInstance then
        homeWorldBonus = self._enchantServiceInstance:GetPetEffectMagnitude(
            player,
            pet:GetAttribute("PetRecordKey"),
            "home_world"
        )
    end
    if (pet:GetAttribute("HomeWorldBonus") or 0) ~= homeWorldBonus then
        pet:SetAttribute("HomeWorldBonus", homeWorldBonus)
    end
    return ElementResonance.biomeMultiplierWithFloor(
        petElement,
        zoneElement,
        self._elementsConfig,
        homeWorldBonus
    )
end

-- Cross-realm resonance: a pet's ALIGNMENT (light = Heaven species, shadow = Hell species, else
-- neutral — derived game-wide from the species' `realm`, no per-pet storage) vs the realm the
-- player stands in (CurrentRealm). Heaven pets hit 1.5x in Hell / 0.8x at home and vice versa
-- (configs/elements.lua resonance); homeworld/neutral pets stay 1.0x. This is the cross-realm
-- value + trade driver — applied to BOTH mining and combat output via the resolver's contextMult.
function PetFollowService:_realmResonance(player, pet)
    self:_ensureResonanceConfigs()
    if not self._elementsConfig then
        return 1
    end
    local petDef = self._petsByType[pet:GetAttribute("PetType")]
    local playerRealm = player:GetAttribute("CurrentRealm") or "neutral"
    return ElementResonance.petRealmMultiplier(
        petDef and petDef.realm,
        playerRealm,
        self._elementsConfig
    )
end

-- Team-composition bonus: scan the player's ACTIVE squad (deployed pets), tag each by archetype
-- (pet_roles) + origin (biome element), and apply the SquadDiversity multiplier to the WHOLE team's
-- output. It's squad-level (identical for every pet), so it's cached per player and recomputed when
-- stale rather than per hit. Also published as SquadDiversityMult for the HUD readout.
function PetFollowService:_squadDiversity(player)
    local cfg = self._squadDiversityConfig
    if not cfg or cfg.enabled == false then
        return 1
    end
    local now = os.clock()
    local cached = self._diversityCache[player]
    if cached and (now - cached.t) < 0.5 then
        return cached.mult
    end
    self:_ensureResonanceConfigs() -- ensures _petElementMap (origin tags) is loaded
    local byType = (self._petRoles and self._petRoles.by_type) or {}
    local defaultRole = (self._petRoles and self._petRoles.default) or "melee"
    local members = {}
    local folder = Workspace:FindFirstChild("PlayerPets")
        and Workspace.PlayerPets:FindFirstChild(player.Name)
    if folder then
        for _, pet in ipairs(folder:GetChildren()) do
            local pt = pet:GetAttribute("PetType")
            if pt then
                members[#members + 1] = {
                    archetype = byType[pt] or defaultRole,
                    origin = self._petElementMap[pt],
                }
            end
        end
    end
    local result = SquadDiversity.evaluate(members, cfg)
    self._diversityCache[player] = { mult = result.mult, t = now }
    player:SetAttribute("SquadDiversityMult", result.mult)
    return result.mult
end

-- Drive one PRINCIPAL's squad. Takes a principal (docs/CREATOR_SUMMON.md), not a Player: a
-- summoned Creator NPC owns a pet folder exactly like a player does, and without this its
-- pets would never move, mine, or fight — nothing was iterating them.
-- `player` here is the principal's `.instance` for the many downstream calls still keyed on
-- a Player; those migrate one at a time behind the same contract.
function PetFollowService:_tickPrincipal(principal)
    local principalInstance = principal.instance
    local rewardPlayer = principal.owner or principalInstance
    if not principalInstance or not rewardPlayer then
        return
    end
    local character = principal.character or principalInstance.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    local petsFolder = Workspace:FindFirstChild("PlayerPets")
        and Workspace.PlayerPets:FindFirstChild(Principal.petFolderName(principal))
    if not hrp or not petsFolder then
        return
    end

    for _, pet in ipairs(petsFolder:GetChildren()) do
        if pet:IsA("Model") and pet.PrimaryPart then
            self:_prepPet(pet)
            local targetId = pet:FindFirstChild("TargetID")
            local liveTarget
            if targetId and targetId.Value ~= 0 then
                local targetType = pet:FindFirstChild("TargetType")
                local targetWorld = pet:FindFirstChild("TargetWorld")
                local breakable = self:_findBreakable(
                    targetType and targetType.Value,
                    targetWorld and targetWorld.Value,
                    targetId.Value
                )
                -- Clear ONLY when the target is gone (mined out / removed), like the
                -- legacy script — never on distance. AutoTargetService owns target
                -- selection + range; a distance leash here fought it and made the
                -- pet flicker between attack and follow during auto-mining.
                local releaseMining = breakable
                    and targetType
                    and string.lower(tostring(targetType.Value)) == "crystals"
                    and self:_releaseMiningTarget(rewardPlayer, breakable)
                if not breakable or releaseMining then
                    -- A missing target follows immediately. Finishing an assigned crystal is
                    -- sticky only while the owner remains outside combat and inside the
                    -- acquisition radius; a fight or walking away also releases the pet.
                    targetId.Value = 0
                else
                    liveTarget = breakable
                end
            end
            if Principal.isNpc(principal) then
                self:_stepNpcCombatPosition(principal, pet, hrp, liveTarget)
            end
            if liveTarget then
                -- An NPC principal's folder remains visually/behaviorally owned by its manifested
                -- character, but rewards and contribution belong to the real owning player.
                self:_mine(rewardPlayer, pet, liveTarget)
            end
        end
    end
end

function PetFollowService:_tick()
    -- Principals, not Players: live players PLUS registered NPC principals (the Creator
    -- summon). Player principals resolve to the same Player objects with the same levels,
    -- so this is behaviour-identical for everyone who was already being ticked.
    for _, principal in ipairs(Principal.all(PRINCIPAL_CTX)) do
        self:_tickPrincipal(principal)
    end
end

return PetFollowService
