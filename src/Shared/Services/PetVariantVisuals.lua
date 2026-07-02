local RunService = game:GetService("RunService")

local PetVariantVisuals = {}

local RAINBOW_SPEED = 0.12
local RAINBOW_SATURATION = 0.85
local RAINBOW_VALUE = 1

local function getVariant(model)
    local attrVariant = model:GetAttribute("Variant")
    if type(attrVariant) == "string" then
        return string.lower(attrVariant)
    end

    local variantValue = model:FindFirstChild("Variant")
    if variantValue and variantValue:IsA("StringValue") then
        return string.lower(variantValue.Value)
    end

    return nil
end

local function shouldTintPart(part)
    return part:IsA("BasePart") and part.Transparency < 0.98
end

local function getOrCreateHighlight(model, name)
    local highlight = model:FindFirstChild(name)
    if highlight and highlight:IsA("Highlight") then
        return highlight
    end

    highlight = Instance.new("Highlight")
    highlight.Name = name
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    highlight.FillTransparency = 0.82
    highlight.OutlineTransparency = 0.25
    highlight.Parent = model
    return highlight
end

function PetVariantVisuals.ApplyServerMetadata(model, petType, variant)
    if not model then
        return
    end

    if petType then
        model:SetAttribute("PetType", tostring(petType))
    end

    if variant then
        model:SetAttribute("Variant", tostring(variant))
    end

    local normalizedVariant = getVariant(model)
    if normalizedVariant == "golden" then
        model:SetAttribute("VariantVisual", "golden")
    elseif normalizedVariant == "rainbow" then
        model:SetAttribute("VariantVisual", "rainbow")
    end
end

function PetVariantVisuals.ApplyStaticVisuals(model)
    local variant = getVariant(model)
    if variant == "golden" then
        local gold = Color3.fromRGB(255, 195, 70)
        for _, descendant in ipairs(model:GetDescendants()) do
            if shouldTintPart(descendant) then
                descendant.Color = descendant.Color:Lerp(gold, 0.35)
            end
        end

        local highlight = getOrCreateHighlight(model, "GoldenVariantHighlight")
        highlight.FillColor = gold
        highlight.OutlineColor = Color3.fromRGB(255, 240, 170)
    elseif variant == "rainbow" then
        local highlight = getOrCreateHighlight(model, "RainbowVariantHighlight")
        highlight.FillColor = Color3.fromRGB(255, 80, 180)
        highlight.OutlineColor = Color3.fromRGB(120, 255, 255)
    end
end

function PetVariantVisuals.StartClient(rootFolder)
    if not RunService:IsClient() then
        return function() end
    end

    local active = {}
    local connections = {}

    local function addRainbowModel(model)
        if not model:IsA("Model") or getVariant(model) ~= "rainbow" or active[model] then
            return
        end

        local parts = {}
        for _, descendant in ipairs(model:GetDescendants()) do
            if shouldTintPart(descendant) then
                table.insert(parts, {
                    part = descendant,
                    baseColor = descendant.Color,
                    offset = (#parts % 7) / 7,
                })
            end
        end

        local highlight = getOrCreateHighlight(model, "RainbowVariantHighlight")
        active[model] = {
            parts = parts,
            highlight = highlight,
            startedAt = os.clock(),
        }
    end

    local function scan(instance)
        if instance:IsA("Model") then
            addRainbowModel(instance)
        end

        for _, child in ipairs(instance:GetChildren()) do
            scan(child)
        end
    end

    scan(rootFolder)

    table.insert(
        connections,
        rootFolder.DescendantAdded:Connect(function(descendant)
            if descendant:IsA("Model") then
                task.defer(addRainbowModel, descendant)
            elseif descendant:IsA("BasePart") then
                local model = descendant:FindFirstAncestorOfClass("Model")
                if model and active[model] then
                    table.insert(active[model].parts, {
                        part = descendant,
                        baseColor = descendant.Color,
                        offset = (#active[model].parts % 7) / 7,
                    })
                end
            end
        end)
    )

    table.insert(
        connections,
        RunService.RenderStepped:Connect(function()
            local now = os.clock()
            for model, state in pairs(active) do
                if not model.Parent then
                    active[model] = nil
                    continue
                end

                local elapsed = now - state.startedAt
                for _, entry in ipairs(state.parts) do
                    local part = entry.part
                    if part and part.Parent then
                        local hue = (elapsed * RAINBOW_SPEED + entry.offset) % 1
                        local color = Color3.fromHSV(hue, RAINBOW_SATURATION, RAINBOW_VALUE)
                        part.Color = entry.baseColor:Lerp(color, 0.72)
                    end
                end

                if state.highlight and state.highlight.Parent then
                    local hue = (elapsed * RAINBOW_SPEED) % 1
                    local outlineHue = (hue + 0.42) % 1
                    state.highlight.FillColor = Color3.fromHSV(hue, 0.8, 1)
                    state.highlight.OutlineColor = Color3.fromHSV(outlineHue, 0.85, 1)
                end
            end
        end)
    )

    return function()
        for _, connection in ipairs(connections) do
            connection:Disconnect()
        end
        table.clear(active)
    end
end

return PetVariantVisuals
