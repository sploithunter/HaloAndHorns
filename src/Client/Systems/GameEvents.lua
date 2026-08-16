--[[
    GameEvents (client) — one hook for every gameplay event; configs/game_events.lua decides the
    reactions.

    Game code DETECTS an event (a level changed, a death, a hit) and calls GameEvents.fire(name, ctx).
    This dispatcher looks up configs/game_events.lua[name] and applies each configured reaction by
    kind. Reaction handlers are registered here once (sound now; vfx/toast/callback can be added the
    same way). So "react to event X" is config; the only code is firing the event and the generic
    handler for each reaction kind.

      • Local fire:  require this module and call GameEvents.fire("level_up", { level = n })
      • Server fire: Signals.GameEvent:FireClient(player, name, ctx) -> bridged to fire() in start()
]]

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local SoundGroups = require(ReplicatedStorage.Shared.Effects.SoundGroups)
local sounds = require(ReplicatedStorage.Configs:WaitForChild("sounds"))
local eventConfig = require(ReplicatedStorage.Configs:WaitForChild("game_events"))
local items = require(ReplicatedStorage.Configs:WaitForChild("items"))
local potions = require(ReplicatedStorage.Configs:WaitForChild("potions"))
local POWER_ICONS = require(ReplicatedStorage.Configs:WaitForChild("power_icons"))
local PetBadge = require(script.Parent.Parent.UI.PetBadge)
local AscensionPresentation = require(script.Parent.AscensionPresentation)

local GameEvents = {}

-- reaction kind -> handler(spec, ctx). Add a new kind here and it's instantly usable from config.
local REACTIONS = {}

-- sound: spec is a key into configs/sounds.lua; play it one-shot on its configured bus.
REACTIONS.sound = function(soundKey)
    -- string key, or { key = "...", volume = 0.5 } for a per-EVENT volume scale
    -- (Jason: the achievement jingle "needs to be about half" — other users of the
    -- same sound keep their loudness)
    local volumeScale = 1
    if type(soundKey) == "table" then
        volumeScale = tonumber(soundKey.volume) or 1
        soundKey = soundKey.key
    end
    local def = soundKey and sounds[soundKey]
    if not (def and def.id) then
        return
    end
    local s = Instance.new("Sound")
    s.SoundId = def.id
    s.Volume = (def.volume or 0.7) * volumeScale
    s.PlaybackSpeed = def.playback_speed or 1
    SoundGroups.assign(s, def.bus or "ui")
    s.Parent = SoundService
    s:Play()
    s.Ended:Once(function()
        s:Destroy()
    end)
    task.delay(8, function() -- safety cleanup if Ended never fires (unapproved/failed asset)
        if s.Parent then
            s:Destroy()
        end
    end)
end

-- vfx: spec = { kind = "burst", color = {r,g,b}?, count = n? }. A self-contained celebratory burst
-- (neon shards flying outward + fading) at the local player — no asset/CombatFX dependency, so it
-- always renders. More `kind`s can be added here (or routed to CombatFX) without config changes.
REACTIONS.vfx = function(spec)
    spec = type(spec) == "table" and spec or {}
    if spec.kind ~= "burst" then
        return
    end
    local char = Players.LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return
    end
    local c = spec.color
    local color = (type(c) == "table") and Color3.fromRGB(c[1] or 255, c[2] or 255, c[3] or 255)
        or Color3.fromRGB(255, 205, 70)
    local count = tonumber(spec.count) or 16
    local origin = hrp.Position + Vector3.new(0, 2, 0)
    for i = 1, count do
        local part = Instance.new("Part")
        part.Size = Vector3.new(0.35, 0.35, 0.35)
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CastShadow = false
        part.Material = Enum.Material.Neon
        part.Color = color
        part.CFrame = CFrame.new(origin)
        part.Parent = Workspace
        local ang = (i / count) * math.pi * 2
        local dist = 3.5 + (i % 3)
        local target = origin + Vector3.new(math.cos(ang) * dist, 2 + (i % 4), math.sin(ang) * dist)
        TweenService:Create(part, TweenInfo.new(0.8, Enum.EasingStyle.Quad), {
            CFrame = CFrame.new(target),
            Transparency = 1,
            Size = Vector3.new(0.05, 0.05, 0.05),
        }):Play()
        task.delay(0.9, function()
            if part.Parent then
                part:Destroy()
            end
        end)
    end
end

-- fanfare: a LOCAL, non-interrupting world celebration AROUND the leveling player — rising gold
-- sparkles + a warm glow that runs as long as the paired song. spec = { sound = "<sounds key>" } ->
-- duration = sounds[sound].duration_seconds (the SSOT in sounds.lua; Jason: "keep the length in
-- config so the animation knows how long to go"); falls back to spec.seconds. The effect rides an
-- Attachment on the HRP so it FOLLOWS the player and never locks input/combat — you keep fighting
-- while it plays. The SOUND is world-wide (world_sound, server-side); this visual is the leveler's
-- local event ("starts out with sparkles... centers around the player" — Jason).
REACTIONS.fanfare = function(spec)
    spec = type(spec) == "table" and spec or {}
    local char = Players.LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return
    end
    local def = spec.sound and sounds[spec.sound]
    local dur = (def and tonumber(def.duration_seconds)) or tonumber(spec.seconds) or 7

    -- follows the player (centred on them; no physics, no input lock)
    local att = Instance.new("Attachment")
    att.Name = "LevelUpFanfare"
    att.Parent = hrp

    -- rising gold sparkles — the sustained body, emits for the whole song
    local sparks = Instance.new("ParticleEmitter")
    sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    sparks.Color = ColorSequence.new(Color3.fromRGB(255, 230, 140), Color3.fromRGB(255, 165, 55))
    sparks.LightEmission = 1
    sparks.LightInfluence = 0
    sparks.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.9),
        NumberSequenceKeypoint.new(1, 0),
    })
    sparks.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.05),
        NumberSequenceKeypoint.new(0.85, 0.35),
        NumberSequenceKeypoint.new(1, 1),
    })
    sparks.Lifetime = NumberRange.new(1.1, 1.8)
    sparks.Rate = 55
    sparks.Speed = NumberRange.new(3, 6)
    sparks.SpreadAngle = Vector2.new(28, 28)
    sparks.Acceleration = Vector3.new(0, 7, 0) -- waft upward
    sparks.Rotation = NumberRange.new(0, 360)
    sparks.Parent = att

    -- warm glow: pulses up on the downbeat, holds, fades out with the last bar
    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 205, 110)
    light.Range = 18
    light.Brightness = 0
    light.Shadows = false
    light.Parent = att
    TweenService:Create(light, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Brightness = 3.5 })
        :Play()

    -- wind down: stop spawning a beat early (stragglers fade), drop the glow, then clean up
    task.delay(math.max(0.1, dur - 1.0), function()
        if sparks.Parent then
            sparks.Enabled = false
        end
        if light.Parent then
            TweenService
                :Create(light, TweenInfo.new(1.0, Enum.EasingStyle.Quad), { Brightness = 0 })
                :Play()
        end
    end)
    task.delay(dur + 2.2, function()
        if att.Parent then
            att:Destroy()
        end
    end)
end

-- ascension: the altar claim ceremony. Presentation is deliberately separated from the
-- authoritative claim: it animates a local visual clone and can never move or mutate the player.
REACTIONS.ascension = function(spec, ctx)
    -- `level_claimed` is emitted only after the server accepts the claim. Dismiss the choice menu
    -- synchronously so the ceremony never starts behind the menu or races its exit tween.
    local menuManager = rawget(_G, "MenuManager")
    if menuManager and menuManager.CloseCurrentPanelImmediately then
        menuManager:CloseCurrentPanelImmediately("PowerChoice")
    end
    AscensionPresentation.play(ctx, spec)
end

-- float: rising announcement text. spec = { color = {r,g,b}?, prefix = ""?, size = px? };
-- the TEXT comes from ctx.name (config stays generic). Anchors at ctx.position (a Vector3 —
-- e.g. the broken crystal) when given, else at the local player.
-- banner: a LINGERING screen-center announcement card — "you got an achievement"-class
-- moments (Jason: floats are too quick for these; and NEVER play a sound without a
-- visual). Text = ctx.name; spec = { seconds (default 5), color {r,g,b} }.
-- One banner at a time: a newer one replaces the current.
local activeBanner
REACTIONS.banner = function(spec, ctx)
    spec = type(spec) == "table" and spec or {}
    local text = (ctx and ctx.name) and tostring(ctx.name) or nil
    if not text then
        return
    end
    local player = Players.LocalPlayer
    local pg = player and player:FindFirstChild("PlayerGui")
    if not pg then
        return
    end
    if activeBanner then
        activeBanner:Destroy()
        activeBanner = nil
    end
    local gui = Instance.new("ScreenGui")
    gui.Name = "GameEventBanner"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 60
    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0.5, 0)
    card.Position = UDim2.new(0.5, 0, 0.28, 0)
    card.Size = UDim2.fromOffset(380, 56)
    card.BackgroundColor3 = Color3.fromRGB(24, 22, 32)
    card.BackgroundTransparency = 0.08
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = card
    local accent = spec.color and Color3.fromRGB(spec.color[1], spec.color[2], spec.color[3])
        or Color3.fromRGB(255, 200, 90)
    local stroke = Instance.new("UIStroke")
    stroke.Color = accent
    stroke.Thickness = 2.5
    stroke.Parent = card
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -24, 1, -12)
    label.Position = UDim2.fromOffset(12, 6)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = accent
    label.TextScaled = true
    label.Font = Enum.Font.GothamBlack
    label.Parent = card
    card.Parent = gui
    gui.Parent = pg
    pcall(function()
        require(script.Parent.Parent.UI.UIViewportScale).attach(card)
    end)
    activeBanner = gui
    -- Jason: not a parked center banner ("annoying") — the card FLOATS UP slowly the
    -- whole time and dissolves near the end. Slow enough to read (spec.seconds, def 5).
    local seconds = tonumber(spec.seconds) or 5
    local TweenService = game:GetService("TweenService")
    TweenService:Create(
        card,
        TweenInfo.new(seconds, Enum.EasingStyle.Linear),
        { Position = UDim2.new(0.5, 0, 0.10, 0) } -- gentle rise from 0.28 screen height
    ):Play()
    local fade = TweenInfo.new(seconds * 0.35) -- dissolve over the last third
    task.delay(seconds * 0.65, function()
        if activeBanner ~= gui then
            return
        end
        TweenService:Create(card, fade, { BackgroundTransparency = 1 }):Play()
        TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
        TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
    end)
    task.delay(seconds, function()
        if activeBanner == gui then
            activeBanner = nil
        end
        gui:Destroy()
    end)
end

function GameEvents.showBanner(text, spec)
    REACTIONS.banner(spec or {}, { name = tostring(text or "") })
end

REACTIONS.float = function(spec, ctx)
    spec = type(spec) == "table" and spec or {}
    local text = (ctx and ctx.name) and tostring(ctx.name) or nil
    if not text then
        return
    end
    if spec.prefix then
        text = tostring(spec.prefix) .. text
    end
    local adornee
    if ctx and typeof(ctx.position) == "Vector3" then
        -- world-anchored: a throwaway anchor part at the event position
        local anchor = Instance.new("Part")
        anchor.Anchored = true
        anchor.CanCollide = false
        anchor.CanQuery = false
        anchor.Transparency = 1
        anchor.Size = Vector3.new(0.1, 0.1, 0.1)
        anchor.CFrame = CFrame.new(ctx.position)
        anchor.Parent = Workspace
        task.delay(2, function()
            anchor:Destroy()
        end)
        adornee = anchor
    else
        local char = Players.LocalPlayer.Character
        adornee = char and char:FindFirstChild("HumanoidRootPart")
    end
    if not adornee then
        return
    end
    local c = spec.color
    local color = (type(c) == "table") and Color3.fromRGB(c[1] or 255, c[2] or 255, c[3] or 255)
        or Color3.fromRGB(255, 235, 170)
    -- Duration: rise + fade span (default 1.6s for the quick farming floats). A row can
    -- set `seconds` to linger — the daily-reward float runs ~8s so it reads at a glance.
    local seconds = tonumber(spec.seconds) or 1.6
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.fromOffset(spec.size or 360, 44)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Adornee = adornee
    bb.Parent = adornee
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextScaled = true
    lbl.Text = text
    lbl.TextColor3 = color
    lbl.TextStrokeTransparency = 0.3
    lbl.Parent = bb
    TweenService:Create(bb, TweenInfo.new(seconds, Enum.EasingStyle.Quad), {
        StudsOffset = Vector3.new(0, 7, 0),
    }):Play()
    TweenService:Create(lbl, TweenInfo.new(seconds), {
        TextTransparency = 1,
        TextStrokeTransparency = 1,
    }):Play()
    task.delay(seconds + 0.1, function()
        bb:Destroy()
    end)
end

-- effect_transfer: make a consumable explain itself spatially. Its universal badge blooms at
-- screen centre, then one or more copies fly to the HUD surface affected by the mechanic:
-- player status row, deployed squad cards, or the selected enemy. This is presentation only;
-- the server has already applied and persisted the effect before it fires the event.
local itemById = {}
for _, def in ipairs(items) do
    if def.id then
        itemById[def.id] = def
    end
end

local function transferBadge(ctx)
    ctx = type(ctx) == "table" and ctx or {}
    if type(ctx.badge) == "table" then
        return ctx.badge
    end
    if ctx.potion then
        local potion = potions.potions and potions.potions[ctx.potion]
        return potion and PetBadge.forPotion(potion.meter) or nil
    end
    local item = itemById[ctx.itemId]
    if not item then
        return nil
    end
    if type(item.badge) == "table" then
        local raw = item.badge
        local ring = POWER_ICONS.rings[raw.ring] and raw.ring
            or POWER_ICONS.targeting_ring[raw.ring or raw.target or "none"]
            or "aura"
        return { element = raw.element, symbol = raw.symbol, ring = ring }
    end
    return item.icon_power and PetBadge.forPower(item.icon_power) or nil
end

local function actuallyVisible(guiObject)
    if not (guiObject and guiObject:IsA("GuiObject")) then
        return false
    end
    if guiObject.AbsoluteSize.X <= 0 or guiObject.AbsoluteSize.Y <= 0 then
        return false
    end
    local node = guiObject
    while node do
        if node:IsA("GuiObject") and not node.Visible then
            return false
        end
        if node:IsA("LayerCollector") and not node.Enabled then
            return false
        end
        node = node.Parent
    end
    return true
end

local function guiCenter(guiObject)
    if typeof(guiObject) == "Vector2" then
        return guiObject
    end
    return guiObject.AbsolutePosition + guiObject.AbsoluteSize / 2
end

local function collectTransferTargets(ctx)
    local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then
        return {}
    end
    local scope = tostring(ctx.targetScope or "player")
    local targets = {}
    if scope == "pets" then
        -- Squad-scoped buffs belong to the squad HUD, not the moving 3D companions. This keeps
        -- the result legible during combat/mining and gives Berserk Brew, heals, and future squad
        -- consumables one stable destination regardless of camera framing.
        local squad = playerGui:FindFirstChild("SquadHud")
        local seen = {}
        for _, obj in ipairs((squad and squad:GetDescendants()) or {}) do
            if
                obj:IsA("GuiObject")
                and (obj.Name:match("^Slot_%d+$") or obj.Name:match("^Pet_%d+$"))
                and actuallyVisible(obj)
            then
                local center = guiCenter(obj)
                local key = math.floor(center.X / 8) .. ":" .. math.floor(center.Y / 8)
                if not seen[key] then
                    seen[key] = true
                    targets[#targets + 1] = obj
                    if #targets >= 12 then
                        break
                    end
                end
            end
        end
        -- Compact/bar modes can collapse every individual card. In that state, land the transfer
        -- once on the visible team handle; expanding the HUD is not required just to show a buff.
        if #targets == 0 then
            local handle = squad and squad:FindFirstChild("TeamHandle", true)
            if handle and actuallyVisible(handle) then
                targets[1] = handle
            end
        end
    elseif scope == "enemy" then
        local enemyHud = playerGui:FindFirstChild("EnemyHud")
        local exactName = ctx.targetId ~= nil and ("Enemy_" .. tostring(ctx.targetId)) or nil
        local fallback
        for _, obj in ipairs((enemyHud and enemyHud:GetDescendants()) or {}) do
            if obj:IsA("GuiObject") and obj.Name:match("^Enemy_") and actuallyVisible(obj) then
                if exactName and obj.Name == exactName then
                    targets[1] = obj
                    break
                end
                fallback = fallback or obj
            end
        end
        if #targets == 0 and fallback then
            targets[1] = fallback
        end
    else
        local playerBar = playerGui:FindFirstChild("PlayerBar")
        local capsule = playerBar and playerBar:FindFirstChild("Capsule", true)
        local exact = ctx.destinationAttr
            and capsule
            and capsule:FindFirstChild("PBadge_" .. tostring(ctx.destinationAttr), true)
        if exact and actuallyVisible(exact) then
            targets[1] = exact
        elseif capsule and actuallyVisible(capsule) then
            targets[1] = capsule
        end
    end
    return targets
end

local function createTransferIcon(parent, badge, size, zIndex)
    local frame = Instance.new("Frame")
    frame.Name = "EffectTransferIcon"
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Size = UDim2.fromOffset(size, size)
    frame.BackgroundTransparency = 1
    frame.ZIndex = zIndex
    frame.Parent = parent
    PetBadge.create(frame, {
        element = badge.element,
        symbol = badge.symbol,
        ring = badge.ring or "aura",
        zIndex = zIndex,
    })
    return frame
end

REACTIONS.effect_transfer = function(_spec, ctx)
    ctx = type(ctx) == "table" and ctx or {}
    local badge = transferBadge(ctx)
    local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
    if not (badge and badge.symbol and playerGui) then
        return
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "EffectTransfer"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 72
    gui.Parent = playerGui

    local viewport = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize
        or Vector2.new(1280, 720)
    local center = viewport * 0.5
    local icon = createTransferIcon(gui, badge, 24, 30)
    icon.Position = UDim2.fromOffset(center.X, center.Y)
    local scale = Instance.new("UIScale")
    scale.Scale = 0.15
    scale.Parent = icon
    local bloom = TweenService:Create(
        scale,
        TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Scale = 6.5 }
    )

    bloom.Completed:Once(function()
        if not gui.Parent then
            return
        end
        local targets = collectTransferTargets(ctx)
        if #targets == 0 then
            targets = collectTransferTargets({ targetScope = "player" })
        end
        local flightsRemaining = #targets
        for i, target in ipairs(targets) do
            local destination = guiCenter(target)
            local flying = createTransferIcon(gui, badge, 112, 30 + i)
            flying.Position = UDim2.fromOffset(center.X, center.Y)
            local targetSize = typeof(target) == "Vector2" and 38
                or math.clamp(math.min(target.AbsoluteSize.X, target.AbsoluteSize.Y), 28, 46)
            local flight = TweenService:Create(
                flying,
                TweenInfo.new(0.58, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut),
                {
                    Position = UDim2.fromOffset(destination.X, destination.Y),
                    Size = UDim2.fromOffset(targetSize, targetSize),
                    Rotation = (i % 2 == 0) and 18 or -18,
                }
            )
            flight.Completed:Once(function()
                if flying.Parent then
                    local settle = TweenService:Create(flying, TweenInfo.new(0.16), {
                        Size = UDim2.fromOffset(4, 4),
                    })
                    settle.Completed:Once(function()
                        flying:Destroy()
                        flightsRemaining -= 1
                        if flightsRemaining == 0 and gui.Parent then
                            gui:Destroy()
                        end
                    end)
                    settle:Play()
                end
            end)
            flight:Play()
        end
        local flash = TweenService:Create(scale, TweenInfo.new(0.18), { Scale = 7.4 })
        flash.Completed:Once(function()
            if icon.Parent then
                icon:Destroy()
            end
            if flightsRemaining == 0 and gui.Parent then
                gui:Destroy()
            end
        end)
        flash:Play()
    end)
    bloom:Play()
end

-- Fire a named event: apply every configured reaction. `ctx` is forwarded to handlers (future use).
function GameEvents.fire(name, ctx)
    local entry = eventConfig[name]
    if type(entry) ~= "table" then
        return -- no reactions configured for this event
    end
    for kind, spec in pairs(entry) do
        local handler = REACTIONS[kind]
        if handler then
            local ok, err = pcall(handler, spec, ctx)
            if not ok then
                warn(
                    ("GameEvents: reaction '%s' for '%s' failed: %s"):format(
                        kind,
                        name,
                        tostring(err)
                    )
                )
            end
        end
    end
end

-- Bridge server-origin events (death/hit/...) onto the same hook.
function GameEvents.start()
    if Signals.GameEvent then
        Signals.GameEvent.OnClientEvent:Connect(function(name, ctx)
            if type(name) == "string" then
                GameEvents.fire(name, ctx)
            end
        end)
    end
    return GameEvents
end

local _ = Players.LocalPlayer -- ensure client context
return GameEvents
