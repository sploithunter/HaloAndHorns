--[[
    NpcPrincipalService — spawns and drives NPC PRINCIPALS (docs/CREATOR_SUMMON.md).

    A principal is a second player-shaped entity: it owns a pet folder, holds a combat level,
    and can anchor a TEMPORARY ALLIANCE. That is what makes the Creator summon more than a
    guardian — nearby low players actually sidekick UP to it, on the shipping AllianceRules
    path, and its squad fights because PetFollowService now ticks principals rather than
    Players.

    WHAT THIS SERVICE OWNS
      • the character (avatar via HumanoidDescription, or a placeholder rig)
      • the GHOST squad — plain pet models parented into workspace.PlayerPets/<name>, with NO
        inventory records anywhere (they are not owned, they are manifested)
      • registration into the Principal registry, so the rest of the game can see it
      • alliance formation on summon / teardown on despawn
      • follow movement for the character itself

    WHAT IT DELIBERATELY DOES NOT OWN
      • pet movement/combat — PetFollowService drives the folder, exactly like a player's
      • the alliance MATH — Shared/Game/AllianceRules, unchanged, one implementation

    PROFILE ISOLATION: nothing here touches any player's saved data. A summon grants nothing
    and costs nothing; a crash mid-window leaves models to clean up and no persistent state.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Principal = require(ReplicatedStorage.Shared.Game.Principal)
local AllianceRules = require(ReplicatedStorage.Shared.Game.AllianceRules)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local VulnMark = require(ReplicatedStorage.Shared.Game.VulnMark)
local ResSickness = require(ReplicatedStorage.Shared.Game.ResSickness)
local CombatApplication = require(script.Parent.Parent.CombatApplication)

local NpcPrincipalService = {}
NpcPrincipalService.__index = NpcPrincipalService

function NpcPrincipalService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._playerProgressionService = self._modules and self._modules.PlayerProgressionService
    self._summonService = self._modules and self._modules.SummonService
    self._config = (self._configLoader and self._configLoader:LoadConfig("creator"))
        or require(ReplicatedStorage.Configs:WaitForChild("creator"))
    self._powersConfig = (self._configLoader and self._configLoader:LoadConfig("powers"))
        or require(ReplicatedStorage.Configs:WaitForChild("powers"))
    self._active = {} -- name -> { model, folder, expireAt, owner, allied = {player,...} }
end

function NpcPrincipalService:Start()
    task.spawn(function()
        while true do
            self:_step(os.clock())
            task.wait(0.2)
        end
    end)
end

function NpcPrincipalService:_log(level, msg, data)
    if self._logger and self._logger[level] then
        self._logger[level](self._logger, msg, data)
    end
end

-- ── Character ───────────────────────────────────────────────────────────────────────

-- Build the NPC's body. A real user's appearance if `avatar_user_id` is set (and the fetch
-- succeeds — it's a web call, so it is pcall'd and degrades to the placeholder rig rather
-- than failing the whole summon).
function NpcPrincipalService:_buildCharacter(def, cf)
    local model
    local userId = tonumber(def.avatar_user_id)
    if userId then
        local ok, desc = pcall(function()
            return Players:GetHumanoidDescriptionFromUserId(userId)
        end)
        if ok and desc then
            local ok2, rig = pcall(function()
                return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
            end)
            if ok2 and rig then
                model = rig
            end
        end
    end
    if not model then
        -- Placeholder rig: the summon must still work when the avatar fetch fails.
        model = Instance.new("Model")
        local root = Instance.new("Part")
        root.Name = "HumanoidRootPart"
        root.Size = Vector3.new(2, 2, 1)
        root.Anchored = true
        root.CanCollide = false
        root.Parent = model
        model.PrimaryPart = root
        Instance.new("Humanoid").Parent = model
        self:_log("Warn", "NPC principal: avatar unavailable, using placeholder rig", {
            npc = def.name,
        })
    end

    model.Name = def.name

    -- DO NOT ANCHOR A CHARACTER. An R15 rig is held together and animated by Motor6D joints;
    -- anchoring the parts destroys them. The first version here copied the PET contract
    -- (anchored + server-pivoted) onto a humanoid, and Jason's screenshot showed the result:
    -- a dressed body with the hat and collar floating where a head should be, sliding around
    -- with no walk animation. Live inspection: 18 parts, **0 Motor6Ds**, so nothing held the
    -- head on and the Animator had nothing to drive.
    --
    -- Pets can be anchored because they're single-mesh, jointless models. A character is the
    -- opposite: leave it unanchored, let the Humanoid own it, and Roblox's default walk/run/
    -- idle animations play for free.
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = tonumber(def.walk_speed) or 24 -- brisk enough to keep up with a player
        hum.DisplayName = def.display_name or def.name
    end
    model:PivotTo(cf)
    -- Server keeps network ownership so no client can be handed the NPC's physics.
    local hrp = model:FindFirstChild("HumanoidRootPart")
    if hrp then
        pcall(function()
            hrp:SetNetworkOwner(nil)
        end)
    end
    self:_driveAnimations(model)
    model:SetAttribute("NpcPrincipal", true)
    model:SetAttribute("Level", tonumber(def.level) or 50)
    model:SetAttribute("EffectiveLevel", tonumber(def.level) or 50)
    model:SetAttribute("DisplayName", def.display_name or def.name)
    return model
end

-- Idle/walk animation for the NPC.
--
-- A PLAYER's character gets a stock `Animate` LocalScript that plays walk/run/idle off the
-- Humanoid's state. A rig built from a HumanoidDescription does NOT — so the NPC assembled
-- and walked correctly but stood perfectly still while sliding (live: MoveState=Running,
-- playingAnims=none). Since an NPC has no client to run a LocalScript, drive the Animator
-- from the server off Humanoid.Running instead.
local R15_IDLE = "rbxassetid://507766388"
local R15_WALK = "rbxassetid://507777826"

function NpcPrincipalService:_driveAnimations(model)
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum then
        return
    end
    local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator")
    animator.Parent = hum

    local function load(id)
        local a = Instance.new("Animation")
        a.AnimationId = id
        local ok, track = pcall(function()
            return animator:LoadAnimation(a)
        end)
        return ok and track or nil
    end

    local idle, walk = load(R15_IDLE), load(R15_WALK)
    if idle then
        idle.Looped = true
        idle:Play()
    end
    if walk then
        walk.Looped = true
    end

    -- Crossfade on the Running signal: speed > 0 means locomotion.
    hum.Running:Connect(function(speed)
        if speed > 0.1 then
            if walk and not walk.IsPlaying then
                walk:Play(0.15)
            end
            if idle and idle.IsPlaying then
                idle:Stop(0.15)
            end
            if walk then
                -- scale playback so a brisk WalkSpeed doesn't look like a moonwalk
                walk:AdjustSpeed(math.clamp(speed / 16, 0.5, 2))
            end
        else
            if walk and walk.IsPlaying then
                walk:Stop(0.15)
            end
            if idle and not idle.IsPlaying then
                idle:Play(0.15)
            end
        end
    end)
end

-- ── Ghost squad ─────────────────────────────────────────────────────────────────────

-- Clone a pet model from the same ReplicatedStorage tree PetHandler uses. Returns nil if the
-- type/variant isn't present rather than substituting something surprising.
function NpcPrincipalService:_clonePet(petId, variant)
    -- ReplicatedStorage.ASSETS.Models.Pets — the same root PetHandler clones from. (An earlier
    -- guess at ReplicatedStorage.Models silently produced a zero-pet squad: the folder simply
    -- doesn't exist, and every lookup short-circuited to nil.)
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    local models = assets and assets:FindFirstChild("Models")
    local pets = models and models:FindFirstChild("Pets")
    local typeFolder = pets and pets:FindFirstChild(petId)
    if not typeFolder then
        return nil
    end
    local proto = typeFolder:FindFirstChild(variant or "basic")
        or typeFolder:FindFirstChild("basic")
    if not proto then
        return nil
    end
    local model = proto:Clone()
    -- The AUTHORED prototypes carry no PrimaryPart — PetHandler assigns one after cloning,
    -- preferring a Face/Head part. Same rule here; without it every consumer that guards on
    -- `pet.PrimaryPart` silently skips the model (caught live: the squad spawned but never
    -- ticked, because PetFollowService's loop requires a PrimaryPart).
    if not model.PrimaryPart then
        local candidate
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("BasePart") then
                local n = string.lower(d.Name)
                if string.find(n, "face") or string.find(n, "head") then
                    candidate = d
                    break
                end
                candidate = candidate or d
            end
        end
        model.PrimaryPart = candidate
    end
    if not model.PrimaryPart then
        return nil -- unusable model; the caller logs and carries on
    end
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored = true -- server-pivoted, same contract as player pets
            d.CanCollide = false
        end
    end
    model:SetAttribute("PetType", petId)
    model:SetAttribute("PetVariant", variant or "basic")
    -- GHOST MARKER: these are manifested, not owned. Anything that reconciles pets against
    -- inventory must skip them rather than "correct" them out of existence.
    model:SetAttribute("GhostPet", true)
    return model
end

-- PUBLIC: spawn ghost pets into an EXISTING folder without wiping it (the prologue grants
-- the player a temporary squad this way — Jason: "one of every dragon plus a huge Ent for a
-- tank"). Each entry: { pet, variant, huge }. Huge applies the same relative ScaleTo the
-- real hatch path uses (pets.lua asset_transform.huge_scale). Returns count spawned.
function NpcPrincipalService:SpawnGhostSquad(folder, squad, originCf)
    if not folder then
        return 0
    end
    local petsConfig
    pcall(function()
        petsConfig = require(ReplicatedStorage.Configs:WaitForChild("pets"))
    end)
    local spawned = 0
    for i, entry in ipairs(squad or {}) do
        local model = self:_clonePet(entry.pet, entry.variant)
        if model then
            -- Clone source is Pets/<pet>/<variant>, so the clone arrives named "rainbow" —
            -- name it by PET (indexed: duplicates share a folder) for HUD/config lookups.
            model.Name = ("%s_%d"):format(entry.pet, i)
            -- Stamp what the squad HUD + formation drive read off a REAL pet. PositionNumber
            -- is the card key AND the formation slot — the prototype's default collapses all
            -- ten ghosts into one card (live-caught: only "Aurora Dragon" showed).
            local pn = model:FindFirstChild("PositionNumber")
            if not pn then
                pn = Instance.new("IntValue")
                pn.Name = "PositionNumber"
                pn.Parent = model
            end
            pn.Value = i
            model:SetAttribute("PetType", entry.pet)
            model:SetAttribute("Variant", entry.variant or "basic")
            -- Damage + HUD endurance both read the Power NUMBERVALUE (the prototype carries
            -- the pet's real base_power via AddPetSystemComponents) — ghosts hit like the
            -- dragons they are, no synthetic stat.
            if entry.huge then
                local raw = petsConfig and petsConfig.pets and petsConfig.pets[entry.pet]
                local hugeScale = raw
                    and raw.asset_transform
                    and tonumber(raw.asset_transform.huge_scale)
                if hugeScale and hugeScale > 1 then
                    pcall(function()
                        model:ScaleTo(model:GetScale() * hugeScale)
                    end)
                end
                model:SetAttribute("Huge", true)
            end
            model:PivotTo(originCf * CFrame.new((i - (#squad + 1) / 2) * 5, 0, 5))
            model.Parent = folder
            spawned += 1
        else
            self:_log("Warn", "ghost squad: pet model missing", {
                pet = tostring(entry.pet),
                variant = tostring(entry.variant),
            })
        end
    end
    return spawned
end

-- Spawn the squad into workspace.PlayerPets/<name>. That folder IS the interface: both
-- PetFollowService (movement/combat) and the client SquadHud read its children directly, so
-- ghost pets need no inventory record to behave — or to render.
function NpcPrincipalService:_spawnSquad(def, originCf)
    local root = Workspace:FindFirstChild("PlayerPets")
    if not root then
        root = Instance.new("Folder")
        root.Name = "PlayerPets"
        root.Parent = Workspace
    end
    -- HARD SAFETY: never touch a folder that belongs to a real player. The NPC's configured
    -- name is username-impossible (it contains spaces) so this shouldn't be reachable — but
    -- the destroy below would delete a live player's entire visible squad if it ever were,
    -- and that is not a failure mode worth leaving to configuration discipline.
    if Players:FindFirstChild(def.name) then
        self:_log("Error", "NPC principal: name collides with a live player — refusing", {
            npc = def.name,
        })
        return nil, 0
    end
    local folder = root:FindFirstChild(def.name)
    if folder then
        folder:Destroy() -- a re-summon replaces, never stacks
    end
    folder = Instance.new("Folder")
    folder.Name = def.name
    -- Marker the client EnemyMotion renderer looks for: this folder's pets are driven by
    -- MoveTarget, not by an owning player's client (there isn't one).
    folder:SetAttribute("NpcSquad", true)
    folder.Parent = root

    local spawned = 0
    for i, entry in ipairs(def.squad or {}) do
        local model = self:_clonePet(entry.pet, entry.variant)
        if model then
            model:PivotTo(originCf * CFrame.new(i * 4 - 6, 0, 4))
            model.Parent = folder
            spawned += 1
        else
            self:_log("Warn", "NPC principal: pet model missing", {
                npc = def.name,
                pet = tostring(entry.pet),
                variant = tostring(entry.variant),
            })
        end
    end
    return folder, spawned
end

-- ── Alliance ────────────────────────────────────────────────────────────────────────

-- Ally nearby unteamed players to this NPC. The GATE and the LIFT are the shipping ones
-- (AllianceRules + the AllianceAnchor attribute the progression service reads) — this is a
-- new *caller*, not a parallel implementation.
function NpcPrincipalService:_formAlliance(def, rec)
    local aCfg = def.alliance or {}
    if aCfg.enabled == false then
        return
    end
    local radius = tonumber(aCfg.radius) or 90
    local origin = rec.model and rec.model:GetPivot().Position
    if not origin then
        return
    end
    local teamingCfg = {}
    pcall(function()
        teamingCfg = require(ReplicatedStorage.Configs:WaitForChild("teaming")) or {}
    end)
    local allianceCfg = teamingCfg.alliance or {}
    local npcLevel = tonumber(def.level) or 50

    for _, player in ipairs(Players:GetPlayers()) do
        if player:GetAttribute("TeamId") == nil then
            local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if hrp and (hrp.Position - origin).Magnitude <= radius then
                local lvl = tonumber(player:GetAttribute("Level")) or 1
                if
                    AllianceRules.shouldAlly(npcLevel, lvl, {
                        enabled = allianceCfg.enabled,
                        min_level_gap = allianceCfg.min_level_gap,
                    })
                then
                    player:SetAttribute("AllianceAnchor", def.name)
                    player:SetAttribute("AllianceWith", def.name)
                    self:_republishEffective(player)
                    table.insert(rec.allied, player)
                    self:_log("Info", "NPC alliance formed", {
                        npc = def.name,
                        player = player.Name,
                        playerLevel = lvl,
                    })
                end
            end
        end
    end
end

-- Republish the player's EffectiveLevel so the lift lands immediately.
-- INJECTED, not a locator: `_G.RBXTemplateServices` is never assigned anywhere in this
-- codebase, so a locator lookup here silently no-ops inside the pcall and the sidekick lift
-- never appears (caught live — allied player stayed at level 1 with the anchor set).
-- BaddieSpawnerService uses the same injected-dependency pattern.
function NpcPrincipalService:_republishEffective(player)
    pcall(function()
        local prog = self._playerProgressionService
        if prog and prog.GetEffectiveLevel then
            player:SetAttribute("EffectiveLevel", prog:GetEffectiveLevel(player))
        end
    end)
end

function NpcPrincipalService:_dissolveAlliance(rec)
    for _, player in ipairs(rec.allied or {}) do
        if player and player.Parent then
            -- Only clear if we're still the anchor: a real player's alliance may have taken
            -- over in the meantime and must not be stomped by our teardown.
            if player:GetAttribute("AllianceAnchor") == rec.name then
                player:SetAttribute("AllianceAnchor", nil)
                player:SetAttribute("AllianceWith", nil)
                self:_republishEffective(player)
            end
        end
    end
    rec.allied = {}
end

-- ── Lifecycle ───────────────────────────────────────────────────────────────────────

-- Summon `npcId` next to `owner`. Returns ok, info.
function NpcPrincipalService:Summon(owner, npcId, opts)
    opts = opts or {}
    if self._config.enabled == false then
        return false, "npc principals disabled"
    end
    local def = self._config[npcId or "creator"]
    if type(def) ~= "table" then
        return false, "unknown npc principal: " .. tostring(npcId)
    end
    local hrp = owner and owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return false, "owner has no character"
    end

    self:Despawn(def.name) -- re-summon replaces

    local off = def.follow_offset or {}
    local cf = hrp.CFrame
        * CFrame.new(tonumber(off.x) or -8, tonumber(off.y) or 0, tonumber(off.z) or 6)
    -- Same collision guard as _spawnSquad, checked BEFORE anything is built: a real player
    -- with this name owns the Workspace model name, the pet folder, and every name-based
    -- alliance reference. Refuse rather than fight them for it.
    if Players:FindFirstChild(def.name) then
        return false, "name collides with a live player: " .. def.name
    end

    local model = self:_buildCharacter(def, cf)
    model.Parent = Workspace

    local folder, spawned = self:_spawnSquad(def, cf)
    if not folder then
        model:Destroy()
        return false, "squad spawn refused"
    end
    -- COMBAT PROXY: the NPC's squad fights AS THE OWNER's — EnemyService resolves NpcSquad
    -- folders through this attribute, so every player-keyed gate (territory, allegiance,
    -- team battle, assist focus) just works and kill credit flows to the summoner.
    folder:SetAttribute("NpcOwner", owner.Name)

    -- Register BEFORE the alliance forms: the anchor resolves by name through the registry,
    -- so an unregistered NPC would fail to lift anyone.
    Principal.register({
        name = def.name,
        level = def.level,
        character = model,
        petFolderName = def.name,
    })

    local rec = {
        name = def.name,
        def = def,
        model = model,
        folder = folder,
        owner = owner,
        expireAt = os.clock() + (tonumber(opts.duration) or tonumber(def.duration) or 20),
        allied = {},
    }
    self._active[def.name] = rec

    -- BASIC TEAMING (Jason: "Colorado should be teamed with you using the basic teaming").
    -- The team HUD is a pure function of the TeamMembers attribute, and the mate strip
    -- renders by NAME from workspace.PlayerPets — so stamping the roster is the whole
    -- integration. Never clobber a REAL party (TeamId set), and leave TeamId nil: every
    -- alliance path requires TeamId == nil, so the sidekick lift keeps working.
    if owner:GetAttribute("TeamId") == nil then
        local csv = owner.Name .. "," .. def.name
        owner:SetAttribute("TeamLead", owner.Name)
        owner:SetAttribute("TeamMembers", csv)
        rec.teamStamp = csv
    end

    -- Cast clocks for the rotation — staggered opens so the tells read one at a time.
    rec.castAt = {}
    for i in ipairs(def.powers or {}) do
        local entry = def.powers[i]
        rec.castAt[i] = os.clock() + (tonumber(entry.first) or (i * 3))
    end

    self:_formAlliance(def, rec)

    self:_log("Info", "NPC principal summoned", {
        npc = def.name,
        owner = owner.Name,
        pets = spawned,
        allied = #rec.allied,
    })
    return true, { name = def.name, pets = spawned, allied = #rec.allied }
end

function NpcPrincipalService:Despawn(name)
    local rec = self._active[name]
    if not rec then
        return false
    end
    self:_dissolveAlliance(rec)
    -- Retract the team stamp — only if it is still OURS (a real party formed since would
    -- have overwritten the csv, and PartyService owns it from then on).
    if rec.teamStamp and rec.owner and rec.owner.Parent then
        if rec.owner:GetAttribute("TeamMembers") == rec.teamStamp then
            rec.owner:SetAttribute("TeamMembers", nil)
            rec.owner:SetAttribute("TeamLead", nil)
        end
    end
    Principal.unregister(name)
    if rec.folder then
        rec.folder:Destroy()
    end
    if rec.model then
        rec.model:Destroy()
    end
    self._active[name] = nil
    self:_log("Info", "NPC principal despawned", { npc = name })
    return true
end

-- ── The Creator's cast rotation ────────────────────────────────────────────────────
-- Scripted casts (Jason: "Colorado should be casting several powers when that's going on").
-- PowerService:Cast is Player-hardwired down to FireClient (docs/CREATOR_SUMMON.md open
-- question #4), so the NPC composes the same primitives the real casts bottom out in:
-- Power_AreaFx broadcasts (caster may be any Instance — the enemy control-counter FX is
-- the precedent), CombatApplication heals, shield/badge attributes, VulnMark. Magnitudes
-- and durations are read from configs/powers.lua at cast time — the numbers stay SSOT.

local function livePetsOf(folder)
    local out = {}
    for _, m in ipairs(folder and folder:GetChildren() or {}) do
        if m:IsA("Model") and not m:GetAttribute("CombatDowned") then
            out[#out + 1] = m
        end
    end
    return out
end

-- The Creator's own ghosts + the summoner's squad: team_aoe semantics for a two-man team.
function NpcPrincipalService:_teamPets(rec)
    local out = livePetsOf(rec.folder)
    local pp = Workspace:FindFirstChild("PlayerPets")
    local ownerFolder = rec.owner and rec.owner.Parent and pp and pp:FindFirstChild(rec.owner.Name)
    for _, m in ipairs(livePetsOf(ownerFolder)) do
        out[#out + 1] = m
    end
    return out
end

local function liveEnemiesNear(pos, range)
    local out = {}
    local game_ = Workspace:FindFirstChild("Game")
    local enemies = game_ and game_:FindFirstChild("Enemies")
    for _, m in ipairs(enemies and enemies:GetChildren() or {}) do
        if (m:GetAttribute("HP") or 0) > 0 then
            local ok, pivot = pcall(m.GetPivot, m)
            if ok and (pivot.Position - pos).Magnitude <= range then
                out[#out + 1] = m
            end
        end
    end
    return out
end

function NpcPrincipalService:_castStep(rec, now)
    local powers = rec.def and rec.def.powers
    if type(powers) ~= "table" or not rec.model or not rec.model.Parent then
        return
    end
    -- powers only fly MID-BATTLE; outside combat the meander stays quiet
    if #liveEnemiesNear(rec.model:GetPivot().Position, 80) == 0 then
        return
    end
    for i, entry in ipairs(powers) do
        if now >= (rec.castAt and rec.castAt[i] or math.huge) then
            rec.castAt[i] = now + (tonumber(entry.every) or 15)
            local ok, err = pcall(function()
                self:_castPower(rec, tostring(entry.id))
            end)
            if not ok then
                self:_log("Warn", "NPC cast failed", { power = entry.id, err = tostring(err) })
            end
            break -- one cast per step: the tells read one at a time
        end
    end
end

function NpcPrincipalService:_castPower(rec, powerId)
    local cfg = self._powersConfig or {}
    local def = cfg.powers and cfg.powers[powerId]
    local kind = cfg.effect_kinds and cfg.effect_kinds[(def and def.effect) or powerId]
    if not def or not kind then
        self:_log("Warn", "NPC cast: unknown power", { power = powerId })
        return
    end
    local now = os.time()
    local family = kind.family
    local element = tostring(def.element or "desert")

    if family == "summon" then
        -- Genie of the Dunes: the REAL guardian via SummonService, summoned on the owner —
        -- its team folders are name-based, so the djinn serves the Creator's ghosts too.
        if self._summonService and rec.owner and rec.owner.Parent then
            self._summonService:Summon(rec.owner, kind, now, powerId)
        end
    elseif family == "absorb" then -- Mirage Veil
        Signals.Power_AreaFx:FireAllClients({
            primId = "shield_bubble",
            element = element,
            kind = "source",
            caster = rec.model,
        })
        local mag = tonumber(kind.magnitude) or 0
        local dur = tonumber(kind.duration) or 10
        for _, pet in ipairs(self:_teamPets(rec)) do
            pet:SetAttribute("CombatShieldPowerId", powerId)
            pet:SetAttribute("CombatShield", math.max(pet:GetAttribute("CombatShield") or 0, mag))
            pet:SetAttribute("CombatShieldUntil", now + dur)
            pet:SetAttribute("Power_" .. powerId .. "_Until", now + dur)
        end
    elseif family == "heal_blind" then -- Simoom: team heal + sand-scoured enemies
        Signals.Power_AreaFx:FireAllClients({
            primId = "heal_nova",
            element = element,
            kind = "source",
            caster = rec.model,
        })
        local mag = tonumber(kind.magnitude) or 0
        for _, pet in ipairs(self:_teamPets(rec)) do
            CombatApplication.ApplyPowerHeal(pet, mag, {
                resource = "pet_endurance",
                minimumTaken = ResSickness.floorFor(pet:GetAttributes(), now),
                fxUntil = now + 3,
                source = rec.name,
                kind = "power_heal",
            })
        end
        local vuln = tonumber(kind.vuln)
        if vuln and vuln > 1 then
            local dur = tonumber(kind.duration) or 6
            for _, m in ipairs(liveEnemiesNear(rec.model:GetPivot().Position, 30)) do
                VulnMark.apply(m, "simoom", vuln, now + dur)
            end
        end
    elseif family == "heal" and kind.field then -- Healing Field: a zone at his feet
        Signals.Power_AreaFx:FireAllClients({
            primId = "heal_glow",
            element = element,
            kind = "source",
            caster = rec.model,
        })
        local center = rec.model:GetPivot().Position
        local radius = tonumber(kind.field_radius) or 28
        local mag = tonumber(kind.magnitude) or 0
        local dur = tonumber(kind.duration) or 8
        local tick = math.max(tonumber(kind.hot_tick) or 2, 0.5)
        task.spawn(function()
            local elapsed = 0
            while elapsed < dur and rec.model and rec.model.Parent do
                for _, pet in ipairs(self:_teamPets(rec)) do
                    local okP, pivot = pcall(pet.GetPivot, pet)
                    if okP and (pivot.Position - center).Magnitude <= radius then
                        CombatApplication.ApplyPowerHeal(pet, mag, {
                            resource = "pet_endurance",
                            minimumTaken = ResSickness.floorFor(pet:GetAttributes(), os.time()),
                            fxUntil = os.time() + 2,
                            source = rec.name,
                            kind = "power_heal",
                        })
                    end
                end
                task.wait(tick)
                elapsed += tick
            end
        end)
    else
        self:_log(
            "Warn",
            "NPC cast: unhandled family",
            { power = powerId, family = tostring(family) }
        )
    end
    self:_log("Info", "NPC cast", { npc = rec.name, power = powerId })
end

-- Follow the summoner + expire. Pet mining/combat is NOT here — PetFollowService owns that.
function NpcPrincipalService:_step(now)
    for name, rec in pairs(self._active) do
        -- THE PROLOGUE HOLDS THE CURTAIN: while the summoner is still in the cold open, the
        -- Creator must not time out (Jason, live: "Colorado was here for a bit and then
        -- disappeared with the pets" — the 38s summon window lapsed inside an open-ended
        -- prologue). The timer resumes the moment InPrologue clears.
        local inPrologue = rec.owner
            and rec.owner.Parent
            and rec.owner:GetAttribute("InPrologue") == true
        if inPrologue then
            rec.expireAt = now + 30 -- keep a rolling grace window
        end
        if now >= rec.expireAt then
            self:Despawn(name)
        else
            local owner = rec.owner
            local hrp = owner
                and owner.Parent
                and owner.Character
                and owner.Character:FindFirstChild("HumanoidRootPart")
            if hrp and rec.model and rec.model.PrimaryPart then
                local off = rec.def.follow_offset or {}
                local goal = hrp.CFrame
                    * CFrame.new(tonumber(off.x) or -8, tonumber(off.y) or 0, tonumber(off.z) or 6)
                -- WALK, don't teleport: Humanoid:MoveTo drives the rig through its own
                -- locomotion, so the default walk/run animations play and the Motor6D joints
                -- do the work. Re-issued each tick — MoveTo times out on its own, and the
                -- goal keeps moving with the player anyway.
                local hum = rec.model:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum:MoveTo(goal.Position)
                    -- Long gap (portal, teleport, falling behind): walking there would take
                    -- forever, so close it instantly. Ordinary following stays a walk.
                    local gap = (rec.model:GetPivot().Position - goal.Position).Magnitude
                    local leash = tonumber(rec.def.teleport_leash) or 60
                    if gap > leash then
                        rec.model:PivotTo(goal)
                    end
                else
                    rec.model:PivotTo(goal) -- placeholder rig has no locomotion
                end
            elseif not (owner and owner.Parent) then
                self:Despawn(name) -- summoner left
            end
            if self._active[name] then
                self:_castStep(rec, now)
            end
        end
    end
end

return NpcPrincipalService
