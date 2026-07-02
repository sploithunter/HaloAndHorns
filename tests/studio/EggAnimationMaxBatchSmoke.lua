--[[
    Studio smoke test for the maximum 99-egg hatch animation layout.

    Run in play mode:

    return require(game:GetService("ReplicatedStorage").Tests.studio.EggAnimationMaxBatchSmoke).runText()
]]

local EggAnimationMaxBatchSmoke = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Locations = require(ReplicatedStorage.Shared.Locations)

local DEFAULT_TIMEOUT_SECONDS = 25

local function waitFor(description, timeoutSeconds, predicate)
    local deadline = os.clock() + (timeoutSeconds or DEFAULT_TIMEOUT_SECONDS)

    while os.clock() < deadline do
        local result = predicate()
        if result then
            return result
        end
        task.wait(0.1)
    end

    error("Timed out waiting for " .. description)
end

local function buildEggBatch(eggType, count)
    local eggs = {}
    for index = 1, count do
        local special = index == count
        eggs[index] = {
            eggType = eggType,
            imageId = "generated_image",
            petImageId = "generated_image",
            petType = special and "colorado" or (index % 2 == 0 and "doggy" or "bear"),
            variant = special and "rainbow" or "basic",
            rarityId = special and "exclusive" or "common",
            rarityName = special and "Exclusive" or "Common",
            specialHatch = special,
            autoDeleted = false,
            animation = {
                useAuthoredEggVisual = true,
            },
            hatchOptions = {
                silentHatch = true,
            },
        }
    end
    return eggs
end

function EggAnimationMaxBatchSmoke.run(options)
    options = options or {}
    local timeoutSeconds = options.timeoutSeconds or DEFAULT_TIMEOUT_SECONDS
    local eggType = options.eggType or "basic_egg"
    local eggHatchingService = require(ReplicatedStorage.Shared.Services.EggHatchingService)
    local eggSystemConfig = Locations.getConfig("egg_system")
    local animationConfig = eggSystemConfig.hatching.animation
    local layoutConfig = animationConfig.layout
    local expectedCount = animationConfig.max_visible_eggs or eggSystemConfig.hatching.max_count

    assert(expectedCount == 99, "Max hatch animation coverage should stay aligned to 99 eggs")

    eggHatchingService:TestCleanup()
    eggHatchingService:StartHatchingAnimation(buildEggBatch(eggType, expectedCount))

    local state = waitFor("maximum animation frames", timeoutSeconds, function()
        local debugState = eggHatchingService:GetActiveAnimationDebugState()
        if debugState.frameCount == expectedCount then
            return debugState
        end
        return nil
    end)

    assert(state.layout.name == "10x10", "Max hatch animation should use 10x10 layout")
    assert(state.layout.columns == 10, "Max hatch animation column count mismatch")
    assert(state.layout.rows == 10, "Max hatch animation row count mismatch")
    assert(state.layout.compactMode == true, "Max hatch animation should use compact mode")
    assert(state.layout.padding == layoutConfig.padding, "Max hatch animation padding mismatch")
    assert(state.layout.eggSize > 0, "Max hatch animation egg size should be positive")
    assert(
        state.layout.eggSize <= layoutConfig.max_egg_size,
        "Max hatch animation egg size above configured maximum"
    )

    local viewportSize = Vector2.new(state.layout.containerWidth, state.layout.containerHeight)
    local authoredCount = 0
    local previousIndex = 0
    for _, frame in ipairs(state.frames) do
        assert(frame.eggIndex == previousIndex + 1, "Max hatch animation frame ordering mismatch")
        previousIndex = frame.eggIndex
        assert(frame.size.x == frame.size.y, "Max hatch animation frame should be square")
        assert(frame.size.x == state.layout.eggSize, "Max hatch animation frame size mismatch")
        assert(frame.position.x >= 0, "Max hatch animation frame escaped left edge")
        assert(frame.position.y >= 0, "Max hatch animation frame escaped top edge")
        assert(
            frame.position.x + frame.size.x <= viewportSize.X + 1,
            "Max hatch animation frame escaped right edge"
        )
        assert(
            frame.position.y + frame.size.y <= viewportSize.Y + 1,
            "Max hatch animation frame escaped bottom edge"
        )
        if frame.eggVisualSource == "authored" then
            authoredCount += 1
        end
    end

    assert(authoredCount == expectedCount, "Max hatch animation did not use authored egg visuals")

    eggHatchingService:TestCleanup()

    return {
        frameCount = state.frameCount,
        layoutName = state.layout.name,
        eggSize = state.layout.eggSize,
        authoredCount = authoredCount,
    }
end

function EggAnimationMaxBatchSmoke.runText(options)
    local result = EggAnimationMaxBatchSmoke.run(options)
    return string.format(
        "EggAnimationMaxBatchSmoke passed: frames=%d layout=%s eggSize=%.1f authored=%d",
        result.frameCount,
        result.layoutName,
        result.eggSize,
        result.authoredCount
    )
end

return EggAnimationMaxBatchSmoke
