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

local NpcPrincipalService = {}
NpcPrincipalService.__index = NpcPrincipalService

function NpcPrincipalService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._playerProgressionService = self._modules and self._modules.PlayerProgressionService
    self._config = (self._configLoader and self._configLoader:LoadConfig("creator"))
        or require(ReplicatedStorage.Configs:WaitForChild("creator"))
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

-- Trail the NPC's squad behind it via the ENEMY MOVEMENT CONTRACT (Jason: "you can probably
-- use the enemy's movement code as well" — the better half of that idea).
--
-- Pet movement is normally client-driven: each player's client pivots its OWN pets. An NPC
-- has no client, so its squad spawned and sat still. The first fix here pivoted them
-- server-side, which worked but was a parallel implementation — no gait, no smoothing, and
-- coarse at the 0.2s service tick.
--
-- Enemies already solved exactly this problem for entities with no owning client: the server
-- decides a destination and stamps `MoveTarget`, and the client EnemyMotion renderer lerps
-- the anchored model toward it every RenderStepped with a procedural gait. Adopting that
-- contract means:
--   • no coupling to the summoner's client (which would freeze on their disconnect, and
--     render nothing for anyone else)
--   • every client renders it, because attributes replicate — no position relay needed
--   • the gait comes for free
-- EnemyMotion picks these up via the folder's NpcSquad marker. PetFollowService still owns
-- their mining/combat through _tickPrincipal; this is only where they should BE.
function NpcPrincipalService:_moveSquad(rec, dt)
    local folder = rec.folder
    if not (folder and folder.Parent and rec.model) then
        return
    end
    local base = rec.model:GetPivot()
    local speed = tonumber(rec.def.pet_speed) or 34 -- studs/sec; > player run so they close gaps
    local leash = tonumber(rec.def.pet_teleport_leash) or 90
    local step = speed * (dt or 0.2)
    local i = 0
    for _, pet in ipairs(folder:GetChildren()) do
        if pet:IsA("Model") and pet.PrimaryPart then
            i += 1
            -- simple rank behind the NPC; formation styles are a later pass
            local slot = (base * CFrame.new((i - 2) * 5, 0, 6)).Position
            local from = pet:GetAttribute("MoveTarget") or pet:GetPivot().Position
            local delta = slot - from
            local gap = delta.Magnitude

            -- STEP the target, don't jump it. EnemyMotion's client lerp is tuned to smooth
            -- the SMALL per-tick deltas EnemyService produces; handing it the final
            -- destination in one jump made the pets crawl — live: correct targets 6-8 studs
            -- behind Colorado while the pets themselves sat 111 studs back, never closing.
            -- Stepping at a real speed gives them a travel rate the lerp can actually track.
            local target
            if gap > leash then
                target = slot -- absurd gap (spawn, portal, teleport): close it now
                pet:PivotTo(CFrame.new(slot))
            elseif gap <= step then
                target = slot
            else
                target = from + delta.Unit * step
            end
            pet:SetAttribute("MoveTarget", target)
            pet:SetAttribute("MoveFace", base.Position) -- face the way the NPC is heading
        end
    end
end

-- Follow the summoner + expire. Pet mining/combat is NOT here — PetFollowService owns that.
function NpcPrincipalService:_step(now)
    for name, rec in pairs(self._active) do
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
                self:_moveSquad(rec, 0.2)
            elseif not (owner and owner.Parent) then
                self:Despawn(name) -- summoner left
            end
        end
    end
end

return NpcPrincipalService
