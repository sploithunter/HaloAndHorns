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

local function applyVisibility(model, mine)
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            d.LocalTransparencyModifier = mine and 0 or 1
        elseif d:IsA("Light") or d:IsA("ParticleEmitter") then
            d.Enabled = mine
        end
    end
end

local function watch(model)
    if not model:IsA("Model") and not model:IsA("BasePart") then
        return
    end
    local function refresh()
        local owner = model:GetAttribute("DropOwner")
        if owner == nil then
            return -- templates/unstamped: leave alone
        end
        applyVisibility(model, owner == Players.LocalPlayer.UserId)
    end
    model:GetAttributeChangedSignal("DropOwner"):Connect(refresh)
    -- parts stream in after the model lands in the folder (pool reparent)
    model.DescendantAdded:Connect(function(d)
        if d:IsA("BasePart") or d:IsA("Light") or d:IsA("ParticleEmitter") then
            task.defer(refresh)
        end
    end)
    refresh()
end

function DropVisibility.start()
    if started then
        return
    end
    started = true
    task.spawn(function()
        local folder = Workspace:WaitForChild("CoinDrops", 30)
        if not folder then
            return
        end
        for _, m in ipairs(folder:GetChildren()) do
            watch(m)
        end
        folder.ChildAdded:Connect(watch)
    end)
end

return DropVisibility
