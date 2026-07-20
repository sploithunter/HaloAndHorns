--[[
    ShopWorldPrompt — makes every authored Pet Shop building interactive.

    The prompt is client-owned because opening a menu is presentation-only.
    Purchases still cross the server-authoritative MonetizationService boundary.
]]

local Workspace = game:GetService("Workspace")

local ShopWorldPrompt = {}

local PROMPT_NAME = "PetShopPrompt"
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

local function bind(model, menuManager)
    if bound[model] or not isPetShop(model) or hasPetShopAncestor(model) then
        return
    end
    local host = promptHost(model)
    if not host then
        return
    end

    local prompt = host:FindFirstChild(PROMPT_NAME)
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
        prompt.Parent = host
    end

    bound[model] = prompt.Triggered:Connect(function()
        menuManager:OpenShopPanel("scale_in_small")
    end)
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
