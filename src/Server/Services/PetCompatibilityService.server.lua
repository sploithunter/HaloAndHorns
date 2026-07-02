--[[
    PetCompatibilityService - Creates compatibility layer for imported pet system
    
    The imported pet system expects:
    - Player.Data.FollowType (StringValue)
    - Player.CurrentWorld (StringValue)
    
    This service creates these expected structures to bridge the gap.
--]]

local Players = game:GetService("Players")

local PetCompatibilityService = {}

-- Default values for imported pet system
local DEFAULT_FOLLOW_TYPE = "align" -- Use Align constraints (legacy followType == 1)
local DEFAULT_CURRENT_WORLD = "Spawn" -- Default world for pets

function PetCompatibilityService:CreatePlayerDataStructure(player)
    print("🔧 PetCompatibilityService: Creating Data structure for", player.Name)

    -- Create Data folder if it doesn't exist
    local dataFolder = player:FindFirstChild("Data")
    if not dataFolder then
        dataFolder = Instance.new("Folder")
        dataFolder.Name = "Data"
        dataFolder.Parent = player
    end

    -- Create FollowType StringValue
    local followType = dataFolder:FindFirstChild("FollowType")
    if not followType then
        followType = Instance.new("StringValue")
        followType.Name = "FollowType"
        followType.Value = DEFAULT_FOLLOW_TYPE
        followType.Parent = dataFolder
    else
        -- Force-align for physics parity with legacy until configurable
        followType.Value = DEFAULT_FOLLOW_TYPE
    end

    -- Create CurrentWorld StringValue (directly under player, not in Data)
    local currentWorld = player:FindFirstChild("CurrentWorld")
    if not currentWorld then
        currentWorld = Instance.new("StringValue")
        currentWorld.Name = "CurrentWorld"
        currentWorld.Value = DEFAULT_CURRENT_WORLD
        currentWorld.Parent = player
    end

    print("✅ PetCompatibilityService: Data structure created for", player.Name)
    print("   - FollowType:", followType.Value)
    print("   - CurrentWorld:", currentWorld.Value)
end

function PetCompatibilityService:OnPlayerAdded(player)
    -- Wait for character to load first
    player.CharacterAdded:Connect(function()
        -- Small delay to ensure other services have set up player folders
        task.wait(1)
        self:CreatePlayerDataStructure(player)
    end)

    -- Also create immediately if character already exists
    if player.Character then
        task.wait(1)
        self:CreatePlayerDataStructure(player)
    end
end

function PetCompatibilityService:Initialize()
    print("🚀 PetCompatibilityService: Initializing...")

    -- Handle existing players
    for _, player in pairs(Players:GetPlayers()) do
        self:OnPlayerAdded(player)
    end

    -- Handle new players
    Players.PlayerAdded:Connect(function(player)
        self:OnPlayerAdded(player)
    end)

    print("✅ PetCompatibilityService: Initialized!")
end

-- Auto-initialize
PetCompatibilityService:Initialize()

return PetCompatibilityService
