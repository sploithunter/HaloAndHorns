-- Client-only downed presentation. Healthy pets need no descendant scans or writes.
-- Does not own lifetime, movement, HP, or a billboard's normal enabled policy.
local Visibility = {}

function Visibility.bind(root)
    local records = {}

    local function release(record, descendant)
        local saved = record.hiddenParts[descendant]
        if saved then
            record.hiddenParts[descendant] = nil
            saved.connection:Disconnect()
            descendant[saved.property] = saved.original
        end
    end

    local function hide(record, descendant)
        if not record.downed or record.hiddenParts[descendant] then
            return
        end
        local property, hidden
        if descendant:IsA("BasePart") then
            property, hidden = "LocalTransparencyModifier", 1
        elseif descendant:IsA("BillboardGui") then
            property, hidden = "Enabled", false
        else
            return
        end
        local saved = { property = property, original = descendant[property] }
        record.hiddenParts[descendant] = saved
        -- Other presentation systems may update their desired state while a pet is
        -- down. Remember that state, but keep the downed override until revival.
        saved.connection = descendant:GetPropertyChangedSignal(property):Connect(function()
            if descendant[property] ~= hidden then
                saved.original = descendant[property]
                descendant[property] = hidden
            end
        end)
        descendant[property] = hidden
    end

    local function remove(model)
        local record = records[model]
        if not record then
            return
        end
        records[model] = nil
        for _, connection in ipairs(record.connections) do
            connection:Disconnect()
        end
        for descendant in pairs(record.hiddenParts) do
            release(record, descendant)
        end
    end

    local function add(model)
        if
            not model:IsA("Model")
            or not model.Parent
            or model.Parent.Parent ~= root
            or records[model]
        then
            return
        end
        local record = { hiddenParts = {}, connections = {}, downed = false }
        records[model] = record
        local function refresh()
            local downed = model:GetAttribute("CombatDowned") == true
            if downed == record.downed then
                return
            end
            record.downed = downed
            if downed then
                for _, descendant in ipairs(model:GetDescendants()) do
                    hide(record, descendant)
                end
            else
                for descendant in pairs(record.hiddenParts) do
                    release(record, descendant)
                end
            end
        end
        record.connections = {
            model:GetAttributeChangedSignal("CombatDowned"):Connect(refresh),
            model.DescendantAdded:Connect(function(descendant)
                hide(record, descendant)
            end),
            model.DescendantRemoving:Connect(function(descendant)
                release(record, descendant)
            end),
        }
        refresh()
    end

    local added = root.DescendantAdded:Connect(add)
    local removed = root.DescendantRemoving:Connect(remove)
    for _, folder in ipairs(root:GetChildren()) do
        for _, model in ipairs(folder:GetChildren()) do
            add(model)
        end
    end
    return function()
        added:Disconnect()
        removed:Disconnect()
        for model in pairs(records) do
            remove(model)
        end
    end
end

function Visibility.watch(workspace)
    local current, disconnect
    local function refresh()
        local root = workspace:FindFirstChild("PlayerPets")
        if root == current then
            return
        end
        if disconnect then
            disconnect()
        end
        current = root
        disconnect = root and Visibility.bind(root) or nil
    end
    local added = workspace.ChildAdded:Connect(refresh)
    local removed = workspace.ChildRemoved:Connect(refresh)
    refresh()
    return function()
        added:Disconnect()
        removed:Disconnect()
        if disconnect then
            disconnect()
        end
        current, disconnect = nil, nil
    end
end

return Visibility
