-- Admin Configuration
-- Define who has admin privileges in the game
-- This file should be SERVER-SIDE ONLY to prevent client injection

return {
    -- Admin User IDs - only these users can use admin functions
    authorizedUsers = {
        -- Add your Roblox User IDs here
        -- You can find your User ID by going to your profile URL
        -- Example: https://www.roblox.com/users/12345/profile -> User ID is 12345

        -- TO SET UP ADMIN ACCESS:
        -- 1. Go to https://www.roblox.com/users/12345/profile (replace 12345 with your user ID)
        -- 2. Copy the number from your profile URL
        -- 3. Add it to this list (uncomment and replace the example)

        3200870803, -- jason (coloradoplays) - Primary admin

        -- Studio Test Players (for multi-player testing in Studio)
        -1, -- Player1 (Studio test player)
        -2, -- Player2 (Studio test player)
        -3, -- Player3 (Studio test player)
        -4, -- Player4 (Studio test player)

        864785140, -- jason alt (xp/s + balance testing)
        -- 987654321,  -- Add more admin User IDs here
    },

    -- Admin permissions - what admins can do
    permissions = {
        -- Self-targeting permissions (existing functionality)
        setCurrency = true, -- Can set arbitrary currency amounts
        adjustCurrency = true, -- Can add/remove currency amounts
        giveItems = true, -- Can give items to players
        unlockZones = true, -- Can unlock configured areas/zones for testing
        manageHatchEntitlements = true, -- Can toggle hatch unlock/shop-stub attributes
        resetData = true, -- Can reset player data
        forceSaveData = true, -- Can force-save own profile during testing
        manageEffects = true, -- Can start/stop effects
        viewDebugInfo = true, -- Can view debug information
        testRateLimit = true, -- Can test rate limiting

        -- Multi-player targeting permissions (NEW)
        setCurrencyOthers = true, -- Can set currency for other players
        adjustCurrencyOthers = true, -- Can adjust currency for other players
        giveItemsOthers = true, -- Can give items to other players
        unlockZonesOthers = true, -- Can unlock configured areas/zones for other players
        manageHatchEntitlementsOthers = true, -- Can toggle hatch unlock/shop-stub attributes for others
        resetDataOthers = true, -- Can reset other players' data
        forceSaveDataOthers = true, -- Can force-save other players during testing
        manageEffectsOthers = true, -- Can manage effects for other players
        viewDebugInfoOthers = true, -- Can view other players' debug info
        kickPlayers = false, -- Can kick players (disabled by default)
        teleportPlayers = true, -- Can teleport players

        -- Global permissions
        globalEffects = true, -- Can apply effects to all players
        serverCommands = false, -- Can execute server-wide commands (disabled by default)
    },

    -- Security settings
    security = {
        logAllAdminActions = true, -- Log all admin actions for auditing
        requireStudioForSensitiveOps = true, -- Require Studio for dangerous operations
        allowStudioAccess = true, -- Treat Studio sessions as admin for local development/testing
        blockClientRequests = false, -- Block all client-originated admin requests (use true for maximum security)
    },
}
