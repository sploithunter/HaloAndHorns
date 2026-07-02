-- Test script to demonstrate different egg hatching speeds
-- Shows how to change the speed preset and test animations

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Test different speed presets
local function testSpeedPreset(presetName, eggCount)
    print("\n🚀 TESTING SPEED PRESET:", presetName:upper())
    print("=" .. string.rep("=", 50))

    -- Load and modify the configuration
    local hatchingConfig = require(ReplicatedStorage.Configs.egg_hatching)
    hatchingConfig.current_preset = presetName

    print("⚡ Speed multiplier:", hatchingConfig.helpers:get_speed_multiplier())
    print("📊 Adjusted timings:")
    print("  🔄 Shake:", hatchingConfig.helpers:get_adjusted_timing("shake_duration") .. "s")
    print("  💥 Flash:", hatchingConfig.helpers:get_adjusted_timing("flash_duration") .. "s")
    print("  🎭 Reveal:", hatchingConfig.helpers:get_adjusted_timing("reveal_duration") .. "s")
    print("  ⏳ Stagger:", hatchingConfig.helpers:get_adjusted_timing("stagger_delay") .. "s")

    -- Create test eggs
    local testEggs = {}
    for i = 1, eggCount do
        table.insert(testEggs, {
            eggType = "basic_egg",
            petType = "bear",
            variant = "basic",
            imageId = "generated_image",
            petImageId = "generated_image",
        })
    end

    -- Start the animation
    local EggHatchingService = require(ReplicatedStorage.Shared.Services.EggHatchingService)
    EggHatchingService:StartHatchingAnimation(testEggs)
end

-- Quick test functions for each speed
local function testNormal()
    testSpeedPreset("normal", 3)
end

local function testFast()
    testSpeedPreset("fast", 3)
end

local function testVeryFast()
    testSpeedPreset("very_fast", 3)
end

local function testUltraFast()
    testSpeedPreset("ultra_fast", 3)
end

local function testSlow()
    testSpeedPreset("slow", 3)
end

-- Test with different egg counts
local function testUltraFast5Eggs()
    testSpeedPreset("ultra_fast", 5)
end

local function testUltraFast10Eggs()
    testSpeedPreset("ultra_fast", 10)
end

-- Show available commands
local function showSpeedCommands()
    print("\n🎮 EGG SPEED TEST COMMANDS")
    print("=" .. string.rep("=", 40))
    print("testNormal()     - Test normal speed (1.0x)")
    print("testFast()       - Test fast speed (0.75x)")
    print("testVeryFast()   - Test very fast speed (0.5x)")
    print("testUltraFast()  - Test ultra fast speed (0.25x)")
    print("testSlow()       - Test slow speed (1.25x)")
    print("")
    print("testUltraFast5Eggs()  - Ultra fast with 5 eggs")
    print("testUltraFast10Eggs() - Ultra fast with 10 eggs")
    print("")
    print("📋 Current preset: " .. require(ReplicatedStorage.Configs.egg_hatching).current_preset)
end

-- Auto-show commands when script loads
showSpeedCommands()

-- Export functions for command bar usage
return {
    testNormal = testNormal,
    testFast = testFast,
    testVeryFast = testVeryFast,
    testUltraFast = testUltraFast,
    testSlow = testSlow,
    testUltraFast5Eggs = testUltraFast5Eggs,
    testUltraFast10Eggs = testUltraFast10Eggs,
    showSpeedCommands = showSpeedCommands,
    testSpeedPreset = testSpeedPreset,
}
