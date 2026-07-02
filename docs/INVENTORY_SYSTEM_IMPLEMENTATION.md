# Universal Inventory System - Implementation Plan

## 🎯 Overview

This document outlines the complete implementation plan for a flexible, configuration-driven inventory system that supports pets, weapons, tools, and any other item types games may need. The system follows the core architectural principles of Configuration as Code, ProfileStore persistence, and folder-based replication.

---

## 🏗️ Core Design Principles

### 1. **Unique Instance IDs (UIDs)**
- Every item/pet gets a globally unique identifier when created
- Format: `{type}_{timestamp}_{guid}` (e.g., `pet_1701234567_a3f8b2c1`)
- Enables tracking of individual items with unique stats/enchantments

### 2. **Configuration-Driven Buckets**
- Games define which inventory categories they need via configuration
- Each bucket has customizable limits, stacking rules, and schemas
- Limits can be extended via gamepasses

### 3. **Separated Concerns**
- Inventory = Storage (what you own)
- Equipped = Active loadout (what you're using)
- Clean separation enables future features like loadout presets

### 4. **No Model Storage**
- Only metadata stored in ProfileStore
- Models loaded via asset IDs when needed
- Keeps data lightweight and secure

---

## 📁 System Architecture

### ProfileStore Structure
```lua
{
    -- Player data...
    
    Inventory = {
        -- Dynamic buckets based on game configuration
        pets = {
            items = {
                ["pet_1701234567_a3f8b2c1"] = {
                    id = "bear",              -- Base type from config
                    variant = "golden",       -- Variant (basic/golden/rainbow)
                    level = 5,
                    exp = 250,
                    nickname = "Goldie",
                    obtained_at = 1701234567,
                    
                    -- Instance-specific stats
                    stats = {
                        power = 55,           -- Base 50 + enchantments
                        health = 780,
                        speed = 1.2
                    },
                    
                    -- Unique modifiers for this instance
                    enchantments = {
                        { type = "power_boost", tier = 1, value = 5 },
                        { type = "health_boost", tier = 2, value = 30 }
                    }
                },
                ["pet_1701234568_d9e4f7a2"] = {
                    -- Another pet instance...
                }
            },
            total_slots = 50,    -- Base + gamepass extensions
            used_slots = 2
        },
        
        consumables = {
            items = {
                ["item_1701234569_b1c3d5e7"] = {
                    id = "health_potion",
                    quantity = 10,    -- Stackable items
                    obtained_at = 1701234569
                }
            },
            total_slots = 100,
            used_slots = 1
        }
    },
    
    Equipped = {
        pets = {
            slot_1 = "pet_1701234567_a3f8b2c1",  -- UID reference
            slot_2 = "pet_1701234568_d9e4f7a2",
            slot_3 = nil                          -- Empty slot
        },
        weapon = "weapon_1701234570_c4e6f8a9",   -- Single slot
        armor = {
            helmet = "armor_1701234571_d5f7g9b0",
            chest = nil,
            gloves = nil,
            boots = nil
        }
    },
    
    InventoryStats = {
        total_items_obtained = 156,
        total_pets_hatched = 45,
        inventory_upgrades_purchased = 2,
        items_deleted = 12,
        items_traded = 8
    }
}
```

### Folder-Based Replication
```
Player/
├── Inventory/
│   ├── Info/
│   │   ├── LastUpdated (NumberValue: 1701234567)
│   │   └── Version (IntValue: 1)
│   ├── pets/
│   │   ├── Info/
│   │   │   ├── SlotsUsed (IntValue: 2)
│   │   │   └── SlotsTotal (IntValue: 50)
│   │   ├── pet_1701234567_a3f8b2c1/ (Folder)
│   │   │   ├── PetType (StringValue: "bear")
│   │   │   ├── Variant (StringValue: "golden")
│   │   │   ├── Level (IntValue: 5)
│   │   │   ├── Power (NumberValue: 55)
│   │   │   ├── Health (NumberValue: 780)
│   │   │   ├── Speed (NumberValue: 1.2)
│   │   │   ├── Nickname (StringValue: "Goldie")
│   │   │   └── Enchantments/ (Folder)
│   │   │       ├── power_boost_1 (NumberValue: 5)
│   │   │       └── health_boost_2 (NumberValue: 30)
│   │   └── pet_1701234568_d9e4f7a2/ (Folder)
│   │       └── [similar structure]
│   └── consumables/
│       ├── Info/
│       │   ├── SlotsUsed (IntValue: 1)
│       │   └── SlotsTotal (IntValue: 100)
│       └── item_1701234569_b1c3d5e7/ (Folder)
│           ├── ItemId (StringValue: "health_potion")
│           └── Quantity (IntValue: 10)
├── Equipped/
│   ├── pets/
│   │   ├── Slot1 (StringValue: "pet_1701234567_a3f8b2c1")
│   │   ├── Slot2 (StringValue: "pet_1701234568_d9e4f7a2")
│   │   └── Slot3 (StringValue: "")
│   └── weapon/
│       └── Current (StringValue: "weapon_1701234570_c4e6f8a9")
```

---

## 📝 Configuration File Structure

### `configs/inventory.lua`
```lua
return {
    -- Version for migration support
    version = "1.0.0",
    
    -- Which inventory buckets this game uses
    enabled_buckets = {
        pets = true,
        weapons = false,      -- Disabled for pet simulator
        tools = false,        -- Disabled for pet simulator
        consumables = true,
        cosmetics = false,
        mounts = false
    },
    
    -- Bucket definitions
    buckets = {
        pets = {
            display_name = "Pets",
            icon = "🐾",
            base_limit = 50,
            stack_size = 1,              -- Pets don't stack
            allow_duplicates = true,     -- Can have multiple of same pet type
            
            -- Limit extensions
            limit_extensions = {
                { 
                    gamepass_id = 123456789,  -- Replace with actual ID
                    additional_slots = 50,
                    name = "Extra Pet Storage"
                },
                { 
                    gamepass_id = 987654321,
                    additional_slots = 100,
                    name = "Ultimate Pet Storage"
                }
            },
            
            -- Schema for pet instances
            item_schema = {
                required = {
                    "id",               -- Pet type from pet config
                    "variant",          -- basic/golden/rainbow
                    "obtained_at"       -- Timestamp
                },
                optional = {
                    "level",            -- Default: 1
                    "exp",              -- Default: 0
                    "nickname",         -- Default: ""
                    "stats",            -- Default: base stats
                    "enchantments",     -- Default: {}
                    "locked"            -- Default: false (for trade protection)
                }
            },
            
            -- Validation rules
            validation = {
                max_nickname_length = 20,
                allowed_characters = "^[%w%s]+$",  -- Alphanumeric + spaces
                max_level = 100,
                max_enchantments = 5
            }
        },
        
        weapons = {
            display_name = "Weapons",
            icon = "⚔️",
            base_limit = 20,
            stack_size = 1,
            allow_duplicates = true,
            
            item_schema = {
                required = {
                    "id",
                    "obtained_at"
                },
                optional = {
                    "level",
                    "durability",       -- Current/max durability
                    "enchantments",
                    "locked"
                }
            }
        },
        
        consumables = {
            display_name = "Consumables",
            icon = "🧪",
            base_limit = 100,
            stack_size = 99,            -- Items can stack
            allow_duplicates = false,   -- Same items merge into stacks
            
            item_schema = {
                required = {
                    "id",
                    "quantity",
                    "obtained_at"
                },
                optional = {
                    "expires_at"        -- For time-limited items
                }
            }
        }
    },
    
    -- Equipped configuration
    equipped = {
        pets = {
            slots = 3,                  -- Number of equipped slots
            display_name = "Active Pets",
            icon = "🐾",
            
            -- Slot extensions via gamepasses
            slot_extensions = {
                {
                    gamepass_id = 456789123,
                    additional_slots = 1,
                    name = "4th Pet Slot"
                },
                {
                    gamepass_id = 789123456,
                    additional_slots = 2,
                    name = "5th & 6th Pet Slots"
                }
            }
        },
        
        weapon = {
            slots = 1,
            display_name = "Equipped Weapon",
            icon = "⚔️"
        },
        
        armor = {
            slots = {
                helmet = 1,
                chest = 1,
                gloves = 1,
                boots = 1
            },
            display_name = "Armor",
            icon = "🛡️"
        }
    },
    
    -- General settings
    settings = {
        enable_trading = true,
        enable_item_locking = true,     -- Prevent accidental deletion/trading
        enable_bulk_actions = true,     -- Mass delete/organize
        auto_sort_enabled = true,
        default_sort_order = "rarity",  -- rarity/level/newest/oldest
        
        -- UID generation settings
        uid_prefix_length = 8,          -- Length of random suffix
        uid_include_timestamp = true
    }
}
```

---

## 🔧 Service Implementation

### InventoryService Methods

```lua
-- Core Operations
InventoryService:AddItem(player, bucket, itemData) → uid
InventoryService:RemoveItem(player, bucket, uid) → boolean
InventoryService:GetItem(player, bucket, uid) → itemData
InventoryService:UpdateItem(player, bucket, uid, updates) → boolean

-- Bulk Operations
InventoryService:AddItems(player, bucket, itemsArray) → {uids}
InventoryService:RemoveItems(player, bucket, uids) → boolean
InventoryService:GetInventory(player, bucket?) → inventory
InventoryService:ClearBucket(player, bucket) → boolean

-- Query Operations
InventoryService:HasSpace(player, bucket, amount?) → boolean
InventoryService:GetUsedSlots(player, bucket) → number
InventoryService:GetTotalSlots(player, bucket) → number
InventoryService:FindItems(player, bucket, filter) → {items}

-- Equipped Operations
InventoryService:EquipItem(player, bucket, uid, slot?) → boolean
InventoryService:UnequipItem(player, bucket, slot) → boolean
InventoryService:GetEquipped(player, bucket?) → equipped
InventoryService:SwapEquipped(player, bucket, slot1, slot2) → boolean
InventoryService:IsEquipped(player, uid) → boolean, bucket, slot

-- Utility Operations
InventoryService:GenerateUID(itemType) → string
InventoryService:ValidateItem(bucket, itemData) → boolean, error
InventoryService:MergeStackableItems(player, bucket) → number
InventoryService:SortInventory(player, bucket, sortBy) → boolean
InventoryService:LockItem(player, bucket, uid, locked) → boolean

-- Trading Support
InventoryService:PrepareTradeItem(player, bucket, uid) → tradeData
InventoryService:CanTradeItem(player, bucket, uid) → boolean, reason
InventoryService:TransferItem(fromPlayer, toPlayer, bucket, uid) → boolean
```

---

## 📋 Implementation Order & Progression

The implementation follows a logical progression where each phase builds upon the previous one, allowing for testing and validation at each step.

### Implementation Flow:
```
Configuration → ProfileStore Setup → Basic InventoryService → Pet Hatching Integration
→ Debug Verification → Basic UI Display → Equipping System → Advanced Features
```

---

## 🚀 Phased Implementation Checklist

### Phase 1: Foundation - Configuration & Profile Structure
**Goal**: Set up the data structure and ensure profiles can store inventory data

- [ ] Create `configs/inventory.lua` with initial pet bucket configuration
- [ ] Update `DataService.lua` to dynamically generate inventory buckets in ProfileTemplate
- [ ] Add inventory configuration validation to ConfigLoader
- [ ] Test that new players get proper inventory structure in their profile
- [ ] Add debug logging to verify profile structure on player join

**Verification**: 
- Use Studio command bar to inspect player profiles
- Check that `player.Profile.Data.Inventory.pets` exists with correct structure

### Phase 2: Basic Inventory Service & Hatching Integration
**Goal**: Get pets flowing into inventory when hatched

- [ ] Create `src/Server/Services/InventoryService.lua` with minimal functionality:
  - [ ] `GenerateUID()` method
  - [ ] `AddItem()` method (basic version)
  - [ ] `GetInventory()` method
  - [ ] `HasSpace()` method
- [ ] Update `EggService` (or create if needed) to:
  - [ ] Generate UID when hatching
  - [ ] Create pet instance with unique stats
  - [ ] Call `InventoryService:AddItem()` instead of direct storage
- [ ] Add comprehensive logging for debugging
- [ ] Test egg hatching and verify pets appear in ProfileStore

**Verification**:
- Hatch eggs and check ProfileStore data
- Verify UIDs are unique
- Confirm inventory space limits work

### Phase 3: Debug Visibility & Folder Replication
**Goal**: Make inventory data visible for debugging and client access

- [ ] Implement folder structure creation in InventoryService
- [ ] Create inventory folders when player joins
- [ ] Update folders when items are added/removed
- [ ] Add debug UI or console commands to view inventory
- [ ] Test that client can see inventory data via folders

**Verification**:
- Use Explorer to inspect Player folder structure
- Verify folder values match ProfileStore data
- Test real-time updates when hatching

### Phase 4: Basic Inventory UI Display
**Goal**: Create read-only inventory display

- [ ] Update `InventoryPanel.lua` to:
  - [ ] Read from inventory folders instead of mock data
  - [ ] Display actual pets with their unique stats
  - [ ] Show inventory space usage (X/50 pets)
  - [ ] Display pet details (level, power, variant)
- [ ] Implement basic sorting (by power, level, rarity)
- [ ] Add search/filter functionality
- [ ] Test UI with various inventory states

**Verification**:
- Open inventory and see real pets
- Verify stats match what's in ProfileStore
- Test with empty, partial, and full inventory

### Phase 5: Equipping System
**Goal**: Allow players to equip/unequip pets

- [ ] Extend InventoryService with:
  - [ ] `EquipItem()` method
  - [ ] `UnequipItem()` method  
  - [ ] `GetEquipped()` method
  - [ ] `IsEquipped()` method
- [ ] Create Equipped folder structure
- [ ] Update InventoryPanel to:
  - [ ] Show equipped indicators
  - [ ] Add equip/unequip buttons
  - [ ] Display equipped pets separately
- [ ] Implement equipped pet effects (if applicable)

**Verification**:
- Equip pets and verify in ProfileStore
- Check equipped folder structure
- Verify only one pet per slot
- Test equip/unequip persistence

### Phase 6: Advanced Inventory Operations
**Goal**: Add quality-of-life features

- [ ] Implement remaining InventoryService methods:
  - [ ] `RemoveItem()` - with confirmation
  - [ ] `UpdateItem()` - for nicknames, etc.
  - [ ] `FindItems()` - for filtering
  - [ ] `SortInventory()` - various sort options
- [ ] Add bulk operations support
- [ ] Implement item locking
- [ ] Add inventory statistics tracking

**Verification**:
- Test all CRUD operations
- Verify data integrity
- Check performance with large inventories

### Phase 7: Polish & Extended Features
**Goal**: Complete the system with all planned features

- [ ] Implement gamepass slot extensions
- [ ] Add trading support preparation
- [ ] Create admin commands
- [ ] Optimize network traffic for bulk updates
- [ ] Add comprehensive error handling
- [ ] Create migration tools for existing data

**Verification**:
- Full system integration test
- Performance benchmarking
- User acceptance testing

---

## 🧪 Testing Approach Per Phase

### Phase 1 Testing:
```lua
-- In Studio command bar
local player = game.Players.YourName
local profile = DataService:GetProfile(player)
print("Inventory structure:", profile.Data.Inventory)
-- Should see: { pets = { items = {}, total_slots = 50, used_slots = 0 } }
```

### Phase 2 Testing:
```lua
-- After hatching an egg
local inventory = profile.Data.Inventory.pets.items
for uid, pet in pairs(inventory) do
    print(uid, pet.id, pet.variant, pet.stats)
end
-- Should see: pet_[timestamp]_[guid] bear golden { power = 55, ... }
```

### Phase 3 Testing:
```lua
-- Check folder replication
local petFolder = player.Inventory.pets
for _, child in pairs(petFolder:GetChildren()) do
    if child:IsA("Folder") then
        print("Pet UID:", child.Name)
        print("Type:", child.PetType.Value)
        print("Power:", child.Power.Value)
    end
end
```

### Progressive Development Benefits:
1. **Each phase is independently testable**
2. **Can catch issues early before building dependent features**
3. **Allows for incremental deployment**
4. **Easier to debug when issues arise**
5. **Can gather feedback at each stage**

---

## 🧪 Testing Strategy

### Unit Tests
```lua
-- Test UID generation uniqueness
test("UID generation produces unique IDs", function()
    local uids = {}
    for i = 1, 1000 do
        local uid = InventoryService:GenerateUID("test")
        expect(uids[uid]).to.equal(nil)
        uids[uid] = true
    end
end)

-- Test inventory space limits
test("Inventory respects bucket limits", function()
    local player = createMockPlayer()
    local bucket = "pets"
    
    -- Fill inventory to limit
    for i = 1, 50 do
        local success = InventoryService:AddItem(player, bucket, {
            id = "test_pet",
            variant = "basic"
        })
        expect(success).to.equal(true)
    end
    
    -- Try to add one more
    local success = InventoryService:AddItem(player, bucket, {
        id = "test_pet",
        variant = "basic"
    })
    expect(success).to.equal(false)
end)
```

### Integration Tests
1. **Pet Hatching Flow**
   - Hatch egg → Verify pet in inventory → Equip pet → Verify equipped
   
2. **Persistence Test**
   - Add items → Disconnect player → Reconnect → Verify items persist

3. **Replication Test**
   - Server adds item → Check client folder structure → Verify values match

4. **Concurrent Operations**
   - Multiple operations on same inventory → Verify data integrity

### Manual Testing Checklist
- [ ] Hatch various pets and verify unique stats
- [ ] Fill inventory to capacity and test limit warnings
- [ ] Equip/unequip items rapidly
- [ ] Test with gamepass slot extensions
- [ ] Verify UI updates in real-time
- [ ] Test inventory during high server load
- [ ] Validate data after server restart

---

## 🚀 Rollout Strategy

### Phase 1: Development Server
- Deploy to test server
- Run automated tests
- Internal team testing

### Phase 2: Beta Release
- Enable for select beta testers
- Monitor for issues
- Gather performance metrics

### Phase 3: Gradual Rollout
- Enable for 10% of players
- Monitor error rates
- Scale to 50%, then 100%

### Phase 4: Legacy Cleanup
- Remove old inventory code
- Archive migration scripts
- Update documentation

---

## 📊 Success Metrics

- **Performance**: Inventory operations < 50ms
- **Reliability**: 99.9% operation success rate
- **Scalability**: Support 1000+ items per player
- **User Experience**: < 1% inventory-related bug reports

---

## 🔍 Monitoring & Debugging

### Key Metrics to Track
- Inventory operation latency
- Failed operation rates
- Memory usage per player
- Replication bandwidth

### Debug Commands
```lua
-- Admin commands
/inventory view [username] [bucket]
/inventory add [username] [bucket] [itemId]
/inventory clear [username] [bucket]
/inventory stats [username]
/inventory repair [username]
```

---

This plan provides a complete roadmap for implementing the universal inventory system. Each phase builds upon the previous one, ensuring a stable and tested implementation at every step.