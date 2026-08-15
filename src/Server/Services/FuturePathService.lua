--[[
    FuturePathService — the authored Home gate into the baked level 2-7 combat route.

    The visible entrance is a Studio-owned clone of a realm `Portal_Home`, renamed
    `Portal_FuturesPath` so RealmPortalService cannot bind it. The destination is the
    `CalloutAnchor` whose Purpose is `future_path_entry` inside Workspace.Maps.FuturePath.
    Its sibling `future_path_return` receives the return prompt.

    This service creates no structural geometry. RobloxGenerateMap builds the route in edit mode;
    Studio saves it; this service only discovers stable authored hooks and moves characters.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local ENTER_PROMPT = "FuturePathEnterPrompt"
local RETURN_PROMPT = "FuturePathReturnPrompt"
local BOUND_ATTRIBUTE = "FuturePathBound"

local FuturePathService = {}
FuturePathService.__index = FuturePathService

function FuturePathService.new()
    local self = setmetatable({}, FuturePathService)
    self._config = {}
    self._returnCFrames = {}
    self._traveling = {}
    return self
end

function FuturePathService:Init()
    self._logger = self._modules and self._modules.Logger
    local layers = self._modules.ConfigLoader:LoadConfig("layers")
    self._config = layers.future_path or {}
end

local function resolvePart(inst)
    if not inst then
        return nil
    end
    if inst:IsA("BasePart") then
        return inst
    end
    if inst:IsA("Model") then
        local host = inst:FindFirstChild("PortalPromptHost", true)
        if host and host:IsA("BasePart") then
            return host
        end
        return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

local function authoredPivot(inst)
    if inst:IsA("Model") then
        return inst:GetPivot()
    end
    return inst.CFrame
end

function FuturePathService:_mapRoot()
    local maps = Workspace:FindFirstChild("Maps")
    return maps and maps:FindFirstChild(self._config.map_folder or "FuturePath")
end

function FuturePathService:_anchor(purpose)
    local root = self:_mapRoot()
    if not root then
        return nil
    end
    for _, inst in ipairs(root:GetDescendants()) do
        if inst:IsA("BasePart") and inst:GetAttribute("Purpose") == purpose then
            return inst
        end
    end
    return nil
end

function FuturePathService:_homePortal()
    local maps = Workspace:FindFirstChild("Maps")
    local home = maps and maps:FindFirstChild("Home")
    return home and home:FindFirstChild(self._config.home_portal_name or "Portal_FuturesPath", true)
end

function FuturePathService:_level(player)
    return tonumber(player:GetAttribute("Level"))
        or tonumber(player:GetAttribute("ClaimedLevel"))
        or 1
end

function FuturePathService:_notifyLocked(player)
    local required = tonumber(self._config.required_level) or 2
    Signals.RealmTravelOffer:FireClient(player, {
        layer = "future_path",
        label = ("🔒 Reach Level %d to enter Future's Path"):format(required),
        locked = true,
    })
end

function FuturePathService:_move(player, target, entering)
    if self._traveling[player] then
        return
    end
    local character = player.Character
    if not (character and character:FindFirstChild("HumanoidRootPart")) then
        return
    end
    self._traveling[player] = true
    task.spawn(function()
        if entering then
            self._returnCFrames[player] = character:GetPivot()
        end
        local targetCF = target
        pcall(function()
            player:RequestStreamAroundAsync(
                targetCF.Position,
                tonumber(self._config.stream_timeout) or 8
            )
        end)
        local liveCharacter = player.Character
        if liveCharacter and liveCharacter:FindFirstChild("HumanoidRootPart") then
            liveCharacter:PivotTo(targetCF)
            player:SetAttribute("InFuturePath", entering == true)
        end
        self._traveling[player] = nil
    end)
end

function FuturePathService:_enter(player)
    local required = tonumber(self._config.required_level) or 2
    if self:_level(player) < required then
        self:_notifyLocked(player)
        return
    end
    local entry = self:_anchor(self._config.entry_purpose or "future_path_entry")
    if not entry then
        if self._logger then
            self._logger:Warn("Future's Path entry blocked: baked map/anchor missing", {
                map = self._config.map_folder,
            })
        end
        return
    end
    self:_move(player, entry.CFrame * CFrame.new(0, 4, 0), true)
end

function FuturePathService:_returnHome(player)
    local destination = self._returnCFrames[player]
    if not destination then
        local portal = self:_homePortal()
        if not portal then
            return
        end
        destination = authoredPivot(portal) * CFrame.new(0, 4, 10)
    end
    self._returnCFrames[player] = nil
    self:_move(player, destination, false)
end

function FuturePathService:_ensurePrompt(host, promptName, actionText, objectText, callback)
    if host:FindFirstChild(promptName) then
        return
    end
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = promptName
    prompt.ActionText = actionText
    prompt.ObjectText = objectText
    prompt.HoldDuration = tonumber(self._config.prompt_hold) or 0.35
    prompt.MaxActivationDistance = tonumber(self._config.max_distance) or 14
    prompt.RequiresLineOfSight = false
    prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
    prompt.Parent = host
    prompt.Triggered:Connect(callback)
end

function FuturePathService:_bind()
    local bound = 0
    local portal = self:_homePortal()
    local portalPart = resolvePart(portal)
    if portalPart and not portalPart:GetAttribute(BOUND_ATTRIBUTE) then
        portalPart:SetAttribute(BOUND_ATTRIBUTE, true)
        self:_ensurePrompt(portalPart, ENTER_PROMPT, "Enter", "Future's Path", function(player)
            self:_enter(player)
        end)
        bound += 1
    end

    local returnAnchor = self:_anchor(self._config.return_purpose or "future_path_return")
    if returnAnchor and not returnAnchor:GetAttribute(BOUND_ATTRIBUTE) then
        returnAnchor:SetAttribute(BOUND_ATTRIBUTE, true)
        self:_ensurePrompt(returnAnchor, RETURN_PROMPT, "Return", "Home", function(player)
            self:_returnHome(player)
        end)
        bound += 1
    end
    return bound
end

function FuturePathService:Start()
    if self._config.enabled == false then
        return
    end
    Players.PlayerRemoving:Connect(function(player)
        self._returnCFrames[player] = nil
        self._traveling[player] = nil
    end)
    self:_bind()

    -- Rojo can start before Studio-owned geometry arrives. React only to relevant authored hooks;
    -- host attributes keep repeated descendant signals idempotent without a polling timer.
    Workspace.DescendantAdded:Connect(function(inst)
        local purpose = inst:GetAttribute("Purpose")
        if
            inst.Name == (self._config.home_portal_name or "Portal_FuturesPath")
            or inst.Name == (self._config.map_folder or "FuturePath")
            or purpose == (self._config.entry_purpose or "future_path_entry")
            or purpose == (self._config.return_purpose or "future_path_return")
        then
            self:_bind()
        end
    end)
end

return FuturePathService
