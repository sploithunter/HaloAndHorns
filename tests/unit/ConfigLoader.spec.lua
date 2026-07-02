--[[
    ConfigLoader Test Suite
    
    Tests for configuration loading, validation, and monetization handling
]]

return function()
    local ConfigLoader = require(game.ReplicatedStorage.Shared.ConfigLoader)
    -- Save original loader for patches throughout this spec
    local originalLoadConfig = ConfigLoader.__TEST_ORIGINAL_LOAD_CONFIG or ConfigLoader.LoadConfig
    ConfigLoader.__TEST_ORIGINAL_LOAD_CONFIG = originalLoadConfig

    describe("ConfigLoader", function()
        local configLoader

        beforeEach(function()
            configLoader = setmetatable({}, ConfigLoader)
            configLoader:Init()
            ConfigLoader.LoadConfig = originalLoadConfig
        end)

        afterEach(function()
            ConfigLoader.LoadConfig = originalLoadConfig
        end)

        describe("Monetization Config Methods", function()
            -- Mock monetization config
            local mockMonetizationConfig = {
                product_id_mapping = {
                    small_gems = 1234567890,
                    medium_gems = 1234567891,
                    starter_pack = 1234567892,
                    vip_pass = 123456789,
                    auto_collect = 123456790,
                    speed_boost = 123456791,
                },
                products = {
                    {
                        id = "small_gems",
                        name = "100 Gems",
                        price_robux = 99,
                        rewards = { gems = 100 },
                    },
                    {
                        id = "medium_gems",
                        name = "500 Gems",
                        price_robux = 399,
                        rewards = { gems = 550 },
                    },
                    {
                        id = "starter_pack",
                        name = "Starter Pack",
                        price_robux = 199,
                        rewards = {
                            gems = 150,
                            coins = 25000,
                            items = { "wooden_sword" },
                        },
                    },
                },
                passes = {
                    {
                        id = "vip_pass",
                        name = "VIP Pass",
                        price_robux = 499,
                        benefits = {
                            multipliers = { xp = 2.0, coins = 1.5 },
                        },
                    },
                    {
                        id = "auto_collect",
                        name = "Auto Collector",
                        price_robux = 299,
                        benefits = {
                            features = { auto_collect_enabled = true },
                        },
                    },
                    {
                        id = "speed_boost",
                        name = "Speed Boost",
                        price_robux = 199,
                        benefits = {
                            effects = {
                                id = "speed_pass",
                                permanent = true,
                                stats = { speedMultiplier = 0.5 },
                            },
                        },
                    },
                },
                premium_benefits = {
                    enabled = true,
                    multipliers = { xp = 1.5, coins = 1.25 },
                },
                first_purchase_bonus = {
                    enabled = true,
                    rewards = { gems = 100, coins = 50000 },
                },
                validation_rules = {
                    test_mode = { enabled = true },
                },
                error_messages = {
                    product_not_found = "Product not found",
                },
                analytics = {
                    track_purchases = true,
                },
            }

            beforeEach(function()
                configLoader._monetizationCache = mockMonetizationConfig
            end)

            it("should get product by ID", function()
                local product = configLoader:GetProduct("small_gems")

                expect(product).to.be.ok()
                expect(product.id).to.equal("small_gems")
                expect(product.name).to.equal("100 Gems")
                expect(product.price_robux).to.equal(99)
                expect(product.rewards.gems).to.equal(100)
            end)

            it("should get game pass by ID", function()
                local pass = configLoader:GetGamePass("vip_pass")

                expect(pass).to.be.ok()
                expect(pass.id).to.equal("vip_pass")
                expect(pass.name).to.equal("VIP Pass")
                expect(pass.price_robux).to.equal(499)
                expect(pass.benefits.multipliers.xp).to.equal(2.0)
            end)

            it("should get product by Roblox ID", function()
                local product = configLoader:GetProductByRobloxId(1234567890)

                expect(product).to.be.ok()
                expect(product.id).to.equal("small_gems")
                expect(product.name).to.equal("100 Gems")
            end)

            it("should return nil for unknown product", function()
                local product = configLoader:GetProduct("unknown_product")
                expect(product).to.equal(nil)
            end)

            it("should return nil for unknown game pass", function()
                local pass = configLoader:GetGamePass("unknown_pass")
                expect(pass).to.equal(nil)
            end)

            it("should get all products", function()
                local products = configLoader:GetAllProducts()

                expect(#products).to.equal(3)
                expect(products[1].id).to.equal("small_gems")
                expect(products[2].id).to.equal("medium_gems")
                expect(products[3].id).to.equal("starter_pack")
            end)

            it("should get all game passes", function()
                local passes = configLoader:GetAllGamePasses()

                expect(#passes).to.equal(3)
                expect(passes[1].id).to.equal("vip_pass")
                expect(passes[2].id).to.equal("auto_collect")
                expect(passes[3].id).to.equal("speed_boost")
            end)

            it("should get product ID mapping", function()
                local mapping = configLoader:GetProductIdMapping()

                expect(mapping).to.be.ok()
                expect(mapping.small_gems).to.equal(1234567890)
                expect(mapping.vip_pass).to.equal(123456789)
            end)

            it("should get Roblox ID from config ID", function()
                local robloxId = configLoader:GetRobloxId("small_gems")
                expect(robloxId).to.equal(1234567890)

                local passId = configLoader:GetRobloxId("vip_pass")
                expect(passId).to.equal(123456789)
            end)

            it("should get premium benefits", function()
                local benefits = configLoader:GetPremiumBenefits()

                expect(benefits).to.be.ok()
                expect(benefits.enabled).to.equal(true)
                expect(benefits.multipliers.xp).to.equal(1.5)
                expect(benefits.multipliers.coins).to.equal(1.25)
            end)

            it("should get first purchase bonus", function()
                local bonus = configLoader:GetFirstPurchaseBonus()

                expect(bonus).to.be.ok()
                expect(bonus.enabled).to.equal(true)
                expect(bonus.rewards.gems).to.equal(100)
                expect(bonus.rewards.coins).to.equal(50000)
            end)

            it("should get validation rules", function()
                local rules = configLoader:GetValidationRules()

                expect(rules).to.be.ok()
                expect(rules.test_mode.enabled).to.equal(true)
            end)

            it("should get error messages", function()
                local messages = configLoader:GetErrorMessages()

                expect(messages).to.be.ok()
                expect(messages.product_not_found).to.equal("Product not found")
            end)

            it("should get analytics config", function()
                local analytics = configLoader:GetAnalyticsConfig()

                expect(analytics).to.be.ok()
                expect(analytics.track_purchases).to.equal(true)
            end)
        end)

        describe("Configuration Validation", function()
            it("should validate valid monetization config", function()
                local validConfig = {
                    product_id_mapping = { test_product = 123456789 },
                    products = {
                        {
                            id = "test_product",
                            name = "Test Product",
                            price_robux = 99,
                            rewards = { gems = 100 },
                        },
                    },
                    passes = {},
                    premium_benefits = { enabled = true },
                }

                local isValid, error = configLoader:ValidateConfig("monetization", validConfig)
                expect(isValid).to.equal(true)
                expect(error).to.equal(nil)
            end)

            it("should reject monetization config with missing product_id_mapping", function()
                local invalidConfig = {
                    products = {},
                    passes = {},
                    premium_benefits = {},
                }

                local isValid, error = configLoader:ValidateConfig("monetization", invalidConfig)
                expect(isValid).to.equal(false)
                expect(string.find(error, "Missing required section: product_id_mapping", 1, true)).to.be.ok()
            end)

            it("should reject product with missing ID", function()
                local invalidConfig = {
                    product_id_mapping = {},
                    products = {
                        {
                            name = "Test Product",
                            price_robux = 99,
                            rewards = {},
                        },
                    },
                    passes = {},
                    premium_benefits = {},
                }

                local isValid, error = configLoader:ValidateConfig("monetization", invalidConfig)
                expect(isValid).to.equal(false)
                expect(string.find(error, "missing or invalid id", 1, true)).to.be.ok()
            end)

            it("should reject product not in ID mapping", function()
                local invalidConfig = {
                    product_id_mapping = {},
                    products = {
                        {
                            id = "test_product",
                            name = "Test Product",
                            price_robux = 99,
                            rewards = {},
                        },
                    },
                    passes = {},
                    premium_benefits = {},
                }

                local isValid, error = configLoader:ValidateConfig("monetization", invalidConfig)
                expect(isValid).to.equal(false)
                expect(string.find(error, "not found in product_id_mapping", 1, true)).to.be.ok()
            end)

            it("should reject breakable spawn entries with unknown crystal ids", function()
                local invalidConfig = {
                    crystals = {
                        SmallCrystal = {
                            display_name = "Small Crystal",
                            procedural_asset = "test",
                            scale = 1,
                            health = 10,
                            value = 1,
                            currency = "coins",
                        },
                    },
                    worlds = {
                        Spawn = {
                            max = 1,
                            interval = 5,
                            spawn_table = {
                                { name = "MissingCrystal", weight = 1 },
                            },
                        },
                    },
                }

                local isValid, error = configLoader:ValidateConfig("breakables", invalidConfig)
                expect(isValid).to.equal(false)
                expect(string.find(error, "must reference breakables.crystals", 1, true)).to.be.ok()
            end)

            it("should reject pet eggs with unknown currency ids", function()
                local invalidConfig = {
                    version = "1.0.0",
                    rarities = {
                        common = { name = "Common" },
                    },
                    variants = {
                        basic = { name = "Basic", rarity = "common" },
                    },
                    pets = {
                        bear = {
                            display_name = "Bear",
                            category = "forest",
                            rarity = "common",
                            base_power = 10,
                            base_health = 10,
                            variants = {
                                basic = {
                                    asset_id = "rbxassetid://1",
                                    display_name = "Bear",
                                    power = 10,
                                    health = 10,
                                },
                            },
                        },
                    },
                    abilities = {},
                    egg_sources = {
                        basic_egg = {
                            name = "Basic Egg",
                            cost = 100,
                            currency = "missing_currency",
                            pet_weights = {
                                bear = 1,
                            },
                        },
                    },
                }

                local isValid, error = configLoader:ValidateConfig("pets", invalidConfig)
                expect(isValid).to.equal(false)
                expect(string.find(error, "must reference configs/currencies.lua", 1, true)).to.be.ok()
            end)

            it("should reject pet eggs with invalid unlock requirements", function()
                local invalidConfig = {
                    version = "1.0.0",
                    rarities = {
                        common = { name = "Common" },
                    },
                    variants = {
                        basic = { name = "Basic", rarity = "common" },
                    },
                    pets = {
                        bear = {
                            display_name = "Bear",
                            category = "forest",
                            rarity = "common",
                            base_power = 10,
                            base_health = 10,
                            variants = {
                                basic = {
                                    asset_id = "rbxassetid://1",
                                    display_name = "Bear",
                                    power = 10,
                                    health = 10,
                                },
                            },
                        },
                    },
                    abilities = {},
                    egg_sources = {
                        basic_egg = {
                            name = "Basic Egg",
                            cost = 100,
                            currency = "coins",
                            unlock_requirement = {
                                type = "pets_hatched",
                                amount = "ten",
                            },
                            pet_weights = {
                                bear = 1,
                            },
                        },
                    },
                }

                local isValid, error = configLoader:ValidateConfig("pets", invalidConfig)
                expect(isValid).to.equal(false)
                expect(string.find(error, "unlock_requirement.amount", 1, true)).to.be.ok()
            end)

            it("should reject pet family rarity ids that are not configured", function()
                local invalidConfig = {
                    version = "1.0.0",
                    rarities = {
                        common = { name = "Common" },
                    },
                    variants = {
                        basic = { name = "Basic", rarity = "common" },
                    },
                    pets = {
                        bear = {
                            display_name = "Bear",
                            category = "forest",
                            rarity = "missing_rarity",
                            base_power = 10,
                            base_health = 10,
                            variants = {
                                basic = {
                                    asset_id = "rbxassetid://1",
                                    display_name = "Bear",
                                    power = 10,
                                    health = 10,
                                },
                            },
                        },
                    },
                    abilities = {},
                    egg_sources = {},
                }

                local isValid, error = configLoader:ValidateConfig("pets", invalidConfig)
                expect(isValid).to.equal(false)
                expect(string.find(error, "pets.bear.rarity", 1, true)).to.be.ok()
            end)

            it("should require pet families to declare a rarity", function()
                local invalidConfig = {
                    version = "1.0.0",
                    rarities = {
                        common = { name = "Common" },
                    },
                    variants = {
                        basic = { name = "Basic", rarity = "common" },
                    },
                    pets = {
                        bear = {
                            display_name = "Bear",
                            category = "forest",
                            base_power = 10,
                            base_health = 10,
                            variants = {
                                basic = {
                                    asset_id = "rbxassetid://1",
                                    display_name = "Bear",
                                    power = 10,
                                    health = 10,
                                },
                            },
                        },
                    },
                    abilities = {},
                    egg_sources = {},
                }

                local isValid, error = configLoader:ValidateConfig("pets", invalidConfig)
                expect(isValid).to.equal(false)
                expect(string.find(error, "pets.bear.rarity", 1, true)).to.be.ok()
            end)

            it("should require pet family display names separate from stable ids", function()
                local invalidConfig = {
                    version = "1.0.0",
                    rarities = {
                        common = { name = "Common" },
                    },
                    variants = {
                        basic = { name = "Basic", rarity = "common" },
                    },
                    pets = {
                        bear = {
                            category = "forest",
                            rarity = "common",
                            base_power = 10,
                            base_health = 10,
                            variants = {
                                basic = {
                                    asset_id = "rbxassetid://1",
                                    display_name = "Bear",
                                    power = 10,
                                    health = 10,
                                },
                            },
                        },
                    },
                    abilities = {},
                    egg_sources = {},
                }

                local isValid, error = configLoader:ValidateConfig("pets", invalidConfig)
                expect(isValid).to.equal(false)
                expect(string.find(error, "pets.bear.display_name", 1, true)).to.be.ok()
            end)

            it("should reject malformed pet family ids", function()
                local invalidConfig = {
                    version = "1.0.0",
                    rarities = {
                        common = { name = "Common" },
                    },
                    variants = {
                        basic = { name = "Basic", rarity = "common" },
                    },
                    pets = {
                        ["Bear Basic"] = {
                            display_name = "Bear",
                            category = "forest",
                            rarity = "common",
                            base_power = 10,
                            base_health = 10,
                            variants = {
                                basic = {
                                    asset_id = "rbxassetid://1",
                                    display_name = "Bear",
                                    power = 10,
                                    health = 10,
                                },
                            },
                        },
                    },
                    abilities = {},
                    egg_sources = {},
                }

                local isValid, error = configLoader:ValidateConfig("pets", invalidConfig)
                expect(isValid).to.equal(false)
                expect(string.find(error, "pets.Bear Basic", 1, true)).to.be.ok()
            end)

            it("should reject scheduled events with unknown event ids", function()
                local invalidConfig = {
                    tick_seconds = 1,
                    workspace = {
                        active_folder = "GlobalEvents",
                    },
                    modifiers = {
                        egg_luck = {
                            display_name = "Egg Luck",
                            base = 0,
                        },
                    },
                    global_events = {
                        lucky_day = {
                            display_name = "Lucky Day",
                            duration_seconds = -1,
                            stacking = "reset",
                            modifiers = {
                                egg_luck = 0.1,
                            },
                        },
                    },
                    scheduled_global_events = {
                        bad_schedule = {
                            event_id = "missing_event",
                            weekdays_utc = { 3 },
                        },
                    },
                }

                local isValid, error = configLoader:ValidateConfig("events", invalidConfig)
                expect(isValid).to.equal(false)
                expect(string.find(error, "must reference global_events", 1, true)).to.be.ok()
            end)

            it("should validate an area zone tree", function()
                local validConfig = {
                    zones = {
                        spawn_world = {
                            id = "spawn_world",
                            kind = "world",
                        },
                        spawn_island = {
                            id = "spawn_island",
                            kind = "island",
                            parent = "spawn_world",
                        },
                        Spawn = {
                            id = "Spawn",
                            kind = "area",
                            parent = "spawn_island",
                            boosts = {},
                            synthetic = {},
                        },
                    },
                }

                local isValid, error = configLoader:ValidateConfig("areas", validConfig)
                expect(isValid).to.equal(true)
                expect(error).to.equal(nil)
            end)

            it("should reject areas with missing parent zone references", function()
                local invalidConfig = {
                    zones = {
                        Spawn = {
                            id = "Spawn",
                            kind = "area",
                            parent = "missing_parent",
                        },
                    },
                }

                local isValid, error = configLoader:ValidateConfig("areas", invalidConfig)
                expect(isValid).to.equal(false)
                expect(string.find(error, "must reference an existing zone", 1, true)).to.be.ok()
            end)

            it("should reject cyclic area zone trees", function()
                local invalidConfig = {
                    zones = {
                        alpha = {
                            id = "alpha",
                            kind = "area",
                            parent = "bravo",
                        },
                        bravo = {
                            id = "bravo",
                            kind = "area",
                            parent = "alpha",
                        },
                    },
                }

                local isValid, error = configLoader:ValidateConfig("areas", invalidConfig)
                expect(isValid).to.equal(false)
                expect(string.find(error, "cycle detected", 1, true)).to.be.ok()
            end)

            it("should reject area unlocks with unknown currencies", function()
                local invalidConfig = {
                    zones = {
                        Spawn = {
                            id = "Spawn",
                            kind = "area",
                            unlock = {
                                currency = "missing_currency",
                                cost = 10,
                            },
                        },
                    },
                }

                local isValid, error = configLoader:ValidateConfig("areas", invalidConfig)
                expect(isValid).to.equal(false)
                expect(string.find(error, "configs/currencies.lua", 1, true)).to.be.ok()
            end)

            it("should validate upgrade definitions", function()
                local validConfig = {
                    version = "1.0.0",
                    upgrades = {
                        pet_equip_slots = {
                            id = "pet_equip_slots",
                            display_name = "Pet Equip Slots",
                            max_level = 2,
                            cost = {
                                currency = "coins",
                                type = "linear",
                                base = 100,
                                increment = 50,
                            },
                            effects = {
                                {
                                    type = "equip_slots",
                                    category = "pets",
                                    amount_per_level = 1,
                                },
                            },
                        },
                    },
                }

                local isValid, error = configLoader:ValidateConfig("upgrades", validConfig)
                expect(isValid).to.equal(true)
                expect(error).to.equal(nil)
            end)

            it("should reject upgrades with dangling inventory effects", function()
                local invalidConfig = {
                    version = "1.0.0",
                    upgrades = {
                        impossible_slots = {
                            id = "impossible_slots",
                            display_name = "Impossible Slots",
                            max_level = 1,
                            cost = {
                                currency = "coins",
                                type = "linear",
                                base = 100,
                                increment = 50,
                            },
                            effects = {
                                {
                                    type = "equip_slots",
                                    category = "mounts",
                                    amount_per_level = 1,
                                },
                            },
                        },
                    },
                }

                local isValid, error = configLoader:ValidateConfig("upgrades", invalidConfig)
                expect(isValid).to.equal(false)
                expect(string.find(error, "inventory.equipped", 1, true)).to.be.ok()
            end)

            it("should validate pet progression tuning", function()
                local validConfig = {
                    version = "1.0.0",
                    enabled = true,
                    unique_only = true,
                    default_max_level = 1,
                    max_level_by_rarity = {
                        exclusive = 75,
                        huge = 100,
                    },
                    xp_curve = {
                        type = "exponential",
                        base = 100,
                        growth = 1.18,
                    },
                    power_scaling = {
                        type = "percent_per_level",
                        percent_per_level = 0.02,
                        max_bonus_percent = 1,
                    },
                    enchant_slots = {
                        default_unlocked_slots = 1,
                        unlocks_by_rarity = {
                            exclusive = {
                                { level = 1, slots = 1 },
                                { level = 25, slots = 2 },
                            },
                            huge = {
                                { level = 1, slots = 1 },
                                { level = 25, slots = 2 },
                                { level = 75, slots = 3 },
                            },
                        },
                    },
                }

                local isValid, error = configLoader:ValidateConfig("pet_progression", validConfig)
                expect(isValid).to.equal(true)
                expect(error).to.equal(nil)
            end)

            it("should reject pet progression rarity typos", function()
                local invalidConfig = {
                    version = "1.0.0",
                    enabled = true,
                    unique_only = true,
                    default_max_level = 1,
                    max_level_by_rarity = {
                        exclusive_typo = 75,
                    },
                    xp_curve = {
                        type = "linear",
                        base = 100,
                        increment = 25,
                    },
                    power_scaling = {
                        type = "percent_per_level",
                        percent_per_level = 0.02,
                        max_bonus_percent = 1,
                    },
                    enchant_slots = {
                        default_unlocked_slots = 1,
                        unlocks_by_rarity = {},
                    },
                }

                local isValid, error = configLoader:ValidateConfig("pet_progression", invalidConfig)
                expect(isValid).to.equal(false)
                expect(string.find(error, "must reference pets.rarities", 1, true)).to.be.ok()
            end)

            it("should validate player-level progression rewards", function()
                local validConfig = {
                    version = "1.0.0",
                    enabled = true,
                    team_power = {
                        enabled = true,
                        stage = "boosts",
                        kind = "team_power",
                        start_level = 1,
                        percent_per_level = 0.01,
                        max_bonus_percent = 1,
                    },
                    level_rewards = {
                        equip_slots = {
                            pets = {
                                enabled = true,
                                start_level = 10,
                                every_levels = 10,
                                slots_per_milestone = 1,
                                max_bonus_slots = 3,
                            },
                        },
                    },
                }

                local isValid, error =
                    configLoader:ValidateConfig("player_progression", validConfig)
                expect(isValid).to.equal(true)
                expect(error).to.equal(nil)
            end)

            it("should reject player progression modifier stage typos", function()
                local invalidConfig = {
                    version = "1.0.0",
                    enabled = true,
                    team_power = {
                        enabled = true,
                        stage = "boosts_typo",
                        kind = "team_power",
                        start_level = 1,
                        percent_per_level = 0.01,
                        max_bonus_percent = 1,
                    },
                    level_rewards = {
                        equip_slots = {
                            pets = {
                                enabled = true,
                                start_level = 10,
                                every_levels = 10,
                                slots_per_milestone = 1,
                                max_bonus_slots = 3,
                            },
                        },
                    },
                }

                local isValid, error =
                    configLoader:ValidateConfig("player_progression", invalidConfig)
                expect(isValid).to.equal(false)
                expect(
                    string.find(error, "must reference economy.modifier_pipeline.stages", 1, true)
                ).to.be.ok()
            end)

            it("should validate auto systems target modes and delete filters", function()
                local validConfig = {
                    version = "1.0.0",
                    enabled = true,
                    auto_target = {
                        enabled = true,
                        default_enabled = false,
                        default_mode = "nearest",
                        default_selected_currency = "crystals",
                        current_world_only = true,
                        request_interval_seconds = 0.3,
                        modes = {
                            nearest = {
                                display_name = "Nearest",
                                sort = "distance_asc",
                            },
                            highest_value = {
                                display_name = "Highest Value",
                                sort = "value_desc",
                            },
                        },
                        compatibility_toggles = {
                            free_mode = "nearest",
                            paid_mode = "highest_value",
                        },
                    },
                    auto_delete = {
                        enabled = true,
                        default_enabled = false,
                        protect_unique = true,
                        protected_rarities = {
                            secret = true,
                            exclusive = true,
                            huge = true,
                        },
                        defaults = {
                            rarities = {
                                common = true,
                            },
                            pet_types = {
                                bear = true,
                            },
                            variants = {
                                basic = true,
                            },
                        },
                    },
                }

                local isValid, error = configLoader:ValidateConfig("auto_systems", validConfig)
                expect(isValid).to.equal(true)
                expect(error).to.equal(nil)
            end)

            it("should reject auto systems mode typos", function()
                local invalidConfig = {
                    version = "1.0.0",
                    enabled = true,
                    auto_target = {
                        enabled = true,
                        default_mode = "nearest_typo",
                        default_selected_currency = "crystals",
                        modes = {
                            nearest = {
                                display_name = "Nearest",
                                sort = "distance_asc",
                            },
                        },
                    },
                    auto_delete = {
                        enabled = true,
                        defaults = {},
                    },
                }

                local isValid, error = configLoader:ValidateConfig("auto_systems", invalidConfig)
                expect(isValid).to.equal(false)
                expect(string.find(error, "must reference auto_target.modes", 1, true)).to.be.ok()
            end)

            local function makeValidEggSystemConfig()
                return {
                    version = "1.0.0",
                    proximity = {
                        max_distance = 18,
                    },
                    performance = {
                        update_interval = 0.1,
                    },
                    cooldowns = {
                        purchase_cooldown = 3,
                    },
                    hatching = {
                        max_count = 99,
                        default_requested_count = 1,
                        default_max_entitled_count = 3,
                        allow_partial = true,
                        transaction_lock_seconds = 0.35,
                        failed_request_lock_seconds = 0.2,
                        auto_loop_delay = 3,
                        debug = {
                            history_limit = 12,
                            result_sample_limit = 20,
                        },
                        animation = {
                            max_visible_eggs = 99,
                            use_authored_egg_visual = true,
                            authored_visual_scale = 1.25,
                            fast_hatch_speed_scale = 0.5,
                            layout = {
                                padding = 20,
                                min_egg_size = 100,
                                compact_min_egg_size = 70,
                                compact_threshold = 37,
                                max_egg_size = 300,
                            },
                            special_reveal_enabled = true,
                            special_world_fx = true,
                            respect_silent_for_special = false,
                            special_reveal_min_duration = 1.1,
                            special_rarities = {
                                mythic = true,
                                secret = true,
                            },
                            special_glow = {
                                enabled = true,
                                stroke_thickness = 5,
                                stroke_transparency = 0.12,
                                pulse_enabled = true,
                                pulse_scale = 1.45,
                                pulse_duration = 0.55,
                                pulse_repeats = 3,
                            },
                            special_backdrop = {
                                enabled = true,
                                transparency = 0.82,
                                pulse_scale = 1.18,
                                pulse_duration = 0.35,
                            },
                            result_stack = {
                                enabled = true,
                                show_name = true,
                                show_count = true,
                                count_minimum = 2,
                                move_tween_seconds = 0.35,
                                recenter_tween_seconds = 0.45,
                                hold_seconds = 1,
                            },
                            reveal_badges = {
                                enabled = true,
                                show_rarity = true,
                                show_variant = true,
                                show_basic_variant = false,
                                show_auto_deleted = true,
                                special_badge_text = "SPECIAL",
                                auto_deleted_text = "AUTO-DELETED",
                            },
                        },
                        shop_stubs = {
                            max_hatch_count = {
                                enabled = true,
                                default_value = 3,
                            },
                            auto_hatch = {
                                enabled = true,
                                owned_by_default = true,
                            },
                            fast_hatch = {
                                enabled = true,
                                owned_by_default = false,
                            },
                            skip_hatch = {
                                enabled = true,
                                owned_by_default = false,
                            },
                            golden_mode = {
                                enabled = true,
                                owned_by_default = false,
                                cost_multiplier = 20,
                            },
                            charged_mode = {
                                enabled = true,
                                owned_by_default = false,
                                cost_multiplier = 5,
                                luck_bonus = 1,
                                secret_luck_bonus = 0.25,
                            },
                            luck_bonus = {
                                enabled = true,
                                default_multiplier = 0,
                            },
                            secret_luck_bonus = {
                                enabled = true,
                                default_multiplier = 0,
                            },
                        },
                    },
                    ui = {
                        interaction_prompt = {
                            mode = "clean",
                            clean_text = "%s Hatch",
                            clean_max_text = "%s Max Hatch",
                            clean_auto_text = "%s Auto Hatch",
                            advertised_text = "%s Hatch | %s Max | %s Auto",
                        },
                        hatch_panel = {
                            enabled = true,
                            width = 500,
                            height = 176,
                            settings_height = 336,
                            count_step = 1,
                            count_large_step = 10,
                            default_selected_count = 1,
                            default_action_mode = "single",
                            show_inline_controls = false,
                            status_display_time = 3,
                            action_modes = {
                                single = {
                                    label = "Single Hatch",
                                    description = "Press E to hatch one egg.",
                                },
                                max = {
                                    label = "Max Hatch",
                                    description = "Press E to hatch the maximum allowed count.",
                                },
                                auto = {
                                    label = "Auto Hatch",
                                    description = "Press E to start or stop auto hatching.",
                                },
                            },
                            responsive = {
                                margin = 16,
                                min_scale = 0.64,
                                max_scale = 1,
                            },
                            buttons = {
                                hatch = "Hatch",
                                max = "Max",
                                auto = "Auto",
                                settings = "Filters",
                            },
                            auto_delete = {
                                description = "Choose filters.",
                                enabled_description = "Turn filtering on.",
                                rarity_description = "By rarity.",
                                pet_type_description = "By pet.",
                                variant_description = "By variant.",
                                rarity_filters = { "common" },
                                pet_type_filters = { "bear" },
                                variant_filters = { "basic" },
                            },
                            modes = {
                                golden = {
                                    label = "Golden",
                                    option = "goldenMode",
                                    default_enabled = false,
                                    description = "Costs more and removes Basic rolls.",
                                    locked_description = "Locked.",
                                    active_description = "Active.",
                                    available_description = "Available.",
                                },
                            },
                            help = {
                                default = "Hover a control.",
                                count = "Choose count.",
                                hatch = "Hatch once.",
                                max = "Request max.",
                                auto = "Auto hatch.",
                                settings = "Open filters.",
                            },
                        },
                    },
                    pet_preview = {},
                    messages = {},
                    spawning = {
                        spawn_point_name = "EggSpawnPoint",
                    },
                    validation = {},
                }
            end

            it("should validate egg hatch system settings", function()
                local validConfig = makeValidEggSystemConfig()

                local isValid, error = configLoader:ValidateConfig("egg_system", validConfig)
                expect(isValid).to.equal(true)
                expect(error).to.equal(nil)
            end)

            it("should reject hatch defaults above the configured hatch max", function()
                local invalidConfig = makeValidEggSystemConfig()
                invalidConfig.hatching.default_requested_count = 100

                local isValid, error = configLoader:ValidateConfig("egg_system", invalidConfig)
                expect(isValid).to.equal(false)
                expect(string.find(error, "hatching.default_requested_count", 1, true)).to.be.ok()
            end)

            it("should reject animation layouts above the configured hatch max", function()
                local invalidConfig = makeValidEggSystemConfig()
                invalidConfig.hatching.max_count = 20
                invalidConfig.hatching.default_max_entitled_count = 20
                invalidConfig.hatching.shop_stubs.max_hatch_count.default_value = 20
                invalidConfig.hatching.animation.max_visible_eggs = 21

                local isValid, error = configLoader:ValidateConfig("egg_system", invalidConfig)
                expect(isValid).to.equal(false)
                expect(string.find(error, "hatching.animation.max_visible_eggs", 1, true)).to.be.ok()
            end)

            it("should reject fast hatch animation speed above normal speed", function()
                local invalidConfig = makeValidEggSystemConfig()
                invalidConfig.hatching.animation.fast_hatch_speed_scale = 1.5

                local isValid, error = configLoader:ValidateConfig("egg_system", invalidConfig)
                expect(isValid).to.equal(false)
                expect(string.find(error, "hatching.animation.fast_hatch_speed_scale", 1, true)).to.be.ok()
            end)

            it("should reject hatch animation layout min size above max size", function()
                local invalidConfig = makeValidEggSystemConfig()
                invalidConfig.hatching.animation.layout.min_egg_size = 320
                invalidConfig.hatching.animation.layout.max_egg_size = 300

                local isValid, error = configLoader:ValidateConfig("egg_system", invalidConfig)
                expect(isValid).to.equal(false)
                expect(string.find(error, "hatching.animation.layout.min_egg_size", 1, true)).to.be.ok()
            end)

            it("should reject special hatch glow transparency above one", function()
                local invalidConfig = makeValidEggSystemConfig()
                invalidConfig.hatching.animation.special_glow.stroke_transparency = 1.5

                local isValid, error = configLoader:ValidateConfig("egg_system", invalidConfig)
                expect(isValid).to.equal(false)
                expect(
                    string.find(
                        error,
                        "hatching.animation.special_glow.stroke_transparency",
                        1,
                        true
                    )
                ).to.be.ok()
            end)

            it("should reject special hatch backdrop transparency above one", function()
                local invalidConfig = makeValidEggSystemConfig()
                invalidConfig.hatching.animation.special_backdrop.transparency = 1.5

                local isValid, error = configLoader:ValidateConfig("egg_system", invalidConfig)
                expect(isValid).to.equal(false)
                expect(
                    string.find(error, "hatching.animation.special_backdrop.transparency", 1, true)
                ).to.be.ok()
            end)

            it("should reject invalid hatch result stack config", function()
                local invalidConfig = makeValidEggSystemConfig()
                invalidConfig.hatching.animation.result_stack.hold_seconds = 0

                local isValid, error = configLoader:ValidateConfig("egg_system", invalidConfig)
                expect(isValid).to.equal(false)
                expect(string.find(error, "hatching.animation.result_stack.hold_seconds", 1, true)).to.be.ok()
            end)

            it("should reject special hatch rarity ids that are not configured", function()
                local invalidConfig = makeValidEggSystemConfig()
                invalidConfig.hatching.animation.special_rarities.missing_rarity = true

                local isValid, error = configLoader:ValidateConfig("egg_system", invalidConfig)
                expect(isValid).to.equal(false)
                expect(
                    string.find(
                        error,
                        "hatching.animation.special_rarities.missing_rarity",
                        1,
                        true
                    )
                ).to.be.ok()
                expect(string.find(error, "pets.rarities", 1, true)).to.be.ok()
            end)

            it("should reject incomplete hatch panel button config", function()
                local invalidConfig = makeValidEggSystemConfig()
                invalidConfig.ui.hatch_panel.buttons.auto = ""

                local isValid, error = configLoader:ValidateConfig("egg_system", invalidConfig)
                expect(isValid).to.equal(false)
                expect(string.find(error, "ui.hatch_panel.buttons.auto", 1, true)).to.be.ok()
            end)

            it(
                "should reject hatch auto-delete filters that do not reference pet config",
                function()
                    local invalidConfig = makeValidEggSystemConfig()
                    invalidConfig.ui.hatch_panel.auto_delete.pet_type_filters = { "missing_pet" }

                    local isValid, error = configLoader:ValidateConfig("egg_system", invalidConfig)
                    expect(isValid).to.equal(false)
                    expect(
                        string.find(error, "ui.hatch_panel.auto_delete.pet_type_filters.1", 1, true)
                    ).to.be.ok()
                    expect(string.find(error, "pets.pets", 1, true)).to.be.ok()

                    invalidConfig = makeValidEggSystemConfig()
                    invalidConfig.ui.hatch_panel.auto_delete.rarity_filters = { "missing_rarity" }

                    isValid, error = configLoader:ValidateConfig("egg_system", invalidConfig)
                    expect(isValid).to.equal(false)
                    expect(string.find(error, "pets.rarities", 1, true)).to.be.ok()

                    invalidConfig = makeValidEggSystemConfig()
                    invalidConfig.ui.hatch_panel.auto_delete.variant_filters = { "missing_variant" }

                    isValid, error = configLoader:ValidateConfig("egg_system", invalidConfig)
                    expect(isValid).to.equal(false)
                    expect(string.find(error, "pets.variants", 1, true)).to.be.ok()
                end
            )

            it("should reject hatch panel responsive scale inversions", function()
                local invalidConfig = makeValidEggSystemConfig()
                invalidConfig.ui.hatch_panel.responsive.min_scale = 0.8
                invalidConfig.ui.hatch_panel.responsive.max_scale = 0.7

                local isValid, error = configLoader:ValidateConfig("egg_system", invalidConfig)
                expect(isValid).to.equal(false)
                expect(string.find(error, "ui.hatch_panel.responsive.max_scale", 1, true)).to.be.ok()
            end)

            it("should reject invalid hatch action settings", function()
                local invalidConfig = makeValidEggSystemConfig()
                invalidConfig.ui.hatch_panel.default_action_mode = "triple"

                local isValid, error = configLoader:ValidateConfig("egg_system", invalidConfig)
                expect(isValid).to.equal(false)
                expect(string.find(error, "ui.hatch_panel.default_action_mode", 1, true)).to.be.ok()

                invalidConfig = makeValidEggSystemConfig()
                invalidConfig.ui.hatch_panel.show_inline_controls = "no"

                isValid, error = configLoader:ValidateConfig("egg_system", invalidConfig)
                expect(isValid).to.equal(false)
                expect(string.find(error, "ui.hatch_panel.show_inline_controls", 1, true)).to.be.ok()
            end)

            it("should reject invalid egg interaction prompt settings", function()
                local invalidConfig = makeValidEggSystemConfig()
                invalidConfig.ui.interaction_prompt.mode = "busy"

                local isValid, error = configLoader:ValidateConfig("egg_system", invalidConfig)
                expect(isValid).to.equal(false)
                expect(string.find(error, "ui.interaction_prompt.mode", 1, true)).to.be.ok()

                invalidConfig = makeValidEggSystemConfig()
                invalidConfig.ui.interaction_prompt.clean_text = false

                isValid, error = configLoader:ValidateConfig("egg_system", invalidConfig)
                expect(isValid).to.equal(false)
                expect(string.find(error, "ui.interaction_prompt.clean_text", 1, true)).to.be.ok()
            end)

            it("should reject non-boolean hatch mode defaults", function()
                local invalidConfig = makeValidEggSystemConfig()
                invalidConfig.ui.hatch_panel.modes.golden.default_enabled = "yes"

                local isValid, error = configLoader:ValidateConfig("egg_system", invalidConfig)
                expect(isValid).to.equal(false)
                expect(string.find(error, "ui.hatch_panel.modes.golden.default_enabled", 1, true)).to.be.ok()
            end)

            it("should validate config-driven enchant roll profiles", function()
                local validConfig = {
                    version = "1.0.0",
                    enabled = true,
                    hatch_rolls = {
                        enabled = true,
                        require_unlocked_slot = true,
                    },
                    reroll = {
                        enabled = true,
                        default_slot = 1,
                        cost = {
                            currency = "gems",
                            amount = 5,
                        },
                    },
                    rarity_profiles = {
                        huge = "huge",
                    },
                    effects = {
                        crystal_finder = {
                            display_name = "Crystal Finder",
                            modifier = {
                                stage = "enchants",
                                kind = "breakable_reward",
                                currency = "crystals",
                                combine = "multiply",
                                amount_per_strength = 0.01,
                            },
                        },
                    },
                    roll_profiles = {
                        huge = {
                            min_rolls = 1,
                            max_rolls = 3,
                            initial_roll_chance = 1,
                            prevent_duplicate_effects = true,
                            chances = {
                                {
                                    effect = "crystal_finder",
                                    weight = 10,
                                    strength = { low = 1, high = 5, scale = 2 },
                                },
                            },
                        },
                    },
                }

                local isValid, error = configLoader:ValidateConfig("enchants", validConfig)
                expect(isValid).to.equal(true)
                expect(error).to.equal(nil)
            end)

            it("should reject enchant chance entries with unknown effects", function()
                local invalidConfig = {
                    version = "1.0.0",
                    hatch_rolls = {
                        enabled = true,
                    },
                    reroll = {
                        enabled = true,
                        default_slot = 1,
                        cost = {
                            currency = "gems",
                            amount = 5,
                        },
                    },
                    rarity_profiles = {
                        huge = "huge",
                    },
                    effects = {
                        crystal_finder = {
                            display_name = "Crystal Finder",
                            modifier = {
                                stage = "enchants",
                                kind = "breakable_reward",
                                currency = "crystals",
                                combine = "multiply",
                                amount_per_strength = 0.01,
                            },
                        },
                    },
                    roll_profiles = {
                        huge = {
                            min_rolls = 1,
                            max_rolls = 1,
                            initial_roll_chance = 1,
                            chances = {
                                {
                                    effect = "typo_finder",
                                    weight = 10,
                                    strength = { low = 1, high = 5, scale = 2 },
                                },
                            },
                        },
                    },
                }

                local isValid, error = configLoader:ValidateConfig("enchants", invalidConfig)
                expect(isValid).to.equal(false)
                expect(string.find(error, "must reference effects", 1, true)).to.be.ok()
            end)

            it("should validate marker tag schemas", function()
                local validConfig = {
                    tags = {
                        SpawnZone = {
                            required_attributes = {
                                AreaId = "string",
                                SpawnerId = "string",
                            },
                            optional_attributes = {
                                DepthOffset = "number",
                                Disabled = "boolean",
                            },
                            config = "breakables.worlds",
                            id_attribute = "SpawnerId",
                        },
                    },
                    synthetic = {},
                }

                local isValid, error = configLoader:ValidateConfig("markers", validConfig)
                expect(isValid).to.equal(true)
                expect(error).to.equal(nil)
            end)

            it("should reject marker schemas with unsupported attribute types", function()
                local invalidConfig = {
                    tags = {
                        SpawnZone = {
                            required_attributes = {
                                AreaId = "Instance",
                            },
                        },
                    },
                }

                local isValid, error = configLoader:ValidateConfig("markers", invalidConfig)
                expect(isValid).to.equal(false)
                expect(string.find(error, "unsupported expected type", 1, true)).to.be.ok()
            end)

            it("should validate pet index milestones", function()
                local validConfig = {
                    version = "1.0.0",
                    milestones = {
                        {
                            id = "first_pet",
                            goal = 1,
                            reward = {
                                type = "currency",
                                currency = "gems",
                                amount = 5,
                            },
                        },
                    },
                }

                local isValid, error = configLoader:ValidateConfig("pet_index", validConfig)
                expect(isValid).to.equal(true)
                expect(error).to.equal(nil)
            end)

            it("should reject achievements with unknown stat counters", function()
                local invalidConfig = {
                    version = "1.0.0",
                    achievements = {
                        missing = {
                            id = "missing",
                            stat = "not_a_counter",
                            tiers = {
                                {
                                    id = "tier_1",
                                    goal = 1,
                                    reward = {
                                        type = "currency",
                                        currency = "gems",
                                        amount = 1,
                                    },
                                },
                            },
                        },
                    },
                }

                local isValid, error = configLoader:ValidateConfig("achievements", invalidConfig)
                expect(isValid).to.equal(false)
                expect(string.find(error, "configs/stats.lua", 1, true)).to.be.ok()
            end)

            it("should validate leaderboards backed by stat counters", function()
                local validConfig = {
                    version = "1.0.0",
                    boards = {
                        {
                            id = "eggs_hatched",
                            stat = "eggs_hatched",
                            sort = "desc",
                            max_entries = 10,
                            global = {
                                enabled = false,
                            },
                        },
                    },
                }

                local isValid, error = configLoader:ValidateConfig("leaderboards", validConfig)
                expect(isValid).to.equal(true)
                expect(error).to.equal(nil)
            end)
        end)

        describe("Monetization Setup Validation", function()
            it("should detect placeholder IDs", function()
                -- Mock monetization config with placeholders
                configLoader._monetizationCache = {
                    product_id_mapping = {
                        small_gems = 1234567890, -- Placeholder
                        vip_pass = 123456789, -- Placeholder
                    },
                    products = {},
                    passes = {},
                    premium_benefits = {},
                    validation_rules = {
                        test_mode = { enabled = true },
                    },
                }

                local status = configLoader:ValidateMonetizationSetup()

                expect(status.isValid).to.equal(true)
                expect(status.hasPlaceholders).to.equal(true)
                expect(#status.warnings).to.equal(3) -- 2 placeholders + test mode
                expect(string.find(status.warnings[1], "placeholder ID", 1, true)).to.be.ok()
                expect(string.find(status.warnings[2], "placeholder ID", 1, true)).to.be.ok()
                expect(string.find(status.warnings[3], "Test mode is enabled", 1, true)).to.be.ok()
            end)

            it("should detect invalid Roblox IDs", function()
                configLoader._monetizationCache = {
                    product_id_mapping = {
                        invalid_product = -1, -- Invalid ID
                    },
                    products = {},
                    passes = {},
                    premium_benefits = {},
                    validation_rules = {
                        test_mode = { enabled = false },
                    },
                }

                local status = configLoader:ValidateMonetizationSetup()

                expect(status.isValid).to.equal(false)
                expect(#status.errors).to.equal(1)
                expect(string.find(status.errors[1], "Invalid Roblox ID", 1, true)).to.be.ok()
            end)

            it("should get monetization status", function()
                configLoader._monetizationCache = {
                    product_id_mapping = {},
                    products = { {}, {} }, -- 2 products
                    passes = { {}, {}, {} }, -- 3 passes
                    premium_benefits = { enabled = true },
                    first_purchase_bonus = { enabled = false },
                    validation_rules = {
                        test_mode = { enabled = true },
                    },
                }

                local status = configLoader:GetMonetizationStatus()

                expect(status.productCount).to.equal(2)
                expect(status.passCount).to.equal(3)
                expect(status.hasPremiumBenefits).to.equal(true)
                expect(status.hasFirstPurchaseBonus).to.equal(false)
                expect(status.testModeEnabled).to.equal(true)
            end)
        end)

        describe("Cache Management", function()
            it("should cache monetization config", function()
                -- Mock the LoadConfig to track calls
                local loadCalls = 0
                -- duplicate patch block removed
                ConfigLoader.LoadConfig = function(self, configName)
                    if configName == "monetization" then
                        loadCalls = loadCalls + 1
                        return {
                            product_id_mapping = {},
                            products = {},
                            passes = {},
                            premium_benefits = {},
                        }
                    end
                    return originalLoadConfig(self, configName)
                end

                -- First call should load
                configLoader:GetProduct("test")
                expect(loadCalls).to.equal(1)

                -- Second call should use cache
                configLoader:GetGamePass("test")
                expect(loadCalls).to.equal(1)

                -- Clear cache and try again
                configLoader:ClearMonetizationCache()
                configLoader:GetProduct("test")
                expect(loadCalls).to.equal(2)
            end)
        end)
    end)
end
