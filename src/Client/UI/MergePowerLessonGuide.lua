local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lessons = require(ReplicatedStorage.Shared.Game.MergePowerLessons)
local Localization = require(ReplicatedStorage.Shared.Game.TutorialLocalization)
local cfg = require(ReplicatedStorage.Configs.merge_egg_prototype).tutorial.power_lessons
local augmentation = require(ReplicatedStorage.Configs.augmentation)
local levelTrack = require(ReplicatedStorage.Configs.level_track)
local Guide = {}

function Guide.text(key)
    local language = Localization.languageFor(Players.LocalPlayer:GetAttribute("TutorialLocaleId"))
    return (cfg.translations[language] or {})[key] or cfg.guide[key]
end

function Guide.entry(controller)
    local now = os.clock()
    if now < (controller._entryPollAt or 0) then
        return
    end
    controller._entryPollAt = now + cfg.guide.entry_poll_seconds
    local player = Players.LocalPlayer
    local wanted = player:GetAttribute("AscensionUnlocked") == true
        and ((tonumber(player:GetAttribute("PendingTraining")) or 0) > 0 or player:GetAttribute(
            "MergePowerLesson"
        ) ~= nil)
        and not _G.PowerChoiceMenuOpen
        and player:GetAttribute("InCombatTutorial") ~= true
    local previous = controller._powerEntryCue
    if previous and (not wanted or not previous.target.Parent) then
        previous.tween:Cancel()
        previous.glowTween:Cancel()
        previous.glow:Destroy()
        previous.label:Destroy()
        previous.target.ClipsDescendants = previous.clipped
        controller._powerEntryCue = nil
    end
    if not wanted then
        return
    end
    if controller._powerEntryCue then
        controller._powerEntryCue.label.Text = Guide.text("click_here") .. "\n▼"
        return
    end
    local pg = player:FindFirstChildOfClass("PlayerGui")
    local target = pg and pg:FindFirstChild("PowersButton", true)
    if not target or not target:IsA("GuiObject") then
        return
    end
    local cue = Instance.new("TextLabel")
    cue.Name = "AscensionPowersClickHere"
    cue.AnchorPoint = Vector2.new(0.5, 1)
    cue.Position = UDim2.fromScale(table.unpack(cfg.guide.entry_position))
    cue.Size = UDim2.fromScale(table.unpack(cfg.guide.entry_size))
    cue.BackgroundColor3 = Color3.fromRGB(table.unpack(cfg.guide.entry_background))
    cue.TextColor3 = Color3.fromRGB(table.unpack(cfg.guide.color))
    cue.Font = Enum.Font.GothamBlack
    cue.TextScaled = true
    cue.Text = Guide.text("click_here") .. "\n▼"
    cue.ZIndex = cfg.guide.entry_z_index
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(cfg.guide.entry_corner, 0)
    corner.Parent = cue
    local clipped = target.ClipsDescendants
    target.ClipsDescendants = false
    cue.Parent = target
    local tween = TweenService:Create(
        cue,
        TweenInfo.new(
            cfg.guide.pulse_seconds,
            Enum.EasingStyle.Sine,
            Enum.EasingDirection.InOut,
            -1,
            true
        ),
        {
            Position = UDim2.fromScale(
                cfg.guide.entry_position[1],
                cfg.guide.entry_position[2] - cfg.guide.entry_bounce
            ),
            TextTransparency = cfg.guide.text_fade,
        }
    )
    local glow = Instance.new("UIStroke")
    glow.Name = "AscensionPowersGlow"
    glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    glow.Color = Color3.fromRGB(table.unpack(cfg.guide.color))
    glow.Thickness = cfg.guide.stroke_thickness
    glow.Parent = target
    local glowTween = TweenService:Create(
        glow,
        TweenInfo.new(
            cfg.guide.pulse_seconds,
            Enum.EasingStyle.Sine,
            Enum.EasingDirection.InOut,
            -1,
            true
        ),
        { Transparency = cfg.guide.stroke_fade }
    )
    controller._powerEntryCue = {
        target = target,
        label = cue,
        tween = tween,
        clipped = clipped,
        glow = glow,
        glowTween = glowTween,
    }
    tween:Play()
    glowTween:Play()
end

function Guide.clear(menu)
    local prior = menu._mergeGuide
    if not prior then
        return
    end
    for _, tween in ipairs(prior.tweens) do
        tween:Cancel()
    end
    for _, object in ipairs(prior.objects) do
        object:Destroy()
    end
    if prior.title and prior.title.Parent then
        prior.title.Text = prior.text
        prior.title.TextTransparency = 0
    end
    menu._mergeGuide = nil
end

function Guide.refresh(menu)
    Guide.clear(menu)
    local player = Players.LocalPlayer
    local stage = player:GetAttribute("MergePowerLesson")
    if not menu.frame or not menu.live or menu:_isRangeCatalog() then
        return
    end
    if not stage and menu.pendingPower == 0 and menu.pendingSlots == 0 then
        return
    end
    local localized = table.clone(cfg)
    localized.guide = setmetatable({}, {
        __index = function(_, key)
            return Guide.text(key)
        end,
    })
    local text, action = Lessons.guide(
        localized,
        stage,
        menu.pendingPower,
        menu.pendingSlots,
        menu:_remainingPicks(),
        menu:_remainingSlots(),
        menu.enhanceFor,
        menu._enhTargetSlot,
        menu._enhStaged
    )
    if not text then
        return
    end
    if action == "slots" and not menu:_canPlaceSlot() then
        action, text = "commit", Guide.text("commit")
    end
    if not menu.archetype and menu.level >= levelTrack.origin_choice_level then
        action = menu.pendingOrigin and "origin_review" or "origin"
        text = Guide.text(menu.pendingOrigin and "review_origin" or "choose_origin")
    end
    local title = menu.frame:FindFirstChild("PowerChoiceTitle")
    local state = { tweens = {}, objects = {}, title = title, text = title and title.Text }
    menu._mergeGuide = state
    local function pulse(object, properties)
        local tween = TweenService:Create(
            object,
            TweenInfo.new(
                cfg.guide.pulse_seconds,
                Enum.EasingStyle.Sine,
                Enum.EasingDirection.InOut,
                -1,
                true
            ),
            properties
        )
        state.tweens[#state.tweens + 1] = tween
        tween:Play()
    end
    if title then
        title.Text = text
        pulse(title, { TextTransparency = cfg.guide.text_fade })
    end
    local target
    if action == "commit" then
        target = menu.commitBtn
    elseif action == "origin" then
        target = menu.originCol
    elseif action == "origin_review" then
        target = menu.frame:FindFirstChild("LockIn", true)
    elseif action == "power" then
        target = menu.frame:FindFirstChild(
            "Row_" .. tostring(player:GetAttribute("MergePowerRecommendation")),
            true
        )
        -- Ordinary ascensions need a visible entry point too; a recommendation is optional.
        target = target or menu.naturalCol
    elseif action == "slots" or action == "owned" then
        local preferred = player:GetAttribute("MergePowerLessonTarget")
        if
            preferred
            and menu.owned[preferred]
            and (
                action == "owned"
                or menu:_effectiveSlots(preferred) < augmentation.max_slots_per_power
            )
        then
            target = menu.frame:FindFirstChild("Row_" .. preferred, true)
        end
        for _, child in ipairs(menu.naturalCol:GetChildren()) do
            if target then
                break
            end
            local id = child.Name:match("^Row_(.+)$")
            if
                id
                and (not stage or table.find(cfg.excluded_lesson_powers, id) == nil)
                and menu.owned[id]
                and (
                    action == "owned"
                    or menu:_effectiveSlots(id) < augmentation.max_slots_per_power
                )
            then
                target = child
                break
            end
        end
    else
        for _, child in ipairs(menu.frame:GetDescendants()) do
            local key = child:GetAttribute("TutorialGuide")
            if
                (action == "slot" and key == "EnhanceEmptySlot")
                or (action == "apply" and key == "EnhanceApply" and child.Name == "EnhanceApply")
                or (
                    action == "enhancement"
                    and type(key) == "string"
                    and (key:find("EnhanceType:", 1, true) == 1 or key == "EnhancePotency")
                )
            then
                target = child
                break
            end
        end
    end
    if not target and action == "slot" then
        for _, child in ipairs(menu.frame:GetDescendants()) do
            if child:GetAttribute("TutorialGuide") == "EnhanceSlot" then
                target = child
                break
            end
        end
    end
    if target then
        if target.Name:match("^Row_") then
            -- Reserve a row-sized callout in the list instead of covering another choice.
            -- Height follows the menu's existing minimum-touch-target row sizing.
            local space = Instance.new("Frame")
            space.Name = "MergeLessonCalloutSpace"
            space.BackgroundTransparency = 1
            space.Size = UDim2.new(1, 0, 0, target.Size.Y.Offset * cfg.guide.row_cue_height_scale)
            space.LayoutOrder = target.LayoutOrder - 1
            space.Parent = target.Parent
            state.objects[#state.objects + 1] = space
        end
        local glow = Instance.new("UIStroke")
        glow.Name = "MergeLessonGlow"
        glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        glow.Color = Color3.fromRGB(table.unpack(cfg.guide.color))
        glow.Thickness = cfg.guide.stroke_thickness
        glow.Parent = target
        state.objects[#state.objects + 1] = glow
        pulse(glow, { Transparency = cfg.guide.stroke_fade })
        -- Overlay avoids clipping inside scrolling rows; resolve after layout settles.
        task.defer(function()
            RunService.RenderStepped:Wait()
            if menu._mergeGuide ~= state or not target.Parent or not menu.frame then
                return
            end
            local size, origin = menu.frame.AbsoluteSize, menu.frame.AbsolutePosition
            if size.X <= 0 or size.Y <= 0 then
                return
            end
            local at, extent = target.AbsolutePosition, target.AbsoluteSize
            local width = cfg.guide.menu_cue_size[1]
            local x =
                math.clamp((at.X + extent.X / 2 - origin.X) / size.X, width / 2, 1 - width / 2)
            local y = math.clamp(
                (at.Y - origin.Y) / size.Y - cfg.guide.menu_cue_gap,
                cfg.guide.menu_cue_size[2],
                1
            )
            local cue = Instance.new("TextLabel")
            cue.Name = "MergeLessonPointer"
            cue.AnchorPoint = Vector2.new(0.5, 1)
            cue.Position = UDim2.fromScale(x, y)
            cue.Size = UDim2.fromScale(table.unpack(cfg.guide.menu_cue_size))
            cue.BackgroundColor3 = Color3.fromRGB(table.unpack(cfg.guide.entry_background))
            cue.TextColor3 = Color3.fromRGB(table.unpack(cfg.guide.color))
            cue.Font = Enum.Font.GothamBlack
            cue.TextScaled = true
            cue.ZIndex = cfg.guide.menu_cue_z_index
            cue.Text = (
                action == "power"
                    and player:GetAttribute("MergePowerRecommendation")
                    and Guide.text("recommended")
                or text
            ) .. "\n▼"
            cue.Parent = menu.frame
            state.objects[#state.objects + 1] = cue
            pulse(cue, {
                Position = UDim2.fromScale(x, y - cfg.guide.menu_cue_bounce),
                TextTransparency = cfg.guide.text_fade,
            })
        end)
    end
end

return Guide
