--[[
    ShopWorldPrompt — makes every authored Pet Shop building interactive.

    The prompt is client-owned because opening a menu is presentation-only.
    Purchases still cross the server-authoritative MonetizationService boundary.
]]

local Workspace = game:GetService("Workspace")

local ShopWorldPrompt = {}

local PROMPT_NAME = "PetShopPrompt"
local ANCHOR_NAME = "PetShopPromptAnchor"
local PROMPT_HEIGHT_ABOVE_MODEL_BOTTOM = 5
local bound = setmetatable({}, { __mode = "k" })

local function isPetShop(model)
    return model:IsA("Model") and string.lower(model.Name) == "pet shop"
end

local function hasPetShopAncestor(model)
    local ancestor = model.Parent
    while ancestor and ancestor ~= Workspace do
        if isPetShop(ancestor) then
            return true
        end
        ancestor = ancestor.Parent
    end
    return false
end

local function promptHost(model)
    local lowestSign
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") and string.lower(descendant.Name) == "sign" then
            if not lowestSign or descendant.Position.Y < lowestSign.Position.Y then
                lowestSign = descendant
            end
        end
    end
    if lowestSign then
        return lowestSign
    end
    if model.PrimaryPart then
        return model.PrimaryPart
    end
    return model:FindFirstChildWhichIsA("BasePart", true)
end

local function promptAnchor(model, host)
    local explicit = model:FindFirstChild(ANCHOR_NAME, true)
    if
        explicit
        and explicit:GetAttribute("RuntimeGenerated") ~= true
        and (explicit:IsA("Attachment") or explicit:IsA("BasePart"))
    then
        return explicit
    end

    local anchor = explicit or host:FindFirstChild(ANCHOR_NAME)
    if anchor and not anchor:IsA("Attachment") then
        anchor:Destroy()
        anchor = nil
    end
    if not anchor then
        anchor = Instance.new("Attachment")
        anchor.Name = ANCHOR_NAME
    end
    anchor:SetAttribute("RuntimeGenerated", true)
    anchor.Parent = host

    -- Authored signs are often on the roof. Keep their useful X/Z placement but move the prompt
    -- down near the building floor so it is visible and reachable from every realm/layer copy.
    local boxCFrame, boxSize = model:GetBoundingBox()
    local targetY = boxCFrame.Position.Y - (boxSize.Y * 0.5) + PROMPT_HEIGHT_ABOVE_MODEL_BOTTOM
    local targetWorld =
        Vector3.new(host.Position.X, math.min(host.Position.Y, targetY), host.Position.Z)
    anchor.Position = host.CFrame:PointToObjectSpace(targetWorld)
    return anchor
end

local function bind(model, menuManager)
    if not isPetShop(model) or hasPetShopAncestor(model) then
        return
    end
    local host = promptHost(model)
    if not host then
        return
    end
    local anchor = promptAnchor(model, host)

    local prompt = model:FindFirstChild(PROMPT_NAME, true)
    if prompt and not prompt:IsA("ProximityPrompt") then
        prompt:Destroy()
        prompt = nil
    end
    if not prompt then
        prompt = Instance.new("ProximityPrompt")
        prompt.Name = PROMPT_NAME
        prompt.ActionText = "Browse"
        prompt.ObjectText = "Pet Shop"
        prompt.KeyboardKeyCode = Enum.KeyCode.E
        prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
        prompt.HoldDuration = 0
        prompt.MaxActivationDistance = 34
        prompt.RequiresLineOfSight = false
        prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
    end
    prompt.Parent = anchor
    prompt.Enabled = true

    if not bound[model] then
        bound[model] = prompt.Triggered:Connect(function()
            menuManager:OpenShopPanel("scale_in_small")
        end)
    end
end

function ShopWorldPrompt.start(menuManager)
    local maps = Workspace:WaitForChild("Maps")
    local count = 0
    for _, descendant in ipairs(maps:GetDescendants()) do
        if isPetShop(descendant) then
            local wasBound = bound[descendant] ~= nil
            bind(descendant, menuManager)
            if not wasBound and bound[descendant] then
                count += 1
            end
        end
    end
    maps.DescendantAdded:Connect(function(descendant)
        -- Streaming/replication can create the shop Model before its BaseParts.
        -- Retry the OUTERMOST shop whenever any child arrives, not only when
        -- the Model itself is first observed.
        local candidate = isPetShop(descendant) and descendant or descendant.Parent
        while candidate and candidate ~= maps do
            if isPetShop(candidate) and not hasPetShopAncestor(candidate) then
                bind(candidate, menuManager)
                break
            end
            candidate = candidate.Parent
        end
    end)
    return count
end

return ShopWorldPrompt
