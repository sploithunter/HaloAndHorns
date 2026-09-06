--[[
    DropVisibility (client) — gems/drops are owner-only PICKUPS, so they're
    owner-only VISIBLE (Jason: "it makes it really confusing if gems are
    everywhere and they're not yours").

    Watches Workspace.CoinDrops; any model whose DropOwner attribute isn't the
    local player is hidden LOCALLY (LocalTransparencyModifier on parts + lights/
    particles disabled). Pool-aware: hidden state re-evaluates whenever DropOwner
    changes (recycled gem models are re-stamped per spawn), so a model hidden for
    one drop un-hides when it respawns as yours. All changes are client-local —
    nothing replicates.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local DropVisibility = {}
local started = false

local function applyPart(d, mine)
    if d:IsA("BasePart") then
        d.LocalTransparencyModifier = mine and 0 or 1
    elseif d:IsA("Light") or d:IsA("ParticleEmitter") then
        d.Enabled = mine
    end
end

function DropVisibility.bind(folder, userId)
    local watched = {}
    local function remove(model)
        local record = watched[model]
        if record then
            watched[model] = nil
            record.active = false
            for _, connection in ipairs(record.connections) do
                connection:Disconnect()
            end
        end
    end

    local function watch(model)
        if watched[model] or (not model:IsA("Model") and not model:IsA("BasePart")) then
            return
        end
        local record = { active = true, connections = {} }
        watched[model] = record
        local function refresh()
            if not record.active then
                return
            end
            local owner = model:GetAttribute("DropOwner")
            if owner == nil then
                return -- templates/unstamped: leave alone
            end
            applyPart(model, owner == userId)
            for _, descendant in ipairs(model:GetDescendants()) do
                applyPart(descendant, owner == userId)
            end
        end
        record.connections = {
            model:GetAttributeChangedSignal("DropOwner"):Connect(refresh),
            model.DescendantAdded:Connect(function(descendant)
                if not record.active then
                    return
                end
                local owner = model:GetAttribute("DropOwner")
                if owner ~= nil then
                    applyPart(descendant, owner == userId)
                end
            end),
        }
        refresh()
    end

    local added = folder.ChildAdded:Connect(watch)
    local removed = folder.ChildRemoved:Connect(remove)
    for _, model in ipairs(folder:GetChildren()) do
        watch(model)
    end
    return function()
        added:Disconnect()
        removed:Disconnect()
        for model in pairs(watched) do
            remove(model)
        end
    end
end

function DropVisibility.start()
    if started then
        return
    end
    started = true
    local current, disconnect
    local function refresh()
        local folder = Workspace:FindFirstChild("CoinDrops")
        if folder == current then
            return
        end
        if disconnect then
            disconnect()
        end
        current = folder
        disconnect = folder and DropVisibility.bind(folder, Players.LocalPlayer.UserId) or nil
    end
    Workspace.ChildAdded:Connect(refresh)
    Workspace.ChildRemoved:Connect(refresh)
    refresh()
end

return DropVisibility
