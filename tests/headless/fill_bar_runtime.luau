-- Production widget with deterministic Tween signals, including deferred stale callbacks.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local signals = {}
local function signal()
    local event = { connections = {} }
    function event:Connect(callback)
        local connection = { callback = callback, Connected = true }
        function connection:Disconnect()
            self.Connected = false
        end
        table.insert(self.connections, connection)
        return connection
    end
    function event:Fire()
        for _, connection in ipairs(table.clone(self.connections)) do
            if connection.Connected then
                connection.callback()
            end
        end
    end
    table.insert(signals, event)
    return event
end
local created = {}
local tweenService = {}
function tweenService:Create(target, _info, goal)
    local tween = { Completed = signal(), destroyed = false }
    function tween:Play()
        self.playing = true
    end
    function tween:Cancel()
        if self.playing then
            self.playing = false
            self.Completed:Fire()
        end
    end
    function tween:Destroy()
        self.destroyed = true
        for _, connection in ipairs(self.Completed.connections) do
            connection:Disconnect()
        end
    end
    function tween:finish()
        self.playing = false
        target.Size = goal.Size
        self.Completed:Fire()
    end
    table.insert(created, tween)
    return tween
end
local FillBar = luau.load(fs.readFile("src/Client/UI/FillBar.lua"), {
    environment = {
        game = {
            GetService = function()
                return tweenService
            end,
        },
        UDim2 = roblox.UDim2,
        Color3 = roblox.Color3,
        Enum = roblox.Enum,
        TweenInfo = {
            new = function()
                return {}
            end,
        },
    },
})()
local fill = { Destroying = signal() }
local root = {
    FindFirstChild = function()
        return fill
    end,
}
for _ = 1, 100 do
    FillBar.setAnimated(root, 0.75, 0.25)
    created[#created]:finish()
end
for _, tween in ipairs(created) do
    assert(tween.destroyed, "completed HUD tween was not disposed")
end
assert(fill.Size.X.Scale == 0.75)
FillBar.setAnimated(root, 1, 0.25)
local old = created[#created]
local stale = old.Completed.connections[1].callback
FillBar.setAnimated(root, 0.5, 0.25)
local replacement = created[#created]
assert(old.destroyed and not replacement.destroyed)
stale() -- A deferred completion from the old tween must not cancel the replacement.
assert(not replacement.destroyed)
FillBar.set(root, 0.2)
assert(replacement.destroyed and math.abs(fill.Size.X.Scale - 0.2) < 1e-6)
FillBar.setAnimated(root, 1, 0.25)
created[#created]:Cancel()
assert(created[#created].destroyed, "external cancellation must dispose the tween")
FillBar.setAnimated(root, 1, 0.25)
fill.Destroying:Fire()
assert(created[#created].destroyed, "destroying the bar must dispose its active tween")
FillBar.setAnimated(root, 1, 0.25)
FillBar.setAnimated(root, -1, 0)
assert(created[#created].destroyed and fill.Size.X.Scale == 0)
for _, event in ipairs(signals) do
    for _, connection in ipairs(event.connections) do
        assert(not connection.Connected, "HUD tween lifecycle left a connected listener")
    end
end
print(
    "PASS: HUD tween completion, cancellation, replacement, stale callbacks and bar destruction clean up"
)
