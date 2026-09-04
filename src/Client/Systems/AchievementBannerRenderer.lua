--!strict

-- Turns attributes on explicitly tagged banner models into real cloth artwork. EditableImages are
-- cached by design; each skinned Cloth MeshPart gets a SurfaceAppearance (or TextureContent
-- fallback) that follows its authored UV and bones.

local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Locations = require(ReplicatedStorage.Shared.Locations)
local ConfigLoader = require(Locations.ConfigLoader)
local BannerDesign = require(ReplicatedStorage.Shared.Game.AchievementBannerDesign)

-- Content is a Roblox datatype global newer than Selene's bundled Roblox standard library.
-- Resolve it through the module environment until that standard library catches up.
local ContentType = (getfenv() :: any).Content

local AchievementBannerRenderer = {}

local RUNTIME_APPEARANCE = "AchievementBannerRuntimeAppearance"
local started = false
local config: any = nil
local imageCache: { [string]: EditableImage } = {}
local tracked: { [Instance]: { RBXScriptConnection } } = {}
local revisions: { [Instance]: number } = {}
local applied: { [Instance]: string } = {}

local function locateCloth(host: Instance): MeshPart?
    if host:IsA("MeshPart") and host.Name == config.model.cloth_name then
        return host
    end
    local child = host:FindFirstChild(config.model.cloth_name, true)
    if child and child:IsA("MeshPart") then
        return child
    end
    return nil
end

local function specFromAttributes(host: Instance): any
    return {
        style = host:GetAttribute("AchievementStyle") or "champion",
        title = host:GetAttribute("AchievementTitle"),
        value = host:GetAttribute("AchievementValue") or 0,
        footer = host:GetAttribute("AchievementFooter"),
    }
end

local function cachedImage(rendered: any): EditableImage?
    local existing = imageCache[rendered.cacheKey]
    if existing then
        return existing
    end
    local ok, editable = pcall(function()
        return AssetService:CreateEditableImage({
            Size = Vector2.new(rendered.size, rendered.size),
        })
    end)
    if not ok or not editable then
        warn("AchievementBannerRenderer: EditableImage allocation failed", editable)
        return nil
    end
    local wrote, writeError = pcall(function()
        editable:WritePixelsBuffer(
            Vector2.new(0, 0),
            Vector2.new(rendered.size, rendered.size),
            rendered.pixels
        )
    end)
    if not wrote then
        warn("AchievementBannerRenderer: pixel upload failed", writeError)
        editable:Destroy()
        return nil
    end
    imageCache[rendered.cacheKey] = editable
    return editable
end

local function clearAppearance(cloth: MeshPart)
    local prior = cloth:FindFirstChild(RUNTIME_APPEARANCE)
    if prior then
        prior:Destroy()
    end
end

local function apply(host: Instance, expectedRevision: number)
    local cloth = locateCloth(host)
    if not cloth then
        return
    end
    local rendered = BannerDesign.render(specFromAttributes(host), config)
    local editable = cachedImage(rendered)
    if not editable or revisions[host] ~= expectedRevision or not host.Parent then
        return
    end

    cloth.DoubleSided = true
    assert(ContentType, "Roblox Content datatype is unavailable")
    local content = ContentType.fromObject(editable)
    local madeSurface, surfaceOrError = pcall(function()
        return AssetService:CreateSurfaceAppearanceAsync({
            ColorMap = content,
        })
    end)
    if revisions[host] ~= expectedRevision or not host.Parent then
        if madeSurface and surfaceOrError then
            surfaceOrError:Destroy()
        end
        return
    end
    clearAppearance(cloth)
    if madeSurface and surfaceOrError and surfaceOrError:IsA("SurfaceAppearance") then
        surfaceOrError.Name = RUNTIME_APPEARANCE
        surfaceOrError.Parent = cloth
        applied[host] = rendered.cacheKey
    else
        -- TextureContent supports EditableImage directly and keeps the banner useful on engine
        -- channels where CreateSurfaceAppearanceAsync is unavailable or temporarily fails.
        local fallbackOk, fallbackError = pcall(function()
            cloth.TextureContent = content
        end)
        if not fallbackOk then
            warn(
                "AchievementBannerRenderer: texture application failed",
                surfaceOrError,
                fallbackError
            )
        else
            applied[host] = rendered.cacheKey
        end
    end
end

local function schedule(host: Instance)
    local revision = (revisions[host] or 0) + 1
    revisions[host] = revision
    applied[host] = nil
    task.spawn(function()
        local ok, err = pcall(apply, host, revision)
        if not ok then
            warn("AchievementBannerRenderer: render failed", err)
        end
    end)
end

local function forget(host: Instance)
    local connections = tracked[host]
    if connections then
        for _, connection in connections do
            connection:Disconnect()
        end
    end
    tracked[host] = nil
    revisions[host] = nil
    applied[host] = nil
end

local function remember(host: Instance)
    if tracked[host] then
        schedule(host)
        return
    end
    local connections = {}
    tracked[host] = connections
    for _, attribute in
        {
            "AchievementStyle",
            "AchievementTitle",
            "AchievementValue",
            "AchievementFooter",
        }
    do
        table.insert(
            connections,
            host:GetAttributeChangedSignal(attribute):Connect(function()
                schedule(host)
            end)
        )
    end
    table.insert(
        connections,
        host.AncestryChanged:Connect(function(_, parent)
            if not parent then
                forget(host)
            end
        end)
    )
    schedule(host)
end

function AchievementBannerRenderer.decorate(host: Instance)
    if not started then
        AchievementBannerRenderer.start()
    end
    remember(host)
end

function AchievementBannerRenderer.start()
    if started then
        return
    end
    started = true
    config = ConfigLoader:LoadConfig("achievement_banners")
    CollectionService:GetInstanceAddedSignal(config.tag):Connect(remember)
    CollectionService:GetInstanceRemovedSignal(config.tag):Connect(forget)
    for _, host in CollectionService:GetTagged(config.tag) do
        remember(host)
    end
    -- Tags authored in Edit can arrive before their streamed instance (or vice versa) without an
    -- AddedSignal edge on every client. A cheap tagged-only rescan closes that replication seam.
    local elapsed = 0
    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed < config.texture.rescan_seconds then
            return
        end
        elapsed = 0
        for _, host in CollectionService:GetTagged(config.tag) do
            if not tracked[host] then
                remember(host)
            elseif not applied[host] then
                -- The tag can stream before the imported Cloth descendant. Retry until one
                -- complete design has actually landed, then stay idle until attributes change.
                schedule(host)
            end
        end
    end)
end

return AchievementBannerRenderer
