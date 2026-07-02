--[[
    RealmPortalLock (client) — PER-PLAYER level lock on open realm portals (World S3).

    RealmPortalService stamps a static face label on every BUILT portal ("Heaven 1 · Lv 7"), the
    same for everyone. But whether you can ENTER is per-player (your earned Level vs the layer's
    requires_level), so the lock has to be client-side. This system overlays a 🔒 on the portals the
    LOCAL player can't enter yet, and drops it the instant they level past the requirement — so a
    locked portal reads like the COMING-SOON lock, and an unlocked one is just the label (Jason:
    "if they're locked they should have a lock... if they're unlocked we should still have a label").

    It reuses the server's badge GUIs (RealmLockBadgeFront/Back) so placement is free, and matches the
    server's two caption layouts exactly (centered when open, dropped-below-the-lock when locked). It
    never touches the COMING-SOON badges (those carry the server 🔒 and are hard-locked for everyone).
    Display-only — the server touch path is the real gate.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RealmPortalLock = {}

local BADGE_NAMES = { RealmLockBadgeFront = true, RealmLockBadgeBack = true }
local LOCK_GLYPH = "🔒"

-- Caption layouts mirror RealmPortalService._addLockBadge: open = centered, locked = dropped below
-- the lock so the 🔒 owns the middle of the oval (exactly like COMING SOON).
local OPEN_CAPTION = {
    Size = UDim2.fromScale(0.62, 0.34),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
}
local LOCKED_CAPTION = {
    Size = UDim2.fromScale(0.52, 0.1),
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.fromScale(0.5, 0.66),
}

local function loadConfig()
    local configs = ReplicatedStorage:FindFirstChild("Configs")
    local mod = configs and configs:FindFirstChild("layers")
    if mod and mod:IsA("ModuleScript") then
        local ok, cfg = pcall(require, mod)
        if ok and type(cfg) == "table" then
            return cfg
        end
    end
    return nil
end

-- Build { partName -> requiredLevel } for the gated portals (skip ungated / no-level layers).
local function portalMap(cfg)
    local out = {}
    local rp = cfg.realm_portals
    local access = cfg.access
    if type(rp) ~= "table" or type(rp.portals) ~= "table" or type(access) ~= "table" then
        return out
    end
    for _, def in ipairs(rp.portals) do
        local a = def.layer and access[def.layer]
        local req = a and tonumber(a.requires_level)
        if def.part and req and req > 1 then
            out[def.part] = req
        end
    end
    return out
end

-- The server caption (the "Heaven 1 · Lv 7" label) is the badge's TextLabel that isn't our lock and
-- isn't a bare 🔒 (the COMING-SOON lock). Returns nil if this is a COMING-SOON badge.
local function captionAndComingSoon(badge)
    local caption, comingSoon = nil, false
    for _, ch in ipairs(badge:GetChildren()) do
        if ch:IsA("TextLabel") and ch.Name ~= "RealmPlayerLock" then
            if ch.Text == LOCK_GLYPH then
                comingSoon = true -- the server's hard 🔒 → leave this badge alone
            else
                caption = ch
            end
        end
    end
    return caption, comingSoon
end

local function ensureLockLabel(badge)
    local lock = badge:FindFirstChild("RealmPlayerLock")
    if lock then
        return lock
    end
    lock = Instance.new("TextLabel")
    lock.Name = "RealmPlayerLock"
    lock.Size = UDim2.fromScale(0.62, 0.62)
    lock.AnchorPoint = Vector2.new(0.5, 0.5)
    lock.Position = UDim2.fromScale(0.5, 0.45)
    lock.BackgroundTransparency = 1
    lock.Text = LOCK_GLYPH
    lock.TextScaled = true
    lock.Font = Enum.Font.GothamBlack
    lock.TextColor3 = Color3.fromRGB(255, 255, 255)
    lock.TextStrokeTransparency = 0.2
    lock.Visible = false
    lock.Parent = badge
    return lock
end

local function applyLayout(label, layout)
    label.Size = layout.Size
    label.AnchorPoint = layout.AnchorPoint
    label.Position = layout.Position
end

function RealmPortalLock.start()
    local player = Players.LocalPlayer
    if not player then
        return
    end
    local cfg = loadConfig()
    if not cfg then
        return
    end
    local gated = portalMap(cfg)
    if not next(gated) then
        return
    end

    local function level()
        return tonumber(player:GetAttribute("Level")) or 1
    end

    -- Apply the per-player lock state to one open portal's badges.
    local function applyPortal(part, requiredLevel, lvl)
        local model = part:FindFirstAncestorOfClass("Model") or part
        local locked = lvl < requiredLevel
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("SurfaceGui") and BADGE_NAMES[d.Name] then
                local caption, comingSoon = captionAndComingSoon(d)
                if not comingSoon then -- only OPEN portals get the per-player lock
                    local lockLabel = ensureLockLabel(d)
                    lockLabel.Visible = locked
                    if caption then
                        applyLayout(caption, locked and LOCKED_CAPTION or OPEN_CAPTION)
                    end
                end
            end
        end
    end

    local function refreshAll()
        local lvl = level()
        for name, requiredLevel in pairs(gated) do
            local part = Workspace:FindFirstChild(name, true)
            if part then
                applyPortal(part, requiredLevel, lvl)
            end
        end
    end

    refreshAll()
    player:GetAttributeChangedSignal("Level"):Connect(refreshAll)
    -- Portals/badges can stream in or be stamped slightly after we start — re-run a few times so the
    -- lock lands once everything exists (cheap: a handful of FindFirstChild scans).
    task.spawn(function()
        for _ = 1, 15 do
            task.wait(2)
            refreshAll()
        end
    end)
end

return RealmPortalLock
