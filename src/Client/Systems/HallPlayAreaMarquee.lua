--!strict

-- Client-only moving dotted boundary for authored Hall of Worlds play areas. This deliberately does
-- not consume the generic SpawnZone tag: the retired RobloxGenerateMap client did that globally and
-- leaked its outline into Crystal World. HallPlayArea is an explicit visual opt-in.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local HallFieldOutline = require(ReplicatedStorage.Shared.Game.HallFieldOutline)

local HallPlayAreaMarquee = {}

type Path = {
    points: { Vector2 },
    cumulative: { number },
    total: number,
}

type Marquee = {
    dashes: { BasePart },
    perimeter: number,
    width: number,
    depth: number,
    path: Path?,
    speed: number,
}

local started = false
local elapsed = 0
local marquees: { [BasePart]: Marquee } = {}
local watchers: { [BasePart]: RBXScriptConnection } = {}
local fxFolder: Folder? = nil

local function isOutlinePart(name: string): boolean
    return name == "FieldKerbCorner"
        or name == "FieldCorner"
        or name == "FieldKerb"
        or name == "Field"
end

local function parsePath(text: any): Path?
    if type(text) ~= "string" or text == "" then
        return nil
    end

    local points = {}
    for pair in string.gmatch(text, "[^;]+") do
        local xText, zText = string.match(pair, "^%s*([^,]+),([^,]+)%s*$")
        local x, z = tonumber(xText), tonumber(zText)
        if x and z then
            points[#points + 1] = Vector2.new(x, z)
        end
    end
    if #points < 3 then
        return nil
    end

    local cumulative = table.create(#points)
    local total = 0
    for index = 1, #points do
        local nextIndex = index % #points + 1
        cumulative[index] = total
        total += (points[nextIndex] - points[index]).Magnitude
    end
    return { points = points, cumulative = cumulative, total = total }
end

local function pathPoint(path: Path, distance: number): (Vector3, number)
    local segment = #path.points
    for index = 2, #path.points do
        if path.cumulative[index] > distance then
            segment = index - 1
            break
        end
    end

    local a = path.points[segment]
    local b = path.points[segment % #path.points + 1]
    local length = (b - a).Magnitude
    local alpha = if length > 0
        then math.clamp((distance - path.cumulative[segment]) / length, 0, 1)
        else 0
    local position = a:Lerp(b, alpha)
    local direction = b - a
    return Vector3.new(position.X, 0, position.Y), math.atan2(direction.X, direction.Y)
end

local function rectanglePoint(width: number, depth: number, distance: number): (Vector3, number)
    local halfWidth, halfDepth = width * 0.5, depth * 0.5
    if distance < depth then
        return Vector3.new(-halfWidth, 0, -halfDepth + distance), 0
    end
    distance -= depth
    if distance < width then
        return Vector3.new(-halfWidth + distance, 0, halfDepth), math.pi * 0.5
    end
    distance -= width
    if distance < depth then
        return Vector3.new(halfWidth, 0, halfDepth - distance), 0
    end
    distance -= depth
    return Vector3.new(halfWidth - distance, 0, -halfDepth), math.pi * 0.5
end

local function remove(zone: BasePart)
    local watcher = watchers[zone]
    if watcher then
        watcher:Disconnect()
        watchers[zone] = nil
    end
    local marquee = marquees[zone]
    if not marquee then
        return
    end
    for _, dash in ipairs(marquee.dashes) do
        dash:Destroy()
    end
    marquees[zone] = nil
end

local function build(instance: Instance)
    if
        not instance:IsA("BasePart")
        or marquees[instance]
        or not instance:IsDescendantOf(Workspace)
    then
        return
    end

    -- The white FieldKerb is the field outline. Follow that, not the smaller SpawnZone.
    local path = parsePath(HallFieldOutline.encode(instance))
        or parsePath(instance:GetAttribute("OutlinePath"))
    local perimeter = if path then path.total else 2 * (instance.Size.X + instance.Size.Z)
    local spacing = math.max(1, tonumber(instance:GetAttribute("DashSpacing")) or 8)
    local dashCount = math.max(8, math.floor(perimeter / spacing))
    local dashes = table.create(dashCount)
    local folder = assert(fxFolder, "Hall play-area FX folder was not initialized")

    for index = 1, dashCount do
        local dash = Instance.new("Part")
        dash.Name = "HallBoundaryDash"
        dash.Anchored = true
        dash.CanCollide = false
        dash.CanTouch = false
        dash.CanQuery = false
        dash.CastShadow = false
        dash.Material = Enum.Material.Neon
        dash.Color = Color3.new(1, 1, 1)
        dash.Size = Vector3.new(
            tonumber(instance:GetAttribute("DashWidth")) or 1.3,
            tonumber(instance:GetAttribute("DashHeight")) or 0.4,
            tonumber(instance:GetAttribute("DashLength")) or 4.5
        )
        dash.Parent = folder
        dashes[index] = dash
    end

    marquees[instance] = {
        dashes = dashes,
        perimeter = perimeter,
        width = instance.Size.X,
        depth = instance.Size.Z,
        path = path,
        speed = tonumber(instance:GetAttribute("MarqueeSpeed")) or 14,
    }

    local parent = instance.Parent
    if parent and not watchers[instance] then
        watchers[instance] = parent.DescendantAdded:Connect(function(added)
            if isOutlinePart(added.Name) then
                task.defer(function()
                    if instance.Parent then
                        remove(instance)
                        build(instance)
                    end
                end)
            end
        end)
    end
end

function HallPlayAreaMarquee.start()
    if started then
        return
    end
    started = true

    local oldFolder = Workspace:FindFirstChild("HallPlayAreaFX")
    if oldFolder then
        oldFolder:Destroy()
    end
    local folder = Instance.new("Folder")
    folder.Name = "HallPlayAreaFX"
    folder.Parent = Workspace
    fxFolder = folder

    for _, zone in ipairs(CollectionService:GetTagged("HallPlayArea")) do
        build(zone)
    end
    CollectionService:GetInstanceAddedSignal("HallPlayArea"):Connect(build)
    CollectionService:GetInstanceRemovedSignal("HallPlayArea"):Connect(function(instance)
        if instance:IsA("BasePart") then
            remove(instance)
        end
    end)

    RunService.RenderStepped:Connect(function(deltaTime)
        elapsed += deltaTime
        for zone, marquee in pairs(marquees) do
            if not zone.Parent then
                remove(zone)
            else
                local dashCount = #marquee.dashes
                for index, dash in ipairs(marquee.dashes) do
                    local distance = (
                        elapsed * marquee.speed
                        + (index - 1) * marquee.perimeter / dashCount
                    ) % marquee.perimeter
                    local localPosition, yaw
                    if marquee.path then
                        localPosition, yaw = pathPoint(marquee.path, distance)
                    else
                        localPosition, yaw = rectanglePoint(marquee.width, marquee.depth, distance)
                    end
                    dash.CFrame = zone.CFrame
                        * CFrame.new(localPosition + Vector3.new(0, 0.5, 0))
                        * CFrame.Angles(0, yaw, 0)
                end
            end
        end
    end)
end

return HallPlayAreaMarquee
