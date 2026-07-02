# Inventory Storage Types - Design Document

## 🎯 Purpose

This document explains the two storage approaches for inventory items: **Stackable** (identical items) vs **Unique** (individual instances with unique properties).

---

## 📦 Storage Type Comparison

### **Stackable Items (storage_type: "stackable")**

**Use Case**: Items that are functionally identical
- Coins, potions, resources, consumables
- No individual properties or uniqueness needed
- Efficient storage via quantity counts

**Storage Structure**:
```lua
bucket.items = {
    ["health_potion"] = {
        id = "health_potion",
        quantity = 15,               -- Player has 15 health potions
        obtained_at = 1701234567
    },
    ["wood"] = {
        id = "wood", 
        quantity = 250,              -- Player has 250 wood
        obtained_at = 1701234568,
        quality = "oak"              -- Optional properties still allowed
    }
}
```

**Slot Usage**: Each unique item type takes 1 slot regardless of quantity
- 15 health potions = 1 slot
- 250 wood = 1 slot  
- Total slots used = 2 (out of bucket limit)

### **Unique Items (storage_type: "unique")**

**Use Case**: Items with individual properties and progression
- Pets, weapons, armor, collectibles
- Each instance has unique stats, levels, enchantments
- Requires individual tracking

**Storage Structure**:
```lua
bucket.items = {
    ["pet_1701234567_a3f8b2c1"] = {
        id = "bear",                 -- Base pet type
        variant = "golden",          -- This bear is golden
        level = 5,                   -- Individual level
        exp = 250,                   -- Individual experience
        nickname = "Goldie",         -- Player-given name
        stats = {
            power = 55,              -- Unique stats due to level/enchantments
            health = 780,
            speed = 1.2
        },
        enchantments = {
            {type = "power_boost", tier = 1, value = 5}
        },
        obtained_at = 1701234567
    },
    ["pet_1701234568_d9e4f7a2"] = {
        id = "bear",                 -- Same type as above...
        variant = "basic",           -- But different variant
        level = 1,                   -- Different level
        exp = 0,                     -- Different experience
        nickname = "Bruno",          -- Different nickname
        stats = {
            power = 50,              -- Different stats
            health = 600,
            speed = 1.0
        },
        enchantments = {},           -- No enchantments
        obtained_at = 1701234568
    }
}
```

**Slot Usage**: Each individual item takes 1 slot
- Golden Bear "Goldie" = 1 slot
- Basic Bear "Bruno" = 1 slot
- Total slots used = 2 (out of bucket limit)

---

## 🔄 Real-World Examples

### **Pet Simulator Game**

**Pets Bucket (Unique Storage)**:
```lua
pets = {
    storage_type = "unique",
    base_limit = 50,
    items = {
        ["pet_001"] = {id = "bear", variant = "golden", level = 10, power = 85},
        ["pet_002"] = {id = "bear", variant = "basic", level = 3, power = 45},
        ["pet_003"] = {id = "dragon", variant = "fire", level = 7, power = 120},
        ["pet_004"] = {id = "bear", variant = "rainbow", level = 15, power = 200}
    }
}
-- 4 slots used: Each pet is unique despite some being same type
```

**Consumables Bucket (Stackable Storage)**:
```lua
consumables = {
    storage_type = "stackable", 
    base_limit = 100,
    items = {
        ["health_potion"] = {quantity = 25},
        ["speed_potion"] = {quantity = 12},
        ["luck_potion"] = {quantity = 8}
    }
}
-- 3 slots used: Each potion type takes 1 slot regardless of quantity
```

**Resources Bucket (Stackable Storage)**:
```lua
resources = {
    storage_type = "stackable",
    base_limit = 50, 
    items = {
        ["wood"] = {quantity = 1500},
        ["stone"] = {quantity = 800},
        ["iron"] = {quantity = 200},
        ["diamond"] = {quantity = 15}
    }
}
-- 4 slots used: Each resource type takes 1 slot
```

---

## ⚖️ Design Benefits

### **Storage Efficiency**
- **Stackable**: 1000 coins = 1 slot
- **Unique**: 1000 pets = 1000 slots (if all unique)

### **Scalability**
- **Stackable**: Player can have millions of coins without affecting performance
- **Unique**: Each pet has individual data, allowing complex progression systems

### **Flexibility**
- **Stackable items** can still have optional properties (quality, source, etc.)
- **Unique items** can share base configurations while maintaining individuality

---

## 🔧 Implementation Guidelines

### **When to Use Stackable**
- ✅ Items are functionally identical
- ✅ No individual progression/stats needed
- ✅ Large quantities expected
- ✅ Simple gameplay mechanics

**Examples**: Currency, basic consumables, crafting materials, ammo

### **When to Use Unique** 
- ✅ Individual progression/leveling
- ✅ Unique stats or properties per instance
- ✅ Player customization (nicknames, enchantments)
- ✅ Complex gameplay mechanics

**Examples**: Pets, weapons, armor, vehicles, collectibles

### **Configuration Example**
```lua
buckets = {
    -- Unique storage for complex items
    pets = {
        storage_type = "unique",
        base_limit = 50,
        stack_size = 1              -- Each pet takes 1 slot
    },
    
    -- Stackable storage for simple items  
    consumables = {
        storage_type = "stackable",
        base_limit = 100,
        stack_size = 99             -- Up to 99 per stack
    }
}
```

---

## 🛡️ Safety Considerations

Both storage types follow the same safety principles:
- ✅ Buckets never deleted from profiles
- ✅ Data preserved during migrations
- ✅ Orphaned buckets detected but preserved
- ✅ Configuration changes only add, never remove

The storage type affects HOW items are stored within buckets, but doesn't change the bucket preservation safety system.

---

This dual approach provides the perfect balance: efficiency for simple items, flexibility for complex items, all within the same unified inventory system.