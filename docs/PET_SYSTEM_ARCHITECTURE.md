# Pet System Architecture

## Overview

The Pet System allows players to equip and use pets that follow them around the game world. Pets provide visual appeal and assist in gameplay by attacking breakable objects. The system supports 0-99 pets per player with intelligent formation algorithms and customizable visibility settings.

Inventory Design Update:
- Normal pets (all pets that are not special) are stackable and identical. They cannot level or be enchanted. Their stats come from configuration as a single source of truth. Example: owning 15 `bear:basic` and 20 `bear:golden` creates two stacks rather than 35 unique instances.
- Special pets (rarities: secret, exclusive) are unique, individualized items that may carry levels, enchantments, nicknames, etc. These remain one-per-UID.
- Equipped state is part of the inventory's single source of truth. Equipping a normal pet temporarily “individualizes” one unit from its stack only for equip management; unequipping returns it to the stack.
- UI builds once at bootstrap, then applies incremental updates (no full refresh) for add/remove/equip/unequip/quantity changes.

## Core Requirements

1. **Pet Spawning & Management**
   - Pets spawn when equipped (added to player's Equipped/pets folder)
   - Pets despawn when unequipped (removed from folder)
   - Support 0-99 pets per player
   - Replicate pet states across all clients

2. **Pet Following System**
   - Pets follow their owner with smooth movement
   - Maintain formation based on pet count
   - Handle obstacles and terrain navigation
   - Different movement speeds based on pet stats

3. **Pet Combat System**
   - Pets attack targeted breakables
   - Use ability system from pet configuration
   - Damage calculation based on pet power
   - Visual feedback for attacks

4. **Visibility Settings**
   - "Show All Pets" - Display all player pets
   - "Show My Pets" - Display only local player's pets
   - "Show No Pets" - Hide all pets for performance

## Architecture Design

### 1. **Folder Structure & Replication**

Single Source of Truth is the player's Inventory. Equipped mirrors live inside the Inventory structure and are also exposed via an Equipped/pets folder for ease of consumption by visualization systems.

Replicated structure:
```
Player/
├── Inventory/
│   └── pets/
│       ├── Stacks/
│       │   ├── bear:basic/
│       │   │   └── Quantity (IntValue: 15)
│       │   ├── bear:golden/
│       │   │   └── Quantity (IntValue: 20)
│       │   └── ...
│       ├── Special/
│       │   ├── pet_uid_abc123/ (Folder with per-item values: PetType, Variant, Power, etc.)
│       │   └── ...
│       └── Equipped/
│           └── pets/
│               ├── slot_1 (StringValue: "stack|bear:basic|eph_1")
│               ├── slot_2 (StringValue: "special|pet_uid_abc123")
│               └── ...
└── Equipped/
    └── pets/
        ├── slot_1 (StringValue: "stack|bear:basic|eph_1")
        ├── slot_2 (StringValue: "special|pet_uid_abc123")
        └── ...
```

Notes:
- `Stacks/<id:variant>/Quantity` represents stack counts for normal pets. Instance count stays low regardless of quantity.
- `Special/<uid>` holds folders for unique pets (secret/exclusive). These retain individualized attributes.
- `Equipped/pets/slot_N` StringValue encodes either a stack-backed equip or a special UID:
  - `stack|<id:variant>|<ephemeralUid>`
  - `special|<uid>`
- The top-level `Player/Equipped/pets` is maintained as a convenience bridge for systems that already watch that path. Long-term, consumers can read from `Player/Inventory/pets/Equipped/pets` directly.

Equip/Unequip mutation only touches a few Values (slot StringValue and affected Quantity), avoiding any full folder rebuilds.

### 2. **Inventory Data Model (ProfileStore v2)**

```
Inventory = {
  pets = {
    version = 2,
    stacks = {
      ["bear:basic"] = { id = "bear", variant = "basic", quantity = 15 },
      ["bear:golden"] = { id = "bear", variant = "golden", quantity = 20 },
      -- ...
    },
    special = {
      ["pet_uid_abc123"] = {
        id = "hydra", variant = "secret", nickname = "", obtained_at = 1701234567,
        stats = { power = 5000 }, enchantments = { /* optional */ }
      },
      -- ...
    },
    equipped = {
      slots = {
        slot_1 = { kind = "stack", stackKey = "bear:basic", ephemeralUid = "eph_1" },
        slot_2 = { kind = "special", uid = "pet_uid_abc123" },
        -- ...
      }
    }
  }
}
```

Rules:
- Normal pets (non-secret, non-exclusive) persist in `stacks` and cannot be leveled or enchanted.
- Special pets (secret, exclusive) persist in `special` with full per-item data.
- Equipping a stack decrements its `quantity` and creates a transient equipped entry; unequipping increments quantity.
- All stats for normal pets derive from configuration at runtime.

### 2. **Component Architecture**

#### **Client Components**

**PetVisualizationService** (Client Service)
```lua
-- Manages pet model spawning and despawning
-- Listens to Equipped/pets folder changes
-- Handles visibility settings
-- Creates pet models with proper tags

Key Methods:
- InitializeService()
- OnPetEquipped(player, slotName, slotData)  -- slotData.kind="stack"/"special"; for stack: {stackKey, ephemeralUid}
- OnPetUnequipped(player, slotName)
- UpdateVisibilitySettings(setting)
- CreatePetModel(owner, petData) → Model
- DestroyPetModel(petModel)
```

**PetMovementController** (Client Controller)
```lua
-- Manages pet movement and formations
-- Uses RunService.Heartbeat for smooth updates
-- Handles pathfinding and obstacle avoidance

Key Methods:
- UpdatePetMovement(deltaTime)
- CalculateFormation(petCount) → Array<CFrame>
- GetTargetPosition(pet, owner, formationIndex) → Vector3
- SmoothMovePet(pet, targetPos, deltaTime)
```

**PetCombatController** (Client Controller)
```lua
-- Manages pet attacks on breakables
-- Syncs with player targeting system
-- Handles ability cooldowns and effects

Key Methods:
- OnPlayerTargetChanged(target)
- UpdatePetCombat(deltaTime)
- ExecutePetAttack(pet, target, ability)
- PlayAttackAnimation(pet, ability)
```

#### **Server Components**

**PetService** (Server Service)
```lua
-- Validates pet equipment changes
-- Handles pet stat calculations
-- Manages pet ability server validation

Key Methods:
- ValidatePetAttack(player, petUid, target, ability)
- CalculateDamage(petData, ability, target) → number
- ApplyDamageToBreakable(target, damage, player)
```

#### **Shared Components**

**PetFormationAlgorithms** (Shared Module)
```lua
-- Provides various formation patterns
-- Scales with pet count dynamically

Formations:
- CircleFormation: Pets form circle around player
- VFormation: Flying V pattern behind player
- GridFormation: Rectangular grid for many pets
- SpiralFormation: Spiral pattern for 20+ pets
- AdaptiveFormation: Switches based on pet count
```

### 3. **Pet Model Structure**

```
PetModel (Model)
├── HumanoidRootPart (Part) - Anchored, CanCollide false
├── Body (Model/Part) - Visual representation
├── Attributes
│   ├── OwnerId (number) - Player.UserId
│   ├── PetUid (string) - Unique identifier
│   ├── PetType (string) - e.g., "bear"
│   ├── Variant (string) - e.g., "golden"
│   └── SlotIndex (number) - Formation position
├── Effects (Folder) - Particle effects, trails
└── Combat (Folder)
    ├── Target (ObjectValue) - Current attack target
    └── LastAttackTime (NumberValue)
```

### 4. **Formation Algorithm System**

```lua
-- Adaptive formation based on pet count
function GetFormationType(petCount)
    if petCount <= 3 then
        return "Line"          -- Simple line behind player
    elseif petCount <= 8 then
        return "Circle"        -- Circle around player
    elseif petCount <= 15 then
        return "DoubleCircle"  -- Two concentric circles
    elseif petCount <= 30 then
        return "Grid"          -- 5x6 or 6x5 grid
    elseif petCount <= 50 then
        return "Spiral"        -- Spiral outward
    else
        return "Swarm"         -- Dynamic swarm behavior
    end
end

-- Example: Circle Formation
function CalculateCircleFormation(petCount, radius)
    local positions = {}
    local angleStep = (2 * math.pi) / petCount
    
    for i = 1, petCount do
        local angle = angleStep * (i - 1)
        local offset = Vector3.new(
            math.cos(angle) * radius,
            0,
            math.sin(angle) * radius
        )
        positions[i] = offset
    end
    
    return positions
end
```

### 5. **Movement System**

```lua
-- Smooth pet following with lerping
function UpdatePetPosition(pet, owner, formationOffset, deltaTime)
    local ownerRoot = owner.Character.HumanoidRootPart
    local targetPos = ownerRoot.Position + 
        (ownerRoot.CFrame * formationOffset)
    
    local petRoot = pet.HumanoidRootPart
    local currentPos = petRoot.Position
    
    -- Calculate movement
    local moveSpeed = pet:GetAttribute("Speed") or 16
    local distance = (targetPos - currentPos).Magnitude
    
    -- Smooth lerping with catch-up speed
    local lerpAlpha = math.min(moveSpeed * deltaTime / distance, 1)
    local newPos = currentPos:Lerp(targetPos, lerpAlpha)
    
    -- Apply movement
    petRoot.CFrame = CFrame.lookAt(newPos, targetPos)
    
    -- Teleport if too far (anti-stuck)
    if distance > 50 then
        petRoot.CFrame = CFrame.new(targetPos)
    end
end
```

### 6. **Inventory UI (Stacking & Incremental Updates)**

Principles:
- Build the inventory UI once at bootstrap.
- Incrementally update UI on specific events:
  - `Stacks.ChildAdded/Removed` → add/remove stack rows.
  - `Quantity.Changed` → update count badge and (if configured) re-sort affected rows.
  - `Special.ChildAdded/Removed` → add/remove unique item rows.
  - `Equipped/pets` slot changes → update the equipped strip at the top and adjust visible stack counts as `visibleCount = Quantity - equippedFromStack`.
- Sort order: equipped first, then by strength (normal stacks use config power; special use per-UID power). 
- Normal stacks show a count badge; special pets render as individual items.

Networking:
- Equip/Unequip toggles send a command payload:
  - Stack: `{ bucket = "pets", kind = "stack", stackKey = "bear:basic" }`
  - Special: `{ bucket = "pets", kind = "special", uid = "pet_uid_abc123" }`
- State replication is folder/value-based; network events are only for commands or toasts.

### 6. **Combat System Integration**

```lua
-- Pet attack coordination
function InitiatePetAttack(pet, target)
    local petData = GetPetData(pet)
    local abilities = petData.abilities
    
    -- Select ability based on cooldowns
    local selectedAbility = SelectBestAbility(abilities, pet)
    if not selectedAbility then return end
    
    -- Check range
    local distance = (pet.Position - target.Position).Magnitude
    if distance > ATTACK_RANGE then
        -- Move closer first
        SetPetTarget(pet, target)
        return
    end
    
    -- Execute attack
    PlayAttackAnimation(pet, selectedAbility)
    
    -- Server validation
    PetService:ValidateAttack(pet, target, selectedAbility)
end
```

### 7. **Visibility Settings System**

```lua
-- Settings stored in ReplicatedStorage or player data
local VisibilitySettings = {
    ALL_PETS = "all",      -- Show everyone's pets
    MY_PETS = "mine",      -- Show only local player's pets
    NO_PETS = "none"       -- Hide all pets
}

-- Apply visibility based on setting
function UpdatePetVisibility(setting)
    for _, petModel in CollectionService:GetTagged("Pet") do
        local ownerId = petModel:GetAttribute("OwnerId")
        local isLocalPet = ownerId == LocalPlayer.UserId
        
        if setting == VisibilitySettings.NO_PETS then
            petModel.Parent = nil
        elseif setting == VisibilitySettings.MY_PETS then
            petModel.Parent = isLocalPet and workspace or nil
        else -- ALL_PETS
            petModel.Parent = workspace
        end
    end
end
```

## Implementation Plan

### Phase 1: Core Pet Spawning (Week 1)
1. Create PetVisualizationService
2. Implement equipped folder monitoring (for current player and other players using player replication)
3. Basic pet model creation/destruction
4. Add CollectionService tags for pets

### Phase 2: Movement System (Week 1-2)
1. Create PetMovementController
2. Implement basic following behavior
3. Add formation algorithms (start with Circle)
4. Implement smooth movement and teleport failsafe

### Phase 3: Formation Scaling (Week 2)
1. Implement all formation types
2. Add adaptive formation switching
3. Test with 1-99 pets
4. Optimize performance for high pet counts

### Phase 4: Combat Integration (Week 3)
1. Create PetCombatController
2. Integrate with existing target system
3. Implement ability selection logic
4. Add attack animations and effects

### Phase 5: Settings & Polish (Week 3-4)
1. Add visibility settings to SettingsService
2. Create settings UI integration
3. Performance optimization
4. Visual effects and polish

### Phase 6: Testing & Optimization (Week 4)
1. Stress test with 99 pets
2. Network optimization
3. Mobile performance testing
4. Bug fixes and polish

## Performance Considerations

1. **Model Pooling**: Reuse pet models instead of creating/destroying
2. **LOD System**: Reduce detail for distant pets
3. **Update Throttling**: Update distant pets less frequently
4. **Batch Operations**: Group pet updates to reduce overhead
5. **Streaming**: Only show pets within range (e.g., 200 studs)

Additional performance gains from stacking:
- Instance count scales with distinct pet types/variants and equipped slots rather than total quantity.
- Equip/unequip touches only small Value sets (slot and quantity), avoiding full tree churn.
- UI uses debounced re-sorts and targeted frame updates instead of full panel rebuilds.

## Configuration Integration

The system will use existing configurations:
- `configs/pets.lua` - Pet stats, abilities, and variants
- `configs/ui.lua` - Settings panel integration
- `configs/game.lua` - Performance limits and defaults

## Network Optimization

1. **Minimal Replication**: Only replicate essential data (position updates handled client-side)
2. **Event Batching**: Batch multiple pet actions into single remote calls
3. **Predictive Movement**: Client predicts movement, server validates important actions
4. **Lazy Loading**: Load pet models on demand, not all at once

## Security Considerations

1. **Server Validation**: All damage calculations on server
2. **Rate Limiting**: Limit pet attack frequency
3. **Ownership Verification**: Verify player owns pet before actions
4. **Anti-Exploit**: Validate pet positions and targets

## Future Enhancements

1. **Pet Interactions**: Pets interact with each other
2. **Pet Emotes**: Command pets to do emotes
3. **Formation Presets**: Save custom formations
4. **Pet Abilities**: Special movement abilities (flying, swimming)
5. **Pet Customization**: Colors, accessories, names

## Migration Plan (Profile v1 → v2)

1. Detect old per-pet unique inventory. For each pet instance, compute rarity from `configs/pets.lua`.
2. If rarity is `secret` or `exclusive`, keep as unique in `special` with same UID; otherwise fold into `stacks[id:variant].quantity += 1` and drop unique-only fields (level/enchantments).
3. Derive equipped slots:
   - If an equipped UID maps to a special pet, keep it as `special|<uid>`.
   - If it maps to a normal pet, allocate a stack-backed equip entry and decrement its stack quantity.
4. Write `Inventory.pets.version = 2` and replicate `Stacks`, `Special`, and `Equipped/pets` as described.
5. Maintain `Player/Equipped/pets` bridge values during rollout; switch consumers to `Inventory/pets/Equipped/pets` when convenient and remove bridge later.
