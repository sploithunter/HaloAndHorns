--[[
    AscensionAltarService — the "trainer" you visit to claim TRAINING level-ups.

    Hybrid level-up (City-of-Heroes style): filler levels auto-claim in the field, but power /
    slot / milestone levels stall until you walk to the Ascension Altar and trigger its
    ProximityPrompt. Triggering it calls PlayerProgressionService:ClaimLevel (server-side, and
    the prompt itself is distance-validated by Roblox), which fires the reveal modal.

    The altar is a world part tagged "AscensionAltar". If the map already has a tagged part we
    bind to it; otherwise we spawn a placeholder glowing pillar at configs/level_track.lua
    `altar.position` (reskin later — the logic keys off the TAG, not the visual). Mirrors the
    ProximityPrompt setup in EnchantService:_ensureStationPrompt.
]]

local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local ALTAR_TAG = "AscensionAltar"
local PROMPT_NAME = "AscendPrompt"

local AscensionAltarService = {}
AscensionAltarService.__index = AscensionAltarService

function AscensionAltarService.new()
    local self = setmetatable({}, AscensionAltarService)
    self._logger = nil
    self._configLoader = nil
    self._altarConfig = nil
    return self
end

function AscensionAltarService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    local okTrack, track = pcall(function()
        return self._configLoader:LoadConfig("level_track")
    end)
    self._altarConfig = (okTrack and type(track) == "table" and track.altar) or {}
end

function AscensionAltarService:_progression()
    local locator = _G.RBXTemplateServices
    if not locator then
        return nil
    end
    local ok, svc = pcall(function()
        return locator:Get("PlayerProgressionService")
    end)
    return ok and svc or nil
end

local function vec(t, fallback)
    if type(t) == "table" and t[1] then
        return Vector3.new(t[1], t[2] or 0, t[3] or 0)
    end
    return fallback
end

local function color(t, fallback)
    if type(t) == "table" and t[1] then
        return Color3.fromRGB(t[1], t[2] or 0, t[3] or 0)
    end
    return fallback
end

-- Find a Model/BasePart by exact name anywhere under Workspace (e.g. a shop building).
local function findNamed(name)
    if not name or name == "" then
        return nil
    end
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d.Name == name and (d:IsA("Model") or d:IsA("BasePart")) then
            return d
        end
    end
    return nil
end

-- Find an existing tagged altar part; else bind to a named map object (invisible prompt host at
-- it); else spawn a placeholder pillar at the config position.
function AscensionAltarService:_ensureAltarPart()
    local tagged = CollectionService:GetTagged(ALTAR_TAG)
    for _, inst in ipairs(tagged) do
        if inst:IsA("BasePart") and inst:IsDescendantOf(Workspace) then
            return inst
        end
        -- a tagged Model: use its PrimaryPart or first BasePart
        if inst:IsA("Model") then
            local part = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")
            if part then
                return part
            end
        end
    end

    local cfg = self._altarConfig or {}

    -- Bind to a named map object (e.g. "Low Poly Shop"): place an invisible, tagged prompt host at
    -- its ground-centre so the building itself is the station. The label clears the object's top.
    local target = findNamed(cfg.bind_to_name)
    if target then
        local pivot = target:IsA("Model") and target:GetPivot().Position or target.Position
        local ext = target:IsA("Model") and target:GetExtentsSize() or target.Size
        local host = Instance.new("Part")
        host.Name = "AscensionAltar"
        host.Anchored, host.CanCollide, host.CanQuery, host.CastShadow = true, false, false, false
        host.Transparency = 1
        host.Size = Vector3.new(4, 8, 4)
        host.Position = Vector3.new(pivot.X, pivot.Y - ext.Y / 2 + 4, pivot.Z)
            + vec(cfg.bind_offset, Vector3.new(0, 0, 0))
        host:SetAttribute("LabelHeight", ext.Y + 4) -- float the label above the building's roof
        CollectionService:AddTag(host, ALTAR_TAG)
        host.Parent = Workspace
        return host
    end

    -- No tag, no named object — spawn a placeholder pillar (reskin later).
    local part = Instance.new("Part")
    part.Name = "AscensionAltar"
    part.Anchored = true
    part.CanCollide = true
    part.Size = vec(cfg.size, Vector3.new(6, 12, 6))
    part.Position = vec(cfg.position, Vector3.new(0, 6, 0))
    part.Material = Enum.Material.Neon
    part.Color = color(cfg.color, Color3.fromRGB(255, 205, 70))
    part.Transparency = 0.1
    CollectionService:AddTag(part, ALTAR_TAG)
    part.Parent = Workspace
    return part
end

function AscensionAltarService:_ensurePrompt(part)
    local cfg = self._altarConfig or {}
    local prompt = part:FindFirstChild(PROMPT_NAME)
    if prompt and not prompt:IsA("ProximityPrompt") then
        return
    end
    if not prompt then
        prompt = Instance.new("ProximityPrompt")
        prompt.Name = PROMPT_NAME
        prompt.RequiresLineOfSight = false
        prompt.Parent = part
    end
    local keyName = cfg.key or "E"
    prompt.KeyboardKeyCode = Enum.KeyCode[keyName] or Enum.KeyCode.E
    prompt.ActionText = cfg.action_text or "Ascend"
    prompt.ObjectText = cfg.object_text or "Ascension Altar"
    prompt.MaxActivationDistance = tonumber(cfg.max_distance) or 14
    prompt.HoldDuration = tonumber(cfg.hold_duration) or 0
    prompt.Enabled = true

    if not prompt:GetAttribute("AscendPromptConnected") then
        prompt:SetAttribute("AscendPromptConnected", true)
        prompt.Triggered:Connect(function(player)
            self:_onTriggered(player)
        end)
    end
    return prompt
end

-- Float a "Level Up" billboard over the station (above the bound building's roof when bound).
function AscensionAltarService:_ensureLabel(part)
    local cfg = self._altarConfig or {}
    local text = cfg.label_text
    if not text or text == "" or part:FindFirstChild("AscendLabel") then
        return
    end
    local height = tonumber(part:GetAttribute("LabelHeight")) or tonumber(cfg.label_height) or 14
    local bb = Instance.new("BillboardGui")
    bb.Name = "AscendLabel"
    bb.Size = UDim2.new(0, 220, 0, 56)
    bb.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = tonumber(cfg.label_max_distance) or 250
    bb.Adornee = part
    bb.Parent = part
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = color(cfg.label_color, Color3.fromRGB(255, 230, 140))
    lbl.TextStrokeTransparency = 0.35
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextScaled = true
    lbl.Parent = bb
end

-- Claim the next TRAINING level for the player (the prompt is already distance-validated).
function AscensionAltarService:_onTriggered(player)
    local prog = self:_progression()
    if not prog or not prog.GetClaimState then
        return
    end
    local state = prog:GetClaimState(player)
    if (state.pendingTraining or 0) <= 0 then
        return -- nothing owed at the altar (filler auto-claims in the field)
    end
    -- Do NOT claim here. Open the level-up menu; the level is claimed ATOMICALLY on COMMIT (together
    -- with the power/slot choice) so a disconnect mid-menu can't leave you leveled with no pick.
    pcall(function()
        Signals.LevelUp_OpenChoice:FireClient(player)
    end)
end

function AscensionAltarService:Start()
    if self._altarConfig and self._altarConfig.enabled == false then
        return
    end
    local ok, err = pcall(function()
        local part = self:_ensureAltarPart()
        if part then
            self:_ensurePrompt(part)
            self:_ensureLabel(part)
        end
    end)
    if not ok and self._logger then
        self._logger:Warn("AscensionAltarService failed to place altar", { error = tostring(err) })
    elseif self._logger then
        self._logger:Info("AscensionAltarService active (Ascension Altar placed)")
    end
end

return AscensionAltarService
