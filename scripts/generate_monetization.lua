#!/usr/bin/env lua

--[[
    Monetization Code Generator
    
    This script parses the monetization.lua configuration and generates:
    1. Network packet definitions
    2. Purchase handler functions
    3. UI product listings code
    4. Analytics events
    5. Documentation
    
    Usage:
    lua scripts/generate_monetization.lua
]]

local function loadMonetizationConfig()
    -- Try to load the config file
    local configPath = "configs/monetization.lua"
    local file = io.open(configPath, "r")
    if not file then
        error(
            "Could not open " .. configPath .. ". Make sure you're running from the project root."
        )
    end

    local content = file:read("*all")
    file:close()

    -- Parse the Lua config (simple eval - would need proper parsing in production)
    local config = load("return " .. content:match("return%s+(.+)"))()
    return config
end

local function generateNetworkPackets(config)
    local code = [[
-- Auto-generated network packet definitions
-- Generated from configs/monetization.lua

local monetizationPackets = {
]]

    -- Generate packets for each product
    for _, product in ipairs(config.products) do
        code = code
            .. string.format(
                [[
    Purchase%s = {
        rateLimit = 10,
        validator = "purchaseValidator",
        requiresData = {"productId"},
        metadata = {
            productId = "%s",
            category = "%s",
            priceRobux = %d
        }
    },
]],
                product.id:gsub("^%l", string.upper):gsub("_(%l)", string.upper),
                product.id,
                product.analytics_category or "unknown",
                product.price_robux
            )
    end

    -- Generate packets for game passes
    for _, pass in ipairs(config.passes) do
        code = code
            .. string.format(
                [[
    Purchase%s = {
        rateLimit = 5,
        validator = "passValidator", 
        requiresData = {"passId"},
        metadata = {
            passId = "%s",
            priceRobux = %d
        }
    },
]],
                pass.id:gsub("^%l", string.upper):gsub("_(%l)", string.upper),
                pass.id,
                pass.price_robux
            )
    end

    code = code .. [[
}

return monetizationPackets
]]

    return code
end

local function generatePurchaseHandlers(config)
    local code = [[
-- Auto-generated purchase handler functions
-- Generated from configs/monetization.lua

local PurchaseHandlers = {}

]]

    -- Generate handlers for each product
    for _, product in ipairs(config.products) do
        local handlerName = "handle"
            .. product.id:gsub("^%l", string.upper):gsub("_(%l)", string.upper)
            .. "Purchase"

        code = code
            .. string.format(
                [[
function PurchaseHandlers.%s(player, receiptInfo)
    local rewards = %s
    
    -- Grant currency rewards
]],
                handlerName,
                "{\n"
            )

        -- Add reward granting code
        if product.rewards then
            for currency, amount in pairs(product.rewards) do
                if type(amount) == "number" then
                    code = code
                        .. string.format(
                            [[
    EconomyService:AddCurrency(player, "%s", %d, "robux_purchase")
]],
                            currency,
                            amount
                        )
                end
            end

            if product.rewards.items then
                code = code .. [[
    
    -- Grant item rewards
]]
                for _, itemId in ipairs(product.rewards.items) do
                    code = code
                        .. string.format(
                            [[
    DataService:AddToInventory(player, "%s", 1)
]],
                            itemId
                        )
                end
            end
        end

        code = code .. [[
    
    return true
end

]]
    end

    code = code .. [[

return PurchaseHandlers
]]

    return code
end

local function generateUIProductList(config)
    local code = [[
-- Auto-generated UI product listing
-- Generated from configs/monetization.lua

local ProductDisplayData = {
    products = {
]]

    -- Generate display data for products
    for _, product in ipairs(config.products) do
        code = code
            .. string.format(
                [[
        {
            id = "%s",
            name = "%s",
            description = "%s",
            priceRobux = %d,
            icon = "rbxassetid://0", -- Replace with actual icon ID
            category = "%s",
            popular = %s,
            rewards = %s,
            testModeEnabled = %s
        },
]],
                product.id,
                product.name,
                product.description or "",
                product.price_robux,
                product.category or "misc",
                product.popular and "true" or "false",
                "{\n            "
                    .. table.concat(generateRewardStrings(product.rewards), ",\n            ")
                    .. "\n        }",
                product.test_mode_enabled and "true" or "false"
            )
    end

    code = code .. [[
    },
    
    passes = {
]]

    -- Generate display data for game passes
    for _, pass in ipairs(config.passes) do
        code = code
            .. string.format(
                [[
        {
            id = "%s",
            name = "%s", 
            description = "%s",
            priceRobux = %d,
            icon = "%s",
            benefits = %s,
            testModeEnabled = %s
        },
]],
                pass.id,
                pass.name,
                pass.description or "",
                pass.price_robux,
                pass.icon or "rbxassetid://0",
                generateBenefitStrings(pass.benefits),
                pass.test_mode_enabled and "true" or "false"
            )
    end

    code = code .. [[
    }
}

return ProductDisplayData
]]

    return code
end

function generateRewardStrings(rewards)
    local strings = {}
    if not rewards then
        return strings
    end

    for key, value in pairs(rewards) do
        if type(value) == "number" then
            table.insert(strings, string.format("%s = %d", key, value))
        elseif type(value) == "table" and key == "items" then
            table.insert(strings, "items = {" .. table.concat(value, '", "') .. "}")
        end
    end
    return strings
end

function generateBenefitStrings(benefits)
    -- Simplified benefit string generation
    return "{\n            -- Benefits configuration here\n        }"
end

local function generateAnalyticsEvents(config)
    local code = [[
-- Auto-generated analytics event definitions
-- Generated from configs/monetization.lua

local AnalyticsEvents = {
]]

    -- Generate events for each product
    for _, product in ipairs(config.products) do
        code = code
            .. string.format(
                [[
    %sPurchased = {
        name = "product_purchased_%s",
        category = "%s",
        properties = {
            "product_id",
            "price_robux", 
            "currency_granted",
            "items_granted",
            "player_level",
            "is_first_purchase"
        }
    },
]],
                product.id,
                product.id,
                product.analytics_category or "product"
            )
    end

    -- Generate events for game passes
    for _, pass in ipairs(config.passes) do
        code = code
            .. string.format(
                [[
    %sPurchased = {
        name = "gamepass_purchased_%s",
        category = "gamepass",
        properties = {
            "pass_id",
            "price_robux",
            "benefits_granted", 
            "player_level"
        }
    },
]],
                pass.id,
                pass.id
            )
    end

    code = code .. [[
}

return AnalyticsEvents
]]

    return code
end

local function generateDocumentation(config)
    local doc = string.format(
        [[
# Monetization Configuration Documentation
*Auto-generated from configs/monetization.lua*

## Products (%d total)

]],
        #config.products
    )

    -- Document products
    for _, product in ipairs(config.products) do
        doc = doc
            .. string.format(
                [[
### %s
- **ID**: `%s`
- **Price**: %d Robux
- **Category**: %s
- **Rewards**: 
]],
                product.name,
                product.id,
                product.price_robux,
                product.category or "misc"
            )

        if product.rewards then
            for key, value in pairs(product.rewards) do
                if type(value) == "number" then
                    doc = doc .. string.format("  - %s: %d\n", key, value)
                elseif type(value) == "table" and key == "items" then
                    doc = doc .. string.format("  - Items: %s\n", table.concat(value, ", "))
                end
            end
        end
        doc = doc .. "\n"
    end

    doc = doc .. string.format(
        [[

## Game Passes (%d total)

]],
        #config.passes
    )

    -- Document game passes
    for _, pass in ipairs(config.passes) do
        doc = doc
            .. string.format(
                [[
### %s
- **ID**: `%s`
- **Price**: %d Robux
- **Benefits**: Multipliers, effects, and features

]],
                pass.name,
                pass.id,
                pass.price_robux
            )
    end

    doc = doc
        .. [[

## Setup Instructions

1. Create products in Roblox Creator Dashboard
2. Update `product_id_mapping` in monetization.lua with actual IDs
3. Test purchases in Studio (test mode enabled)
4. Deploy and monitor analytics

## Generated Files

- `generated_network_packets.lua` - Network packet definitions
- `generated_purchase_handlers.lua` - Purchase processing functions  
- `generated_ui_products.lua` - UI display data
- `generated_analytics.lua` - Analytics event definitions
]]

    return doc
end

local function writeFile(filename, content)
    local file = io.open(filename, "w")
    if not file then
        error("Could not write to " .. filename)
    end
    file:write(content)
    file:close()
    print("Generated: " .. filename)
end

-- Main execution
local function main()
    print("🔧 Monetization Code Generator")
    print("Loading configuration...")

    local config = loadMonetizationConfig()

    print(string.format("Found %d products and %d game passes", #config.products, #config.passes))

    -- Generate all code files
    print("\nGenerating code files...")

    writeFile("generated/generated_network_packets.lua", generateNetworkPackets(config))
    writeFile("generated/generated_purchase_handlers.lua", generatePurchaseHandlers(config))
    writeFile("generated/generated_ui_products.lua", generateUIProductList(config))
    writeFile("generated/generated_analytics.lua", generateAnalyticsEvents(config))
    writeFile("generated/MONETIZATION_DOCS.md", generateDocumentation(config))

    print("\n✅ Code generation complete!")
    print("📁 Check the 'generated/' folder for output files")
    print("\n🚀 Next steps:")
    print("1. Review generated code")
    print("2. Update product_id_mapping with real Roblox IDs")
    print("3. Test in Studio")
    print("4. Deploy to production")
end

-- Create generated directory if it doesn't exist
os.execute("mkdir -p generated")

-- Run the generator
main()
