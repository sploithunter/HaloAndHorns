--[[
    PromoCodePanel — public reward-code entry using the shared menu chrome.

    The server owns normalization, eligibility, claim limits, and rewards. A code supplied through
    Roblox LaunchData only prefills this box; the player still explicitly presses Redeem.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PanelChrome = require(script.Parent.Parent.Components.PanelChrome)
local Pill = require(script.Parent.Parent.Pill)

local REMOTE_NAME = "GameAPICommand"
local COLOR_READY = Color3.fromRGB(46, 190, 100)
local COLOR_ERROR = Color3.fromRGB(235, 90, 90)
local COLOR_INFO = Color3.fromRGB(190, 198, 215)

local PromoCodePanel = {}
PromoCodePanel.__index = PromoCodePanel

function PromoCodePanel.new()
    return setmetatable({ isVisible = false, frame = nil, redeeming = false }, PromoCodePanel)
end

function PromoCodePanel:_callBus(name, args)
    local remote = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
    if not remote then
        return nil
    end
    local ok, envelope = pcall(function()
        return remote:InvokeServer(name, args or {})
    end)
    if not ok or type(envelope) ~= "table" then
        return nil
    end
    return envelope.result
end

function PromoCodePanel:Show(parent)
    if self.isVisible then
        return
    end
    self:_createUI(parent)
    self.isVisible = true
    self:_loadStatus()
end

function PromoCodePanel:Hide()
    if self.frame then
        self.frame:Destroy()
        self.frame = nil
    end
    self.isVisible = false
    self.redeeming = false
end

function PromoCodePanel:IsVisible()
    return self.isVisible
end

function PromoCodePanel:GetFrame()
    return self.frame
end

function PromoCodePanel:Destroy()
    self:Hide()
end

function PromoCodePanel:_setStatus(message, color)
    if self.statusLabel then
        self.statusLabel.Text = message or ""
        self.statusLabel.TextColor3 = color or COLOR_INFO
    end
end

function PromoCodePanel:_createUI(parent)
    local shell = PanelChrome.build(parent, {
        name = "PromoCodePanel",
        title = "🎁 Redeem Code",
        size = UDim2.new(0.58, 0, 0.56, 0),
        onClose = function()
            self:Hide()
        end,
    })
    self.frame = shell.frame

    local intro = Instance.new("TextLabel")
    intro.Name = "Introduction"
    intro.Size = UDim2.new(0.88, 0, 0.16, 0)
    intro.Position = UDim2.new(0.5, 0, 0.25, 0)
    intro.AnchorPoint = Vector2.new(0.5, 0.5)
    intro.BackgroundTransparency = 1
    intro.Text = "Enter a weekly, creator, or event code to claim its reward."
    intro.TextColor3 = COLOR_INFO
    intro.TextWrapped = true
    intro.TextScaled = true
    intro.Font = Enum.Font.Gotham
    intro.ZIndex = 102
    intro.Parent = shell.frame
    local introSize = Instance.new("UITextSizeConstraint")
    introSize.MaxTextSize = 21
    introSize.MinTextSize = 12
    introSize.Parent = intro

    local inputShell = Pill.frame({
        parent = shell.frame,
        color = Color3.fromRGB(37, 40, 52),
        size = UDim2.new(0.82, 0, 0, 62),
        position = UDim2.new(0.5, 0, 0.45, 0),
        anchorPoint = Vector2.new(0.5, 0.5),
        zIndex = 102,
        strokeColor = shell.areaColor,
    })
    inputShell.Name = "CodeInputShell"

    self.codeInput = Instance.new("TextBox")
    self.codeInput.Name = "CodeInput"
    self.codeInput.Size = UDim2.new(1, -30, 1, -12)
    self.codeInput.Position = UDim2.new(0.5, 0, 0.5, 0)
    self.codeInput.AnchorPoint = Vector2.new(0.5, 0.5)
    self.codeInput.BackgroundTransparency = 1
    self.codeInput.ClearTextOnFocus = false
    self.codeInput.PlaceholderText = "ENTER CODE"
    self.codeInput.PlaceholderColor3 = Color3.fromRGB(135, 142, 160)
    self.codeInput.Text = ""
    self.codeInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.codeInput.TextSize = 24
    self.codeInput.Font = Enum.Font.GothamBold
    self.codeInput.TextXAlignment = Enum.TextXAlignment.Center
    self.codeInput.ZIndex = 104
    self.codeInput.Parent = inputShell
    self.codeInput.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            self:_redeem()
        end
    end)

    self.redeemButton = Pill.button({
        parent = shell.frame,
        color = COLOR_READY,
        size = UDim2.new(0.52, 0, 0, 52),
        position = UDim2.new(0.5, 0, 0.65, 0),
        anchorPoint = Vector2.new(0.5, 0.5),
        text = "REDEEM",
        textSize = 20,
        zIndex = 104,
    })
    self.redeemButton.Name = "RedeemButton"
    self.redeemButton.Activated:Connect(function()
        self:_redeem()
    end)

    self.statusLabel = Instance.new("TextLabel")
    self.statusLabel.Name = "Status"
    self.statusLabel.Size = UDim2.new(0.88, 0, 0.18, 0)
    self.statusLabel.Position = UDim2.new(0.5, 0, 0.82, 0)
    self.statusLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    self.statusLabel.BackgroundTransparency = 1
    self.statusLabel.Text = ""
    self.statusLabel.TextColor3 = COLOR_INFO
    self.statusLabel.TextWrapped = true
    self.statusLabel.TextScaled = true
    self.statusLabel.Font = Enum.Font.GothamBold
    self.statusLabel.ZIndex = 103
    self.statusLabel.Parent = shell.frame
    local statusSize = Instance.new("UITextSizeConstraint")
    statusSize.MaxTextSize = 20
    statusSize.MinTextSize = 11
    statusSize.Parent = self.statusLabel
end

function PromoCodePanel:_loadStatus()
    local status = self:_callBus("promo.status", {})
    if not status or not status.ok then
        self:_setStatus(
            (status and status.message) or "Codes couldn't be loaded. Please try again.",
            COLOR_ERROR
        )
        return
    end
    if status.enabled == false then
        self:_setStatus("Codes are temporarily unavailable.", COLOR_ERROR)
        return
    end
    if status.prefill and status.prefill ~= "" then
        self.codeInput.Text = status.prefill
        self:_setStatus("Code found in your launch link — press Redeem.", COLOR_INFO)
    else
        self:_setStatus("Codes are case-insensitive and can only be claimed as configured.")
    end
end

function PromoCodePanel:_redeem()
    if self.redeeming then
        return
    end
    local code = self.codeInput and self.codeInput.Text or ""
    if code:gsub("%s+", "") == "" then
        self:_setStatus("Enter a code first.", COLOR_ERROR)
        return
    end
    self.redeeming = true
    self.redeemButton.Label.Text = "CHECKING…"
    self:_setStatus("Checking code…", COLOR_INFO)

    local result = self:_callBus("promo.redeem", { code = code })
    self.redeeming = false
    if self.redeemButton then
        self.redeemButton.Label.Text = "REDEEM"
    end
    if not result then
        self:_setStatus("The server didn't respond. Please try again.", COLOR_ERROR)
    elseif result.ok then
        self.codeInput.Text = ""
        self:_setStatus(result.message or "Code redeemed!", COLOR_READY)
    else
        self:_setStatus(result.message or "That code couldn't be redeemed.", COLOR_ERROR)
    end
end

return PromoCodePanel
