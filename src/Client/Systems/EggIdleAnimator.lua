--!strict

-- Gentle client-only idle motion for authored display eggs. The server egg and its stand anchor
-- never move, so proximity prompts and hatch validation remain stable while the visual feels alive.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local EggIdleAnimator = {}

local started = false
local basePivots: { [Instance]: CFrame } = {}
local ANIMATED_TAGS = { "EggStand", "EggDisplay" }

local function readPivot(inst: Instance): CFrame?
    if inst:IsA("Model") then
        return inst:GetPivot()
    elseif inst:IsA("BasePart") then
        return inst.CFrame
    end
    return nil
end

local function writePivot(inst: Instance, pivot: CFrame)
    if inst:IsA("Model") then
        inst:PivotTo(pivot)
    elseif inst:IsA("BasePart") then
        inst.CFrame = pivot
    end
end

local function forget(inst: Instance)
    local base = basePivots[inst]
    if base and inst.Parent then
        writePivot(inst, base)
    end
    basePivots[inst] = nil
end

-- Prefer the stand cup so a moved pedestal (or a stale model pivot) cannot
-- leave the visual egg floating at last frame's XZ.
local function cupBase(egg: Instance): CFrame?
    local stand = egg.Parent
    if not (stand and stand:IsA("Model")) then
        return nil
    end
    local anchor = stand:FindFirstChild("UIanchor")
    if not (anchor and anchor:IsA("BasePart")) then
        return nil
    end
    local offsetY = tonumber(egg:GetAttribute("IdleBaseOffsetY")) or 0
    local _, yaw = anchor.CFrame:ToEulerAnglesYXZ()
    return CFrame.new(anchor.Position) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, offsetY, 0)
end

function EggIdleAnimator.start()
    if started then
        return
    end
    started = true

    for _, tag in ipairs(ANIMATED_TAGS) do
        CollectionService:GetInstanceRemovedSignal(tag):Connect(forget)
    end
    RunService.RenderStepped:Connect(function()
        local now = os.clock()
        local animated: { [Instance]: boolean } = {}
        for _, tag in ipairs(ANIMATED_TAGS) do
            for _, egg in ipairs(CollectionService:GetTagged(tag)) do
                animated[egg] = true
            end
        end
        for egg in pairs(animated) do
            local amplitude = tonumber(egg:GetAttribute("IdleFloatAmplitude")) or 0
            local period = math.max(tonumber(egg:GetAttribute("IdleFloatPeriod")) or 3.4, 0.1)
            if amplitude > 0 and egg.Parent then
                local base = cupBase(egg)
                if not base then
                    base = basePivots[egg]
                    if not base then
                        base = readPivot(egg)
                        if base then
                            basePivots[egg] = base
                        end
                    end
                else
                    basePivots[egg] = base
                end
                if base then
                    local y = math.sin(now * math.pi * 2 / period) * amplitude
                    writePivot(egg, base * CFrame.new(0, y, 0))
                end
            end
        end
    end)
end

return EggIdleAnimator
