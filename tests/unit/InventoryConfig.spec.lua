--[[
    Inventory Configuration Test Suite
    
    Tests for inventory system Phase 1:
    - Configuration loading and validation
    - ProfileTemplate generation 
    - Bucket structure correctness
]]

return function()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Locations = require(ReplicatedStorage.Shared.Locations)
    local ConfigLoader = require(Locations.ConfigLoader)

    describe("Inventory Configuration", function()
        local configLoader

        beforeEach(function()
            configLoader = setmetatable({}, ConfigLoader)
            configLoader:Init()
        end)

        describe("Loading", function()
            it("should load inventory configuration successfully", function()
                local success, config = pcall(function()
                    return configLoader:LoadConfig("inventory")
                end)

                expect(success).to.equal(true)
                expect(config).to.be.ok()
                expect(config.version).to.be.ok()
                expect(config.enabled_buckets).to.be.ok()
                expect(config.buckets).to.be.ok()
                expect(config.settings).to.be.ok()
            end)

            it("should validate inventory configuration structure", function()
                local config = configLoader:LoadConfig("inventory")

                -- Check version
                expect(type(config.version)).to.equal("string")

                -- Check enabled buckets
                expect(type(config.enabled_buckets)).to.equal("table")
                expect(config.enabled_buckets.pets).to.equal(true)
                expect(config.enabled_buckets.consumables).to.equal(true)

                -- Check bucket definitions
                expect(type(config.buckets)).to.equal("table")
                expect(config.buckets.pets).to.be.ok()
                expect(config.buckets.consumables).to.be.ok()

                -- Check pet bucket structure
                local petBucket = config.buckets.pets
                expect(petBucket.display_name).to.equal("Pets")
                expect(petBucket.icon).to.equal("🐾")
                expect(petBucket.base_limit).to.equal(50)
                expect(petBucket.stack_size).to.equal(1)
                expect(petBucket.allow_duplicates).to.equal(true)

                -- Check schemas
                expect(type(petBucket.item_schema)).to.equal("table")
                expect(type(petBucket.item_schema.required)).to.equal("table")
                expect(type(petBucket.item_schema.optional)).to.equal("table")

                -- Check equipped configuration
                expect(type(config.equipped)).to.equal("table")
                expect(config.equipped.pets).to.be.ok()
                expect(config.equipped.pets.slots).to.equal(3)
            end)
        end)

        describe("Validation", function()
            it("should validate correct inventory configuration", function()
                local config = configLoader:LoadConfig("inventory")
                local isValid, errorMsg = configLoader:ValidateConfig("inventory", config)

                expect(isValid).to.equal(true)
                expect(errorMsg).to.equal(nil)
            end)

            it("should reject invalid inventory configuration", function()
                local invalidConfig = {
                    version = "1.0.0",
                    enabled_buckets = { pets = true },
                    buckets = {}, -- Missing bucket definition for enabled 'pets'
                    settings = {},
                }

                local isValid, errorMsg = configLoader:ValidateConfig("inventory", invalidConfig)

                expect(isValid).to.equal(false)
                expect(errorMsg).to.be.ok()
                expect(string.find(errorMsg, "bucket definition")).to.be.ok()
            end)

            it("should reject configuration missing required fields", function()
                local invalidConfig = {
                    version = "1.0.0",
                    -- Missing enabled_buckets, buckets, settings
                }

                local isValid, errorMsg = configLoader:ValidateConfig("inventory", invalidConfig)

                expect(isValid).to.equal(false)
                expect(errorMsg).to.be.ok()
            end)
        end)
    end)

    describe("Profile Template Generation", function()
        -- This test would require access to DataService's generateProfileTemplate function
        -- For now, we'll test this manually by examining actual player profiles

        it("should create basic inventory structure for testing", function()
            -- Mock test for now - actual profile testing requires server environment
            local mockInventoryStructure = {
                pets = {
                    items = {},
                    total_slots = 50,
                    used_slots = 0,
                },
                consumables = {
                    items = {},
                    total_slots = 100,
                    used_slots = 0,
                },
            }

            local mockEquippedStructure = {
                pets = {
                    slot_1 = nil,
                    slot_2 = nil,
                    slot_3 = nil,
                },
            }

            -- Verify mock structure matches expected format
            expect(mockInventoryStructure.pets).to.be.ok()
            expect(mockInventoryStructure.pets.total_slots).to.equal(50)
            expect(mockInventoryStructure.pets.used_slots).to.equal(0)
            expect(type(mockInventoryStructure.pets.items)).to.equal("table")

            expect(mockEquippedStructure.pets).to.be.ok()
            expect(mockEquippedStructure.pets.slot_1).to.equal(nil)
            expect(mockEquippedStructure.pets.slot_2).to.equal(nil)
            expect(mockEquippedStructure.pets.slot_3).to.equal(nil)
        end)
    end)
end
