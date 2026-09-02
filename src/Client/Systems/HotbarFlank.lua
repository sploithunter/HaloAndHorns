--[[
    HotbarFlank (client) — dock Pets + Menu + Powers + Board around the power bar:

        Desktop:  [pets] [ ----------powerbar---------- ] [powers] [board]
        Compact:  [pets] [ ----------powerbar---------- ] [powers]
                  [menu]                                  [board]
                  Same 48px squares both sides. Admin sits in the far
                  lower-left corner (AdminController), not under Pets.
                  Jump stays in the right-hand gap (do not cover it).

    Post-process in the MenuTrayStyle/CurrencyStack mold: BaseUI still BUILDS the buttons
    in the tray pane (click wiring untouched), MenuTrayStyle pill-styles them, and THIS
    module adopts them into HotbarBar's root frame — inheriting the bar's ViewportScale.
    The tutorial's PetsButton pulse finds the button by name recursively, so the move is
    transparent to it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Readiness = require(ReplicatedStorage.Shared.Utils.Readiness)

local HOTBAR_CONFIG = require(ReplicatedStorage.Configs:WaitForChild("hotbar"))
local HotbarSize = require(ReplicatedStorage.Shared.Game.HotbarSize)

local HotbarFlank = {}
local started = false

local SLOTS = {
    PetsButton = { side = "left", stack = "top" },
    CompactMenuButton = { side = "left", stack = "bottom" },
    PowersButton = { side = "right", stack = "top" },
    HoverboardButton = { side = "right", stack = "bottom" },
}

local function flankCfg()
    local size = HOTBAR_CONFIG.size
    local flank = type(size) == "table" and size.flank or nil
    local classicPets =
        assert(flank and flank.classic_pets, "hotbar.size.flank.classic_pets is required")
    return {
        size = tonumber(flank and flank.size) or 62,
        compactSize = tonumber(flank and flank.compact_size) or 48,
        -- Clears the bar PillFrame overhang (~23px past the root).
        gap = tonumber(flank and flank.gap) or 26,
        inner = tonumber(flank and flank.inner) or 8,
        classicPets = classicPets,
    }
end

local function vector2(spec, field)
    local value = assert(spec[field], ("classic_pets.%s is required"):format(field))
    return Vector2.new(
        assert(tonumber(value.x), ("classic_pets.%s.x is required"):format(field)),
        assert(tonumber(value.y), ("classic_pets.%s.y is required"):format(field))
    )
end

local function sizeVector(spec, field)
    local value = assert(spec[field], ("classic_pets.%s is required"):format(field))
    return Vector2.new(
        assert(tonumber(value.width), ("classic_pets.%s.width is required"):format(field)),
        assert(tonumber(value.height), ("classic_pets.%s.height is required"):format(field))
    )
end

local function placeRelativeClassicPets(petsButton, responsiveDock, spec)
    local anchor = vector2(spec, "anchor")
    local position = vector2(spec, "position")
    local size = vector2(spec, "size")
    petsButton.Parent = responsiveDock
    petsButton.AnchorPoint = anchor
    petsButton.Position = UDim2.fromScale(position.X, position.Y)
    petsButton.Size = UDim2.fromScale(size.X, size.Y)

    local aspect = petsButton:FindFirstChild("ClassicPetsAspect")
        or Instance.new("UIAspectRatioConstraint")
    aspect.Name = "ClassicPetsAspect"
    aspect.AspectRatio =
        assert(tonumber(spec.aspect_ratio), "classic_pets.aspect_ratio is required")
    aspect.DominantAxis = Enum.DominantAxis.Width
    aspect.Parent = petsButton

    local bounds = petsButton:FindFirstChild("ClassicPetsBounds")
        or Instance.new("UISizeConstraint")
    bounds.Name = "ClassicPetsBounds"
    bounds.MinSize = sizeVector(spec, "minimum_size")
    bounds.MaxSize = sizeVector(spec, "maximum_size")
    bounds.Parent = petsButton
end

local function placeButton(btn, name, cfg, compact)
    local slot = SLOTS[name]
    if not slot then
        return
    end
    local size = compact and cfg.compactSize or cfg.size
    local gap = cfg.gap
    local stackGap = 2
    local function stackColumn(towardRight)
        if slot.stack == "top" then
            btn.AnchorPoint = towardRight and Vector2.new(0, 1) or Vector2.new(1, 1)
            btn.Position =
                UDim2.new(towardRight and 1 or 0, towardRight and gap or -gap, 0.5, -stackGap)
        else
            btn.AnchorPoint = towardRight and Vector2.new(0, 0) or Vector2.new(1, 0)
            btn.Position =
                UDim2.new(towardRight and 1 or 0, towardRight and gap or -gap, 0.5, stackGap)
        end
        btn.Size = UDim2.fromOffset(size, size)
    end
    if HotbarSize.orientation(HOTBAR_CONFIG.size) == "vertical_left" then
        -- Leftover path: flanks sit right of the left-edge strip.
        stackColumn(true)
        return
    end
    if compact then
        -- Matching columns: Pets/Menu left, Powers/Board right. Jump keeps
        -- the far-right gap between the right column and the screen edge.
        stackColumn(slot.side == "right")
        return
    end
    if slot.side == "left" then
        if name == "CompactMenuButton" then
            return
        end
        btn.AnchorPoint = Vector2.new(1, 0.5)
        btn.Position = UDim2.new(0, -gap, 0.5, 0)
        btn.Size = UDim2.fromOffset(cfg.size, cfg.size)
        return
    end
    local index = slot.stack == "bottom" and 1 or 0
    local along = gap + index * (cfg.size + cfg.inner)
    btn.AnchorPoint = Vector2.new(0, 0.5)
    btn.Position = UDim2.new(1, along, 0.5, 0)
    btn.Size = UDim2.fromOffset(cfg.size, cfg.size)
end

function HotbarFlank.start()
    if started then
        return
    end
    started = true
    local player = Players.LocalPlayer
    local pg = player:WaitForChild("PlayerGui")

    task.spawn(function()
        -- No give-up timeouts (see MenuTrayStyle): BaseUI + HotbarBar boot LATE, and on a non-owner
        -- account that boot stalls on failing asset loads past the old 20/30s windows. When this
        -- task gave up, Pets/Powers were never adopted out to flank the bar — they stayed in the raw
        -- vertical tray ("old HUD" on non-owner Studio sessions). Both guis are guaranteed to appear.
        local hotbarGui = pg:WaitForChild("HotbarBar")
        local bar = hotbarGui and hotbarGui:WaitForChild("Bar", 10)
        local responsiveDock = hotbarGui and hotbarGui:WaitForChild("ResponsiveDock", 10)
        local base = pg:WaitForChild("ProfessionalBaseUI")
        local mc = base and base:WaitForChild("MainContainer", 10)
        local pane = mc and mc:WaitForChild("menu_buttons_pane", 15)
        if not (bar and responsiveDock and pane and mc) then
            return
        end

        local adopted = {}
        local function applyLayout()
            local compact = player:GetAttribute("HudLayoutResolved") == "compact"
            local cfg = flankCfg()
            for name, btn in pairs(adopted) do
                if btn.Parent then
                    if name == "PetsButton" and not compact then
                        placeRelativeClassicPets(btn, responsiveDock, cfg.classicPets)
                    else
                        if btn.Parent ~= bar then
                            btn.Parent = bar
                        end
                        placeButton(btn, name, cfg, compact)
                    end
                end
            end
        end

        for name, _ in pairs(SLOTS) do
            task.spawn(function()
                local btn = name == "CompactMenuButton" and mc:WaitForChild(name, 20)
                    or pane:WaitForChild(name, 15)
                if not btn then
                    return
                end
                -- let MenuTrayStyle pill it first (the adopt would hide it from that pass)
                Readiness.awaitAttribute(btn, "Pillified", true, 8)
                -- offset square (the bar's ViewportScale scales it with the bar). NOT an
                -- aspect constraint: its default FitWithinMaxSize treats a 0 width as a
                -- MAX and collapses to 0x0 — live-debugged ("little tiny dots").
                local aspect = btn:FindFirstChildOfClass("UIAspectRatioConstraint")
                if aspect then
                    aspect:Destroy()
                end
                local ownScale = btn:FindFirstChild("ViewportScale")
                if ownScale then
                    ownScale:Destroy()
                end
                btn.Parent = bar
                if name == "HoverboardButton" then
                    btn.Visible = player:GetAttribute("HoverboardEligible") == true
                end
                adopted[name] = btn
                applyLayout()
            end)
        end

        player:GetAttributeChangedSignal("HudLayoutResolved"):Connect(applyLayout)
    end)
end

return HotbarFlank
