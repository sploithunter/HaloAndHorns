--[[
    BlockLetterRainbow — client-only shop-sign visualization.

    Builds the roof letters locally from hoverboard config and slides the
    rainbow through them. No server parts, no replicated tags.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BlockLetterSign = require(ReplicatedStorage.Shared.Assets.BlockLetterSign)

local BlockLetterRainbow = {}
local started = false
local signs = {}

local function loadHoverboard()
    local ok, cfg = pcall(function()
        return require(ReplicatedStorage.Configs.hoverboard)
    end)
    if ok and type(cfg) == "table" then
        return cfg
    end
    return nil
end

local function collect(model)
    local groups = {}
    local count = tonumber(model:GetAttribute("RainbowCount")) or 0
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
            local index = tonumber(descendant:GetAttribute("RainbowIndex"))
            if index then
                local bucket = groups[index]
                if not bucket then
                    bucket = {}
                    groups[index] = bucket
                end
                table.insert(bucket, descendant)
                if index > count then
                    count = index
                end
            end
        end
    end
    return {
        groups = groups,
        count = math.max(count, 1),
    }
end

local function bind(model)
    if not model or signs[model] then
        return
    end
    signs[model] = collect(model)
    model.Destroying:Connect(function()
        signs[model] = nil
    end)
end

local function waitShack(location)
    location = location or {}
    local maps = Workspace:WaitForChild("Maps", 30)
    local world = maps and maps:WaitForChild(location.map_name or "FuturePath", 30)
    local tiles = world and world:WaitForChild("Tiles", 15)
    local tile = tiles and tiles:WaitForChild(location.tile_name or "Tile01_cap", 15)
    return tile and tile:WaitForChild(location.model_name or "Shack", 15)
end

local function spawnKadeSign()
    local config = loadHoverboard()
    local shop = config and config.shop
    local location = shop and shop.location
    local sign = location and location.sign
    if type(sign) ~= "table" or type(sign.lines) ~= "table" then
        return
    end
    local shack = waitShack(location)
    if not shack then
        return
    end
    local existing = shack:FindFirstChild(sign.name or "KadesBoardsSign")
    if existing then
        existing:Destroy()
    end
    local model = BlockLetterSign.build(shack, sign)
    if model then
        bind(model)
    end
end

function BlockLetterRainbow.start()
    if started then
        return
    end
    started = true
    task.spawn(spawnKadeSign)
    RunService.Heartbeat:Connect(function()
        local now = os.clock()
        for model, state in pairs(signs) do
            if not model.Parent then
                signs[model] = nil
            else
                local speed = tonumber(model:GetAttribute("RainbowSpeed")) or 0
                if speed ~= 0 and state.count > 0 and next(state.groups) ~= nil then
                    local sat = tonumber(model:GetAttribute("RainbowSaturation")) or 1
                    local value = tonumber(model:GetAttribute("RainbowValue")) or 1
                    local phase = now * speed
                    for index, parts in pairs(state.groups) do
                        local color = Color3.fromHSV(
                            BlockLetterSign.rainbowHue(index, state.count, phase),
                            sat,
                            value
                        )
                        for _, part in ipairs(parts) do
                            part.Color = color
                        end
                    end
                end
            end
        end
    end)
end

return BlockLetterRainbow
