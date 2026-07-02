--[[
    SummonService (server, #178) — the capstone "call a pet" guardians.

    PowerService routes the `summon` family here. A guardian model joins your squad for the power's
    duration, expresses its fantasy through squad buffs (firewall-safe — no direct player damage),
    trails the player, then despawns. Two guardians today (configs/guardians.lua):
      • Colossus (Gaia's Colossus) — big squad +Defense and x pet-damage while it stands.
      • Djinn (Genie of the Dunes) — revives every downed pet + full-heals on arrival, then a HoT tick.

    Model is a scaled+tinted clone of a squad pet as a placeholder until Jason's real guardian models
    land (drop their Open Cloud asset ids in configs/guardians.lua `model_asset`).
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local PetRevive = require(script.Parent.Parent.PetRevive)
local ResSickness = require(ReplicatedStorage.Shared.Game.ResSickness) -- post-revive heal clamp
local RunService = game:GetService("RunService")
local InsertService = game:GetService("InsertService")

local AssetFetch = require(ReplicatedStorage.Shared.Utils.AssetFetch)

local SummonService = {}
SummonService.__index = SummonService

local function color3(t)
    t = t or {}
    return Color3.fromRGB(t[1] or 200, t[2] or 200, t[3] or 200)
end

-- A character's HumanoidRootPart sits ~2.7 studs above its feet; subtract this so a guardian's
-- BASE (not its center) lands at the player's foot level before applying the config `hover`.
local FOOT_DROP = 2.7

-- World CFrame for a guardian: trail toward the player at its offset, auto-grounded by half the
-- model height (+ config hover), facing the player but kept level (no pitch/roll).
local function targetCFrame(rec, hrpPos, fromPos, lerp)
    local o = rec.offset
    local y = hrpPos.Y + (rec.halfHeight - FOOT_DROP) + rec.hover
    local target = Vector3.new(hrpPos.X + (o.x or 6), y, hrpPos.Z + (o.z or 4))
    local nextPos = fromPos and fromPos:Lerp(target, lerp or 1) or target
    return CFrame.lookAt(nextPos, Vector3.new(hrpPos.X, nextPos.Y, hrpPos.Z))
end

function SummonService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._config = (self._configLoader and self._configLoader:LoadConfig("guardians"))
        or require(game:GetService("ReplicatedStorage").Configs:WaitForChild("guardians"))
    self._active = {} -- { model, owner=userId, gkind, expireAt, healEvery, lastHeal, healAmt }

    self._folder = Instance.new("Folder")
    self._folder.Name = "Guardians"
    self._folder.Parent = Workspace

    self._conn = RunService.Heartbeat:Connect(function()
        self:_step()
    end)
end

local function squadFolder(player)
    local pp = Workspace:FindFirstChild("PlayerPets")
    return pp and pp:FindFirstChild(player.Name)
end

-- Resolve a loader-registered service at RUNTIME via the global locator (init.server.lua).
-- NOT self._modules: the loader only injects DECLARED deps there — self._modules.EnemyService
-- was nil, so the resurrect path silently fell back to plain PetRevive and the lockout ledger
-- never released (the split-second-revive bug survived its own fix, live-caught 2026-07-02).
local function locateService(name)
    local locator = _G.RBXTemplateServices
    if not locator then
        return nil
    end
    local ok, svc = pcall(function()
        return locator:Get(name)
    end)
    return ok and svc or nil
end

-- Build the guardian model: the real asset if configured, else a scaled+tinted clone of a squad pet,
-- else a glowing blob. Sanitized so other systems don't treat it as a real squad pet.
function SummonService:_buildModel(player, gkind, gcfg)
    local model
    local usingPlaceholder = true -- real asset keeps its own textures; placeholder gets tinted
    local assetId = self._config.model_asset and self._config.model_asset[gkind]
    if assetId then
        local ok, loaded = pcall(function()
            return AssetFetch.load(assetId)
        end)
        if ok and loaded then
            model = loaded:FindFirstChildWhichIsA("Model") or loaded
            if model.Parent == loaded then
                model.Parent = nil
            end
            usingPlaceholder = false
        end
    end
    if not model then
        local pets = squadFolder(player)
        local src = pets and pets:FindFirstChildWhichIsA("Model")
        if src then
            model = src:Clone()
        end
    end
    if not model then
        local p = Instance.new("Part")
        p.Shape = Enum.PartType.Ball
        p.Size = Vector3.new(6, 6, 6)
        local m = Instance.new("Model")
        p.Parent = m
        m.PrimaryPart = p
        model = m
    end
    -- sanitize: strip pet/breakable system markers + scripts so nothing else manages it
    for _, d in ipairs(model:GetDescendants()) do
        if
            d:IsA("BaseScript")
            or d.Name == "PositionNumber"
            or d.Name == "TargetID"
            or d.Name == "TargetType"
            or d.Name == "TargetWorld"
            or d.Name == "BreakableID"
        then
            pcall(function()
                d:Destroy()
            end)
        end
    end
    if not model.PrimaryPart then
        model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart")
    end
    -- scale: placeholder uses a flat multiplier; a real asset is scaled to a target stud height
    if usingPlaceholder then
        pcall(function()
            model:ScaleTo(gcfg.scale or 2.5)
        end)
    elseif gcfg.height then
        pcall(function()
            local ext = model:GetExtentsSize()
            if ext and ext.Y > 0.1 then
                model:ScaleTo(gcfg.height / ext.Y)
            end
        end)
    end
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored = true
            d.CanCollide = false
            d.CanQuery = false
            d.CanTouch = false
            d.Massless = true
            if usingPlaceholder then -- real asset keeps its authored textures/colors
                d.Color = color3(gcfg.tint)
                d.Material = Enum.Material.SmoothPlastic
            end
        elseif d:IsA("Humanoid") then
            d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        end
    end
    if model.PrimaryPart then
        local light = Instance.new("PointLight")
        light.Color = color3(gcfg.light)
        light.Range = math.clamp((gcfg.height or 12) * 0.8, 13, 42) -- scale the glow with the giant's size
        light.Brightness = 1.6 -- soft glow; high brightness washed the textures out
        light.Parent = model.PrimaryPart
    end
    model.Name = "Guardian_" .. gkind
    return model
end

-- Heal one pet by `amount` endurance (mirrors PowerService:_healPet; used by the Djinn HoT).
local function healPet(pet, amount)
    if not (pet and pet:IsA("Model")) or pet:GetAttribute("CombatDowned") then
        return
    end
    local taken = pet:GetAttribute("CombatDamageTaken") or 0
    if amount <= 0 or taken <= 0 then
        return
    end
    -- res-sickness clamp: the genie's own burst/HoT can't lift a fresh revive past its res floor
    local newTaken =
        ResSickness.clampTaken(pet:GetAttributes(), math.max(0, taken - amount), os.time())
    local healed = math.max(0, taken - newTaken)
    pet:SetAttribute("CombatDamageTaken", newTaken)
    pet:SetAttribute("HealFxUntil", os.time() + 3)
    -- green "+N" float, like every other heal path (this was the one heal with no number)
    pcall(function()
        Signals.Combat_Heal:FireAllClients({ target = pet, amount = math.floor(healed + 0.5) })
    end)
end

-- Summon a guardian for `kind` (the effect_kind: guardian/duration/revive/magnitude). Called by
-- PowerService:_summonGuardian. Applies the immediate payoff + spawns the model + standing buffs.
function SummonService:Summon(player, kind, now, powerId)
    local gkind = kind.guardian
    local gcfg = gkind and self._config[gkind]
    if not gcfg then
        return
    end
    local dur = tonumber(kind.duration) or 20
    -- STRONGER GUARDIAN: a `potency` enhancement on the summon power scales the guardian's strength.
    -- Genie's arrival burst is kind.magnitude (already enhancement-scaled at cast), but the gcfg-sourced
    -- strength (Colossus squad defense/damage, Djinn HoT) is NOT — so apply the potency factor here.
    local strengthMult = tonumber(kind._strengthMult) or 1
    local pets = squadFolder(player)

    -- Powered revives must go through EnemyService:ResurrectPet — it releases the #179 lockout
    -- ledger FIRST. PetRevive alone stands the pet up and the lockout enforcement holds it right
    -- back down ("back for a split second and then dead again" — Jason, live 2026-07-02).
    local enemyService = locateService("EnemyService")
    local function resurrect(pet)
        if enemyService and enemyService.ResurrectPet then
            enemyService:ResurrectPet(pet, player)
        else
            PetRevive.revive(pet, player)
        end
    end

    -- immediate payoff: revive + heal (Genie's never-wipe)
    if pets then
        if kind.revive then
            for _, pet in ipairs(pets:GetChildren()) do
                if pet:IsA("Model") and pet:GetAttribute("CombatDowned") then
                    resurrect(pet)
                end
            end
        end
        local burst = tonumber(kind.magnitude) or 0
        if burst > 0 then
            for _, pet in ipairs(pets:GetChildren()) do
                healPet(pet, burst)
            end
        end
        -- Colossus standing buffs: the WALL (squad +Defense) + the FIST (x pet-damage)
        if gkind == "colossus" then
            -- WALL: +Defense scales straight by potency. FIST: squad_damage is a MULTIPLIER (1.0 = no
            -- buff), so scale its BONUS above 1 (1 + (mult-1)*potency) — not the whole multiplier.
            local defense = (gcfg.squad_defense or 200) * strengthMult
            local dmgBonus = ((gcfg.squad_damage or 1.5) - 1) * strengthMult
            for _, pet in ipairs(pets:GetChildren()) do
                if pet:IsA("Model") then
                    pet:SetAttribute("DefenseBuff", defense)
                    pet:SetAttribute("DefenseBuffUntil", now + dur)
                    pet:SetAttribute("DefenseBuffPowerId", powerId)
                end
            end
            player:SetAttribute("PetDamageBuff", 1 + dmgBonus)
            player:SetAttribute("PetDamageBuffUntil", now + dur)
            player:SetAttribute("PetDamageBuffPowerId", powerId)
        end
    end

    local model = self:_buildModel(player, gkind, gcfg)
    model.Parent = self._folder

    local halfHeight = 2.5
    pcall(function()
        local ext = model:GetExtentsSize()
        if ext and ext.Y > 0 then
            halfHeight = ext.Y / 2
        end
    end)

    -- WISH AURA (Genie v2): while the guardian floats, the OWNER regenerates extra focus —
    -- FocusService:RegenTick consumes these attributes. Scales with potency like the HoT.
    if tonumber(gcfg.focus_regen) then
        player:SetAttribute("FocusRegenBonus", gcfg.focus_regen * strengthMult)
        player:SetAttribute("FocusRegenBonusUntil", now + dur)
    end

    local rec = {
        model = model,
        owner = player.UserId,
        gkind = gkind,
        offset = gcfg.offset or { x = 6, y = 0, z = 4 },
        hover = gcfg.hover or 0,
        halfHeight = halfHeight,
        expireAt = os.clock() + dur,
        healEvery = gcfg.tick_seconds,
        -- Djinn HoT scales with potency (the arrival burst = kind.magnitude is already scaled at cast)
        healAmt = gcfg.heal_per_tick and (gcfg.heal_per_tick * strengthMult) or nil,
        lastHeal = os.clock(),
        -- Genie v2: revive-on-down (death refused inside the window) + follow the FIGHT centroid
        reviveDuring = gcfg.revive_during == true,
        followFight = gcfg.follow == "fight",
        fightAt = 0, -- next fight-centroid rescan (throttled)
        fightPos = nil, -- cached centroid
    }

    -- place it at the player's side immediately (don't slide in from the world origin)
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if hrp and model.PrimaryPart then
        pcall(function()
            model:PivotTo(targetCFrame(rec, hrp.Position, nil, 1))
        end)
    end

    self._active[#self._active + 1] = rec
    if self._logger and self._logger.Info then
        self._logger:Info(
            "Guardian summoned",
            { kind = gkind, player = player.Name, seconds = dur }
        )
    end
end

function SummonService:_despawn(rec)
    pcall(function()
        rec.model:Destroy()
    end)
end

-- FIGHT CENTROID for a fight-following guardian (Genie v2, Jason: "it needs to fall in a fight,
-- not just hang out next to me"): the average LIVE position of the owner's aggro'd enemies.
-- Enemy models are anchored + client-interpolated, so the live position is the MoveTarget
-- attribute (the same truth taunt/knockback trust), falling back to the pivot. nil = no fight.
local function fightCentroid(playerName)
    local gameFolder = Workspace:FindFirstChild("Game")
    local enemies = gameFolder and gameFolder:FindFirstChild("Enemies")
    if not enemies then
        return nil
    end
    local sx, sy, sz, n = 0, 0, 0, 0
    for _, e in ipairs(enemies:GetChildren()) do
        if
            e:IsA("Model")
            and e:GetAttribute("AggroOwner") == playerName
            and (e:GetAttribute("HP") or 0) > 0
        then
            local mt = e:GetAttribute("MoveTarget")
            local pos = (typeof(mt) == "Vector3") and mt
                or (e.PrimaryPart and e.PrimaryPart.Position)
            if pos then
                sx, sy, sz, n = sx + pos.X, sy + pos.Y, sz + pos.Z, n + 1
            end
        end
    end
    if n == 0 then
        return nil
    end
    return Vector3.new(sx / n, sy / n, sz / n)
end

function SummonService:_step()
    local now = os.clock()
    local lerp = self._config.follow_lerp or 0.18
    for i = #self._active, 1, -1 do
        local rec = self._active[i]
        if not rec or not rec.model or not rec.model.Parent or now >= rec.expireAt then
            if rec then
                self:_despawn(rec)
            end
            table.remove(self._active, i)
        else
            local plr = Players:GetPlayerByUserId(rec.owner)
            local hrp = plr and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            local pp = rec.model.PrimaryPart
            if hrp and pp then
                -- ANCHOR: a fight-follower hovers over the battle (the owner's aggro'd enemies);
                -- rescan the centroid ~3x/sec (cheap folder walk), fall back to the player when
                -- nothing is aggro'd — it drifts home between fights.
                local anchor = hrp.Position
                if rec.followFight then
                    if now >= (rec.fightAt or 0) then
                        rec.fightAt = now + 0.35
                        rec.fightPos = fightCentroid(plr.Name)
                    end
                    anchor = rec.fightPos or hrp.Position
                end
                -- PivotTo moves the whole (anchored, multi-part) model; auto-grounded + level
                pcall(function()
                    rec.model:PivotTo(targetCFrame(rec, anchor, pp.Position, lerp))
                end)
            end
            -- Djinn window tick: heal-over-time + REVIVE-ON-DOWN (Genie v2 — "pets go down, they
            -- just come right back up": the unique never-wipe hook, per Jason. A 5-minute-cooldown
            -- capstone earns it; downs inside the window cost nothing).
            if rec.healEvery and now - rec.lastHeal >= rec.healEvery then
                rec.lastHeal = now
                local pets = plr and squadFolder(plr)
                if pets then
                    for _, pet in ipairs(pets:GetChildren()) do
                        if
                            rec.reviveDuring
                            and pet:IsA("Model")
                            and pet:GetAttribute("CombatDowned")
                        then
                            -- via ResurrectPet: releases the lockout ledger first, else the
                            -- enforcement re-downs it next pass (the split-second-revive bug)
                            local enemyService = locateService("EnemyService")
                            pcall(function()
                                if enemyService and enemyService.ResurrectPet then
                                    enemyService:ResurrectPet(pet, plr)
                                else
                                    PetRevive.revive(pet, plr)
                                end
                            end)
                        end
                        healPet(pet, rec.healAmt or 0)
                    end
                end
            end
        end
    end
end

return SummonService
