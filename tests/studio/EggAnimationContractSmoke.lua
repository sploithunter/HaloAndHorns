--[[
    Studio smoke test for client hatch animation metadata and reveal badges.

    Run in play mode:

    return require(game:GetService("ReplicatedStorage").Tests.studio.EggAnimationContractSmoke).runText()
]]

local EggAnimationContractSmoke = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Locations = require(ReplicatedStorage.Shared.Locations)

local DEFAULT_TIMEOUT_SECONDS = 20

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

function EggAnimationContractSmoke.run(options)
    options = options or {}
    local timeoutSeconds = options.timeoutSeconds or DEFAULT_TIMEOUT_SECONDS
    local eggHatchingService = require(ReplicatedStorage.Shared.Services.EggHatchingService)
    local eggSystemConfig = Locations.getConfig("egg_system")
    local animationConfig = eggSystemConfig.hatching.animation
    local layoutConfig = animationConfig.layout

    eggHatchingService:TestCleanup()

    local animationResult = eggHatchingService:StartHatchingAnimation({
        {
            eggType = options.eggType or "basic_egg",
            imageId = "generated_image",
            petImageId = "generated_image",
            petType = "colorado",
            variant = "rainbow",
            rarityId = "exclusive",
            rarityName = "Exclusive",
            specialHatch = true,
            autoDeleted = false,
            animation = {
                useAuthoredEggVisual = true,
            },
            hatchOptions = {
                fastHatch = true,
                silentHatch = true,
            },
        },
        {
            eggType = options.eggType or "basic_egg",
            imageId = "generated_image",
            petImageId = "generated_image",
            petType = "bear",
            variant = "basic",
            rarityId = "common",
            rarityName = "Common",
            specialHatch = false,
            autoDeleted = true,
            autoDeleteReason = "rarity",
            animation = {
                useAuthoredEggVisual = true,
            },
            hatchOptions = {
                fastHatch = true,
                silentHatch = true,
            },
        },
        {
            eggType = options.eggType or "basic_egg",
            imageId = "generated_image",
            petImageId = "generated_image",
            petType = "bear",
            variant = "basic",
            rarityId = "common",
            rarityName = "Common",
            specialHatch = false,
            autoDeleted = true,
            autoDeleteReason = "rarity",
            animation = {
                useAuthoredEggVisual = true,
            },
            hatchOptions = {
                fastHatch = true,
                silentHatch = true,
            },
        },
    })

    local initial = waitFor("animation frames", timeoutSeconds, function()
        local state = eggHatchingService:GetActiveAnimationDebugState()
        if state.frameCount == 3 then
            return state
        end
        return nil
    end)

    local specialFrame = initial.frames[1]
    local autoDeletedFrame = initial.frames[2]
    assert(initial.layout.name == "2x2", "Animation layout name mismatch")
    assert(initial.layout.padding == layoutConfig.padding, "Animation layout padding mismatch")
    assert(
        initial.layout.eggSize >= layoutConfig.min_egg_size,
        "Animation egg size below configured min"
    )
    assert(initial.timing.fastHatch == true, "Fast hatch timing flag missing")
    assert(initial.timing.silentHatch == true, "Silent hatch timing flag missing")
    assert(
        math.abs(initial.timing.speedScale - animationConfig.fast_hatch_speed_scale) < 0.001,
        "Fast hatch speed scale did not match config"
    )
    assert(specialFrame.specialHatch == true, "Special hatch flag missing")
    assert(specialFrame.rarityId == "exclusive", "Special hatch rarity mismatch")
    assert(specialFrame.hasSpecialRevealStroke == true, "Special hatch stroke missing")
    assert(specialFrame.specialGlowPulseEnabled == true, "Special hatch glow pulse missing")
    assert(specialFrame.hasSpecialRevealBackdrop == true, "Special hatch backdrop missing")
    assert(
        math.abs(
            specialFrame.specialRevealBackdropTransparency
                - animationConfig.special_backdrop.transparency
        ) < 0.001,
        "Special hatch backdrop transparency did not match config"
    )
    assert(specialFrame.badges.SpecialBadge, "Special hatch badge missing")
    assert(specialFrame.badges.RarityBadge, "Special rarity badge missing")
    assert(specialFrame.badges.VariantBadge, "Special variant badge missing")
    assert(autoDeletedFrame.autoDeleted == true, "Auto-delete flag missing")
    assert(autoDeletedFrame.badges.AutoDeleteBadge, "Auto-delete badge missing")

    local revealed = waitFor("visible reveal badges", timeoutSeconds, function()
        local state = eggHatchingService:GetActiveAnimationDebugState()
        local first = state.frames[1]
        local second = state.frames[2]
        if
            first
            and second
            and first.badges.SpecialBadge
            and first.badges.SpecialBadge.visible == true
            and first.specialRevealBackdropVisible == true
            and second.badges.AutoDeleteBadge
            and second.badges.AutoDeleteBadge.visible == true
        then
            return state
        end
        return nil
    end)

    local stacked = waitFor("stacked result labels", timeoutSeconds, function()
        local state = eggHatchingService:GetActiveAnimationDebugState()
        local second = state.frames[2]
        if
            second
            and second.stackCount == 2
            and second.stackDisplayName == "Bear"
            and second.stackNameLabel
            and second.stackNameLabel.text == "Bear"
            and second.stackCountLabel
            and second.stackCountLabel.text == "x2"
        then
            return state
        end
        return nil
    end)

    eggHatchingService:TestCleanup()

    local skippedAnimation = eggHatchingService:StartHatchingAnimation({
        {
            eggType = options.eggType or "basic_egg",
            imageId = "generated_image",
            petImageId = "generated_image",
            petType = "colorado",
            variant = "rainbow",
            rarityId = "exclusive",
            rarityName = "Exclusive",
            specialHatch = true,
            autoDeleted = false,
            animation = {
                useAuthoredEggVisual = true,
            },
            hatchOptions = {
                skipHatch = true,
                silentHatch = true,
            },
        },
    })
    local skippedState = eggHatchingService:GetActiveAnimationDebugState()
    assert(skippedAnimation.skipped == true, "Skip hatch did not return skipped result")
    assert(skippedAnimation.isComplete == true, "Skip hatch did not complete immediately")
    assert(skippedState.skipped == true, "Skip hatch debug flag missing")
    assert(skippedState.timing.skipHatch == true, "Skip hatch timing flag missing")
    assert(skippedState.guiStatus == "disabled", "Skip hatch left animation GUI enabled")
    assert(skippedState.frameCount == 0, "Skip hatch created animation frames")

    eggHatchingService:TestCleanup()

    local hiddenAnimation = eggHatchingService:StartHatchingAnimation({
        {
            eggType = options.eggType or "basic_egg",
            imageId = "generated_image",
            petImageId = "generated_image",
            petType = "colorado",
            variant = "basic",
            rarityId = "exclusive",
            rarityName = "Exclusive",
            specialHatch = true,
            autoDeleted = false,
            animation = {
                useAuthoredEggVisual = true,
            },
            hatchOptions = {
                showHatch = false,
            },
        },
    })
    local hiddenState = eggHatchingService:GetActiveAnimationDebugState()
    assert(hiddenAnimation.skipped == true, "Show Hatch off did not return skipped result")
    assert(hiddenAnimation.isComplete == true, "Show Hatch off did not complete immediately")
    assert(hiddenState.skipped == true, "Show Hatch off debug skipped flag missing")
    assert(hiddenState.timing.showHatch == false, "Show Hatch timing flag missing")
    assert(hiddenState.timing.skipHatch == true, "Show Hatch off did not suppress animation")
    assert(hiddenState.guiStatus == "disabled", "Show Hatch off left animation GUI enabled")
    assert(hiddenState.frameCount == 0, "Show Hatch off created animation frames")

    eggHatchingService:TestCleanup()

    return {
        frameCount = initial.frameCount,
        specialBadge = specialFrame.badges.SpecialBadge.text,
        rarityBadge = specialFrame.badges.RarityBadge.text,
        variantBadge = specialFrame.badges.VariantBadge.text,
        autoDeleteBadge = autoDeletedFrame.badges.AutoDeleteBadge.text,
        revealedStatus = revealed.guiStatus,
        stackedCount = stacked.frames[2].stackCount,
        stackedName = stacked.frames[2].stackNameLabel.text,
        animationComplete = animationResult.isComplete == true,
        skipSuppressed = skippedAnimation.skipped == true,
    }
end

function EggAnimationContractSmoke.runText(options)
    local result = EggAnimationContractSmoke.run(options)
    return string.format(
        "EggAnimationContractSmoke passed: frames=%d special=%q rarity=%q variant=%q autoDelete=%q stack=%s/%s revealedStatus=%s skipSuppressed=%s",
        result.frameCount,
        result.specialBadge,
        result.rarityBadge,
        result.variantBadge,
        result.autoDeleteBadge,
        tostring(result.stackedName),
        tostring(result.stackedCount),
        result.revealedStatus,
        tostring(result.skipSuppressed)
    )
end

return EggAnimationContractSmoke
