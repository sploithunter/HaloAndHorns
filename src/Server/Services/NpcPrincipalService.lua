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
    local hrp = model:FindFirstChild("HumanoidRootPart")
    if hrp then
        -- Anchored + server-pivoted: the same contract the pets use, so nothing fights the
        -- physics solver over an NPC nobody is controlling.
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("BasePart") then
                d.Anchored = true
                d.CanCollide = false
            end
        end
        model:PivotTo(cf)
    end
    model:SetAttribute("NpcPrincipal", true)
    model:SetAttribute("Level", tonumber(def.level) or 50)
    model:SetAttribute("EffectiveLevel", tonumber(def.level) or 50)
    model:SetAttribute("DisplayName", def.display_name or def.name)
    return model
end

-- ── Ghost squad ─────────────────────────────────────────────────────────────────────

-- Clone a pet model from the same ReplicatedStorage tree PetHandler uses. Returns nil if the
-- type/variant isn't present rather than substituting something surprising.
function NpcPrincipalService:_clonePet(petId, variant)
    local models = ReplicatedStorage:FindFirstChild("Models")
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
    local folder = root:FindFirstChild(def.name)
    if folder then
        folder:Destroy() -- a re-summon replaces, never stacks
    end
    folder = Instance.new("Folder")
    folder.Name = def.name
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

function NpcPrincipalService:_republishEffective(player)
    pcall(function()
        local prog = _G.RBXTemplateServices
            and _G.RBXTemplateServices:Get("PlayerProgressionService")
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
    local model = self:_buildCharacter(def, cf)
    model.Parent = Workspace

    local folder, spawned = self:_spawnSquad(def, cf)

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

-- Follow the summoner + expire. Pet movement is NOT here — PetFollowService owns the folder.
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
                local lerp = tonumber(rec.def.follow_lerp) or 0.18
                rec.model:PivotTo(rec.model:GetPivot():Lerp(goal, lerp))
            elseif not (owner and owner.Parent) then
                self:Despawn(name) -- summoner left
            end
        end
    end
end

return NpcPrincipalService
