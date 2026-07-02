# Pet Realm Game — Given-When-Then Acceptance Specification

**Companion document to:** `DESIGN_DOCUMENT.md`
**Purpose:** Behavior specification in Given-When-Then (Gherkin-flavored) format. Each scenario serves dual purpose: (1) unambiguous functional architecture, (2) executable acceptance test specification.
**Test framework target:** TestEZ for unit/integration, Studio command-bar runners for end-to-end (existing RBX-Template patterns).

---

## 0. How To Use This Document

Each **Feature** in this document maps to a system from the design doc. Each **Scenario** within a feature is a single, deterministic behavior specification.

### Scenario Format

All scenarios follow Gherkin convention:
- `Given` — preconditions, world state, player state
- `When` — the triggering action
- `Then` — required outcome (single observable change)
- `And` — additional related outcomes
- `But` — explicit negative outcomes (things that must NOT happen)

### Test Level Tags

Each scenario is tagged with its target test level:
- **[unit]** — pure logic, no Roblox services required, TestEZ in `tests/unit/`
- **[integration]** — touches ProfileStore, modifier pipeline, multiple services, TestEZ in `tests/integration/`
- **[studio]** — requires real player/world state, Studio command-bar runner in `tests/studio/`

### Status Marking

- **[required]** — must implement and pass
- **[deferred]** — agreed behavior, defer implementation to later phase
- **[open]** — design question, behavior not yet finalized

### How To Convert To Test Code

Each scenario maps roughly to one `it` block in TestEZ:

```lua
describe("Soul stat", function()
    it("increases by 5 when player conquers clockwise neighbor", function()
        -- Given
        local profile = makeProfile({ soul = 0, last_conquered = "earth" })
        -- When
        AlignmentService:onBiomeConquest(profile, "desert")
        -- Then
        expect(profile.soul).to.equal(5)
    end)
end)
```

The Given/When/Then mapping is mechanical. Studio scenarios follow the existing `Phase5AutoSystemsSmoke` pattern.

### Reading Convention

Scenarios assume the player and world state is in a consistent starting condition unless otherwise noted in `Background`. Anything not specified in `Given` should be treated as default/empty.

---

## Feature 1: Ring Map Topology

**System:** map/world | **Existing code reference:** `configs/areas.lua`, `configs/markers.lua`
**Description:** The map is a ring of biomes with deterministic adjacency. Biome order and themes are config-driven; service code must not hardcode.

### Background

```gherkin
Given the prototype config defines biomes in clockwise order: [earth, ice, lava, desert, beach]
And each biome has a theme tag matching its name
And the Central Hub is at the ring center
```

### Scenario: Biome adjacency lookup — clockwise neighbor [unit] [required]

```gherkin
Given a biome named "earth"
When the system queries the clockwise neighbor of "earth"
Then it should return "ice"
```

### Scenario: Biome adjacency lookup — counterclockwise neighbor [unit] [required]

```gherkin
Given a biome named "earth"
When the system queries the counterclockwise neighbor of "earth"
Then it should return "beach"
```

### Scenario: Biome adjacency wraps around the ring [unit] [required]

```gherkin
Given a biome named "beach" which is the last in clockwise order
When the system queries the clockwise neighbor of "beach"
Then it should return "earth" (wrapping to the start)
```

### Scenario: Biome theme is config-driven, not inferred [unit] [required]

```gherkin
Given a biome config entry { id: "ice", theme: "ice" }
When the system queries the theme of biome "ice"
Then it should return "ice"
But the system must not hardcode any biome-to-theme mapping in service code
```

### Scenario: Adding a biome to config does not require service code changes [integration] [required]

```gherkin
Given the existing ring has 5 biomes
When a developer adds a 6th biome "swamp" to configs/areas.lua
And the developer rebuilds the place
Then the new biome appears in the ring topology
And adjacency lookups correctly include "swamp"
And no service code modification was required
```

### Scenario: Biome theme dichotomies are config-driven [unit] [required]

```gherkin
Given the prototype config defines dichotomies: earth↔desert, ice↔lava
When the system queries the dichotomy partner of "earth"
Then it should return "desert"
And queries for "ice" return "lava"
And queries for "beach" (no dichotomy) return nil
```

---

## Feature 2: Soul Stat (Alignment Tracking)

**System:** `AlignmentService` (new) | **Persistence:** ProfileStore field `soul`
**Description:** Tracks the player's alignment along Heaven (positive) / Hell (negative) axis. Updated on biome conquest based on directional progression.

### Background

```gherkin
Given a player with profile.soul = 0
And profile.last_conquered_biome = nil
And the ring biome order is [earth, ice, lava, desert, beach] (clockwise)
And the per-conquest Soul delta is configured as 5
And the Soul range is configured as [-100, +100]
```

### Scenario: Initial Soul stat is zero [unit] [required]

```gherkin
Given a newly created player profile
When the profile is loaded
Then profile.soul should equal 0
```

### Scenario: Conquering clockwise neighbor increases Soul [unit] [required]

```gherkin
Given profile.soul = 0
And profile.last_conquered_biome = "earth"
When the player conquers "ice" (clockwise neighbor of earth)
Then profile.soul should equal 5
And profile.last_conquered_biome should equal "ice"
```

### Scenario: Conquering counterclockwise neighbor decreases Soul [unit] [required]

```gherkin
Given profile.soul = 0
And profile.last_conquered_biome = "earth"
When the player conquers "beach" (counterclockwise neighbor of earth)
Then profile.soul should equal -5
And profile.last_conquered_biome should equal "beach"
```

### Scenario: Conquering non-adjacent biome does not change Soul [unit] [required]

```gherkin
Given profile.soul = 10
And profile.last_conquered_biome = "earth"
When the player conquers "lava" (not adjacent to earth)
Then profile.soul should remain 10
And profile.last_conquered_biome should equal "lava"
```

### Scenario: First conquest has no last_conquered, no Soul change [unit] [required]

```gherkin
Given profile.soul = 0
And profile.last_conquered_biome = nil
When the player conquers their first biome "earth"
Then profile.soul should remain 0
And profile.last_conquered_biome should equal "earth"
```

### Scenario: Re-conquering an already-conquered biome does not affect Soul [unit] [required]

```gherkin
Given profile.soul = 15
And profile.last_conquered_biome = "ice"
And profile.conquered_biomes includes "earth"
When the player re-enters and "completes" earth content
Then profile.soul should remain 15
And the conquest event should not fire
```

### Scenario: Soul is capped at upper bound [unit] [required]

```gherkin
Given profile.soul = 98
And profile.last_conquered_biome = "earth"
When the player conquers a clockwise neighbor (delta +5)
Then profile.soul should equal 100 (capped, not 103)
```

### Scenario: Soul is capped at lower bound [unit] [required]

```gherkin
Given profile.soul = -98
And profile.last_conquered_biome = "earth"
When the player conquers a counterclockwise neighbor (delta -5)
Then profile.soul should equal -100 (capped, not -103)
```

### Scenario: HUD displays current Soul value [studio] [required]

```gherkin
Given a player with profile.soul = 42
When the player joins the game
Then the Soul HUD element should display a value tilted toward Light
And the visual representation should match 42/100 of the positive direction
```

### Scenario: Soul updates are visible in HUD in real time [studio] [required]

```gherkin
Given a player in-game with profile.soul = 0
And the HUD Soul meter is visible at zero
When the player conquers a clockwise-neighbor biome
Then within 1 second the HUD should reflect soul = 5
And a brief notification "Your soul tilts toward the Light..." should appear
```

### Scenario: Soul delta value is config-driven [unit] [required]

```gherkin
Given the config sets soul_delta_per_conquest = 10 (instead of 5)
And profile.soul = 0
And profile.last_conquered_biome = "earth"
When the player conquers a clockwise neighbor
Then profile.soul should equal 10
```

### Scenario: Soul value persists across sessions [integration] [required]

```gherkin
Given a player with profile.soul = 35
When the player logs out
And the player logs back in
Then profile.soul should still equal 35
```

---

## Feature 3: Layer Access & Portals

**System:** `LayerService` (new), extends existing portal/pad travel | **Existing code reference:** server-authoritative portal travel
**Description:** Stacked layers (base, Heaven 1/2/3, Hell 1/2/3) accessed via portals at the Central Hub. Access gated by Soul magnitude and token cost.

### Background

```gherkin
Given the prototype config defines layers:
  | layer    | y_offset | requires_soul | token_cost           |
  | base     | 0        | none          | none                 |
  | heaven_1 | +2000    | +20           | 100 light_tokens     |
  | heaven_2 | +4000    | +40           | 250 light_tokens     |
  | heaven_3 | +6000    | +60           | 500 light_tokens     |
  | hell_1   | -2000    | -20           | 100 shadow_tokens    |
  | hell_2   | -4000    | -40           | 250 shadow_tokens    |
  | hell_3   | -6000    | -60           | 500 shadow_tokens    |
```

### Scenario: New player can access base layer [unit] [required]

```gherkin
Given a newly created player with profile.soul = 0
When the player checks accessible layers
Then "base" should be in the accessible list
```

### Scenario: Player cannot access Heaven 1 without sufficient Soul [unit] [required]

```gherkin
Given profile.soul = 10
And profile.light_tokens = 1000
When the player attempts to use the Heaven 1 portal
Then the portal should reject the request
And the player should remain in their current layer
And an error message indicating "Soul too low" should be shown
But no tokens should be deducted
```

### Scenario: Player cannot access Heaven 1 without sufficient tokens [unit] [required]

```gherkin
Given profile.soul = 50
And profile.light_tokens = 50 (less than required 100)
When the player attempts to use the Heaven 1 portal
Then the portal should reject the request
And an error message indicating "Insufficient Light Tokens" should be shown
But no tokens should be deducted
```

### Scenario: Player successfully ascends to Heaven 1 [studio] [required]

```gherkin
Given profile.soul = 25
And profile.light_tokens = 150
And the player is at the Central Hub
When the player uses the Heaven 1 portal
Then profile.light_tokens should equal 50 (150 - 100)
And the player's character should be teleported to Heaven 1 layer
And profile.current_layer should equal "heaven_1"
```

### Scenario: Player cannot descend to Hell with positive Soul [unit] [required]

```gherkin
Given profile.soul = 30
And profile.shadow_tokens = 1000
When the player attempts to use the Hell 1 portal
Then the portal should reject the request
And an error message indicating Soul tilts wrong direction should be shown
```

### Scenario: Cross-path visit portal is accessible regardless of Soul [unit] [required]

```gherkin
Given profile.soul = 50 (Heaven-aligned)
And profile.shadow_tokens = 100
And a "Hell Layer 1 Visit" portal exists at the central hub with cost 100 shadow_tokens (and no soul requirement)
When the player attempts to use the visit portal
Then the portal should accept the request
And profile.shadow_tokens should equal 0
And profile.current_layer should equal "hell_1"
```

### Scenario: Portal costs are validated server-side [integration] [required]

```gherkin
Given a malicious client sends a portal-use request with manipulated cost
When the server receives the request
Then the server should re-validate cost against config
And reject any request whose costs don't match the config values
```

### Scenario: Multiple layers are stacked correctly in workspace [studio] [required]

```gherkin
Given the world is loaded
When the system inspects layer Y-offsets
Then "base" geometry should be at Y=0
And "heaven_1" geometry should be at Y=+2000
And "hell_1" geometry should be at Y=-2000
And StreamingEnabled is configured with appropriate radius
```

### Scenario: Current layer persists across sessions [integration] [required]

```gherkin
Given profile.current_layer = "heaven_2"
When the player logs out and back in
Then profile.current_layer should still equal "heaven_2"
And the player should spawn in Heaven 2 layer geometry
```

---

## Feature 4: Themed Currency System

**System:** existing currency framework, extended | **Existing code reference:** RBX-Template currencies
**Description:** Per-biome themed currencies (earth/desert/ice/lava coins). Higher layers grant scaling rewards. Currencies are non-tradeable.

### Background

```gherkin
Given the prototype config defines biome currencies:
  | biome  | currency_id  |
  | earth  | earth_coins  |
  | desert | desert_coins |
  | ice    | ice_coins    |
  | lava   | lava_coins   |
And layer reward multipliers:
  | layer    | multiplier |
  | base     | 1.0×       |
  | heaven_1 | 1.5×       |
  | heaven_2 | 2.0×       |
  | hell_1   | 1.5×       |
  | hell_2   | 2.0×       |
```

### Scenario: Earth biome breakable in base layer drops earth coins [integration] [required]

```gherkin
Given a player in the base Earth biome
And the breakable's base reward is 10 earth_coins
When the player destroys the breakable
Then profile.earth_coins should increase by 10
```

### Scenario: Earth biome breakable in Heaven 1 drops more earth coins (same currency) [integration] [required]

```gherkin
Given a player in the Heaven 1 Earth biome
And the breakable's base reward is 10 earth_coins
And Heaven 1 multiplier is 1.5×
When the player destroys the breakable
Then profile.earth_coins should increase by 15
But no separate "blessed earth coins" should be created
```

### Scenario: Earth biome breakable in Hell 1 drops earth coins (not separate currency) [integration] [required]

```gherkin
Given a player in the Hell 1 Earth biome
And the breakable's base reward is 10 earth_coins
And Hell 1 multiplier is 1.5×
When the player destroys the breakable
Then profile.earth_coins should increase by 15
But no separate "cursed earth coins" should be created
```

### Scenario: Currency drops vary by biome [unit] [required]

```gherkin
Given a player destroying breakables across biomes
When the player destroys a breakable in earth biome
Then they receive earth_coins
When the player destroys a breakable in ice biome
Then they receive ice_coins
But the player does not receive earth_coins from the ice breakable
```

### Scenario: Currencies cannot be transferred between players [integration] [required]

```gherkin
Given two players in a trade window
And player A has 1000 earth_coins
When player A attempts to add earth_coins to the trade
Then the trade UI should reject the addition
And display "Currencies cannot be traded"
```

### Scenario: Currencies cannot be exfiltrated via API exploits [integration] [required]

```gherkin
Given a client sends a fabricated currency-transfer RemoteEvent
When the server receives the event
Then the server should reject the request
And log the attempt for security review
```

### Scenario: Light Tokens drop only from Heaven layer activities [integration] [required]

```gherkin
Given a player destroying breakables in Heaven 1 biomes
When the player destroys breakables
Then profile.light_tokens should increase
But destroying breakables in base or Hell layers should not increase light_tokens
```

### Scenario: Shadow Tokens drop only from Hell layer activities [integration] [required]

```gherkin
Given a player destroying breakables/enemies in Hell layers
When the player destroys enemies
Then profile.shadow_tokens should increase
But activities in base or Heaven layers should not increase shadow_tokens
```

---

## Feature 5: Pet Element Assignment

**System:** extends `PetGrantService` | **Existing code reference:** `configs/pets.lua`, PetGrantService
**Description:** Pets gain an element tag at hatch time based on the layer where the hatch occurred.

### Background

```gherkin
Given hatching in base layer assigns element "neutral"
And hatching in any Heaven layer assigns element "light"
And hatching in any Hell layer assigns element "shadow"
And Chaotic element is never assigned at hatch (only via fusion)
```

### Scenario: Pet hatched in base layer has neutral element [integration] [required]

```gherkin
Given a player in base layer with currency for hatching
When the player hatches an egg
Then the resulting pet record should have element = "neutral"
```

### Scenario: Pet hatched in Heaven layer has light element [integration] [required]

```gherkin
Given a player in Heaven 1 with currency for hatching
When the player hatches an egg
Then the resulting pet record should have element = "light"
```

### Scenario: Pet hatched in Hell layer has shadow element [integration] [required]

```gherkin
Given a player in Hell 1 with currency for hatching
When the player hatches an egg
Then the resulting pet record should have element = "shadow"
```

### Scenario: Element is immutable after hatch (except via fusion) [unit] [required]

```gherkin
Given a pet with element = "light"
When any non-fusion action is taken (level up, enchant, equip, trade)
Then pet.element should remain "light"
```

### Scenario: Realm eggs use distinct pet ids instead of element-split stacks [integration] [required]

```gherkin
Given a player owns a Heaven pet stack: { pet_id: "frostlight_hare", element: "light", count: 10 }
And the player is currently in a Hell layer
When the player hatches from the matching Hell egg
Then the new pet uses its Hell catalog id, such as "rimelight_hare"
And the new pet has element = "shadow"
And it never merges into the Heaven pet stack because the pet ids are different
```

### Scenario: Variant remains independent of element [unit] [required]

```gherkin
Given a pet with element = "light"
When the player applies a "gold" variant upgrade
Then pet.element should remain "light"
And pet.variant should become "gold"
```

---

## Feature 6: Pet Power Calculation (Runtime)

**System:** modifier pipeline | **Existing code reference:** existing enchant providers, new ElementResonanceProvider, ThemeUtilityProvider
**Description:** Pet power is always computed at runtime from base config + per-pet state + contextual modifiers. Never persisted.

### Background

```gherkin
Given the multiplier table for elements:
  | pet_element | heaven_biome | hell_biome | neutral_biome |
  | light       | 1.2          | 1.5        | 1.0           |
  | shadow      | 1.5          | 1.2        | 1.0           |
  | chaotic     | 1.3          | 1.3        | 1.3           |
  | neutral     | 1.0          | 1.0        | 1.0           |
```

### Scenario: Power calculation uses base from config [unit] [required]

```gherkin
Given a pet with pet_id = "frost_drake"
And configs/pets.lua entry for frost_drake has base_power = 100
And no variants, levels, enchants, or context modifiers
When the system calculates pet.power
Then the result should equal 100
```

### Scenario: Variant multiplier is applied [unit] [required]

```gherkin
Given a pet with pet_id = "frost_drake" (base 100), variant = "gold"
And gold variant multiplier = 2.0
When the system calculates pet.power
Then the result should equal 200
```

### Scenario: Element resonance multiplier applied in opposing realm [unit] [required]

```gherkin
Given a pet with pet_id = "frost_drake" (base 100), element = "light"
And the player is in Hell 1 (realm_alignment = "hell")
When the system calculates pet.power
Then the element multiplier of 1.5 should be applied
And the result should equal 150
```

### Scenario: Element resonance multiplier applied in home realm [unit] [required]

```gherkin
Given a pet with pet_id = "frost_drake" (base 100), element = "light"
And the player is in Heaven 1 (realm_alignment = "heaven")
When the system calculates pet.power
Then the element multiplier of 1.2 should be applied
And the result should equal 120
```

### Scenario: Element multiplier of 1.0 in base/neutral realm [unit] [required]

```gherkin
Given a pet with element = "light" (base 100)
And the player is in base layer (realm_alignment = "neutral")
When the system calculates pet.power
Then the element multiplier of 1.0 should be applied
And the result should equal 100
```

### Scenario: Chaotic pets have flat multiplier across realms [unit] [required]

```gherkin
Given a pet with element = "chaotic" (base 100)
When the system calculates pet.power in Heaven biome
Then the result should equal 130
When the system calculates pet.power in Hell biome
Then the result should equal 130
When the system calculates pet.power in base biome
Then the result should equal 130
```

### Scenario: All multipliers stack multiplicatively [unit] [required]

```gherkin
Given a pet with:
  | field       | value           |
  | base_power  | 100             |
  | variant     | gold (2.0x)     |
  | level       | 10 (1.5x curve) |
  | element     | light           |
  | biome       | hell (1.5x)     |
When the system calculates pet.power
Then the result should equal 100 × 2.0 × 1.5 × 1.5 = 450
```

### Scenario: Power is never persisted to pet record [unit] [required]

```gherkin
Given a pet record loaded from ProfileStore
When the system inspects the pet record's fields
Then no field named "power", "calculated_power", or similar should exist
And only identity + mutable state fields should be present
```

### Scenario: Power recalculates dynamically when player changes biome [studio] [required]

```gherkin
Given a player in Heaven 1 with a pet at calculated power = 120
When the player travels to Hell 1
Then the same pet's calculated power should change to 150 (light dominance)
But no save data should be modified
```

### Scenario: Theme utility passive applies in dichotomy biome [unit] [required]

```gherkin
Given a pet with theme = "earth"
And the dichotomy partner of "earth" is "desert"
And the player is in a desert biome
When the system queries the pet's active utility passives
Then "Deep Roots" (or equivalent earth-in-desert passive) should be active
```

### Scenario: Theme utility passive does NOT apply in non-dichotomy biome [unit] [required]

```gherkin
Given a pet with theme = "earth"
And the player is in an earth biome (home theme)
When the system queries the pet's active utility passives
Then no theme-utility passives should be active
```

---

## Feature 7: Spirit Form & Cooldowns (Unique Pets)

**System:** `SpiritFormService` (new) | **Persistence:** `lastDownedAt` field on unique pet records
**Description:** Unique pets enter Spirit Form when downed in combat. They cannot be redeployed until cooldown elapses. Recovery is faster in Heaven biomes.

### Background

```gherkin
Given the cooldown configuration:
  | content_tier         | base_cooldown_seconds |
  | trash_mob            | 60                    |
  | mid_tier             | 300                   |
  | boss                 | 1800                  |
  | chaos_rift           | 3600                  |
And Heaven biomes apply a 2× recharge speed multiplier (halving cooldown)
```

### Scenario: Healthy pet has no cooldown [unit] [required]

```gherkin
Given a unique pet with lastDownedAt = nil
When the system checks deployability
Then the pet should be deployable
And the pet's state should be "Healthy"
```

### Scenario: Pet enters Spirit Form after taking sufficient damage [studio] [required]

```gherkin
Given a unique pet in active squad in a Hell biome
And the pet has full health
When the pet takes damage equal to its max HP
Then the pet should transition to "Spirit Form"
And the pet record should have lastDownedAt = current timestamp
And the pet should be removed from active squad
And the pet should appear in inventory with a spirit-form visual indicator
```

### Scenario: Pet in Spirit Form cannot be deployed during cooldown [unit] [required]

```gherkin
Given a unique pet with lastDownedAt = 1000 seconds ago
And the pet's cooldown_seconds = 300 (mid-tier)
When the player attempts to deploy the pet to active squad
Then the deployment should be rejected
And an error message "Pet is still in spirit form" should be shown
```

### Scenario: Pet becomes deployable after cooldown elapses [unit] [required]

```gherkin
Given a unique pet with lastDownedAt = 400 seconds ago
And the pet's cooldown_seconds = 300
When the player attempts to deploy the pet
Then the deployment should succeed
And the pet should appear in active squad
And the pet's state should be "Healthy"
```

### Scenario: Cooldown is halved in Heaven biomes [unit] [required]

```gherkin
Given a unique pet with lastDownedAt = current timestamp
And the pet's cooldown_seconds = 300
And the player is in a Heaven biome
When the system computes effective cooldown
Then the effective cooldown should be 150 seconds (300 / 2)
```

### Scenario: Cooldown timing matches content tier where pet was downed [integration] [required]

```gherkin
Given a unique pet is in active squad during a boss fight (content_tier = boss, cooldown = 1800)
When the pet is downed during the boss fight
Then the pet's cooldown_seconds should be set to 1800
And not the lower mid-tier or trash-mob value
```

### Scenario: Staged degradation transitions are visible [studio] [required]

```gherkin
Given a unique pet with full HP in combat
When the pet's HP drops below 75% threshold
Then the pet's visible state should change to "Strained"
And a subtle aura/glow change should be visible
When the pet's HP drops below 25% threshold
Then the pet's visible state should change to "Critical"
And a warning UI element should appear
When the pet's HP reaches 0
Then the pet should transition to "Spirit Form" as in earlier scenario
```

### Scenario: Player can recall a Critical pet to prevent Spirit Form [studio] [required]

```gherkin
Given a unique pet in active squad with state = "Critical"
When the player issues a Recall command (e.g., hotbar tactical command)
Then the pet should return to bench
And the pet should retain its current HP (not regenerate immediately)
And the pet should NOT enter Spirit Form
```

### Scenario: Instant-recharge consumable removes cooldown [integration] [required]

```gherkin
Given a unique pet in Spirit Form with lastDownedAt = current timestamp
And the player owns an "instant_recharge_potion" consumable
When the player uses the consumable on the pet
Then the pet's lastDownedAt should be set to nil
And the pet should be immediately deployable
And the consumable count should decrease by 1
```

### Scenario: Cooldown timestamps persist across sessions [integration] [required]

```gherkin
Given a unique pet with lastDownedAt = some_past_timestamp
When the player logs out and back in
Then the pet's lastDownedAt should still equal some_past_timestamp
And the effective cooldown calculation should account for time elapsed during logout
```

### Scenario: All pets in active squad downed → graceful encounter end [studio] [required]

```gherkin
Given a player in active combat in Hell biome
And all pets in active squad are in Spirit Form
When the system detects no deployable pets remain
Then the encounter should end
And the player should be teleported to the nearest safe zone (Heaven sanctuary or hub)
And no item loss, no XP loss, no death penalty should occur
And the message "Your team needs rest" should be shown
```

---

## Feature 8: Stacked Pet Pool Model

**System:** `StackPoolService` (new) | **Persistence:** `ready_count`, `last_update` fields on stacked pet records
**Description:** Stacked common pets use a token bucket model. The stack has a `ready_count` that depletes when downed and refills over time.

### Background

```gherkin
Given a stacked pet record has fields: { pet_id, total_count, ready_count, last_update }
And the base recharge_per_instance_seconds = 300 (for mid-tier content)
```

### Scenario: New stack defaults to fully ready [unit] [required]

```gherkin
Given a player hatches a stack of 5 frost_drakes
When the stack is created
Then ready_count should equal 5
And total_count should equal 5
And last_update should be nil or current timestamp
```

### Scenario: Stack ready_count refreshes lazily on read [unit] [required]

```gherkin
Given a stack { total: 30, ready: 24, last_update: 1500 seconds ago }
And recharge_per_instance = 300 seconds
When the system queries the stack's ready_count
Then ready_count should be refreshed to min(30, 24 + floor(1500/300)) = min(30, 24 + 5) = 29
And last_update should be updated to current time
```

### Scenario: Stack ready_count caps at total_count [unit] [required]

```gherkin
Given a stack { total: 10, ready: 9, last_update: 10000 seconds ago }
And recharge_per_instance = 300
When the system queries the stack
Then ready_count should be capped at 10 (not 9 + 33 = 42)
```

### Scenario: Downing a pet from stack decrements ready_count [unit] [required]

```gherkin
Given a stack { total: 30, ready: 30, last_update: nil }
When a pet from the stack is downed in combat
Then ready_count should equal 29
And last_update should be set to current timestamp
```

### Scenario: Downing from already-empty stack is no-op [unit] [required]

```gherkin
Given a stack { total: 30, ready: 0, last_update: 100 seconds ago }
When a pet from the stack would be downed
Then ready_count should remain 0
And the stack should not "go negative"
```

### Scenario: Stack contribution scales by ready/total ratio (linear curve) [unit] [required]

```gherkin
Given a stack { total: 30, ready: 24 } with base_power = 100
And the configured contribution_curve = "linear"
When the system calculates stack contribution
Then the result should equal 100 × (24/30) = 80
```

### Scenario: Stack contribution uses sqrt diminishing curve when configured [unit] [required]

```gherkin
Given a stack { total: 30, ready: 24 } with base_power = 100
And the configured contribution_curve = "sqrt_diminishing"
When the system calculates stack contribution
Then the result should equal 100 × (sqrt(24) / sqrt(30)) ≈ 100 × 0.894 = ~89.4
```

### Scenario: Adding pets to stack increases both total and ready [integration] [required]

```gherkin
Given a stack { total: 10, ready: 5, last_update: 100 seconds ago }
When the player hatches 3 more of the same pet type with the same element
Then total_count should become 13
And ready_count should become 8 (5 + 3 new ready pets)
And last_update should remain unchanged (the refill state is unaffected)
```

### Scenario: Removing pets from stack pulls from ready first [integration] [required]

```gherkin
Given a stack { total: 30, ready: 25 }
When the player trades away 10 of this pet
Then ready_count should become 15 (25 - 10, pulled from ready)
And total_count should become 20
```

### Scenario: Removing more than ready falls through to non-ready [integration] [required]

```gherkin
Given a stack { total: 30, ready: 5 }
When the player trades away 10 of this pet
Then ready_count should become 0
And total_count should become 20
And the system should still allow the trade (deletes are not blocked by spirit form)
```

### Scenario: Cooldown of 0 means stack refills instantly [unit] [required]

```gherkin
Given a stack { total: 30, ready: 20 } in a configured 0-cooldown zone
When the system queries ready_count
Then ready_count should become 30 immediately
```

---

## Feature 9: Active Squad Hierarchy

**System:** extends existing equip service | **Persistence:** new active_squad field in player profile
**Description:** Three-tier hierarchy: Inventory (all owned), Equipped (10 followers), Active Squad (3-5 fighters).

### Background

```gherkin
Given configured limits:
  | tier          | max  |
  | inventory     | 1000 |
  | equipped      | 10   |
  | active_squad  | 5    |
And in-combat swap cooldown = 5 seconds
```

### Scenario: New player has empty active squad [unit] [required]

```gherkin
Given a newly created player profile
When the system inspects profile.active_squad
Then it should be an empty array
```

### Scenario: Pet can be moved from equipped to active squad [integration] [required]

```gherkin
Given the player has a pet in equipped slot 3
And profile.active_squad is empty
And the player is not in combat
When the player moves the pet to active squad
Then the pet should be removed from equipped slot 3
And the pet should appear in active_squad
And the move should be instant (no cooldown out of combat)
```

### Scenario: Active squad cannot exceed max size [integration] [required]

```gherkin
Given profile.active_squad has 5 pets (at max)
When the player attempts to deploy a 6th pet
Then the deployment should be rejected
And an error "Active squad full" should be shown
```

### Scenario: In-combat swap has cooldown [studio] [required]

```gherkin
Given a player in active combat
And the player has just swapped a pet 2 seconds ago
When the player attempts another swap
Then the swap should be rejected with "Swap cooldown active"
And the rejection includes remaining cooldown time
```

### Scenario: In-combat swap allowed after cooldown [studio] [required]

```gherkin
Given a player in active combat
And the player has not swapped a pet in the last 5+ seconds
When the player swaps a pet
Then the swap should succeed
And a new 5-second swap cooldown should start
```

### Scenario: Downed pet auto-returns to bench [integration] [required]

```gherkin
Given a unique pet in active squad
When the pet enters Spirit Form
Then the pet should be automatically moved out of active squad
And the pet should appear in inventory (or bench, depending on UI design)
And no swap cooldown should be triggered (this is automatic, not player action)
```

### Scenario: Stacked pets occupy one active squad slot [unit] [required]

```gherkin
Given a stack { pet_id: "frost_drake", total: 30 }
When the player deploys the stack to active squad
Then the stack occupies 1 slot in active_squad
And the remaining 4 slots are available for other deployments
But the stack's full 30 pets contribute to combat per the pool model
```

### Scenario: Active squad persists across sessions [integration] [required]

```gherkin
Given a player with specific pets in active_squad
When the player logs out and back in
Then profile.active_squad should be restored exactly
But all swap cooldowns should be reset (fresh session)
```

---

## Feature 10: Combat System (Hell-Focused)

**System:** `CombatService` (new), depends on Spirit Form, Active Squad, Modifier Pipeline
**Description:** Pets engage enemies; players support via powers. Combat respects spirit form and squad architecture.

### Background

```gherkin
Given the player is in a Hell layer biome with enemy spawners configured
And the player has 5 pets in active_squad, all Healthy
And the player has full Focus
```

### Scenario: Entering an active combat zone spawns enemies [studio] [required]

```gherkin
Given an active combat zone with configured enemy spawner
When the player enters the zone
Then enemies should spawn at configured marker points
And combat state should be set to "active"
```

### Scenario: Pets auto-attack nearest enemy by default [studio] [required]

```gherkin
Given combat is active
And no auto-target mode override is set
When pets are deployed
Then each pet should target the nearest enemy
And pet attacks should fire at configured cadence
```

### Scenario: Player has 0 HP and cannot be damaged [studio] [required]

```gherkin
Given a player in active combat
And the player's character is visible on the battlefield
When an enemy attacks the player character
Then the player should take 0 damage
And no health bar should appear above the player
And the attack should visually pass through or miss
```

### Scenario: Player powers buff own pets [integration] [required]

```gherkin
Given a player in combat with a Geomancer archetype
And the player has Stone Skin power equipped
And a pet "frost_drake" is in active squad
When the player casts Stone Skin targeting frost_drake
Then frost_drake should gain a damage-absorption shield
And the shield should match the configured Stone Skin effect
```

### Scenario: Player powers cost Focus [integration] [required]

```gherkin
Given a player with profile.focus = 100 (max)
And Stone Skin costs 20 Focus per cast
When the player casts Stone Skin
Then profile.focus should decrease to 80
And the power should go on cooldown
```

### Scenario: Power cannot be cast without sufficient Focus [unit] [required]

```gherkin
Given profile.focus = 10
And the player has a power costing 20 Focus
When the player attempts to cast the power
Then the cast should be rejected with "Insufficient Focus"
And no cooldown should be incurred
```

### Scenario: Player Focus regenerates over time [unit] [required]

```gherkin
Given profile.focus = 50 and max focus = 100
And focus_regen_per_second = 5
When 5 seconds pass with no power usage
Then profile.focus should equal 75
And focus should never exceed max_focus
```

### Scenario: Sundering enemy attacks disrupt player Focus [studio] [required]

```gherkin
Given an enemy with a "Sundering" attack ability
And the player has profile.focus = 100
When the enemy successfully lands a Sundering attack on the player
Then profile.focus should decrease per the attack's specified amount
And player power cooldowns may be extended per the attack's spec
But profile.health is never affected (no health stat exists)
```

### Scenario: Encounter ends when all enemies defeated [studio] [required]

```gherkin
Given an active combat encounter with 5 enemies
When the last enemy is defeated
Then combat state should transition to "ended"
And loot drops should be distributed per drop table
And surviving pets should remain in active squad (not auto-recalled)
```

### Scenario: Combat loot includes biome currency + Shadow Tokens in Hell [integration] [required]

```gherkin
Given the player defeats an enemy in Hell 1 Lava biome
And the enemy's drop table includes: lava_coins, shadow_tokens, occasional rare drops
When the enemy is defeated
Then the player should receive lava_coins per drop table
And the player should receive shadow_tokens per drop table
```

---

## Feature 11: Heaven Farming Mode

**System:** extends existing breakable/farming systems
**Description:** Heaven layers are farming-focused. Existing pet sim mechanics apply with scaled rewards.

### Background

```gherkin
Given the player is in a Heaven layer
And breakables spawn per existing active-zone rules
And the player has farming-capable pets equipped
```

### Scenario: Breakables in Heaven layer reward scaled currency [integration] [required]

```gherkin
Given a breakable in Heaven 1 Earth biome
And base reward is 10 earth_coins
And Heaven 1 multiplier is 1.5×
When the breakable is destroyed
Then the player receives 15 earth_coins
```

### Scenario: Heaven breakables also drop Light Tokens [integration] [required]

```gherkin
Given a breakable in Heaven 1 biome
And configured Light Token drop rate is 1 per 5 breakables
When the player destroys 5 breakables
Then approximately 1 light_token should drop (probabilistic, allow variance)
```

### Scenario: Occasional minor enemy encounters appear in Heaven [studio] [deferred]

```gherkin
Given a player farming in Heaven 1 with configured encounter chance = 1/20
When the player destroys 20 breakables on average
Then approximately 1 minor enemy should spawn
And the enemy is easy and primarily flavor (not difficult or mandatory)
```

### Scenario: Heaven biomes accelerate pet spirit form recovery [unit] [required]

```gherkin
Given a unique pet in Spirit Form with lastDownedAt = current_time
And the pet's cooldown is 300 seconds in base
When the player enters a Heaven biome
Then the effective cooldown should be 150 seconds (halved)
```

### Scenario: Idle farming progresses without active player input [studio] [required]

```gherkin
Given a player AFK in a Heaven biome with equipped pets
When the auto-target system is enabled (existing RBX-Template feature)
Then breakables should be destroyed automatically by pet attacks
And currency should accumulate without active player interaction
```

---

## Feature 12: Player Character (Spirit Presence)

**System:** `FocusService` (new)
**Description:** Player is invulnerable, ethereal, supports via powers. Has Focus stat that can be disrupted.

### Background

```gherkin
Given profile.focus_max = 100
And focus_regen_per_second = 5
```

### Scenario: Player has no HP field [unit] [required]

```gherkin
Given a player profile loaded from ProfileStore
When the system inspects the profile structure
Then no field named "health", "hp", or "max_hp" should exist on the player profile
```

### Scenario: Enemy attacks targeted at player do no damage [studio] [required]

```gherkin
Given an enemy with a damaging attack
And the enemy targets the player character (not a pet)
When the attack lands
Then the player takes 0 damage
And no health bar appears
And the attack may visually trigger but has no mechanical effect
```

### Scenario: Player avatar appears ethereal in combat [studio] [required]

```gherkin
Given a player in combat
When other clients render the player avatar
Then the avatar should have visible translucency or aura effect
And the visual treatment should match the player's alignment (golden for Light, dark for Shadow)
```

### Scenario: Player cannot die from any cause [studio] [required]

```gherkin
Given any catastrophic event (boss kill move, environmental hazard, time-out, etc.)
When the event would normally cause player death in other games
Then the player remains alive
And any "lethal" effects translate to: pets recalled, teleport to safe zone, or Focus disruption
```

### Scenario: Focus can never go below 0 [unit] [required]

```gherkin
Given profile.focus = 5
And a Sundering attack would reduce Focus by 50
When the attack lands
Then profile.focus should equal 0 (not -45)
```

### Scenario: Focus regen pauses while at zero [unit] [open]

```gherkin
Given profile.focus = 0
When 1 second elapses
Then profile.focus should regenerate per normal rate (e.g., to 5)
# OR: profile.focus should remain 0 for a "stun duration" before regen begins
# Open design question: which behavior do we want?
```

---

## Feature 13: Archetype System

**System:** `ArchetypeService` (new) | **Persistence:** profile.archetype field
**Description:** Player picks one archetype at character creation. Archetype gates power pool.

### Background

```gherkin
Given the prototype defines four archetypes: geomancer, sandwalker, cryomancer, pyromancer
And each archetype has its own power pool
```

### Scenario: New player must select archetype before playing [studio] [required]

```gherkin
Given a newly created player who has not selected an archetype
When the player joins the game
Then an archetype selection UI should appear
And the player must select one of the four archetypes
And gameplay should not begin until selection is made
```

### Scenario: Archetype is persisted [integration] [required]

```gherkin
Given a player who has selected "geomancer"
When the player logs out and back in
Then profile.archetype should still equal "geomancer"
And the archetype selection UI should not reappear
```

### Scenario: Archetype determines available power pool [unit] [required]

```gherkin
Given a player with archetype = "geomancer"
When the system queries available powers
Then the result should include geomancer-only powers (Stone Skin, Bulwark, etc.)
But should NOT include other archetypes' powers (Frost Bind, Mark of Flame, etc.)
```

### Scenario: Archetype cannot be changed without respec [integration] [required]

```gherkin
Given a player with archetype = "geomancer"
When the player attempts to change archetype mid-game (via API or UI manipulation)
Then the change should be rejected
And the player should be directed to the respec ritual
```

### Scenario: Respec ritual allows archetype change [integration] [open]

```gherkin
Given a player with archetype = "geomancer" and sufficient respec_cost tokens
When the player performs the respec ritual
Then profile.archetype can be updated to a new selection
And all power selections are reset
And all augmentation slots are returned to "unallocated"
# Open: should archetype change be its own ritual, or part of standard respec?
```

### Scenario: Alignment is orthogonal to archetype [unit] [required]

```gherkin
Given a player with archetype = "geomancer"
When profile.soul changes (Light, Shadow, or neutral)
Then profile.archetype should remain "geomancer"
And the available power pool should remain the geomancer pool
```

---

## Feature 14: Power Selection at Level-Up

**System:** extends `configs/player_progression.lua`, `PowerService` (new)
**Description:** At specific level milestones, the player chooses 1 power from a 2-option pool. Cumulative selections shape the build.

### Background

```gherkin
Given the prototype defines power-select levels: 5, 10, 15, 20, 30
And each level has 2 options from the player's archetype pool
And profile.powers stores the ordered list of selected powers
```

### Scenario: Player at level 4 has no power selections pending [unit] [required]

```gherkin
Given a player at level 4 with profile.powers = []
When the system checks pending power selections
Then no selection prompt should be triggered
```

### Scenario: Reaching level 5 triggers power selection [studio] [required]

```gherkin
Given a player at level 4 with profile.powers = []
When the player levels up to 5
Then a power selection UI should appear
And the UI should show 2 tier-1 powers from the player's archetype pool
And the player must choose before continuing
```

### Scenario: Power selection persists [integration] [required]

```gherkin
Given a player who selects "Stone Skin" at level 5
When the player logs out and back in
Then profile.powers should include "Stone Skin"
And no power-select UI should reappear for level 5
```

### Scenario: Each level grants at most one selection [unit] [required]

```gherkin
Given a player at level 5
When the player completes the selection
Then no further power-select UI should appear until level 10
```

### Scenario: Skipping a level-up power selection is not allowed [studio] [required]

```gherkin
Given a player at level 5 with pending power selection
When the player attempts to exit the selection UI without choosing
Then the UI should reject the exit attempt
Or the system should auto-select the first option (configurable)
```

### Scenario: Power selections accumulate across levels [unit] [required]

```gherkin
Given a player at level 30 who has selected powers at every milestone
When the system queries profile.powers
Then the list should contain exactly 5 powers (one per milestone: 5, 10, 15, 20, 30)
```

### Scenario: Cannot select a power from another archetype [unit] [required]

```gherkin
Given a player with archetype = "geomancer"
When the system constructs the power-select UI options
Then options should only come from the geomancer pool
But other archetype powers should not be presented
```

### Scenario: Respec resets all power selections [integration] [required]

```gherkin
Given a player with profile.powers = ["Stone Skin", "Bulwark", "Mountain's Strength"]
When the player completes the respec ritual
Then profile.powers should become []
And the player should be prompted to re-select powers at appropriate level milestones
```

---

## Feature 15: Augmentation Slots

**System:** `AugmentationService` (new) | **Persistence:** profile.slots
**Description:** Slot rewards interleaved with power selection. Slots applied to powers; matching types trigger set bonuses.

### Background

```gherkin
Given slot-grant levels: 8, 12, 18, 25, 35, 45
And slot types: recharge, strength, range, duration, efficiency, reliability
And max slots per power = 6
And set bonus thresholds: 3 of same type, 4 of same type, 5 of same type
```

### Scenario: Reaching slot-grant level adds a slot [integration] [required]

```gherkin
Given a player at level 7 with 0 slots
When the player levels up to 8
Then the player should receive 1 unallocated slot
And the slot allocation UI should be accessible
```

### Scenario: Slot can be placed on any unlocked power [integration] [required]

```gherkin
Given a player with profile.powers = ["Stone Skin"]
And the player has 1 unallocated slot of type "recharge"
When the player places the slot on Stone Skin
Then Stone Skin's effective cooldown should decrease by the configured per-slot amount (e.g., 5%)
And profile.slots.stone_skin should contain 1 entry of type "recharge"
```

### Scenario: Slot cannot be placed on a locked (unselected) power [unit] [required]

```gherkin
Given a player who has not unlocked "Bulwark"
And the player has 1 unallocated slot
When the player attempts to place the slot on Bulwark
Then the placement should be rejected
And an error "Power not unlocked" should be shown
```

### Scenario: Slot count per power cannot exceed maximum [unit] [required]

```gherkin
Given a power with 6 slots already placed (at max)
When the player attempts to place a 7th slot
Then the placement should be rejected
And an error "Max slots reached" should be shown
```

### Scenario: 3 matching slot types in same power trigger set bonus [unit] [required]

```gherkin
Given a player places 3 "recharge" slots on Stone Skin
When the system computes power effects
Then the set bonus of "+5% cooldown reduction on ALL powers" should activate
And this bonus should apply globally (not just to Stone Skin)
```

### Scenario: Higher-tier matching sets grant stronger bonuses [unit] [required]

```gherkin
Given a player places 4 "recharge" slots on a single power
When the system computes set bonuses
Then both the 3-slot bonus and the 4-slot bonus should apply
And the 4-slot bonus should be configured as stronger than the 3-slot
```

### Scenario: Slot allocations persist [integration] [required]

```gherkin
Given a player with allocated slots on multiple powers
When the player logs out and back in
Then all slot allocations should be exactly restored
```

### Scenario: Respec returns all slots to unallocated [integration] [required]

```gherkin
Given a player with multiple slot allocations
When the player respecs
Then all slots return to the unallocated pool
And the player can re-allocate them
And total slot count is preserved (not lost)
```

### Scenario: Slot bonuses flow through the modifier pipeline [integration] [required]

```gherkin
Given a power with a "strength" slot applied (+5% magnitude)
When the player casts the power
Then the magnitude (heal amount, buff strength, etc.) should be 5% higher than base
And this should be calculated at cast time via the modifier pipeline
```

---

## Feature 16: Hotbar / Command Bar

**System:** `HotbarService` (new)
**Description:** 20-slot hotbar with 4 bind types: Power, Roster Macro, Specific Pet, Tactical Command.

### Background

```gherkin
Given the hotbar has 20 slots (1-9, 0, Shift+1-9, Shift+0)
And each slot can hold one bind: { type, target }
And bind types: "power", "roster", "specific_pet", "tactical"
```

### Scenario: Hotbar initializes with archetype defaults for new players [integration] [required]

```gherkin
Given a new player has just selected geomancer archetype
When the hotbar is initialized
Then slots 1-4 should be bound to starter Geomancer powers
And slots 5-7 should be bound to default roster macros
And slots 8-10 should be bound to default tactical commands
And Shift+1-0 should be empty by default
```

### Scenario: Player can rebind a slot to any valid bind type [integration] [required]

```gherkin
Given a player with hotbar slot 1 bound to "Stone Skin" (power)
And the player owns a roster named "Healer Team"
When the player rebinds slot 1 to roster "Healer Team"
Then hotbar[1] should become { type: "roster", target: "Healer Team" }
```

### Scenario: Hotbar bindings persist [integration] [required]

```gherkin
Given a player with customized hotbar bindings
When the player logs out and back in
Then all hotbar bindings should be exactly restored
```

### Scenario: Pressing a hotbar key fires the bound action [studio] [required]

```gherkin
Given hotbar[1] = { type: "power", target: "stone_skin" }
And the player is in combat with available Focus and Stone Skin off cooldown
When the player presses the "1" key
Then Stone Skin should be cast (per Feature 10)
```

### Scenario: Pressing a roster macro key swaps active squad [studio] [required]

```gherkin
Given hotbar[5] = { type: "roster", target: "Healer Team" }
And the player owns a "Healer Team" roster with 3 pets in it
When the player presses the "5" key
Then the active squad should be swapped per the roster's deploy rules (Feature 17)
```

### Scenario: Pressing a tactical command affects all active pets [studio] [required]

```gherkin
Given hotbar[8] = { type: "tactical", target: "scatter" }
And active squad has 5 pets in close formation
When the player presses the "8" key
Then all active squad pets should spread out per the scatter command spec
```

### Scenario: Cooldown overlay displays on slot [studio] [required]

```gherkin
Given hotbar[1] = power "stone_skin" which is on cooldown for 30 seconds
When the player views the hotbar
Then slot 1 should display a radial sweep showing 30 seconds remaining
And the slot icon should appear dimmed
```

### Scenario: Insufficient resources prevent activation but show feedback [studio] [required]

```gherkin
Given hotbar[1] = power costing 20 Focus
And profile.focus = 10
When the player presses the "1" key
Then the power should not activate
And visual/audio feedback should indicate insufficient Focus
And the slot should briefly flash with an error indicator
```

### Scenario: Empty slot does nothing on press [unit] [required]

```gherkin
Given hotbar[15] is empty
When the player presses Shift+5 (slot 15)
Then no action should fire
And no error message should appear
```

### Scenario: Mobile UI shows reduced slot count [studio] [required]

```gherkin
Given a mobile client
When the hotbar is rendered
Then 5-6 slots should be visible at once
And a swipe-to-secondary-tray affordance should be available
And the underlying bindings should match desktop (no data loss)
```

---

## Feature 17: Roster System

**System:** `RosterService` (new) | **Persistence:** profile.rosters
**Description:** Player-defined named teams of pets. Hotbar macros invoke rosters. Injury rules govern how downed pets are handled.

### Background

```gherkin
Given a roster has structure: { name, ordered_pets, max_to_deploy, injury_rule }
And injury_rule options: "ready_only", "best_available", "deploy_anyway"
And default injury_rule is "ready_only"
```

### Scenario: Player can create a new roster [integration] [required]

```gherkin
Given a player with no existing rosters
When the player creates a roster named "Healer Team" with 3 pets and max_to_deploy = 2
Then profile.rosters should contain an entry { name: "Healer Team", ordered_pets: [...3 ids], max_to_deploy: 2, injury_rule: "ready_only" }
```

### Scenario: Roster pet order is preserved [unit] [required]

```gherkin
Given a roster with ordered_pets = ["pet_A", "pet_B", "pet_C"]
When the system iterates the roster for deployment
Then the iteration order should be pet_A, then pet_B, then pet_C
And not alphabetical, randomized, or sorted by stat
```

### Scenario: Roster call deploys ordered pets up to max [studio] [required]

```gherkin
Given a roster "Healer Team" with ordered_pets = [pet_A, pet_B, pet_C, pet_D] and max_to_deploy = 3
And all 4 pets are ready (no spirit form)
When the player invokes the roster (via hotbar macro)
Then active squad should be set to [pet_A, pet_B, pet_C]
And pet_D remains on bench
```

### Scenario: injury_rule "ready_only" skips spirit-form pets [studio] [required]

```gherkin
Given a roster with ordered_pets = [pet_A, pet_B, pet_C] and max_to_deploy = 3
And pet_B is in spirit form
And injury_rule = "ready_only"
When the roster is invoked
Then active squad should contain [pet_A, pet_C]
And the third slot should be empty (only 2 ready pets in roster)
And pet_B is NOT auto-substituted from outside the roster
```

### Scenario: injury_rule "best_available" picks most-recovered pets [unit] [required]

```gherkin
Given a roster with [pet_A (ready), pet_B (spirit, 50% recovered), pet_C (spirit, 80% recovered)] and max_to_deploy = 3
And injury_rule = "best_available"
When the roster is invoked
Then active squad should contain [pet_A, pet_C, pet_B] in that order (most-recovered first among injured)
```

### Scenario: injury_rule "deploy_anyway" uses original order regardless [unit] [required]

```gherkin
Given a roster with [pet_A, pet_B (spirit), pet_C (spirit)] and max_to_deploy = 3
And injury_rule = "deploy_anyway"
When the roster is invoked
Then active squad should contain [pet_A, pet_B, pet_C] in that order
And pet_B and pet_C contribute reduced effectiveness (per their spirit state)
But they are deployed anyway
```

### Scenario: A pet can appear in multiple rosters [unit] [required]

```gherkin
Given the player creates "Healer Team" containing pet_A
When the player also creates "Hell Squad" containing pet_A
Then both rosters should validly contain pet_A
And no error or warning should be raised
```

### Scenario: Invoking a roster replaces the active squad (default) [unit] [required]

```gherkin
Given active squad currently contains [pet_X, pet_Y]
And the player invokes a roster containing [pet_A, pet_B, pet_C]
When the roster invocation completes
Then active squad should be [pet_A, pet_B, pet_C] (replacement, not addition)
And pet_X and pet_Y are returned to bench
```

### Scenario: Deleting a pet referenced in roster removes the reference [integration] [required]

```gherkin
Given a roster containing pet_A
When the player permanently deletes pet_A
Then the roster's ordered_pets should no longer contain pet_A
And the roster otherwise remains intact
```

### Scenario: Trading away a pet referenced in roster removes the reference [integration] [required]

```gherkin
Given a roster containing pet_A
When the player trades pet_A to another player
Then the roster's ordered_pets should no longer contain pet_A
```

### Scenario: Roster max_to_deploy cannot exceed active squad capacity [integration] [required]

```gherkin
Given active squad capacity is 5
When a player attempts to create a roster with max_to_deploy = 10
Then the system should clamp max_to_deploy to 5
Or reject the creation with a validation error
```

### Scenario: Roster persists across sessions [integration] [required]

```gherkin
Given a player with 3 named rosters
When the player logs out and back in
Then all rosters should be exactly restored
```

---

## Feature 18: Multiplayer / Group Play

**System:** existing party system + cross-player support
**Description:** Up to 4 players. Cross-player support powers. Difficulty scales.

### Background

```gherkin
Given the configured max group size = 4
And each player has their own active squad of 5
And cross-player support powers are enabled by default
```

### Scenario: Players can form a party [studio] [required]

```gherkin
Given two players online
When player A sends a party invite to player B
And player B accepts
Then both players should be in the same party
And both should see the other's avatar/name in party UI
```

### Scenario: Party can grow to max size [studio] [required]

```gherkin
Given a party of 3 players
And a 4th player accepts an invite
When the join completes
Then party size = 4
When a 5th player attempts to join
Then the join should be rejected with "Party full"
```

### Scenario: Cross-player support power buffs ally pets [studio] [required]

```gherkin
Given player A (Geomancer) and player B in the same party
And player A casts Bless (AoE buff) near player B's active pets
When the buff is applied
Then player B's pets should receive the Bless effect
And the effect duration matches the configured spec
```

### Scenario: Damage is attributed correctly in groups [integration] [required]

```gherkin
Given a 4-player party fighting a shared enemy
And the enemy is defeated
When the system computes damage attribution
Then each player receives credit proportional to their pets' contributions
And an MVP bonus is awarded to the highest contributor
```

### Scenario: Loot is distributed per party rules [integration] [required]

```gherkin
Given a 4-player party that defeats a boss with 100 lava_coins drop
And configured loot rule = "split equally"
When the boss is defeated
Then each player receives 25 lava_coins
```

### Scenario: Encounter difficulty scales with party size [studio] [required]

```gherkin
Given a configured encounter with base HP = 1000 for solo
And the encounter's group scaling multiplier = 1.5× per additional player
When a 4-player party enters
Then enemy HP should be 1000 × (1 + 0.5 × 3) = 2500 (or per configured curve)
```

### Scenario: One player's pet downed does not affect other players' pets [studio] [required]

```gherkin
Given a party of 4 players in combat
And player A's pet is downed
When player A's pet enters spirit form
Then player A's active squad is updated
But players B, C, D's active squads remain unchanged
```

### Scenario: Player wiping (all pets down) does not end party encounter [studio] [required]

```gherkin
Given a 4-player party with player A's pets all downed
And players B, C, D still have active pets
When player A is teleported to safe zone
Then the encounter continues for B, C, D
And player A can rejoin from safe zone (or wait it out)
```

---

## Feature 19: Trade System

**System:** existing planned trade marketplace + new constraints
**Description:** Pets are tradeable; currencies and account-bound items are not. Trade is server-authoritative with anti-duplication.

### Background

```gherkin
Given the tradeable-item config marks:
  - all pets: tradeable
  - all currencies: not tradeable
  - augmentation slots: deferred decision
  - cosmetics: tradeable
```

### Scenario: Two players can initiate a trade [studio] [required]

```gherkin
Given two players in close proximity
When player A initiates a trade request to player B
And player B accepts
Then a trade UI should open showing both players' offered items
```

### Scenario: Pets can be added to trade [integration] [required]

```gherkin
Given an open trade between players A and B
And player A owns pet_X
When player A adds pet_X to the trade
Then the trade UI should display pet_X in player A's offer slot
```

### Scenario: Currencies cannot be added to trade [integration] [required]

```gherkin
Given an open trade
When either player attempts to add any biome currency or token
Then the addition should be rejected
And an error "Currencies cannot be traded" should be shown
```

### Scenario: Trade requires both players to confirm [studio] [required]

```gherkin
Given an open trade with both players having added items
When only player A confirms
Then the trade should not execute
When player B also confirms
Then the trade should execute
And ownership of items should swap
```

### Scenario: Trade is atomic (anti-duplication) [integration] [required]

```gherkin
Given a trade in progress
When a network disconnect or error occurs mid-execution
Then either the full trade completes or none of it does
And no item should exist in both players' inventories
And no item should be deleted from both inventories
```

### Scenario: Trade history is logged for audit [integration] [required]

```gherkin
Given a successfully completed trade
When the trade completes
Then a trade-history record should be saved
And the record should include both players, items, timestamp
And the record should be queryable for support/audit purposes
```

### Scenario: Locked pets cannot be traded [integration] [required]

```gherkin
Given a pet with lock_state = "locked" in player A's inventory
When player A attempts to add the pet to trade
Then the addition should be rejected
And an error "Pet is locked. Unlock before trading." should be shown
```

---

## Feature 20: Chaotic Fusion

**System:** `FusionService` (new)
**Description:** Sacrifice 1 Light + 1 Shadow pet at fusion altar to produce 1 Chaotic pet.

### Background

```gherkin
Given a fusion altar exists in the Central Hub
And fusion requires: 1 Light element pet + 1 Shadow element pet
And both inputs are consumed (permanently)
And the output is a Chaotic pet of the same theme family (or per fusion recipe)
```

### Scenario: Fusion accepts valid Light + Shadow pets [studio] [required]

```gherkin
Given a player at the fusion altar
And player owns Light pet_A and Shadow pet_B (both unique pets)
When the player initiates fusion with pet_A and pet_B
Then a confirmation modal should appear listing both pets to be sacrificed
And the resulting Chaotic pet preview is shown
```

### Scenario: Fusion requires explicit confirmation [studio] [required]

```gherkin
Given a fusion confirmation modal is open
When the player closes the modal without confirming
Then no fusion executes
And both input pets remain unchanged in the player's inventory
```

### Scenario: Fusion consumes inputs and produces Chaotic output [integration] [required]

```gherkin
Given a confirmed fusion of pet_A (Light) and pet_B (Shadow)
When the fusion executes
Then pet_A should be permanently removed from inventory
And pet_B should be permanently removed from inventory
And a new pet with element = "chaotic" should be added to inventory
And the new pet's theme should match the fusion recipe
```

### Scenario: Fusion rejects same-element inputs [unit] [required]

```gherkin
Given two Light element pets selected for fusion
When the player initiates fusion
Then the system should reject the operation
And display "Fusion requires one Light and one Shadow pet"
```

### Scenario: Fusion rejects Chaotic inputs [unit] [required]

```gherkin
Given a Chaotic pet selected as one of the fusion inputs
When the player initiates fusion
Then the system should reject the operation
And display "Cannot fuse Chaotic pets"
```

### Scenario: Fusion rejects Neutral inputs [unit] [required]

```gherkin
Given a Neutral element pet selected as one of the fusion inputs
When the player initiates fusion
Then the system should reject the operation
And display "Fusion requires aligned pets (Light + Shadow)"
```

### Scenario: Fusion log is recorded for audit [integration] [required]

```gherkin
Given a successful fusion
When the fusion completes
Then a fusion-history record should be saved with: input pet ids, output pet id, timestamp, player id
```

### Scenario: Fusion can use stacked pets [integration] [open]

```gherkin
Given a stack of Light frost_drakes (count = 10) and a stack of Shadow ember_wraiths (count = 5)
When the player attempts fusion using 1 from each stack
Then the fusion should accept (consuming 1 from each stack, decreasing count)
And a new Chaotic pet is produced
# Open: should fusion only accept unique pets, or also stacks?
```

---

## Feature 21: Chaos Rifts (Endgame Events)

**System:** Time-limited content system | **Status:** [deferred] to later phase
**Description:** Rare events where Chaotic pets dominate.

### Background

```gherkin
Given Chaos Rifts open at configured event times
And Rift content multipliers:
  | element | multiplier |
  | light   | 0.5×       |
  | shadow  | 0.5×       |
  | chaotic | 2.0×       |
  | neutral | 0.5×       |
```

### Scenario: Chaos Rift opens at scheduled time [studio] [deferred]

```gherkin
Given the configured event time for a Chaos Rift arrives
When the system checks event schedule
Then a Chaos Rift should spawn at the designated location (e.g., Central Hub)
And all players should receive a notification
```

### Scenario: Element multipliers reverse in Chaos Rift [unit] [deferred]

```gherkin
Given a Chaotic pet with base power 100 inside an active Chaos Rift
When the system calculates pet.power
Then the result should equal 100 × 2.0 = 200
```

### Scenario: Light pets are penalized in Chaos Rift [unit] [deferred]

```gherkin
Given a Light pet with base power 100 inside a Chaos Rift
When the system calculates pet.power
Then the result should equal 100 × 0.5 = 50
```

### Scenario: Chaos Rift drops include Aether [integration] [deferred]

```gherkin
Given a player defeats a Chaos Rift enemy
When the enemy's drop table includes Aether
Then the player receives Aether to profile.aether
And other rewards drop per the rift's drop table
```

---

## Feature 22: UI / Side Menu

**System:** Existing UI infrastructure + new tabs
**Description:** Persistent side menu with tabs for Active, Bench, Inventory, Rosters, Powers, Hotbar, Achievements, Pet Index.

### Scenario: Side menu is accessible at all times [studio] [required]

```gherkin
Given a player in-game (any context)
When the player opens the side menu
Then the menu should appear without interrupting gameplay
And tabs should be visible: Active, Bench, Inventory, Rosters, Powers, Hotbar, Achievements, Pet Index
```

### Scenario: Tab switching is instant [studio] [required]

```gherkin
Given the side menu is open on the Active tab
When the player clicks the Inventory tab
Then the view should switch immediately (< 200ms)
```

### Scenario: Inventory tab supports filtering by alignment [studio] [required]

```gherkin
Given the Inventory tab is open
When the player selects filter "Light element"
Then only pets with element = "light" should be displayed
```

### Scenario: Inventory tab supports filtering by theme [studio] [required]

```gherkin
Given the Inventory tab is open
When the player selects filter "Earth theme"
Then only pets with theme = "earth" should be displayed
```

### Scenario: Multiple filters can be combined [studio] [required]

```gherkin
Given the Inventory tab is open
When the player selects filter "Light" AND filter "Earth"
Then only pets with element = "light" AND theme = "earth" should be displayed
```

### Scenario: Status filter excludes spirit form pets when "Ready only" selected [studio] [required]

```gherkin
Given the Inventory tab is open with status filter "Ready only"
When the system queries pets to display
Then pets currently in spirit form should be hidden
```

### Scenario: In-combat mode hides editor tabs [studio] [required]

```gherkin
Given a player enters active combat
When the side menu state is checked
Then the Powers and Hotbar tabs should be hidden or in read-only mode
And the Active and Bench tabs should auto-focus
```

### Scenario: Out-of-combat mode allows full editing [studio] [required]

```gherkin
Given a player is in a safe zone (out of combat)
When the side menu is opened
Then all tabs are editable
And the player can manage rosters, allocate slots, rebind hotbar, etc.
```

### Scenario: Mobile UI collapses to bottom drawer [studio] [required]

```gherkin
Given a mobile client
When the side menu is opened
Then it should appear as a bottom drawer (not a side panel)
And tabs should be touch-friendly (large hit targets)
```

---

## Feature 23: Mobile Adaptations

**System:** UI configuration | **Description:** Mobile clients receive simplified UI without losing functionality.

### Scenario: Mobile client detection [unit] [required]

```gherkin
Given a player joins from a mobile client
When the system queries the client platform
Then the platform should be identified as "mobile"
And mobile-specific UI configurations should activate
```

### Scenario: Mobile hotbar shows fewer slots [studio] [required]

```gherkin
Given a mobile client with full hotbar configured
When the hotbar UI is rendered
Then 5-6 slots should be visible at once
And a clear affordance (swipe, button) exists to access remaining slots
```

### Scenario: Mobile bindings sync with desktop [integration] [required]

```gherkin
Given a player has customized their hotbar on desktop
When the player logs in on mobile
Then the same bindings should be reflected
And the mobile UI presents them in the adapted layout (without losing bindings)
```

### Scenario: Touch hit targets meet accessibility minimums [studio] [required]

```gherkin
Given a mobile UI element (hotbar slot, button, tab)
When the element is rendered
Then the touch hit target should be at least 44×44 pixels
And spacing between adjacent targets prevents fat-finger errors
```

---

## Feature 24: Pet Deletion (Safeguards)

**System:** existing pet management + confirmation flow
**Description:** Pet deletion is irreversible; confirmation is required.

### Scenario: Deleting a common pet requires single confirmation [studio] [required]

```gherkin
Given a player owns a common stacked pet
When the player initiates deletion
Then a confirmation modal should appear
And require explicit "Yes, delete" tap before executing
```

### Scenario: Deleting a unique pet shows full pet details before confirm [studio] [required]

```gherkin
Given a player owns a unique pet "Phantom Spectral" (level 25, with enchants)
When the player initiates deletion
Then the modal should show: pet name, level, enchants, serial (if huge)
And require explicit confirmation
```

### Scenario: Deleting a locked pet is rejected [integration] [required]

```gherkin
Given a pet with lock_state = "locked"
When the player attempts to delete the pet
Then deletion should be rejected
And an error "Pet is locked. Unlock first." should be shown
```

### Scenario: Bulk delete of stacked pets allowed with single confirmation [studio] [required]

```gherkin
Given a stack of 50 common pets
When the player initiates "delete 20"
Then a single confirmation modal should show the count
And confirmation deletes 20 from the stack (total_count drops by 20)
```

### Scenario: Bulk delete cannot bypass per-pet confirmation for unique pets [integration] [required]

```gherkin
Given a player selects multiple unique pets for deletion
When the player initiates the bulk action
Then each unique pet requires its own confirmation
Or the bulk action is rejected with "Use individual delete for unique pets"
```

### Scenario: Eternal/Huge pet deletion requires extra confirmation [integration] [required]

```gherkin
Given a player attempts to delete an Eternal or Huge pet
When the standard confirmation is shown
Then an additional confirmation step is required (e.g., typing the pet's name)
And only after both steps does deletion execute
```

---

## Feature 25: Edge Cases & Error Handling

### Scenario: Server validates all state-changing actions [integration] [required]

```gherkin
Given any state-changing client request (currency spend, pet swap, power cast, portal use, trade, fusion)
When the server receives the request
Then the server should re-validate all preconditions
And reject requests with mismatched state
And log mismatches for security review
```

### Scenario: Player profile load failure has graceful fallback [integration] [required]

```gherkin
Given a player joins with a corrupted or missing profile
When the system attempts to load the profile
Then a default profile should be created
And the player should not be locked out of the game
And the error should be logged for investigation
```

### Scenario: Layer travel rejected on missing or invalid layer ID [unit] [required]

```gherkin
Given a portal request with target_layer = "fake_layer"
When the system processes the request
Then it should reject with "Invalid layer"
And not perform any teleport
And not deduct any tokens
```

### Scenario: Profile schema migrations handle missing new fields [integration] [required]

```gherkin
Given an existing player profile from before the alignment system was added
When the player joins after deploy
Then any missing fields (soul, archetype, light_tokens, etc.) should be initialized to safe defaults
And the player can play normally
```

### Scenario: Concurrent modifications to active squad are serialized [integration] [required]

```gherkin
Given two rapid client requests to modify active_squad (e.g., hotbar mash)
When the server processes them
Then they should be serialized (executed one at a time)
And the final state should be consistent with both ops applied in order
And no race-condition state corruption should occur
```

### Scenario: Pet count cap is enforced [integration] [required]

```gherkin
Given a player at the configured inventory cap (e.g., 1000 pets)
When the player attempts to hatch another pet
Then the hatch should be rejected with "Inventory full"
And the player should be prompted to delete or trade pets
```

### Scenario: Pet records cannot be modified by client [integration] [required]

```gherkin
Given a client sends a RemoteEvent with manipulated pet fields
When the server receives the event
Then it should reject any direct pet field modifications
And only allow modifications through authorized service endpoints
```

---

## Feature 26: Template vs Prototype Configurability

### Scenario: Game-specific values are config-driven [unit] [required]

```gherkin
Given the prototype config defines four archetypes
When the developer creates a new game on RBX-Template
And replaces configs/archetypes.lua with a different set
Then no service code change should be required
And the new archetype set should fully function
```

### Scenario: Element multiplier matrix is config-driven [unit] [required]

```gherkin
Given the prototype config defines a 3-element matrix (light/shadow/chaotic)
When a different game on the template defines a 5-element matrix
Then the same modifier provider code should support both
And the matrix size is read from config at runtime
```

### Scenario: Layer count and depth are configurable [unit] [required]

```gherkin
Given the prototype defines 3 layers per realm (Heaven 1/2/3)
When a different game configures 9 layers per realm (Dante-style)
Then the layer system should handle 9 without code changes
And all layer-traversal logic should generalize
```

### Scenario: Pet config additions don't require code changes [unit] [required]

```gherkin
Given the prototype has N pet entries in configs/pets.lua
When a developer adds a new pet entry with valid fields
Then the new pet should appear in hatch pools, drop tables, and modifier calculations
And no service code modification should be required
```

### Scenario: New configs introduced by this design respect the pattern [unit] [required]

```gherkin
Given the new configs: configs/elements.lua, configs/theme_utility.lua, configs/archetypes.lua, configs/powers.lua, configs/augmentation.lua, configs/enemies.lua, configs/cooldowns.lua, configs/combat.lua, configs/rosters.lua, configs/portals.lua
When the developer modifies any of these configs (within valid schemas)
Then game behavior changes accordingly
And no service code modification is required
```

---

## Feature 27: Performance & Scale

### Scenario: 4-player party with full squads renders smoothly [studio] [required]

```gherkin
Given a 4-player party in active Hell combat
And each player has 5 pets in active squad (20 pets total)
And enemies spawn at configured density (5-10 mobs)
When combat is active for 30+ seconds
Then frame rate should remain above 30 FPS on baseline test hardware
And no significant memory leaks should occur
```

### Scenario: Stacked pets render as single entity [studio] [required]

```gherkin
Given an active squad slot containing a stack of 30 frost_drakes
When the active squad is rendered
Then a single visual entity (aura/spectral form) should appear
And not 30 individual pet meshes
```

### Scenario: Streaming radius prevents over-streaming [studio] [required]

```gherkin
Given a player in Heaven 1 at Y=+2000
And configured StreamingTargetRadius = 512 studs
When the player is rendered
Then geometry outside the streaming radius should not be loaded
And geometry in other layers (base, Hell, Heaven 2) should not be loaded
```

### Scenario: Modifier pipeline computes quickly even with many providers [unit] [required]

```gherkin
Given a pet power calculation involving 10+ stacked modifier providers
When the calculation runs
Then it should complete in under 1ms (target)
And caching/memoization should be applied where modifier inputs are stable
```

### Scenario: Save profile writes are batched [integration] [required]

```gherkin
Given multiple state changes within a short window (e.g., 1 second)
When ProfileStore writes occur
Then writes should be batched (not one write per change)
And the batched write should respect ProfileStore rate limits
```

---

## Appendix A: Test Coverage Matrix

The following table maps test levels to feature coverage. Use this to prioritize test development:

| Feature | Unit | Integration | Studio |
|---|---|---|---|
| 1. Ring Map Topology | ✓ | ✓ | — |
| 2. Soul Stat | ✓ | ✓ | ✓ |
| 3. Layer Access & Portals | ✓ | ✓ | ✓ |
| 4. Themed Currencies | ✓ | ✓ | — |
| 5. Pet Element Assignment | — | ✓ | — |
| 6. Pet Power Calculation | ✓ | — | ✓ |
| 7. Spirit Form & Cooldowns | ✓ | ✓ | ✓ |
| 8. Stacked Pet Pool | ✓ | ✓ | — |
| 9. Active Squad Hierarchy | ✓ | ✓ | ✓ |
| 10. Combat System | — | ✓ | ✓ |
| 11. Heaven Farming Mode | ✓ | ✓ | ✓ |
| 12. Player Character (Spirit) | ✓ | — | ✓ |
| 13. Archetype System | ✓ | ✓ | ✓ |
| 14. Power Selection | ✓ | ✓ | ✓ |
| 15. Augmentation Slots | ✓ | ✓ | — |
| 16. Hotbar | ✓ | ✓ | ✓ |
| 17. Roster System | ✓ | ✓ | ✓ |
| 18. Multiplayer | — | ✓ | ✓ |
| 19. Trade System | — | ✓ | ✓ |
| 20. Chaotic Fusion | ✓ | ✓ | ✓ |
| 21. Chaos Rifts | ✓ | ✓ | ✓ |
| 22. UI / Side Menu | — | — | ✓ |
| 23. Mobile Adaptations | ✓ | ✓ | ✓ |
| 24. Pet Deletion | — | ✓ | ✓ |
| 25. Edge Cases | ✓ | ✓ | — |
| 26. Template Configurability | ✓ | — | — |
| 27. Performance & Scale | ✓ | ✓ | ✓ |

---

## Appendix B: Implementation Checklist Per Phase

Maps to design doc Section 28 phasing. Each phase has the GWT features to focus on:

**Phase 1 (Foundations):** Features 1, 4 (partial)
**Phase 2 (Soul & Heaven Layers):** Features 2, 3, 4 (full), 11
**Phase 3 (Spirit Form + Active Squad):** Features 7, 8, 9
**Phase 4 (Element System):** Features 5, 6
**Phase 5 (Hell + Basic Combat):** Features 10, 12
**Phase 6 (Archetypes & Powers):** Features 13, 14
**Phase 7 (Hotbar & Rosters):** Features 16, 17
**Phase 8 (Augmentation):** Feature 15
**Phase 9 (Multiplayer):** Feature 18
**Phase 10 (Deep Hell + Chaotic):** Features 19, 20, 21
**Phase 11 (Endgame & Polish):** Features 22, 23 (full), 24, 25

---

## Appendix C: Open Questions & Deferred Decisions

The following scenarios are tagged [open] or [deferred] in the spec. These need decisions before implementation:

| Scenario | Question |
|---|---|
| Feature 12 — "Focus regen pauses while at zero" | Should Focus pause briefly at 0 (stun effect) or always regenerate? |
| Feature 13 — Archetype change | Should archetype change be its own ritual, or part of general respec? |
| Feature 20 — Fusion can use stacked pets | Should fusion accept stacked-pet inputs, or only unique pets? |
| Feature 21 — Chaos Rifts | Full design deferred to later phase; current scenarios are sketches. |

Resolve these before reaching the phase they're in. Document decisions in `docs/wiki/DECISIONS.md`.

---

## Appendix D: Glossary

(Defer to the glossary in DESIGN_DOCUMENT.md, Section 30.)

---

*End of GWT acceptance specification. Word count target: ~20,000 words covering ~250 scenarios. Use scenarios as direct test specifications and as architectural reference.*
