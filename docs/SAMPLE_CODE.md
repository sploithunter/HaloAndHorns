# Sample Code Examples

## 🏗️ Service Implementation

### Basic Service Structure
```lua
-- src/Server/Services/MyService.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MyService = {}
MyService.__index = MyService

function MyService:Init()
    -- Get injected dependencies
    self._logger = self._modules.Logger
    self._configLoader = self._modules.ConfigLoader
    self._dataService = self._modules.DataService
    
    -- Validate critical dependencies
    if not self._configLoader then
        error("MyService: ConfigLoader dependency missing")
    end
    
    -- Load configuration
    self._config = self._configLoader:LoadConfig("myservice")
    
    -- Set up player connections (but don't start operations)
    Players.PlayerAdded:Connect(function(player)
        self:_onPlayerAdded(player)
    end)
    
    self._logger:Info("MyService initialized")
end

function MyService:Start()
    -- Begin operations after all services initialized
    self:_startMainLoop()
    self._logger:Info("MyService started")
end

function MyService:_onPlayerAdded(player)
    self._logger:Debug("Player added to service", {player = player.Name})
end

function MyService:_startMainLoop()
    -- Main service operations
end

return MyService
```

### Economy Service Example
```lua
-- src/Server/Services/EconomyService.lua
local EconomyService = {}
EconomyService.__index = EconomyService

function EconomyService:Init()
    self._logger = self._modules.Logger
    self._configLoader = self._modules.ConfigLoader
    self._dataService = self._modules.DataService
    self._networkBridge = self._modules.NetworkBridge
    
    -- Load configurations
    self._itemsConfig = self._configLoader:LoadConfig("items")
    self._currenciesConfig = self._configLoader:LoadConfig("currencies")
end

function EconomyService:PurchaseItem(player, itemId)
    -- Get item configuration
    local item = self._configLoader:GetItem(itemId)
    if not item then
        self._logger:Warn("Unknown item purchase attempt", {
            player = player.Name,
            itemId = itemId
        })
        return false, "Item not found"
    end
    
    -- Check player currency
    local currentCurrency = self:GetCurrency(player, item.price.currency)
    if currentCurrency < item.price.amount then
        self._logger:Info("Purchase failed - insufficient funds", {
            player = player.Name,
            itemId = itemId,
            required = item.price.amount,
            current = currentCurrency
        })
        return false, "Insufficient funds"
    end
    
    -- Perform atomic transaction
    local success = self:_performTransaction(player, item)
    if success then
        self._logger:Info("Purchase completed", {
            player = player.Name,
            itemId = itemId,
            price = item.price.amount,
            currency = item.price.currency
        })
    end
    
    return success, success and "Purchase successful" or "Transaction failed"
end

function EconomyService:GetCurrency(player, currencyType)
    local data = self._dataService:GetData(player)
    if not data or not data.Currencies then
        return 0
    end
    return data.Currencies[currencyType] or 0
end

function EconomyService:_performTransaction(player, item)
    local data = self._dataService:GetData(player)
    if not data then return false end
    
    -- Deduct currency
    local currentAmount = data.Currencies[item.price.currency] or 0
    if currentAmount < item.price.amount then
        return false
    end
    
    data.Currencies[item.price.currency] = currentAmount - item.price.amount
    
    -- Add item to inventory
    if not data.Inventory then
        data.Inventory = {}
    end
    
    local existingItem = data.Inventory[item.id]
    if existingItem and item.stackable then
        existingItem.quantity = (existingItem.quantity or 1) + 1
    else
        data.Inventory[item.id] = {
            id = item.id,
            quantity = 1,
            acquiredAt = os.time()
        }
    end
    
    -- Apply effects if item has them
    if item.effects then
        for _, effectId in ipairs(item.effects) do
            self._modules.PlayerEffectsService:ApplyEffect(player, effectId, 300)
        end
    end
    
    return true
end

return EconomyService
```

---

## 🎮 Configuration Examples

### Items Configuration
```lua
-- configs/items.lua
return {
    {
        id = "speed_potion",
        name = "⚡ Speed Potion",
        type = "consumable",
        rarity = "common",
        description = "Increases movement speed by 50% for 5 minutes",
        price = {
            currency = "gems",
            amount = 5
        },
        effects = {"speed_boost"},
        stackable = true,
        max_stack = 10,
        level_requirement = 1
    },
    {
        id = "wooden_sword",
        name = "🗡️ Wooden Sword",
        type = "weapon",
        rarity = "common",
        stats = {
            damage = 10,
            speed = 1.5,
            range = 5
        },
        price = {
            currency = "coins",
            amount = 100
        },
        level_requirement = 1
    },
    {
        id = "lucky_charm",
        name = "🍀 Lucky Charm",
        type = "accessory",
        rarity = "rare",
        description = "Permanently increases luck by 25%",
        price = {
            currency = "gems",
            amount = 50
        },
        effects = {"luck_boost"},
        permanent = true
    }
}
```

### Effect Configuration
```lua
-- configs/ratelimits.lua (excerpt)
return {
    effectModifiers = {
        speed_boost = {
            actions = {"CollectResource", "DealDamage"},
            multiplier = 1.5,  -- 50% faster actions
            duration = 300,    -- 5 minutes
            maxUses = 20,      -- OR 20 uses, whichever first
            consumeOnUse = true,
            description = "Increases action speed by 50%",
            displayName = "⚡ Speed Boost",
            icon = "⚡",
            stacking = "extend_duration",
            statModifiers = {
                speedMultiplier = 0.5,  -- +50% speed
                luckBoost = 0.1         -- +10% luck bonus
            }
        },
        
        luck_boost = {
            actions = {"CollectResource"},
            multiplier = 1.25,  -- 25% better luck
            duration = -1,      -- Permanent
            description = "Increases resource collection luck",
            displayName = "🍀 Lucky",
            icon = "🍀",
            stacking = "stack",  -- Multiple can stack
            statModifiers = {
                luckBoost = 0.25
            }
        }
    }
}
```

### Network Configuration
```lua
-- configs/network.lua
return {
    bridges = {
        Economy = {
            PurchaseItem = {
                rateLimit = 30,  -- 30 purchases per minute
                validator = "itemPurchaseValidator",
                requiresData = {"itemId"}
            },
            SellItem = {
                rateLimit = 60,  -- 60 sells per minute
                validator = "itemSellValidator",
                requiresData = {"itemId", "quantity"}
            },
            GetShopItems = {
                rateLimit = 10,  -- 10 shop refreshes per minute
                validator = "basicValidator"
            }
        },
        
        PlayerEffects = {
            GetActiveEffects = {
                rateLimit = 30,
                validator = "basicValidator"
            },
            ClearAllEffects = {
                rateLimit = 5,  -- 5 clear requests per minute
                validator = "basicValidator",
                adminOnly = true
            }
        }
    },
    
    validators = {
        itemPurchaseValidator = function(data)
            return type(data.itemId) == "string" and
                   data.itemId:match("^[a-z_]+$") and
                   #data.itemId <= 50
        end,
        
        itemSellValidator = function(data)
            return type(data.itemId) == "string" and
                   type(data.quantity) == "number" and
                   data.quantity > 0 and
                   data.quantity <= 100
        end,
        
        basicValidator = function(data)
            return true  -- Always valid for simple requests
        end
    }
}
```

---

## 🎨 UI Component Examples

### Basic Button Component
```lua
-- src/Client/UI/Components/Button.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Maid = require(ReplicatedStorage.Shared.Libraries.Maid)

local Button = {}
Button.__index = Button

function Button.new(frame, config)
    local self = setmetatable({}, Button)
    
    self._maid = Maid.new()
    self._frame = frame
    self._config = config or {}
    
    -- Default styling
    self._frame.BackgroundColor3 = self._config.backgroundColor or Color3.fromRGB(67, 154, 234)
    self._frame.BorderSizePixel = 0
    self._frame.Font = Enum.Font.SourceSansBold
    self._frame.TextColor3 = Color3.fromRGB(255, 255, 255)
    self._frame.TextSize = self._config.textSize or 18
    
    -- Add corner radius
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = self._frame
    
    -- Set up interactions
    self:_setupInteractions()
    
    return self
end

function Button:_setupInteractions()
    -- Hover effects
    self._maid:GiveTask(self._frame.MouseEnter:Connect(function()
        self:_animateHover(true)
    end))
    
    self._maid:GiveTask(self._frame.MouseLeave:Connect(function()
        self:_animateHover(false)
    end))
    
    -- Click handler
    if self._config.onClick then
        self._maid:GiveTask(self._frame.Activated:Connect(function()
            self:_animateClick()
            self._config.onClick()
        end))
    end
end

function Button:_animateHover(hovering)
    local targetColor = hovering and 
        Color3.fromRGB(87, 174, 254) or 
        (self._config.backgroundColor or Color3.fromRGB(67, 154, 234))
    
    local tween = TweenService:Create(
        self._frame,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad),
        {BackgroundColor3 = targetColor}
    )
    tween:Play()
end

function Button:_animateClick()
    local originalSize = self._frame.Size
    
    local shrinkTween = TweenService:Create(
        self._frame,
        TweenInfo.new(0.1, Enum.EasingStyle.Quad),
        {Size = UDim2.new(originalSize.X.Scale * 0.95, 0, originalSize.Y.Scale * 0.95, 0)}
    )
    
    shrinkTween:Play()
    shrinkTween.Completed:Connect(function()
        local expandTween = TweenService:Create(
            self._frame,
            TweenInfo.new(0.1, Enum.EasingStyle.Quad),
            {Size = originalSize}
        )
        expandTween:Play()
    end)
end

function Button:SetText(text)
    self._frame.Text = text
end

function Button:SetEnabled(enabled)
    self._frame.Interactable = enabled
    self._frame.BackgroundTransparency = enabled and 0 or 0.5
end

function Button:Destroy()
    self._maid:DoCleaning()
end

return Button
```

### Currency Display Component
```lua
-- src/Client/UI/Components/CurrencyDisplay.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Maid = require(ReplicatedStorage.Shared.Libraries.Maid)

local CurrencyDisplay = {}
CurrencyDisplay.__index = CurrencyDisplay

function CurrencyDisplay.new(frame, currencyType)
    local self = setmetatable({}, CurrencyDisplay)
    
    self._maid = Maid.new()
    self._frame = frame
    self._currencyType = currencyType
    self._lastAmount = 0
    
    -- Find UI elements
    self._iconLabel = frame:FindFirstChild("Icon")
    self._amountLabel = frame:FindFirstChild("Amount")
    
    -- Set up currency monitoring
    self:_setupCurrencyMonitoring()
    
    return self
end

function CurrencyDisplay:_setupCurrencyMonitoring()
    local player = Players.LocalPlayer
    
    -- Monitor player's currency data via ProfileStore replication
    local function updateDisplay()
        -- This would connect to your data replication system
        -- For now, using a simple approach
        local currentAmount = self:_getCurrentAmount()
        
        if currentAmount ~= self._lastAmount then
            self:_animateUpdate(self._lastAmount, currentAmount)
            self._lastAmount = currentAmount
        end
    end
    
    -- Update every second (in real implementation, use change events)
    self._maid:GiveTask(task.spawn(function()
        while true do
            updateDisplay()
            task.wait(1)
        end
    end))
end

function CurrencyDisplay:_getCurrentAmount()
    -- In real implementation, this would read from replicated data
    local player = Players.LocalPlayer
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local currency = leaderstats:FindFirstChild(self._currencyType)
        if currency then
            return currency.Value
        end
    end
    return 0
end

function CurrencyDisplay:_animateUpdate(oldAmount, newAmount)
    if self._amountLabel then
        -- Animate number change
        local difference = newAmount - oldAmount
        
        -- Color flash based on change
        local flashColor = difference > 0 and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
        local originalColor = self._amountLabel.TextColor3
        
        -- Flash animation
        local flashTween = TweenService:Create(
            self._amountLabel,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad),
            {TextColor3 = flashColor}
        )
        
        flashTween:Play()
        flashTween.Completed:Connect(function()
            local returnTween = TweenService:Create(
                self._amountLabel,
                TweenInfo.new(0.3, Enum.EasingStyle.Quad),
                {TextColor3 = originalColor}
            )
            returnTween:Play()
        end)
        
        -- Update text
        self._amountLabel.Text = self:_formatNumber(newAmount)
    end
end

function CurrencyDisplay:_formatNumber(amount)
    if amount >= 1000000 then
        return string.format("%.1fM", amount / 1000000)
    elseif amount >= 1000 then
        return string.format("%.1fK", amount / 1000)
    else
        return tostring(amount)
    end
end

function CurrencyDisplay:Destroy()
    self._maid:DoCleaning()
end

return CurrencyDisplay
```

---

## 🎲 Matter ECS Examples

### Basic Component Definition
```lua
-- src/Shared/Matter/Components/Health.lua
local Matter = require(game.ReplicatedStorage.Shared.Libraries.Matter)

local Health = Matter.component("Health", {
    current = 100,
    max = 100,
    regeneration = 0,
    lastDamageTime = 0
})

return Health
```

### Transform Component
```lua
-- src/Shared/Matter/Components/Transform.lua
local Matter = require(game.ReplicatedStorage.Shared.Libraries.Matter)

local Transform = Matter.component("Transform", {
    cf = CFrame.new(),
    velocity = Vector3.zero,
    angularVelocity = Vector3.zero
})

return Transform
```

### Health System
```lua
-- src/Shared/Matter/Systems/HealthSystem.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Components = require(ReplicatedStorage.Shared.Matter.Components)

local function healthSystem(world, deltaTime)
    -- Health regeneration
    for id, health in world:query(Components.Health) do
        if health.regeneration > 0 and health.current < health.max then
            -- Only regenerate if not recently damaged
            local timeSinceLastDamage = tick() - health.lastDamageTime
            if timeSinceLastDamage > 5 then  -- 5 second delay
                health.current = math.min(
                    health.max,
                    health.current + health.regeneration * deltaTime
                )
            end
        end
    end
    
    -- Remove dead entities
    for id, health in world:query(Components.Health) do
        if health.current <= 0 then
            world:despawn(id)
        end
    end
end

return healthSystem
```

### Movement System
```lua
-- src/Shared/Matter/Systems/MovementSystem.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Components = require(ReplicatedStorage.Shared.Matter.Components)

local function movementSystem(world, deltaTime)
    for id, transform in world:query(Components.Transform) do
        if transform.velocity.Magnitude > 0 then
            -- Update position
            local newPosition = transform.cf.Position + transform.velocity * deltaTime
            transform.cf = CFrame.new(newPosition, newPosition + transform.cf.LookVector)
            
            -- Apply friction
            transform.velocity = transform.velocity * 0.95
        end
        
        if transform.angularVelocity.Magnitude > 0 then
            -- Update rotation
            local rotation = CFrame.Angles(
                transform.angularVelocity.X * deltaTime,
                transform.angularVelocity.Y * deltaTime,
                transform.angularVelocity.Z * deltaTime
            )
            transform.cf = transform.cf * rotation
            
            -- Apply angular friction
            transform.angularVelocity = transform.angularVelocity * 0.9
        end
    end
end

return movementSystem
```

---

## 🌐 Network Implementation

### Client Network Setup
```lua
-- src/Client/Controllers/NetworkController.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local NetworkBridge = require(ReplicatedStorage.Shared.Network.NetworkBridge)

local NetworkController = {}
NetworkController.__index = NetworkController

function NetworkController:Init()
    self._logger = self._modules.Logger
    self._bridges = {}
    
    -- Create client-side bridges
    self._bridges.Economy = NetworkBridge:CreateBridge("Economy")
    self._bridges.PlayerEffects = NetworkBridge:CreateBridge("PlayerEffects")
    
    -- Set up response handlers
    self:_setupResponseHandlers()
    
    self._logger:Info("NetworkController initialized")
end

function NetworkController:_setupResponseHandlers()
    -- Economy responses
    self._bridges.Economy:Connect(function(packetType, data)
        if packetType == "PurchaseResult" then
            self:_handlePurchaseResult(data)
        elseif packetType == "CurrencyUpdate" then
            self:_handleCurrencyUpdate(data)
        end
    end)
    
    -- Effect responses
    self._bridges.PlayerEffects:Connect(function(packetType, data)
        if packetType == "EffectUpdate" then
            self:_handleEffectUpdate(data)
        end
    end)
end

function NetworkController:PurchaseItem(itemId)
    self._bridges.Economy:Fire("PurchaseItem", {
        itemId = itemId
    })
end

function NetworkController:_handlePurchaseResult(data)
    if data.success then
        self._logger:Info("Purchase successful", data)
        -- Update UI, play sound, etc.
    else
        self._logger:Warn("Purchase failed", data)
        -- Show error message
    end
end

function NetworkController:_handleCurrencyUpdate(data)
    -- Update currency displays
    local event = ReplicatedStorage:FindFirstChild("CurrencyUpdateEvent")
    if event then
        event:Fire(data.currency, data.amount)
    end
end

return NetworkController
```

### Server Network Handler
```lua
-- src/Server/Services/NetworkService.lua
local NetworkService = {}
NetworkService.__index = NetworkService

function NetworkService:Init()
    self._logger = self._modules.Logger
    self._economyService = self._modules.EconomyService
    self._networkBridge = self._modules.NetworkBridge
    
    -- Set up packet handlers
    self:_setupPacketHandlers()
end

function NetworkService:_setupPacketHandlers()
    -- Economy bridge
    local economyBridge = self._networkBridge:CreateBridge("Economy")
    economyBridge:Connect(function(player, packetType, data)
        if packetType == "PurchaseItem" then
            self:_handlePurchaseItem(player, data)
        elseif packetType == "SellItem" then
            self:_handleSellItem(player, data)
        end
    end)
end

function NetworkService:_handlePurchaseItem(player, data)
    local success, message = self._economyService:PurchaseItem(player, data.itemId)
    
    -- Send result back to client
    local economyBridge = self._networkBridge:CreateBridge("Economy")
    economyBridge:Fire(player, "PurchaseResult", {
        success = success,
        message = message,
        itemId = data.itemId
    })
    
    -- If successful, send currency update
    if success then
        local newAmount = self._economyService:GetCurrency(player, "coins")
        economyBridge:Fire(player, "CurrencyUpdate", {
            currency = "coins",
            amount = newAmount
        })
    end
end

return NetworkService
```

---

## 🧪 Testing Examples

### Unit Test for Economy Service
```lua
-- tests/unit/EconomyService.spec.lua
return function()
    local EconomyService = require(game.ServerScriptService.Server.Services.EconomyService)
    
    describe("EconomyService", function()
        local mockLogger, mockConfigLoader, mockDataService
        local economyService
        
        beforeEach(function()
            -- Create mocks
            mockLogger = {
                Info = function() end,
                Warn = function() end,
                Debug = function() end
            }
            
            mockConfigLoader = {
                LoadConfig = function(self, name)
                    if name == "items" then
                        return {
                            {
                                id = "test_item",
                                price = {currency = "coins", amount = 50}
                            }
                        }
                    end
                    return {}
                end,
                GetItem = function(self, itemId)
                    return {
                        id = "test_item",
                        price = {currency = "coins", amount = 50}
                    }
                end
            }
            
            mockDataService = {
                GetData = function(self, player)
                    return {
                        Currencies = {coins = 100},
                        Inventory = {}
                    }
                end
            }
            
            -- Create service with mocks
            economyService = setmetatable({}, EconomyService)
            economyService._modules = {
                Logger = mockLogger,
                ConfigLoader = mockConfigLoader,
                DataService = mockDataService
            }
            economyService:Init()
        end)
        
        it("should allow purchase with sufficient funds", function()
            local mockPlayer = {Name = "TestPlayer"}
            local success, message = economyService:PurchaseItem(mockPlayer, "test_item")
            
            expect(success).to.equal(true)
            expect(message).to.equal("Purchase successful")
        end)
        
        it("should reject purchase with insufficient funds", function()
            -- Override mock to return low currency
            mockDataService.GetData = function()
                return {
                    Currencies = {coins = 10},
                    Inventory = {}
                }
            end
            
            local mockPlayer = {Name = "TestPlayer"}
            local success, message = economyService:PurchaseItem(mockPlayer, "test_item")
            
            expect(success).to.equal(false)
            expect(message).to.equal("Insufficient funds")
        end)
    end)
end
```

### Integration Test
```lua
-- tests/integration/PurchaseFlow.spec.lua
return function()
    describe("Purchase Flow Integration", function()
        local DataService, EconomyService, PlayerEffectsService
        
        beforeAll(function()
            -- Load real services
            DataService = require(game.ServerScriptService.Server.Services.DataService)
            EconomyService = require(game.ServerScriptService.Server.Services.EconomyService)
            PlayerEffectsService = require(game.ServerScriptService.Server.Services.PlayerEffectsService)
            
            -- Initialize services with test configuration
            -- (This would require a test setup helper)
        end)
        
        it("should complete full purchase flow", function()
            local mockPlayer = createMockPlayer("TestPlayer", 12345)
            
            -- Load player data
            DataService:LoadProfile(mockPlayer)
            wait(0.1)  -- Allow async operation
            
            -- Verify initial state
            local initialCoins = EconomyService:GetCurrency(mockPlayer, "coins")
            expect(initialCoins).to.equal(100)  -- Default starting amount
            
            -- Purchase item with effect
            local success = EconomyService:PurchaseItem(mockPlayer, "speed_potion")
            expect(success).to.equal(true)
            
            -- Verify currency deduction
            local newCoins = EconomyService:GetCurrency(mockPlayer, "coins")
            expect(newCoins).to.equal(95)  -- 100 - 5 gems converted to coins
            
            -- Verify effect application
            local activeEffects = PlayerEffectsService:GetActiveEffects(mockPlayer)
            expect(activeEffects.speed_boost).to.be.ok()
            
            -- Verify aggregate calculation
            local aggregates = mockPlayer:FindFirstChild("Aggregates")
            expect(aggregates).to.be.ok()
            expect(aggregates.speedMultiplier.Value).to.equal(1.5)
        end)
    end)
end
```

This sample code demonstrates the key patterns and implementations used throughout the game template, providing practical examples for extending and maintaining the system. 