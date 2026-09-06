-- Cosmetic only. Authored endpoints are sampled, never generated or moved here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ConfigLoader = require(ReplicatedStorage.Shared.ConfigLoader)
local EnchantLightning = require(ReplicatedStorage.Shared.Effects.EnchantLightning)
local Logic = require(ReplicatedStorage.Shared.Game.HellGateLightning)
local FloraSway = require(script.Parent.FloraSway)

local HellGateLightning = {}
local connection
local gates = {}
local hidden = {}
local activeUntil = {}
local counts = { sky = 0, inner = 0 }

local function point(part)
    local p = part.Position
    return { x = p.X, y = p.Y, z = p.Z, part = part }
end

local function rescan(cfg, now)
    local root = Workspace
    for _, name in ipairs(cfg.root_path) do
        root = root and root:FindFirstChild(name)
    end
    local previous = {}
    for _, gate in ipairs(gates) do
        previous[gate.host] = gate
    end
    gates = {}
    local liveMarkers = {}
    if root then
        for _, host in ipairs(root:GetChildren()) do
            if not host:IsA("Model") or host.Name:sub(1, #cfg.host_prefix) ~= cfg.host_prefix then
                continue
            end
            local group = host:FindFirstChild(cfg.marker_group)
            if not group then
                continue
            end
            local markers = {}
            for _, names in pairs(cfg.markers) do
                for _, name in ipairs(names) do
                    local part = group:FindFirstChild(name)
                    if part and part:IsA("BasePart") then
                        markers[name] = point(part)
                        liveMarkers[part] = true
                        if cfg.hide_markers then
                            if hidden[part] == nil then
                                hidden[part] = part.LocalTransparencyModifier
                            end
                            part.LocalTransparencyModifier = 1
                        end
                    end
                end
            end
            local gate = previous[host]
                or {
                    host = host,
                    id = host.Name,
                    skyAt = Logic.nextAt(now, cfg.sky_interval, math.random()),
                    innerAt = Logic.nextAt(now, cfg.inner_interval, math.random()),
                    side = "left",
                }
            gate.roles = Logic.roles(markers, cfg.markers)
            table.insert(gates, gate)
        end
    end
    for part, transparency in pairs(hidden) do
        if not liveMarkers[part] then
            if part.Parent then
                part.LocalTransparencyModifier = transparency
            end
            hidden[part] = nil
        end
    end
end

local function emit(gate, kind, cfg, bolt, now)
    local origin, target = Logic.pick(gate.roles, kind, gate.side, math.random)
    if not origin or not target then
        return
    end
    local from, to = origin.part, target.part
    if not from:IsDescendantOf(Workspace) or not to:IsDescendantOf(Workspace) then
        return
    end
    if (from.Position - to.Position).Magnitude < cfg.minimum_span then
        return
    end
    if EnchantLightning.Play(from, bolt, to) then
        table.insert(activeUntil, now + bolt.duration + cfg.lifetime_margin_seconds)
        counts[kind] += 1
        if kind == "inner" then
            gate.side = gate.side == "left" and "right" or "left"
        end
    end
end

function HellGateLightning.stats()
    return { gates = #gates, active = #activeUntil, sky = counts.sky, inner = counts.inner }
end

function HellGateLightning.stop()
    if connection then
        connection:Disconnect()
        connection = nil
    end
    for part, transparency in pairs(hidden) do
        if part.Parent then
            part.LocalTransparencyModifier = transparency
        end
    end
    table.clear(hidden)
    table.clear(gates)
    -- Already emitted bolts own their bounded lifetime. Preserve their slot
    -- leases if stop/start happens before that lifetime expires.
end

function HellGateLightning.start()
    if connection then
        return
    end
    local cfg = ConfigLoader:LoadConfig("hall_of_worlds").hell_gate_lightning
    if not cfg or cfg.enabled == false then
        return
    end
    local bolt = table.clone(cfg.bolt)
    bolt.target_offset = Vector3.new(table.unpack(bolt.target_offset))
    local rescanAt, updateAt = 0, 0
    connection = RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if now >= rescanAt then
            rescanAt = now + cfg.rescan_seconds
            rescan(cfg, now)
        end
        if now < updateAt then
            return
        end
        updateAt = now + cfg.update_seconds
        for index = #activeUntil, 1, -1 do
            if activeUntil[index] <= now then
                table.remove(activeUntil, index)
            end
        end
        if cfg.respect_prop_effects and not FloraSway.isEnabled() then
            return
        end
        local character = Players.LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not root then
            return
        end
        for _, gate in
            ipairs(Logic.nearest(gates, point(root), cfg.view_distance, cfg.maximum_visible_gates))
        do
            for _, kind in ipairs({ "sky", "inner" }) do
                local key = kind .. "At"
                if now >= gate[key] and #activeUntil < cfg.maximum_active_strikes then
                    gate[key] = Logic.nextAt(now, cfg[kind .. "_interval"], math.random())
                    emit(gate, kind, cfg, bolt, now)
                end
            end
        end
    end)
end

return HellGateLightning
