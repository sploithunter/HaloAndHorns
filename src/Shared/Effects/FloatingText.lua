--[[
    FloatingText — client floating combat text (damage / crit / miss / heal numbers).

    A number pops above a hit point and floats UP while fading out. Driven by Combat_PetHit on
    the client (the real swing), so the number is the damage that actually landed. Reusable for
    heals (green) / other feedback later.

      FloatingText.show(worldPosition, text, { color, size, rise, duration, jitter, max_distance })
]]

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local FloatingText = {}

local function fxFolder()
    local f = Workspace:FindFirstChild("Effects")
    if not f then
        f = Instance.new("Folder")
        f.Name = "Effects"
        f.Parent = Workspace
    end
    return f
end

function FloatingText.show(position, text, opts)
    opts = opts or {}
    local jitter = opts.jitter or 1.6
    local holder = Instance.new("Part")
    holder.Anchored = true
    holder.CanCollide = false
    holder.CanQuery = false
    holder.Transparency = 1
    holder.Size = Vector3.new(0.2, 0.2, 0.2)
    holder.CFrame = CFrame.new(
        position + Vector3.new((math.random() - 0.5) * jitter, 0.5, (math.random() - 0.5) * jitter)
    )
    holder.Parent = fxFolder()

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.fromOffset(opts.width or 130, opts.height or 44)
    bb.AlwaysOnTop = true
    bb.MaxDistance = opts.max_distance or 220
    bb.LightInfluence = 0
    bb.Parent = holder

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.Font = Enum.Font.GothamBold
    lbl.Text = text
    lbl.TextSize = opts.size or 22
    lbl.TextColor3 = opts.color or Color3.fromRGB(255, 255, 255)
    lbl.TextStrokeTransparency = 0.25
    lbl.Parent = bb

    local rise = opts.rise or 6
    local dur = opts.duration or 0.9
    -- Quick "pop" scale-in (TextSize), then float up + fade out.
    local fullSize = opts.size or 22
    lbl.TextSize = math.floor(fullSize * 0.6)
    TweenService
        :Create(lbl, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            TextSize = fullSize,
        })
        :Play()
    TweenService
        :Create(holder, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            CFrame = holder.CFrame + Vector3.new(0, rise, 0),
        })
        :Play()
    TweenService:Create(lbl, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        TextTransparency = 1,
        TextStrokeTransparency = 1,
    }):Play()
    Debris:AddItem(holder, dur + 0.15)
end

return FloatingText
