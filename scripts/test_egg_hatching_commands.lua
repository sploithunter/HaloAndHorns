-- test_egg_hatching_commands.lua
--
-- Simple command bar functions for testing egg hatching animations
-- These can be copied and pasted into the Studio command bar
--
-- USAGE:
-- 1. Copy a function below
-- 2. Paste it into the command bar in Studio
-- 3. Press Enter to execute

-- Get the service
local EggHatchingService =
    require(game:GetService("ReplicatedStorage").Shared.Services.EggHatchingService)

-- Quick test functions for command bar use:

-- Test single egg
function testEgg1()
    local testEggs = {
        {
            eggType = "basic_egg",
            petType = "bear",
            variant = "basic",
            imageId = "generated_image",
            petImageId = "generated_image",
        },
    }
    EggHatchingService:StartHatchingAnimation(testEggs)
end

-- Test 3 eggs with random pets
function testEgg3()
    local petTypes = { "bear", "bunny", "doggy", "dragon", "kitty" }
    local variants = { "basic", "golden", "rainbow" }
    local testEggs = {}

    for i = 1, 3 do
        table.insert(testEggs, {
            eggType = "basic_egg",
            petType = petTypes[math.random(1, #petTypes)],
            variant = variants[math.random(1, #variants)],
            imageId = "generated_image",
            petImageId = "generated_image",
        })
    end

    EggHatchingService:StartHatchingAnimation(testEggs)
end

-- Test 5 eggs with random pets
function testEgg5()
    local petTypes = { "bear", "bunny", "doggy", "dragon", "kitty" }
    local variants = { "basic", "golden", "rainbow" }
    local testEggs = {}

    for i = 1, 5 do
        table.insert(testEggs, {
            eggType = "basic_egg",
            petType = petTypes[math.random(1, #petTypes)],
            variant = variants[math.random(1, #variants)],
            imageId = "generated_image",
            petImageId = "generated_image",
        })
    end

    EggHatchingService:StartHatchingAnimation(testEggs)
end

-- Test 10 eggs with random pets
function testEgg10()
    local petTypes = { "bear", "bunny", "doggy", "dragon", "kitty" }
    local variants = { "basic", "golden", "rainbow" }
    local testEggs = {}

    for i = 1, 10 do
        table.insert(testEggs, {
            eggType = "basic_egg",
            petType = petTypes[math.random(1, #petTypes)],
            variant = variants[math.random(1, #variants)],
            imageId = "generated_image",
            petImageId = "generated_image",
        })
    end

    EggHatchingService:StartHatchingAnimation(testEggs)
end

-- Test 42 eggs (stress test)
function testEgg42()
    local petTypes = { "bear", "bunny", "doggy", "dragon", "kitty" }
    local variants = { "basic", "golden", "rainbow" }
    local testEggs = {}

    for i = 1, 42 do
        table.insert(testEggs, {
            eggType = "basic_egg",
            petType = petTypes[math.random(1, #petTypes)],
            variant = variants[math.random(1, #variants)],
            imageId = "generated_image",
            petImageId = "generated_image",
        })
    end

    EggHatchingService:StartHatchingAnimation(testEggs)
end

-- Test specific pet
function testSpecificPet(petType, variant)
    petType = petType or "bear"
    variant = variant or "basic"

    local testEggs = {
        {
            eggType = "basic_egg",
            petType = petType,
            variant = variant,
            imageId = "generated_image",
            petImageId = "generated_image",
        },
    }

    EggHatchingService:StartHatchingAnimation(testEggs)
end

-- Test custom egg count
function testCustomEggs(count)
    count = count or 5

    local petTypes = { "bear", "bunny", "doggy", "dragon", "kitty" }
    local variants = { "basic", "golden", "rainbow" }
    local testEggs = {}

    for i = 1, count do
        table.insert(testEggs, {
            eggType = "basic_egg",
            petType = petTypes[math.random(1, #petTypes)],
            variant = variants[math.random(1, #variants)],
            imageId = "generated_image",
            petImageId = "generated_image",
        })
    end

    EggHatchingService:StartHatchingAnimation(testEggs)
end

-- Print available commands
function showEggCommands()
    print("🥚 EGG HATCHING COMMANDS:")
    print("==========================")
    print("testEgg1() - Test 1 egg")
    print("testEgg3() - Test 3 eggs with random pets")
    print("testEgg5() - Test 5 eggs with random pets")
    print("testEgg10() - Test 10 eggs with random pets")
    print("testEgg42() - Test 42 eggs (stress test)")
    print("")
    print("testSpecificPet(petType, variant) - Test specific pet")
    print("testCustomEggs(count) - Test custom number of eggs")
    print("showEggCommands() - Show this help")
    print("")
    print("Examples:")
    print("testSpecificPet('dragon', 'golden')")
    print("testCustomEggs(25)")
    print("")
    print("Or use the Admin Panel for a GUI interface!")
end

-- Show commands when script is loaded
showEggCommands()

-- Export for easy access
return {
    testEgg1 = testEgg1,
    testEgg3 = testEgg3,
    testEgg5 = testEgg5,
    testEgg10 = testEgg10,
    testEgg42 = testEgg42,
    testSpecificPet = testSpecificPet,
    testCustomEggs = testCustomEggs,
    showEggCommands = showEggCommands,
}
