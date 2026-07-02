-- Game Configuration
-- Main game settings and parameters
return {
    GameMode = "Simulator", -- Options: Simulator, FPS, TowerDefense, Custom
    MaxPlayers = 20,
    EnableTrading = true,
    EnablePvP = false,
    RespawnTime = 5,

    features = {
        stats = true,
        modifiers = true,
        economy_ledger = true,
        global_events = true,
        player_effects = true,
        monetization = true,
        admin_tools = true,
        auto_target = true,
        auto_systems = true,
        inventory = true,
        settings = true,
        diagnostics = true,
        map_binding = true,
        upgrades = true,
        player_progression = true,
        pet_progression = true,
        rebirths = false,
        enchants = true,
        achievements = true,
        leaderboards = true,
        pet_index = true,
        daily_rewards = false,
        pet_of_the_day = false,
        chaseables = false,
        stock = false,
        marketplace = false,
    },

    map = {
        mode = "auto", -- auto | synthetic | authored
    },

    -- Simulator specific settings
    SimulatorSettings = {
        BaseClickPower = 1,
        MaxRebirths = 100,
        RebirthMultiplier = 2,
        AutoClickers = {
            maxOwned = 10,
            basePrice = 100,
            priceMultiplier = 1.5,
        },
    },

    -- FPS specific settings
    FPSSettings = {
        RoundTime = 300,
        MaxKills = 30,
        WeaponRespawnTime = 10,
        TeamBalance = true,
    },

    -- Tower Defense specific settings
    TowerDefenseSettings = {
        StartingLives = 20,
        StartingMoney = 500,
        WaveCount = 50,
        DifficultyMultiplier = 1.1,
    },

    -- World settings
    WorldSettings = {
        Gravity = 196.2,
        WalkSpeed = 16,
        JumpPower = 50,
    },
}
