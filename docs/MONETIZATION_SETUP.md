# Monetization Setup Guide

## Overview

This guide covers the complete setup process for monetization in the game template, including:
1. Creating products in Roblox
2. Configuring the monetization system
3. Testing purchases
4. Code generation and integration

## 🎯 Implementation Plan

### Phase 1: Roblox Product Creation (User Tasks)

#### Developer Products (Consumable Purchases)
Users must create these products in the Roblox Creator Dashboard:

1. **Small Gem Pack**
   - Name: "100 Gems"
   - Price: 99 Robux
   - Description: "Get 100 Gems instantly!"
   - Icon: Upload a gem icon

2. **Medium Gem Pack**
   - Name: "500 Gems (+50 Bonus)"
   - Price: 399 Robux
   - Description: "Best value! Get 550 Gems total!"
   - Icon: Upload a gem icon with "BEST VALUE" badge

3. **Starter Bundle**
   - Name: "Starter Pack"
   - Price: 199 Robux
   - Description: "Perfect for new players! Gems, Coins, and exclusive items!"
   - Icon: Upload a gift box icon

#### Game Passes (Permanent Benefits)
Users must create these game passes:

1. **VIP Pass**
   - Name: "VIP Membership"
   - Price: 499 Robux
   - Description: "Daily rewards, 2x XP, exclusive areas!"
   - Icon: Upload a crown icon

2. **Auto Collect Pass**
   - Name: "Auto Collector"
   - Price: 299 Robux
   - Description: "Automatically collect resources near you!"
   - Icon: Upload a robot icon

3. **Speed Boost Pass**
   - Name: "Speed Boost"
   - Price: 199 Robux
   - Description: "Move 50% faster forever!"
   - Icon: Upload a lightning bolt icon

### Phase 2: Configuration Setup (Code Tasks)

#### Step 1: Update monetization.lua
```lua
-- configs/monetization.lua
return {
    -- Map config IDs to actual Roblox product IDs
    product_id_mapping = {
        -- Developer Products
        small_gems = 1234567890,  -- Replace with actual ID from Roblox
        medium_gems = 1234567891, -- Replace with actual ID from Roblox
        starter_pack = 1234567892, -- Replace with actual ID from Roblox
        
        -- Game Passes
        vip_pass = 123456789,     -- Replace with actual ID from Roblox
        auto_collect = 123456790, -- Replace with actual ID from Roblox
        speed_boost = 123456791   -- Replace with actual ID from Roblox
    },
    
    -- Developer Products Configuration
    products = {
        {
            id = "small_gems",
            name = "💎 100 Gems",
            description = "Get 100 Gems instantly!",
            price_robux = 99,
            rewards = {
                gems = 100
            },
            analytics_category = "currency_small"
        },
        {
            id = "medium_gems",
            name = "💎 500 Gems (+50 Bonus)",
            description = "Best value! Get 550 Gems total!",
            price_robux = 399,
            rewards = {
                gems = 550
            },
            badge = "best_value",
            analytics_category = "currency_medium"
        },
        {
            id = "starter_pack",
            name = "🎁 Starter Pack",
            description = "Perfect for new players!",
            price_robux = 199,
            rewards = {
                gems = 150,
                coins = 25000,
                items = {"wooden_sword", "health_potion"}
            },
            one_time_only = true,
            level_requirement = {max = 10},
            analytics_category = "bundle"
        }
    },
    
    -- Game Pass Configuration
    passes = {
        {
            id = "vip_pass",
            name = "👑 VIP Membership",
            description = "Daily rewards, 2x XP, exclusive areas!",
            price_robux = 499,
            benefits = {
                daily_rewards = {
                    gems = 50,
                    coins = 10000
                },
                multipliers = {
                    xp = 2.0,
                    coins = 1.5
                },
                effects = {
                    id = "vip_effect",
                    permanent = true,
                    stats = {
                        speedMultiplier = 0.25,
                        luckBoost = 0.1
                    }
                },
                perks = {
                    exclusive_chat_tag = "[VIP]",
                    exclusive_area_access = true,
                    extra_inventory_slots = 50
                }
            }
        },
        {
            id = "auto_collect",
            name = "🤖 Auto Collector",
            description = "Automatically collect resources!",
            price_robux = 299,
            benefits = {
                features = {
                    auto_collect_enabled = true,
                    auto_collect_range = 20,
                    auto_collect_rate = 1.0
                }
            }
        },
        {
            id = "speed_boost",
            name = "⚡ Speed Boost",
            description = "Move 50% faster forever!",
            price_robux = 199,
            benefits = {
                effects = {
                    id = "speed_pass",
                    permanent = true,
                    stats = {
                        speedMultiplier = 0.5
                    }
                }
            }
        }
    },
    
    -- Premium Benefits
    premium_benefits = {
        daily_rewards = {
            gems = 25,
            coins = 5000
        },
        multipliers = {
            xp = 1.5,
            coins = 1.25
        },
        perks = {
            exclusive_chat_tag = "[Premium]",
            extra_inventory_slots = 25,
            premium_discount = 0.1 -- 10% off purchases
        }
    }
}
```

### Phase 3: Code Implementation

#### 1. MonetizationService (New Service)
Create `src/Server/Services/MonetizationService.lua`:
- Handle ProcessReceipt for developer products
- Check game pass ownership on player join
- Apply game pass benefits
- Track purchase analytics
- Handle purchase failures and retries

#### 2. ProductIdMapper Utility
Create `src/Shared/Utils/ProductIdMapper.lua`:
- Map config IDs to Roblox product IDs
- Validate product configurations
- Handle missing ID mappings gracefully
- Support both products and game passes

#### 3. Enhanced EconomyService
Update to integrate with MonetizationService:
- Delegate Robux purchases to MonetizationService
- Apply rewards from successful purchases
- Handle first-time purchase bonuses
- Log all transactions

#### 4. Code Generation Script
Create `scripts/generate_monetization.lua`:
- Parse monetization.lua config
- Generate network packet definitions
- Create purchase handler functions
- Generate UI product listings
- Create analytics events

### Phase 4: Testing Suite

#### Test Cases to Implement:

1. **Developer Product Tests**
   - Successful purchase flow
   - Purchase with insufficient Robux
   - Network failure during purchase
   - Double purchase prevention
   - Reward granting verification
   - One-time purchase enforcement
   - Level requirement validation

2. **Game Pass Tests**
   - Ownership check on join
   - Benefits application
   - Multiple pass stacking
   - Pass purchase flow
   - Premium player detection

3. **Edge Cases**
   - Player leaving during purchase
   - Server shutdown during transaction
   - Malformed purchase data
   - Missing product configuration
   - Invalid product IDs
   - Concurrent purchase attempts

### Phase 5: Integration Points

#### Auto-Generated Code Locations:

1. **NetworkBridge Integration**
   ```lua
   -- Auto-generated in src/Server/Services/MonetizationService.lua
   local purchaseBridge = NetworkBridge:CreateBridge("Monetization")
   purchaseBridge:DefinePacket("InitiatePurchase", {
       rateLimit = 10,
       validator = validatePurchaseRequest
   })
   ```

2. **UI Product Display**
   ```lua
   -- Auto-generated in src/Client/UI/Screens/ShopScreen.lua
   local products = MonetizationConfig:GetProducts()
   for _, product in ipairs(products) do
       createProductButton(product)
   end
   ```

3. **Analytics Events**
   ```lua
   -- Auto-generated analytics tracking
   AnalyticsService:TrackEvent("purchase_initiated", {
       product_id = productId,
       category = product.analytics_category,
       price = product.price_robux
   })
   ```

## 📋 User Setup Checklist

### Before Starting:
- [ ] Have access to Roblox Creator Dashboard
- [ ] Have a published game or group game
- [ ] Understand basic Roblox monetization rules

### Product Creation:
- [ ] Create 3 developer products in Roblox
- [ ] Create 3 game passes in Roblox
- [ ] Upload icons for each product/pass
- [ ] Note down all product/pass IDs

### Configuration:
- [ ] Update monetization.lua with actual IDs
- [ ] Set appropriate prices and rewards
- [ ] Configure one-time purchases
- [ ] Set level requirements where needed

### Testing:
- [ ] Test each product in Studio
- [ ] Verify rewards are granted
- [ ] Check game pass benefits apply
- [ ] Test with test accounts

## 🚀 Implementation Order

1. **Week 1: Core Implementation**
   - Create MonetizationService
   - Implement ProcessReceipt
   - Add game pass checking
   - Create ProductIdMapper

2. **Week 2: Integration & Testing**
   - Integrate with EconomyService
   - Create test suite
   - Add purchase UI
   - Implement analytics

3. **Week 3: Polish & Edge Cases**
   - Handle all edge cases
   - Add retry logic
   - Create admin tools
   - Performance optimization

## 🔧 Code Generation Examples

### Example: Auto-Generated Purchase Handler
```lua
-- This would be auto-generated from config
function MonetizationService:_handleSmallGemsPurchase(player, receipt)
    local config = self._config.products["small_gems"]
    
    -- Grant rewards
    self._economyService:AddCurrency(player, "gems", config.rewards.gems, "robux_purchase")
    
    -- Track analytics
    self:_trackPurchase(player, "small_gems", config.price_robux)
    
    -- First purchase bonus
    if self:_isFirstPurchase(player) then
        self:_grantFirstPurchaseBonus(player)
    end
    
    return Enum.ProductPurchaseDecision.PurchaseGranted
end
```

### Example: Auto-Generated Game Pass Benefits
```lua
-- This would be auto-generated from config
function MonetizationService:_applyVipPassBenefits(player)
    local config = self._config.passes["vip_pass"]
    
    -- Apply multipliers
    self._dataService:SetMultiplier(player, "xp", config.benefits.multipliers.xp)
    self._dataService:SetMultiplier(player, "coins", config.benefits.multipliers.coins)
    
    -- Apply effects
    self._playerEffectsService:ApplyPermanentEffect(player, config.benefits.effects.id, config.benefits.effects.stats)
    
    -- Grant perks
    self:_grantVipPerks(player, config.benefits.perks)
end
```

## 📊 Success Metrics

- All products purchasable without errors
- 100% test coverage for purchase flows
- < 0.1% transaction failure rate
- Proper analytics tracking
- No duplicate purchases
- Correct benefit application

This comprehensive plan ensures a robust, testable, and maintainable monetization system that follows the configuration-as-code principle. 