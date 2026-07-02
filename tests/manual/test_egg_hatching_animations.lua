-- test_egg_hatching_animations.lua
--
-- Manual test script for the egg hatching animation system.
-- Tests various egg counts and grid layouts to ensure proper scaling.
--
-- USAGE:
-- 1. Run this script in Studio
-- 2. Use the GUI buttons to test different scenarios
-- 3. Verify animations work correctly at all scales

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for game to load
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local player = Players.LocalPlayer
if not player then
    Players.PlayerAdded:Wait()
    player = Players.LocalPlayer
end

-- Load required services
local EggHatchingService = require(ReplicatedStorage.Shared.Services.EggHatchingService)
local Locations = require(ReplicatedStorage.Shared.Locations)
local petConfig = Locations.getConfig("pets")

-- ═══════════════════════════════════════════════════════════════════════════════════
-- TEST DATA GENERATION
-- ═══════════════════════════════════════════════════════════════════════════════════

local function generateTestEggData(count)
    local eggsData = {}

    -- Cycle through available pets for variety
    local petTypes = { "bear", "cat", "dog", "dragon", "phoenix" }
    local variants = { "normal", "golden", "rainbow" }

    for i = 1, count do
        local petType = petTypes[((i - 1) % #petTypes) + 1]
        local variant = variants[((i - 1) % #variants) + 1]

        -- Use generated images from AssetPreloadService
        local eggImageId = "rbxasset://textures/face.png" -- Placeholder
        local petImageId = "rbxasset://textures/face.png" -- Placeholder

        -- Try to get actual images from assets if available
        pcall(function()
            local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
            if assetsFolder then
                local imagesFolder = assetsFolder:FindFirstChild("Images")
                if imagesFolder then
                    -- Get pet image
                    local petsFolder = imagesFolder:FindFirstChild("Pets")
                    if petsFolder then
                        local petTypeFolder = petsFolder:FindFirstChild(petType)
                        if petTypeFolder then
                            local petImage = petTypeFolder:FindFirstChild(variant)
                            if petImage then
                                petImageId = "rbxassetid://123" -- Would clone the ViewportFrame
                            end
                        end
                    end

                    -- Get egg image
                    local eggsFolder = imagesFolder:FindFirstChild("Eggs")
                    if eggsFolder then
                        local eggImage = eggsFolder:FindFirstChild("basic_egg")
                        if eggImage then
                            eggImageId = "rbxassetid://456" -- Would clone the ViewportFrame
                        end
                    end
                end
            end
        end)

        table.insert(eggsData, {
            petType = petType,
            variant = variant,
            imageId = eggImageId,
            petImageId = petImageId,
            rarity = "common", -- Could be dynamic
        })
    end

    return eggsData
end

-- ═══════════════════════════════════════════════════════════════════════════════════
-- TEST GUI CREATION
-- ═══════════════════════════════════════════════════════════════════════════════════

local function createTestGui()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "EggHatchingTestGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player:WaitForChild("PlayerGui")

    -- Main panel
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainPanel"
    mainFrame.Size = UDim2.new(0, 300, 0, 400)
    mainFrame.Position = UDim2.new(0, 20, 0, 20)
    mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    mainFrame.BorderSizePixel = 1
    mainFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
    mainFrame.Parent = screenGui

    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    title.BorderSizePixel = 0
    title.Text = "🥚 Egg Hatching Test"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextScaled = true
    title.Font = Enum.Font.SourceSansBold
    title.Parent = mainFrame

    -- Test buttons container
    local buttonContainer = Instance.new("ScrollingFrame")
    buttonContainer.Name = "ButtonContainer"
    buttonContainer.Size = UDim2.new(1, -20, 1, -60)
    buttonContainer.Position = UDim2.new(0, 10, 0, 50)
    buttonContainer.BackgroundTransparency = 1
    buttonContainer.BorderSizePixel = 0
    buttonContainer.ScrollBarThickness = 8
    buttonContainer.Parent = mainFrame

    -- Test scenarios
    local testScenarios = {
        { name = "1 Egg (Center)", count = 1, description = "Single egg in center" },
        { name = "2 Eggs (Side by Side)", count = 2, description = "Two eggs horizontal" },
        { name = "4 Eggs (2x2 Grid)", count = 4, description = "Small square grid" },
        { name = "9 Eggs (3x3 Grid)", count = 9, description = "Medium grid" },
        { name = "16 Eggs (4x4 Grid)", count = 16, description = "Large grid" },
        { name = "25 Eggs (5x5 Grid)", count = 25, description = "Very large grid" },
        { name = "50 Eggs (Stress Test)", count = 50, description = "High count test" },
        { name = "99 Eggs (Maximum)", count = 99, description = "Maximum capacity test" },
        { name = "Random (1-10)", count = math.random(1, 10), description = "Random small batch" },
        {
            name = "Random (10-30)",
            count = math.random(10, 30),
            description = "Random medium batch",
        },
    }

    -- Create buttons
    local buttonHeight = 50
    local buttonSpacing = 10

    for i, scenario in ipairs(testScenarios) do
        local button = Instance.new("TextButton")
        button.Name = "TestButton_" .. i
        button.Size = UDim2.new(1, -10, 0, buttonHeight)
        button.Position = UDim2.new(0, 5, 0, (i - 1) * (buttonHeight + buttonSpacing))
        button.BackgroundColor3 = Color3.fromRGB(80, 120, 160)
        button.BorderSizePixel = 1
        button.BorderColor3 = Color3.fromRGB(100, 140, 180)
        button.Text = scenario.name
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextScaled = true
        button.Font = Enum.Font.SourceSans
        button.Parent = buttonContainer

        -- Button hover effects
        button.MouseEnter:Connect(function()
            button.BackgroundColor3 = Color3.fromRGB(100, 140, 180)
        end)

        button.MouseLeave:Connect(function()
            button.BackgroundColor3 = Color3.fromRGB(80, 120, 160)
        end)

        -- Button click handler
        button.Activated:Connect(function()
            print("🧪 Testing scenario:", scenario.name, "with", scenario.count, "eggs")

            -- Generate test data
            local eggsData = generateTestEggData(scenario.count)

            -- Start animation
            local animationResult = EggHatchingService:StartHatchingAnimation(eggsData)

            -- Auto-cleanup after 10 seconds
            task.spawn(function()
                task.wait(10)
                if animationResult and animationResult.cleanup then
                    animationResult.cleanup()
                    print("✅ Test scenario completed and cleaned up")
                end
            end)
        end)
    end

    -- Update canvas size
    buttonContainer.CanvasSize = UDim2.new(0, 0, 0, #testScenarios * (buttonHeight + buttonSpacing))

    return screenGui
end

-- ═══════════════════════════════════════════════════════════════════════════════════
-- GRID LAYOUT TESTING
-- ═══════════════════════════════════════════════════════════════════════════════════

local function testGridLayoutCalculations()
    print("🧮 Testing grid layout calculations...")

    local testCases = { 1, 2, 4, 9, 16, 25, 36, 49, 64, 81, 99 }

    for _, eggCount in ipairs(testCases) do
        local gridInfo = EggHatchingService:CalculateGridLayout(eggCount, 800, 600)
        local positions = EggHatchingService:GenerateEggPositions(eggCount, gridInfo)

        print(
            string.format(
                "📊 %d eggs -> %s grid (%.0fx%.0f) -> %d positions",
                eggCount,
                gridInfo.layout.name,
                gridInfo.totalWidth,
                gridInfo.totalHeight,
                #positions
            )
        )
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════════
-- AUTO INITIALIZATION
-- ═══════════════════════════════════════════════════════════════════════════════════

-- Run tests automatically
print("🚀 Initializing Egg Hatching Animation Tests...")

-- Test grid calculations
testGridLayoutCalculations()

-- Create test GUI
local testGui = createTestGui()

print("✅ Egg Hatching Test GUI created! Use the buttons to test different scenarios.")
print("📝 Test different egg counts to verify grid layouts scale correctly.")
print("🎮 GUI will auto-cleanup animations after 10 seconds per test.")

-- Cleanup function for manual testing
_G.cleanupEggHatchingTests = function()
    if testGui then
        testGui:Destroy()
        print("🧹 Egg hatching test GUI cleaned up")
    end
end

print("💡 Tip: Run _G.cleanupEggHatchingTests() to manually clean up the test GUI")
