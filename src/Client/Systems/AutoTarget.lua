--[[
    AutoTarget (Client Module)
    - Polls while active and asks the server to choose/attack a target.
    - Runs continuously with small throttle; status is server-driven (see AutoTargetService)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local AutoTarget = {}
AutoTarget.__index = AutoTarget
AutoTarget._singleton = nil

local lastSelect = 0
local SELECT_INTERVAL = 0.3

function AutoTarget.new()
    if AutoTarget._singleton then
        return AutoTarget._singleton
    end
    local self = setmetatable({
        status = { free = false, paid = false, active = false, mode = "nearest" },
        running = false,
    }, AutoTarget)

    -- Track server status
    Signals.AutoTarget_Status.OnClientEvent:Connect(function(s)
        self.status.free = s.free and true or false
        self.status.paid = s.paid and true or false
        self.status.active = s.active and true or false
        self.status.mode = s.mode or self.status.mode
    end)

    -- Request initial status on start (server sends status on PlayerAdded, but ensure sync)
    task.delay(0.5, function()
        Signals.AutoTarget_ToggleFree:FireServer() -- noop flip to get a status echo if needed
        task.wait(0.1)
        Signals.AutoTarget_ToggleFree:FireServer() -- flip back
    end)

    AutoTarget._singleton = self
    return AutoTarget._singleton
end

function AutoTarget:ToggleFree()
    Signals.AutoTarget_ToggleFree:FireServer()
end

function AutoTarget:TogglePaid()
    Signals.AutoTarget_TogglePaid:FireServer()
end

function AutoTarget:Start()
    if self.running then
        return
    end
    self.running = true

    task.spawn(function()
        while self.running do
            RunService.Heartbeat:Wait()
            local now = tick()
            if (now - lastSelect) >= SELECT_INTERVAL then
                lastSelect = now
                if self.status.active or self.status.free or self.status.paid then
                    Signals.AutoTarget_RequestAttack:FireServer()
                end
            end
        end
    end)
end

function AutoTarget:Stop()
    self.running = false
end

return AutoTarget
