# Pet Realm Game — Complete Design Document

**Status:** Design specification for handoff to coding agent
**Source codebase:** [sploithunter/RBX-Template](https://github.com/sploithunter/RBX-Template) (Rojo, config-as-code Roblox template)
**Document purpose:** Capture the design conversation in implementable form. Intended to be split into multiple architecture documents on the consumer side as needed.

---

## 0. How To Read This Document

This document covers **two distinct layers**:

1. **Template-level abstractions** — generic mechanics that any game built on RBX-Template could use. These belong in the template's core systems and configs.
2. **Prototype-game specifics** — the heaven/hell pet game we're prototyping. These live in this game's config files and content.

Wherever a section makes a design decision that should be **configurable** rather than hard-coded, it's marked **[TEMPLATE]**. Wherever a specific value or naming is chosen for our prototype, it's marked **[PROTOTYPE]**.

The goal is that someone else could fork RBX-Template, ignore the prototype configs, and build a completely different game (sci-fi, fantasy, modern) using the same systems.

### Existing codebase context this document assumes

The RBX-Template codebase already has:
- Rojo + Wally toolchain, config-as-code pattern in `configs/*.lua`
- Server-authoritative ProfileStore persistence
- Mixed pet inventory (stacked vs unique pet records)
- Active-zone breakable spawning with entry/exit lifecycle
- Server-authoritative portal/pad travel between areas
- Modifier provider pipeline (enchants feed breakable rewards, pet XP, hatch luck, damage, team power, efficiency)
- `PetGrantService` centralizing pet grants
- Variant system in `configs/pets.lua` (base power × variant multipliers, runtime calculated)
- Eternal/Huge pet handling
- AGENTS.md and `docs/wiki/` workflow for persistent project memory

Where this document references **"existing"** infrastructure, it means this baseline.

---

## 1. Game Concept

### 1.1 High-Level Pitch

A Roblox pet game where players collect pets, explore a ring-shaped world divided into themed biomes, and choose between two directional paths — **Heaven** (clockwise, ascending) for chill farming progression, or **Hell** (counterclockwise, descending) for City of Heroes-style party combat.

The player is a spiritual presence who **never directly fights**. Instead, they act as a healer/buffer/conductor for their pets, who do all the damage. Combat depth comes from:
- Pet collection and roster composition (genre standard)
- Player archetype (Geomancer/Sandwalker/Cryomancer/Pyromancer) and chosen powers (CoH-style level-up choices)
- Tactical real-time decisions about buffs, debuffs, sacrifices, and pet swaps

### 1.2 Genre Positioning

This is a **pet game with combat depth**, not a pet sim with combat tacked on, and not an ARPG with pets. The distinction matters:
- Pure pet sim audience (casual, idle-friendly) is served by the Heaven path
- MMO-veteran audience (City of Heroes nostalgia, support-role mains) is served by the Hell path
- Same game, two playstyles, player-chosen

The genre identity is preserved by one inviolable rule: **all damage comes from pets**. Players never deal direct damage. This keeps it a pet game.

### 1.3 Three Design Pillars

1. **The Ring** — a small map with directional progression. Loop-based content overlays let the world scale without expanding geometry.
2. **The Two Paths** — Heaven and Hell are not cosmetic. They're fundamentally different play experiences (farming vs combat) that share infrastructure but feel distinct.
3. **Pets as Party** — pets aren't just damage multipliers, they're party members. The player is the conductor; pets are the orchestra.

### 1.4 Audience Strategy

- **Casual / idle players:** play Heaven, ignore combat, focus on collection and chill farming. Their pet-sim genre needs are fully met.
- **Engaged / collector players:** play both paths, engage with trade economy between them, optimize across the dual axis.
- **MMO veterans:** play Hell, build archetype, engage with combat, multiplayer raids. Genuinely underserved by current Roblox pet sims.

---

## 2. The Ring Map: Topology

### 2.1 Layout

The map is a **ring** with biomes arranged in a circular sequence. Players literally walk around the ring to encounter different biomes in order. The center of the ring is the **Central Hub** (commerce, social, portals, endgame arena).

The visible biomes in the prototype map (clockwise from top):

1. **Snow / Tundra** (Ice biome) — north
2. **Autumn / Desert** — northwest
3. **Beach / Sandy / Tropical hub** — southwest (likely the starter / tutorial area)
4. **Central grass** — the hub itself
5. **Volcanic / Lava** — southeast/east
6. **Dark / Corrupted** — northeast (may be repurposed as the entry portal to Hell layers)

**[PROTOTYPE]** The exact biome count and layout is prototype-specific. **[TEMPLATE]** The ring topology with N biomes in adjacency order is generic — different games could have 4, 6, or 8 biomes.

### 2.2 Biome Adjacency Matters

The order of biomes around the ring is **mechanically meaningful**, not just aesthetic. Specifically:

- Directional progression (clockwise vs counterclockwise) determines alignment shift
- Biome dichotomies (see Section 7) are based on geographical opposition on the ring
- Future synergy mechanics could reward adjacency (e.g., visiting two adjacent biomes in sequence)

The coding agent should treat biome order as **data** (configurable) and never assume a fixed order in service code.

### 2.3 Center Hub As Endgame, Not Tutorial

After the player completes their first loop, the Central Hub **awakens** — it becomes the location of endgame raids, boss arenas, and Chaos Rifts (see Section 13). Before that, it functions as a normal hub (shops, NPCs, portals).

The visible center is a constant **north star** — players can see boss/raid content from anywhere on the map, which creates aspirational pull. This works particularly well on small maps where everything is visible at once.

---

## 3. The Loop & Overlay System

### 3.1 Core Concept

The ring is small. To scale content without expanding the map, each completion of the ring unlocks a new **overlay** of the same world — a Heaven layer (if the player ascended) or a Hell layer (if they descended).

The same physical biomes exist in every layer, but with:
- Different visual treatment (lighting, particles, color grading)
- Stronger enemies / better drops
- New pet variants
- Layer-specific currency rewards (Light Tokens or Shadow Tokens)

By **Loop 3** in either direction, the player has access to 3 stacked versions of the world plus the original — and they can teleport between them.

### 3.2 Implementation in Roblox: Stacked Layers

**[TEMPLATE]** Use **stacked layers** in the workspace, vertically offset:

- Base realm: Y = 0
- Heaven Layer 1: Y = +2000
- Heaven Layer 2: Y = +4000
- Heaven Layer 3: Y = +6000
- Hell Layer 1: Y = −2000
- Hell Layer 2: Y = −4000
- Hell Layer 3: Y = −6000

Each layer is a separate region of the workspace with its own copy of the biome geometry (or shared geometry with overlay decorators — see Section 3.4). Players teleport between layers via portals.

**Why stacked layers:**
- Roblox `StreamingEnabled` automatically streams in only nearby geometry, so stacked layers are essentially free at runtime
- Clean separation makes balance, mob spawns, and drop tables easy to tune per layer
- Cross-layer player visibility is irrelevant (different layers = no contention)
- Maps cleanly to mythology (literally going up or down in worldspace)

**StreamingTargetRadius** should be tuned (likely 512–1024 studs) to avoid pop-in without negating the streaming win.

### 3.3 Alternative Considered: Per-Player Visibility (NOT chosen)

We considered using `LocalScript` + `CollectionService` tags to show different layer overlays to different players in the same workspace area. This allows players in different loops to *see* each other (social aspirational visibility).

**Why we rejected it** for the main implementation:
- Mobs and farmable resources would need per-player state (complicated)
- Server still pays replication cost for everything
- Debugging is harder

**Hybrid recommendation:** use stacked layers for biome farming areas (where balance/separation matters), keep the **Central Hub shared** across all loops (so players see each other socially regardless of layer). This is the best of both.

### 3.4 Visual Treatment of Layers

Same physical geometry, different vibe:
- **Heaven layers:** brighter palette, sunbeams, light mist, lighter color grading
- **Hell layers:** red/orange tint, ember particles, darker shadows, ash particles
- **Each biome stays mechanically itself** — Heaven Lava is still a lava biome, just with a holy-fire aesthetic; Hell Ice is still ice, but darker and crueler

This means existing biome art doesn't need to be rebuilt — alignment is largely **lighting + tinting + particle overlay** layered atop the same base meshes. Cheap to produce, distinctive at a glance.

For art direction, lean into surprise contrast:
- Heaven Lava = solar/celestial fire (gold, white flames, sun-temple aesthetic)
- Hell Lava = corrupted volcanic (the version players expect, but darker)
- Heaven Ice = crystal cathedral / holy frost
- Hell Ice = frozen suffering / dark ice

### 3.5 Portal Mechanics

Portals are placed in the Central Hub. **[TEMPLATE]** Generic portal system with:
- Source layer
- Destination layer
- Unlock cost (Soul magnitude threshold + Light or Shadow token cost, see Section 4 and 13)
- Server-authoritative travel (already exists in RBX-Template)

Each layer has its own set of portals — once you're in Heaven Layer 1, you can portal to Heaven Layer 2 (cost increases) or back to base.

---

## 4. The Soul Stat (Alignment)

### 4.1 Purpose

The Soul stat tracks the player's **alignment** along the Heaven–Hell axis. It determines:
- Which overlay layers the player can access
- Aesthetic and identity expressions (halo vs horns, etc.)
- Possibly gates Chaotic fusion access at extreme magnitudes (deferred)

### 4.2 Data Type

**[TEMPLATE]** Signed integer per player, suggested range −100 to +100.
- Positive = Heaven-aligned
- Negative = Hell-aligned
- Near zero = Purgatory / undecided

Stored as a single field in the player's ProfileStore data. No complex schema.

### 4.3 How It Updates

The Soul stat changes based on which **adjacent biome** the player conquers next, after completing a previous one:

```
on biome conquest completed:
  if next_conquered_biome == clockwise_neighbor(last_conquered):
    soul += +5   // Toward Light
  elif next_conquered_biome == counterclockwise_neighbor(last_conquered):
    soul += -5   // Toward Shadow
  else:
    // non-adjacent or same biome - no change (prevents random hopping)
    no-op
```

**[PROTOTYPE]** Suggested delta: ±5 per biome conquest. **[TEMPLATE]** The delta values are config-driven.

### 4.4 What Counts as "Conquering" a Biome

Reuse the existing `active-zone breakable spawning` lifecycle. When a player enters and clears a biome's content (defined by a threshold of breakables destroyed, or a biome-boss kill, or a quest completion — configurable), that counts as a conquest event.

The first conquest of each biome in a loop fires the Soul-update logic. Re-entering doesn't.

### 4.5 HUD Visibility

**Critical for discoverability.** The player must see their Soul stat changing in real time to understand the mechanic:
- A visible **Soul Scale** UI element on the HUD
- Tilts visually toward Light or Shadow as alignment shifts
- Possibly accompanied by a halo (Heaven) or horns (Hell) on the player avatar at higher magnitudes
- Show a small notification when biome conquest changes Soul ("Your soul tilts toward the Light...")

This is a non-negotiable design requirement. The previous design instinct (just track conquest order silently) was rejected because it creates discoverability problems and players locking themselves into paths they didn't know they were choosing.

### 4.6 Resetting / Switching Alignment

Open design question. Two options:
- **Permanent per character:** strong identity, players make alts to try the other side
- **Resettable but costly:** a ritual at high cost (lots of tokens, sacrifice rare pet, cooldown) lets players switch

**Recommendation:** resettable-but-expensive. Pet sims typically lean this way. The cost should be high enough that players feel the gravity of switching, low enough that they don't feel locked out forever.

### 4.7 Loop Commitment

When a player completes a loop, they reach the Central Hub and visit an **altar** (or interact with the central portal). At this altar:
- They commit to ascend (Heaven) or descend (Hell) into the next layer
- The Soul stat **gates** the choice: very negative Soul can't ascend; very positive can't descend
- Near-zero Soul can choose either, but only enters **Purgatory** (a neutral mid-tier layer with weaker rewards)

This gives the commitment moment ceremony and consequence.

---

## 5. Heaven vs Hell: Two Game Modes

### 5.1 The Core Split

This is the design decision that unifies the whole concept:

- **Heaven layers = farming-oriented gameplay** (traditional pet sim mechanics, extended)
- **Hell layers = combat-oriented gameplay** (City of Heroes-style party combat)
- **Base realm = mixed** (farming with occasional minor encounters, tutorial-friendly)

Player chooses their path by directional progression around the ring.

### 5.2 Why This Split

1. **Mythology does mechanical work.** Heaven = peaceful abundance, gardens, holy labor → farming. Hell = struggle, conquest, battle for souls → combat. Players intuit it without a tutorial.
2. **Serves both audiences from one game.** Casual idle farmers and combat-engaged MMO veterans share content space but not gameplay style.
3. **Combat scope is constrained.** Heaven extends existing systems (cheap to build). Hell requires new combat systems (expensive, but only one path needs them). Can ship Heaven first, add Hell as v2.
4. **Trade economy strengthens.** Each side produces what the other consumes (see Section 8).

### 5.3 What's in Each

**Heaven layers contain:**
- Standard breakables (crystals, etc.) with scaled rewards at higher loops
- Resource nodes / farming utility passives matter
- Slow, steady progression
- Light, occasional combat encounters (some "fallen" enemies — angels gone astray, corrupted creatures) — narrative flavor, not the focus
- Heaven-themed loot: Light Tokens, blessed pet variants, support gear

**Hell layers contain:**
- Combat encounters (enemy mobs, boss fights, raids)
- Limited but present farming (resource drops from kills, occasional breakables in safer pockets)
- Active gameplay required — idle players won't progress here efficiently
- Hell-themed loot: Shadow Tokens, corrupted pet variants, combat gear

### 5.4 Permeability

Cross-path play matters. A Heaven-aligned player can briefly descend into Hell (with limited reward, for trade or curiosity), and a Hell-aligned player can ascend (similarly). Pure walls between paths would kill the trade economy and feel arbitrary.

**Design rule:** alignment determines which **deep layers** you can access, but both paths' layer 1 is reachable by anyone (with some token cost). Players can sample the other side.

---

## 6. The Central Hub & Portal System

### 6.1 Hub Functions

The Central Hub is the only shared social space across all loops/layers. It contains:
- **Trade post** — player-to-player pet trading
- **Shops** — purchase pets, upgrades, consumables
- **Altars** — alignment commitment, fusion (Chaotic pet creation), respec
- **Portals** — travel to other layers
- **Endgame arena** — boss content (awakens after Loop 1)
- **Recharge sanctuary** — pets recover faster here (see Section 11)
- **Social/leaderboard areas**

### 6.2 Portal Design

Portals are physical objects in the world (markers, per existing `configs/markers.lua` pattern) with server-authoritative travel logic. Each portal has:
- **Source layer** (where the portal is)
- **Destination layer** (where it sends you)
- **Cost** to use (Soul magnitude threshold + token cost)
- **Direction** (ascend/descend)

**Example portal costs:**
- Base → Heaven Layer 1: requires Soul ≥ +20, 100 Light Tokens
- Heaven Layer 1 → Heaven Layer 2: requires Soul ≥ +40, 250 Light Tokens
- Heaven Layer 2 → Heaven Layer 3: requires Soul ≥ +60, 500 Light Tokens
- Mirror for Hell with negative thresholds

This creates the **token sink** that justifies earning Light/Shadow Tokens.

### 6.3 Cross-Path Visit Portals

Separate, cheaper portals allow players to *visit* the opposite side at layer 1 only:
- Heaven → Hell Layer 1: small fixed token cost, doesn't require negative Soul
- Hell → Heaven Layer 1: same in reverse

This lets a Heaven player briefly farm Hell biomes (for combat experience, rare drops, or to use their dominant Light pets there — see Section 8).

---

## 7. Biome System & Themed Currencies

### 7.1 The Four Biome Themes

**[PROTOTYPE]** Four primary biome themes:
1. **Earth** — green, grassy, default starter feel
2. **Desert** — sandy, hot, dry
3. **Ice** — snowy, frozen, tundra
4. **Lava / Fire** — volcanic, molten

**[TEMPLATE]** The number, names, and themes are config-driven. Other games could have water/forest/sky/mountain, etc.

### 7.2 Themed Pets

Pets are tagged with a **theme**. Pets thematically belong to a biome:
- Earth pets: bears, wolves, deer, eagles, anything terrestrial
- Desert pets: snakes, scorpions, vultures, jackals
- Ice pets: penguins, polar bears, frost wolves, walruses
- Lava pets: salamanders, phoenix, lava golems, magma slugs

A pet's theme determines which biome's content it interfaces with (which currencies, which utility passives apply).

### 7.3 Themed Currencies (One Per Biome)

**[PROTOTYPE]** Each biome has a single themed currency:
- Earth coins
- Desert coins
- Ice coins
- Lava coins

**Important design rule:** currencies are **NOT realm-tinted**. Earth coins are earth coins everywhere — in base, Heaven, or Hell layers. Higher layers grant **more** earth coins per breakable, but the currency itself is identical.

**Reasoning:** currency proliferation (Heaven Earth coins, Hell Earth coins, etc.) creates UI nightmare and trading chaos. Players intuitively expect "earth coins are earth coins."

### 7.4 No Trading of Hatch-Currencies

Genre rule. Biome currencies are used to hatch pets, so they cannot be traded between players. This prevents botting, alt-account farming abuse, and exploit chains.

Tradeable items: pets themselves, certain consumables, gear (if added). Non-tradeable: currencies used in hatching, alignment tokens, account-bound progression items.

### 7.5 Biome Dichotomies as UTILITY (Not Damage)

The original design instinct was to make biome dichotomies a damage type chart (Earth pet better in Desert biome, etc.). This was **rejected** because stacking two type charts (biome dichotomy + alignment dominance) creates cognitive overload and redundant mechanics.

**Final design:** biome dichotomies grant **unique utility passives**, not damage multipliers. The dichotomies on the ring:

- **Earth ↔ Desert**
- **Ice ↔ Lava**

These are arranged geographically opposite on the ring map.

### 7.6 Example Utility Passives

When a pet is in its **opposing** biome (the dichotomy), it gains a flavor passive:

- **Earth pet in Desert:** "Deep Roots" — passive: finds 50% more rare resources from breakables here
- **Desert pet in Earth biome:** "Mirage Walker" — passive: short stealth/dodge chance, avoids first hit
- **Ice pet in Lava:** "Frost Aura" — passive: nearby enemies attack 20% slower (great in combat zones)
- **Lava pet in Ice biome:** "Heat Bloom" — passive: melts ice barriers, opens shortcut paths that only this pet type can access

These are **abilities and access bonuses**, not damage multipliers. They reward diversity in pet collection without competing with the alignment dominance system (Section 8).

### 7.7 Why This Works

- Casual players ignore the dichotomies — no penalty
- Engaged players use opposing-theme pets for specific resource gathering or access
- Trade economy gains another axis (specific Lava pets needed to unlock Ice biome shortcuts)
- No second type chart to memorize

---

## 8. Element System (Alignment Affinity)

### 8.1 Three Elements

**[PROTOTYPE]** Pets have an **element** tag separate from their theme:
1. **Light**
2. **Shadow**
3. **Chaotic** (rare third element, see Section 9.5)

A pet's element is **independent** of its theme. So a pet can be:
- "Light Frost Drake" (Ice theme, Light element)
- "Shadow Frost Drake" (Ice theme, Shadow element)
- "Chaotic Frost Drake" (Ice theme, Chaotic element)

Same base pet, three alignment variants.

**[TEMPLATE]** The element system is config-driven. Other games might use Fire/Water/Earth elements, or Cyber/Bio/Arcane, or any N-element system.

### 8.2 Element Acquisition

A pet's element is determined at hatch time, based on **where it was hatched**:
- Hatched in base realm: usually Neutral (no element bonus) or random
- Hatched in Heaven layers: Light element (always or with high probability)
- Hatched in Hell layers: Shadow element
- Chaotic pets: only from **fusion** (see Section 9.5) — never naturally hatched

This means the realm you spend time in determines your pet element pool. A Heaven-aligned player naturally hatches Light pets. A Hell-aligned player naturally hatches Shadow pets.

### 8.3 Cross-Realm Dominance (Symmetric)

**The key mechanic:** pets are stronger in the **opposite** realm from their element.

- Light pets dominate **Hell biomes**
- Shadow pets dominate **Heaven biomes**
- Chaotic pets are moderately effective in both, but never optimal in either

**Multiplier table:**

| Pet element | In Heaven biome | In Hell biome | In Neutral/base |
|---|---|---|---|
| Light | 1.2× (resonance, home) | 1.5× (smite, dominance) | 1.0× |
| Shadow | 1.5× (corrupt, dominance) | 1.2× (resonance, home) | 1.0× |
| Chaotic | 1.3× | 1.3× | 1.3× |

**[PROTOTYPE]** These specific multipliers. **[TEMPLATE]** The multiplier table is a config-driven 3×3 matrix (or NxN for any element system).

### 8.4 Why Symmetric?

This is the design move that creates the trade economy:
- To efficiently farm any biome, you want pets from the **opposite** alignment
- A Heaven player hatches Light pets (in Heaven) but wants Shadow pets to actually farm Heaven biomes optimally
- A Hell player hatches Shadow pets but wants Light pets to farm Hell biomes optimally
- Each side **produces** one element and **consumes** both
- Trade between aligned players becomes structurally necessary — not a bolt-on feature

This is far stronger than asymmetric ("Light is just better") because:
1. Asymmetric kills one side as a viable choice
2. Symmetric forces interdependence without forcing alignment switching
3. Players can commit to their identity (Heaven or Hell main) and still need the opposite side's output

### 8.5 Element vs Theme Composition

Element and theme are **orthogonal**. A pet has both. In combat/farming calculation:
- Element multiplier applies based on **current biome's realm alignment**
- Theme/utility passive applies based on **current biome's theme**

So a Light Frost Drake (Ice theme, Light element) in a Hell Lava biome gets:
- 1.5× from Light element in Hell biome
- "Frost Aura" utility passive from Ice pet in Lava biome
- Plus base power × variant × level × enchants

Stacks multiplicatively in the runtime power calculation (see Section 10).

---

## 9. Pet System Architecture

### 9.1 Identity vs State (Single Source of Truth)

**Pet records store identity and mutable state. They do NOT store calculated values.**

Already established in RBX-Template — power is always a runtime calculation from `(config_base × variant × level × enchants × contextual_modifiers)`. This document extends that pattern with new modifiers but does not change the principle.

**A pet record contains:**
- `pet_id` (references the config entry)
- `theme` (read from config but cached for query speed)
- `element` (assigned at hatch, mutable only via fusion or special events)
- `variant` (e.g., normal, gold, eternal, huge — from existing variant system)
- `level` and `XP` (for unique pets)
- `enchants` (rolled at hatch, modifiable via enchanter)
- `serial` (for huge pets — provenance tracking)
- `lastDownedAt` timestamp (for spirit form recharge — Section 11)
- `lock_state` (favorite/locked from accidental delete)

**A pet record does NOT contain:**
- `power` (always computed)
- `damage`, `attack_speed`, etc. (computed from base + modifiers)
- Any cached calculated value

### 9.2 Stacked vs Unique Pets

Existing distinction preserved:
- **Stacked pets** (common): one record per pet type with `count` field. Up to N stacked instances per entry. No per-instance state.
- **Unique pets** (special, eternal, huge): one record per instance with full per-instance state.

**Spirit form mechanic (Section 11) handles these differently:**
- Unique pets: individual `lastDownedAt` timestamp per record
- Stacked pets: pool model with `ready_count` and `total_count` per stack

### 9.3 The Element Tag Addition

This is the main new field on pets. Add `element` to:
- Pet config entries in `configs/pets.lua` (default element per pet family, can be neutral)
- Pet save records (assigned at hatch based on layer hatched in)

**[PROTOTYPE]** Element values: `"light"`, `"shadow"`, `"chaotic"`, `"neutral"`. Most prototype pets hatched in base realm are `"neutral"`. Pets hatched in alignment layers are `"light"` or `"shadow"`. Chaotic only via fusion.

### 9.4 Variants Extension

Existing variant system (normal, gold, etc. with multipliers) **does not need replacement**. Add new variants for alignment expression:
- `"blessed"` (for Light pets, visual gold/halo treatment)
- `"corrupted"` (for Shadow pets, visual dark/horns treatment)

Variants are independent of element but typically correlated. A `"blessed"` variant is visually angelic; a `"corrupted"` variant looks demonic.

This gives art direction a simple expression layer without entirely new pet models. The same base mesh, different shaders/particles per variant.

### 9.5 Chaotic Pets (Fusion Outputs)

**Chaotic pets are not hatched.** They are created via **fusion** at a special altar in the Central Hub:

- Sacrifice 1 Light pet + 1 Shadow pet
- Result: 1 Chaotic pet of the same theme family (or a curated family per fusion recipe)
- Pets sacrificed are permanently consumed (with confirmation modal — see Section 11.7)

**Why this design:**
- Justifies their rarity structurally — must engage both realms to even make one
- Ties together Hell's sacrifice mechanic and Heaven's purification mechanic (both flavor existing alignment philosophies)
- Creates long-tail decision making ("what should I fuse?")
- Chaotic pets feel earned, not random

**Chaotic pet behavior:**
- Moderate multipliers in both realms (1.3× from element table)
- Only effective in **Chaos Rifts** (endgame content — Section 24) where they get 2.0×+
- Other elements are penalized in Chaos Rifts (0.5× or worse)
- Optionally: Chaotic pets generate a unique third currency (e.g., "Aether") usable only for Chaotic progression

### 9.6 Eternal/Huge Pet Handling

Existing eternal/huge handling unchanged. These are rare special variants with config-only durable power. The element/realm system layers on top — an Eternal pet can be Light, Shadow, or Chaotic just like a normal pet.

---

## 10. Pet Power Calculation Formula

### 10.1 The Runtime Formula

Power is always computed, never stored. The full formula (in execution order):

```
power = base_power(pet.pet_id)              // from configs/pets.lua family entry
      × variant_multiplier(pet.variant)      // from configs/pets.lua variant table
      × level_multiplier(pet.level)          // from configs/pet_progression.lua
      × enchant_multiplier(pet.enchants)     // from configs/enchants.lua (existing pipeline)
      × element_multiplier(pet.element, current_biome.realm_alignment)  // NEW
      × theme_utility(pet.theme, current_biome.theme)  // NEW (utility passive, conditional)
      × stack_contribution(pet)              // NEW for stacked pets (Section 12)
      × player_buff_multiplier(player, pet) // from active player powers (Section 17+)
      × team_synergy(player.active_squad)   // optional, future
```

Each step is its own **modifier provider** in the existing pipeline. The element and theme utility additions slot in alongside existing providers (breakable rewards, pet damage, hatch luck, etc.).

### 10.2 Where The New Providers Slot

**[TEMPLATE]** Two new modifier providers added:

1. **Element Resonance Provider**
   - Inputs: pet element, current biome realm alignment
   - Output: multiplier from the element table (Section 8.3)
   - Config: `configs/elements.lua` (new file) with the multiplier matrix
   - Lookup happens at power calculation time (no save schema change)

2. **Theme Utility Provider**
   - Inputs: pet theme, current biome theme
   - Output: list of passive abilities (not just a number) — e.g., "stealth", "shortcut access", "rare drop chance"
   - Config: `configs/theme_utility.lua` (new file) with the dichotomy lookup
   - Some utilities are numeric (multipliers on specific drops); some are unique abilities (path access)

### 10.3 Stack Contribution

For stacked pets (Section 12), the entire stack contributes one "pet slot" to combat with a power scaled by `ready_count / total_count` (or a curve like sqrt/log of that ratio).

**[TEMPLATE]** Contribution curve is config-selectable:
```lua
contribution_curves = {
    linear = function(ready, total) return ready / total end,
    sqrt_diminishing = function(ready, total) 
        return math.sqrt(ready) / math.sqrt(total) 
    end,
    log_diminishing = function(ready, total) 
        return math.log(1 + ready) / math.log(1 + total) 
    end,
}
```

Prototype picks one. Other games on template pick different.

---

## 11. Spirit Form & Recharge Mechanic

### 11.1 The Core Rule (Inviolable)

**Pets never die. Pets are never lost to gameplay.**

This is a genre rule and a third rail. Players form attachments to pets. The community will revolt if pets can be permanently lost without explicit player action.

**Loss only via player-initiated actions:**
- Explicit deletion (with double-confirm modal)
- Sacrifice for fusion (Chaotic creation)
- Sacrifice for other upgrades (future)
- Trade (gives to another player)
- All require an explicit "are you sure" confirmation step

### 11.2 The Lore Framing: Spirit Animals

Pets are spirit animals that manifest in the world. When overwhelmed in combat, they return to spirit form to recharge.

This framing matters: "*my Frost Drake is resting*" feels completely different than "*my Frost Drake is dead, respawning*." Same mechanic, different emotional register. Use the lore framing in all UI/dialogue copy.

### 11.3 Staged Degradation

In combat, pets pass through visible health states before going to spirit form:

| State | Visual cue | Mechanical effect |
|---|---|---|
| Healthy | normal appearance | full power |
| Strained | slight glow shift, aura change | minor damage reduction (5–10%) |
| Critical | translucent, red/distressed glow | significant damage reduction (25–40%), warning UI |
| Spirit Form | returned to inventory, ghostly icon | not deployable, recharge timer active |

This gives the player **agency** — they can see the pet is in trouble and pull it out before forced spirit form. Loss-of-control feels like a failed decision, not arbitrary game punishment.

### 11.4 Recharge Timing by Content Tier

**[PROTOTYPE]** Suggested recharge times:

| Content | Recharge time |
|---|---|
| Trash mobs in early Hell layers | 1–3 minutes |
| Mid-tier Hell content | 5–15 minutes |
| Boss fights | 30 minutes |
| Chaos Rifts / endgame raids | 30–60 minutes |

**[TEMPLATE]** Config-driven per encounter or biome.

Always provide **instant-recharge consumables** as a currency sink — players can pay to immediately restore.

### 11.5 Heaven Biomes Accelerate Recharge

Pets in spirit form recharge **2× faster** in Heaven biomes. This creates bidirectional pull:
- Hell raiders return to Heaven to rest their squad
- Heaven players don't really need this (they rarely lose pets to farming)
- Creates a natural rhythm: combat in Hell, rest in Heaven, re-engage

### 11.6 Implementation: Unique Pets

Add `lastDownedAt` field (timestamp) to unique pet records. Deployment check:

```lua
function can_deploy(pet, now)
    if not pet.lastDownedAt then return true end
    return (now - pet.lastDownedAt) >= pet.cooldownSeconds
end
```

`cooldownSeconds` comes from the current content tier when the pet was downed.

### 11.7 Confirmation for Player-Initiated Deletion

Any action that permanently destroys a pet must:
- Show a modal with the pet's name, level, enchants, serial (if huge)
- Require an explicit "Yes, I'm sure" confirmation
- For high-value pets (eternals, huges, max-level), require a second confirmation or a typed phrase
- Never allow bulk-delete without per-item review for unique pets

Stacked pets can be bulk-deleted from the stack with a single confirmation showing the count.

---

## 12. Stacked Pet Pool Model

### 12.1 The Problem

Stacked common pets have only `count` in storage (no per-instance state). When 30 stacked Frost Drakes are deployed in combat, the spirit-form mechanic can't track individual cooldowns. Need a pool model.

### 12.2 The Solution: Token Bucket

For each stack, add two fields:

```lua
stack = {
    pet_id = "frost_drake",
    total_count = 30,          -- existing
    ready_count = 24,          -- NEW
    last_update = timestamp,   -- NEW
}
```

`ready_count` represents how many instances are not in spirit form. `last_update` is when this count was last recalculated.

### 12.3 Lazy Refill

When the stack is queried (for deployment or display):

```lua
function refresh_stack(stack, now)
    local elapsed = now - stack.last_update
    local recharge_per_instance = base_cooldown_seconds  -- from config
    local new_ready = math.min(
        stack.total_count,
        stack.ready_count + math.floor(elapsed / recharge_per_instance)
    )
    if new_ready > stack.ready_count then
        stack.ready_count = new_ready
        stack.last_update = now
    end
    return stack.ready_count
end
```

Continuous refill, single-counter storage. No per-instance tracking needed.

### 12.4 Combat Contribution

When the stack is deployed, its contribution to the active squad scales with `ready_count`:

```lua
contribution = base_power(stack.pet_id)
             × stack_contribution_curve(stack.ready_count, stack.total_count)
             × (all other multipliers from Section 10)
```

The chosen curve (linear / sqrt / log) determines whether 24/30 ready feels like 80% or 90% or 70% effectiveness.

### 12.5 When Pets Are Downed

In combat, when the stack takes "enough" damage to lose an instance:

```lua
function down_one(stack, now)
    refresh_stack(stack, now)  -- first refill any pending recovery
    if stack.ready_count > 0 then
        stack.ready_count = stack.ready_count - 1
        if stack.last_update == nil then
            stack.last_update = now
        end
    end
    -- If ready_count was already 0, the stack is "all in spirit form" - 
    -- contribution is 0 but stack stays in active squad slot until pulled
end
```

### 12.6 Add/Remove From Stack

When the player hatches more or trades away:
- **Add N pets:** `total_count += N`, `ready_count += N` (new pets ready by default)
- **Trade/delete N pets:** prefer to pull from ready first; if forced to remove from "tired" portion, the deleted ones are still considered owned-and-then-removed (no edge case)

---

## 13. Currency System Details

### 13.1 Currency Inventory

The full currency list in the prototype:

**Biome currencies (one per theme, non-tradeable):**
- Earth coins
- Desert coins
- Ice coins
- Lava coins

**Alignment currencies (non-tradeable):**
- Light Tokens (earned in Heaven layers)
- Shadow Tokens (earned in Hell layers)

**Chaotic currency (optional, deferred):**
- Aether (earned only by Chaotic pets — gates Chaotic progression)

**Universal currency:**
- Whatever your existing universal currency is (gems, robux equivalent, etc. — RBX-Template already has this)

**[PROTOTYPE]** This list. **[TEMPLATE]** Currency definitions are config-driven.

### 13.2 Sinks and Sources

Each currency needs sources (earned how?) and sinks (spent on what?):

| Currency | Sources | Sinks |
|---|---|---|
| Earth/Desert/Ice/Lava coins | Breakables in respective biome | Hatching theme-matched eggs, biome-specific upgrades |
| Light Tokens | Farming Heaven layers (any biome), Heaven daily rewards | Heaven portal access costs, Light pet upgrades, fusion |
| Shadow Tokens | Farming Hell layers, Hell daily rewards | Hell portal access costs, Shadow pet upgrades, fusion |
| Aether (if used) | Only Chaotic pets generate it via passive | Chaotic progression tree, Chaos Rift entry |

### 13.3 No Currency Tinting Across Realms

Repeating for emphasis: earth coins from Heaven Earth biome are the same coins as from Hell Earth biome. Higher layers grant more coins per breakable, but the currency is identical.

The only currencies that differentiate by realm are **Light vs Shadow Tokens**, and these are alignment progression resources, not biome resources.

---

## 14. Combat System (Hell-Focused)

### 14.1 Where Combat Lives

Active combat content is in:
- Hell layers (the primary combat experience)
- Chaos Rifts (cross-realm endgame events)
- Boss arenas in the Central Hub (after Loop 1)
- Light combat encounters in Heaven (flavor, not focus)

### 14.2 Enemy Design

Enemies are themed by biome + realm:
- **Hell Earth biome:** corrupted bears, twisted wolves, malevolent earth elementals
- **Hell Ice biome:** frost wraiths, undead polar bears, ice demons
- **Hell Lava biome:** classic demons, lava beasts, fire imps
- **Hell Desert biome:** sand wraiths, mummies, scorpion demons
- **Heaven enemies:** corrupted/fallen versions of holy beings (angels gone astray, etc.)
- **Chaos Rift enemies:** primordial entities, reality-warping creatures

Each enemy has:
- HP / armor
- Attack patterns (telegraphs for player reaction)
- Special abilities (e.g., "Sundering" attacks that disrupt player Focus — Section 16)
- Drop tables (loot, tokens, occasional Chaotic essences)

**[TEMPLATE]** Enemy definitions live in a new `configs/enemies.lua`. **[PROTOTYPE]** This file's contents are prototype-specific.

### 14.3 Combat Flow

1. Player enters Hell biome with their loaded Active Squad (3–5 pets)
2. Enemies spawn from designated marker points (use existing `configs/markers.lua` pattern)
3. Pets engage automatically (basic AI: target nearest enemy, use abilities on cooldown)
4. Player uses **commands and powers** via hotbar to:
   - Buff pets (Bless, Forge Heat)
   - Heal/protect pets (Stone Skin, Aegis)
   - Debuff/control enemies (Curse, Frost Bind)
   - Swap pets (hotbar macros, see Section 21)
5. Enemies fall, drop loot, encounter ends or continues
6. Pets that took critical damage may go to spirit form

### 14.4 Pets as Active Combatants (Not Just Multipliers)

This is the genre departure point. In standard pet sims, pets are passive damage multipliers attached to the player. In this game, **pets are active combat agents** with:
- Their own HP/stamina pool (visible)
- Movement and positioning
- Targeted abilities (not just "do damage")
- Death/spirit form states

The active squad of 3–5 pets feels like a small **party** — closer to a Pokemon battle or City of Heroes Mastermind than a Pet Sim 99 follower train.

### 14.5 Boss Fights

Bosses in Hell are gated by layer:
- Hell Layer 1: each biome has a boss (5 biome bosses)
- Hell Layer 2: paired bosses (two biomes combine)
- Hell Layer 3: the **Realm Lord** of Hell (capstone for the path)

Bosses have:
- Phases (HP thresholds trigger new abilities)
- Mechanics requiring active player engagement (telegraphs, positioning, interrupts)
- Significant drops (rare pets, ascension materials, large token rewards)
- Long recharge for downed pets (30+ minutes), so you really care about your team

---

## 15. Farming System (Heaven-Focused, Extended)

### 15.1 What's in Heaven

Heaven layers are the **deepened pet sim experience**. Extensions of existing RBX-Template farming:

- Breakables with scaled rewards per layer
- Resource nodes (specific drops for specific biomes)
- Daily gifts, rotating shop items (already planned in RBX-Template)
- Pet of the Day rotations
- Idle progression — players can AFK farm efficiently here
- Light, occasional combat encounters (narrative flavor only)

### 15.2 Why Heaven Looks Like Existing RBX-Template

The Heaven extension is **mostly content scaling**, not new systems. The bones are:
- Existing breakable spawning system
- Existing pet equipping for farming buffs
- Existing modifier pipeline (luck, damage, efficiency)
- Existing currency rewards

What's new in Heaven specifically:
- Light Token drops from breakables
- Blessed pet variants hatch here
- Biome utility passives apply (per Section 7.5)
- Pets recharge faster here (Section 11.5)

This is why Heaven can ship first — it's mostly content, not new systems.

### 15.3 Soft Combat in Heaven

A small, optional combat layer in Heaven keeps it from feeling lifeless:
- Occasional "fallen" enemies appear (1 in 20 breakables triggers a small encounter)
- These are easy — meant to be a small flavor break, not a real challenge
- Casual players can ignore (auto-pets handle it)
- Heaven combat rewards are minor (small token boost) — never feels mandatory

This ensures Heaven players experience the game's combat system in light doses without being forced into Hell.

---

## 16. Player Character System

### 16.1 The Invulnerability Rule

**Players cannot be injured. Players cannot die in combat. The player has no HP bar.**

This is a fundamental design rule, second only to the "pets never die" rule. Reasoning:
- Player is a **spiritual presence**, not a physical combatant
- Adding player HP/death/respawn doubles the design surface for no genre benefit
- Casual audience hates dying in pet sims
- Healer/buffer fantasy breaks if the healer also needs healing
- Mythologically consistent: you are the soul, not the warrior

The model is **Pokemon trainer**: outside the battle, directing pets, untouchable.

### 16.2 Visual Presentation

The player avatar is visible but **ethereal**:
- Slight translucency
- Soft particle/aura effects matching alignment (golden glow for Light, dark wisps for Shadow)
- Floats or hovers (not strictly grounded)
- Cannot be targeted by enemies

In peaceful zones (Heaven hub, sanctuary), player can appear more solid for social/cosmetic purposes. In active combat, the ethereal treatment is canonical.

### 16.3 Focus / Concentration Stat (Soft Vulnerability)

Replace HP with **Focus** — a resource that can be disrupted but never destroyed:

- **Default state:** full Focus, all powers available
- **"Sundering" / "Silence" enemy attacks:** disrupt Focus, putting commands on increased cooldown or temporarily locking specific powers
- **Recovery:** automatic over time, no death state
- **Player never loses the encounter from Focus damage alone**

This adds tactical stakes:
- "Don't let the Banshee finish her scream or I lose Bless for 20s"
- "Time my Aegis before the Sunderer hits"
- Players feel real vulnerability without HP mechanics

**[TEMPLATE]** Focus mechanic config-driven (max focus, disruption strength, recovery rate). Other games on the template might disable Focus entirely or replace with their own system.

### 16.4 What Happens When All Pets Are Downed

The "lose" state for a player who runs out of active pets:
- Player is teleported to a safe zone (Heaven sanctuary, Central Hub, or biome entrance)
- Pets enter their normal recharge timers
- No item loss, no XP loss, no death penalty
- The "loss" is the time the player can't redeploy that squad

This respects the no-death rule while still giving combat real stakes (your A-team is unavailable for the next X minutes).

### 16.5 Player Powers Never Deal Damage

**Firewall rule.** All player powers are support:
- Buffs (pets do more)
- Debuffs (enemies take more from pets)
- Heals (pets recharge faster, take less damage)
- Control (slow, stop, position)
- Sacrifice (trade one pet's spirit for another's restoration)
- Mark / Focus (designate priority targets)

If a power deals damage directly, the game has crossed into ARPG territory. This firewall is non-negotiable.

**Reaffirmed 2026-06-02** (see 17.8): the clinching argument is risk symmetry — pets are the only ones
who can be damaged/downed, so they must be the only ones who deal damage, or the pet-collection economy
becomes cosmetic. "Damage" capstones (e.g. Cataclysm) are **pet-damage amplification** anchored to the
pets' targets and scaled by squad attack power — never a standalone player hit.

---

## 17. The Four Archetypes

### 17.1 Archetype Concept

Each player picks one **archetype** at character creation, themed after a biome homeland:
1. **Geomancer** (Earth) — defensive, protective
2. **Sandwalker** (Desert) — mobility, utility
3. **Cryomancer** (Ice) — crowd control
4. **Pyromancer** (Lava) — aggression, debuffs

Archetype determines the player's **power pool** — the set of powers they can choose from at level-up.

**[TEMPLATE]** Number of archetypes and their definitions are config-driven. Other games could ship completely different archetype sets.

### 17.2 Archetype Identity vs Alignment

Archetype and alignment (Heaven/Hell Soul stat) are **orthogonal**:
- A Geomancer can be Heaven or Hell-aligned
- The archetype defines mechanics; alignment defines flavor expression

Example: Geomancer's "Stone Skin" power:
- Light-aligned Geomancer: manifests as golden barriers, slight extra heal-on-block
- Shadow-aligned Geomancer: manifests as bone armor, slight extra lifesteal-on-block
- Same mechanical power, different aesthetic

This gives 4 archetypes × 3 alignments = **12 distinct player identities** before power selection.

### 17.3 Geomancer (Earth) — Power List

Theme: defensive, protective, "I keep my team alive"

| Tier | Power | Effect |
|---|---|---|
| 1 | **Stone Skin** | Shield single pet — absorb next N damage |
| 1 | **Mountain Ward** | Smaller shield on all active pets (AoE) |
| 2 | **Bulwark** | Active squad gains damage reduction for 15s |
| 2 | **Root** | Immobilize one enemy for 5s |
| 3 | **Mountain's Strength** | Pet HP buff +30% for 30s |
| 3 | **Stone Vow** | Next attack on a pet redirects to a stone shield |
| 4 | **Earthen Resurgence** | Restore N% spirit to most-downed pet |
| 4 | **Avalanche** | Knockdown all enemies in front (no damage, big disruption) |
| 5 | **Living Fortress** | Squad pets become temporarily un-downable (5s, long CD) |

### 17.4 Sandwalker (Desert) — Power List

Theme: mobility, utility, "I bend the field"

| Tier | Power | Effect |
|---|---|---|
| 1 | **Sun's Blessing** | Pet accuracy/crit buff |
| 1 | **Mirage** | Redirect one enemy attack to a phantom |
| 2 | **Cooling Wind** | Reduce all player command cooldowns by 30% for 10s |
| 2 | **Sandstorm** | Mass blind, enemies miss frequently |
| 3 | **Dune Restoration** | Heal over time on active squad |
| 3 | **Sirocco** | Push enemies back, gain breathing room |
| 4 | **Oasis** | Spawn a temporary safe zone — pets in it heal faster |
| 4 | **Veil of Sand** | All pets gain temporary stealth (avoid next hit) |
| 5 | **Sand King's Dominion** | All enemies briefly disoriented, lose aggro |

### 17.5 Cryomancer (Ice) — Power List

Theme: crowd control, locking down, classic Controller fantasy

| Tier | Power | Effect |
|---|---|---|
| 1 | **Frost Bind** | Slow one enemy to 30% speed |
| 1 | **Frostbite** | Single enemy takes increased damage |
| 2 | **Frozen Edge** | Pet attacks apply slow stacks |
| 2 | **Ice Wall** | Block enemy movement line for 8s |
| 3 | **Glacial Restoration** | Heal pets and grant brief damage immunity |
| 3 | **Frozen Heart** | Stop one enemy completely for 4s |
| 4 | **Blizzard** | AoE slow on all enemies, vision reduced |
| 4 | **Crystal Lattice** | Pets gain reflect damage thorns |
| 5 | **Absolute Zero** | All enemies frozen for 6s (long CD, encounter-changer) |

### 17.6 Pyromancer (Lava) — Power List

Theme: aggression, debuffs, "I make my pets hit harder"

| Tier | Power | Effect |
|---|---|---|
| 1 | **Mark of Flame** | Target takes +25% damage from all sources |
| 1 | **Ember Pulse** | Restore spirit to one pet |
| 2 | **Forge Heat** | Pet attacks apply burn DoT |
| 2 | **Pyre Mark** | Marked enemy explodes on death, damages others |
| 3 | **Volcanic Surge** | Squad damage burst (+50% for 10s) |
| 3 | **Inferno Bond** | Pet attacks have chance to apply Mark of Flame |
| 4 | **Crucible** | Sacrifice one pet to fully restore another (high-stakes choice) |
| 4 | **Ash Cloud** | Enemies blinded, lose accuracy |
| 5 | **Eruption** | Massive AoE buff zone — pets in it deal triple damage briefly |

### 17.7 Archetype Power Pool Structure

Each archetype's power pool has roughly 9 powers across 5 tiers:
- Tier 1: 2 options (pick 1 at level 5)
- Tier 2: 2 options (pick 1 at level 10)
- Tier 3: 2 options (pick 1 at level 15)
- Tier 4: 2 options (pick 1 at level 20)
- Tier 5: 1 capstone (unlocked at level 30)

Players end with **5 powers** out of 9 possible. Two players of the same archetype can have very different builds.

**[TEMPLATE]** Power pool structure (tiers, choices per tier, gating levels) is config-driven.

### 17.8 Signature Powers & Role-King Capstones — REVISED (2026-06-02)

> This subsection supersedes the per-archetype lists in 17.3–17.6 as the **identity layer** of the
> power system. The target is a **20-power pool per archetype** of which the player unlocks ~10 via
> level-up (City-of-Heroes style: choices are permanent, no respec yet). That pool is built as:
> **(a)** the 3 *exclusive signatures* below, **(b)** a set of *shared templates* skinned per element
> (built once, reused across archetypes), and **(c)** elemental rock-paper-scissors tuning
> (`CombatElementResonance`, separate from the heaven/hell `ElementResonance`). (b) and (c) are future
> work; the signatures are locked here.

**Firewall reaffirmed (see 16.5), with the damage clarification.** Pets remain the *sole* source of
damage and the *sole* bearers of combat risk (they take aggro and can be downed; the player cannot be
damaged). This is non-negotiable for a decisive reason: a player who can deal damage but cannot take
it has no skin in the game and could clear content without pets — which makes the entire pet-collection
economy cosmetic. Therefore **no player power deals standalone damage.** A power that reads as "damage"
(e.g. Cataclysm) is an **amplification of pet damage** anchored to the pets' own targets — the burst is
scaled by the squad's attack power and credited to the pets. A weak squad → a weak meteor.

**Targeting model — the pet picks the target; the player augments it.** No reticle, no aim. Delivery types:
- **single** — affects the enemy a pet is currently attacking (the squad focus).
- **targeted AoE** — an AoE centered on what the squad is attacking.
- **team AoE** — *every* pet erupts simultaneously around its own target.
- **friendly** — applies to your own pets (heals/buffs/shields); some are tap-a-pet (Verdant Bloom).
- **hybrid** (e.g. a life-transfer that damages + heals) rides single or AoE.

Each archetype has **3 exclusive signatures** (not available to any other archetype): 2 mid-tier
signatures + 1 high-level **capstone** that crowns it king of one role. The four capstones cover
heal / buff / debuff / damage, so a 4-player team naturally wants one of each.

| Archetype | Signature | Signature | ✦ Capstone (role-king) |
|---|---|---|---|
| 🟢 **Geomancer** (earth — defense) | **Tectonic Bastion** — *friendly*: squad encased in stone, heavy mitigation/absorb, briefly rooted | **Fissure** — *targeted AoE*: ground crack → knockdown/root + enemies take increased pet damage | **Verdant Bloom** — HEAL: *tap-a-pet* huge heal + splash heal to nearby pets, very long CD |
| 🟤 **Sandwalker** (desert — utility) | **Mirage Legion** — *friendly*: sand decoys taunt/soak, squad briefly untargetable | **Quicksand Maw** — *targeted AoE*: pull to center + root + armor shred | **Sirocco** — BUFF: *friendly* squad attack-speed + damage + evasion for a window |
| 🔵 **Cryomancer** (ice — control) | **Absolute Zero** — *targeted AoE*: mass hard freeze (full stun) | **Shatter** — *single/AoE*: detonate frozen/slowed enemies for massive **pet** damage (amplification payoff) | **Brittle Field** — DEBUFF: *targeted AoE* slow + brittle (enemies take greatly increased pet damage) |
| 🔴 **Pyromancer** (lava — damage) | **Wildfire** — *single→spreading*: burn mark ramps pet damage and spreads to neighbors (contagion vulnerability) | **Firestorm** — *team AoE*: every pet's attacks erupt with a burning cleave / flame nova (reshaped from a cone) | **Cataclysm** — DAMAGE: *targeted AoE* meteor; burst = multiple of squad attack power (pet-credited) + lingering molten pool that amplifies pet damage |

**New server mechanics these require** (signatures earn bespoke logic): pet-scaled "amplified-damage"
burst tied to the squad's attack total; encase-root (Bastion); spreading/contagion vulnerability
(Wildfire); conditional detonate on a CC'd target (Shatter); decoy entities (Mirage); team-AoE
every-pet emission (Firestorm); tap-a-pet friendly targeting + splash (Verdant Bloom).

---

## 18. Level-Up & Power Selection System

### 18.1 Player Level Curve

**[PROTOTYPE]** Player levels go from 1 to ~50, with diminishing-returns XP requirements.

XP sources:
- Breakable kills (in any biome, any realm)
- Enemy kills (Hell content)
- Quest/achievement completion
- Daily rewards

XP rewards scale with content tier (Hell mobs > base breakables).

### 18.2 What Levels Grant

Not all levels are the same. The progression interleaves:
- **Power-select levels** (5, 10, 15, 20, 30): pick a new power from your archetype tier
- **Augmentation slot levels** (8, 12, 18, 25, 35, 45): gain 1 augmentation slot (Section 19)
- **Stat levels** (others): minor stat bumps (Focus pool, base recharge rate)
- **Milestone levels** (1, 10, 25, 50): unlock features (auto-target modes, extra equip slots, etc. — leverages existing `configs/player_progression.lua`)

### 18.3 Power Selection UI

At a power-select level, present the player with:
- "Choose your Tier N power"
- 2 options shown side-by-side with descriptions
- Tooltips with mechanics
- Visual preview if possible (ability icon + animation)
- "Choose" is final until respec — make it clear

### 18.4 Respec

Players should be able to respec their powers, but at a cost:
- **[PROTOTYPE]** Respec costs significant Light or Shadow Tokens (a multi-hour grind worth)
- Once-per-week free respec for casual experimentation
- Respec resets all power selections, refunds all augmentation slots
- Player keeps level/XP

The cost gates impulse respeccing while allowing serious build refinement.

### 18.5 Default Choices for Casuals

For players who don't want to choose, the system auto-selects a sensible default at each power-select level (e.g., always pick the first option). They can later visit a trainer NPC to redo choices if they engage more deeply.

This preserves casual accessibility without removing the depth.

---

## 19. Augmentation System

### 19.1 Slot Mechanic

At augmentation-slot levels, the player gains 1 **slot** that they can place on an existing power. Each power can hold up to N slots (suggest 6, configurable).

**[TEMPLATE]** Slot count per power and total slots earnable are config-driven.

### 19.2 Slot Types

Slots come in types, each enhancing a different aspect of the power:

- **Recharge** — reduces that power's cooldown
- **Strength** — increases magnitude (buff size, heal amount, debuff potency)
- **Range** — increases AoE radius or targeting distance
- **Duration** — extends buff/debuff/control duration
- **Efficiency** — reduces Focus cost
- **Reliability** — reduces variance in effect (less random)

Each slot of a type adds a small bonus (e.g., 5% per Recharge slot).

### 19.3 Set Bonuses

Matching slot types in the same power grant **set bonuses** — escalating tiered rewards for stacking:

- 3 Recharge slots in same power: +5% cooldown reduction on **all** powers (not just this one)
- 3 Strength slots in same power: +5% buff strength on all powers
- 4 of a type: stronger universal bonus
- 5 of a type: special set-only ability unlocked

This is the deep customization layer — fully maxed builds spend hours optimizing slot allocation.

### 19.4 Slot Acquisition

Slots themselves come from:
- Level-up augmentation slots (free, basic)
- Drops from Hell content (rarer, higher-tier slots)
- Crafting from materials (mid-game)
- Special event rewards

Higher-tier slots have stronger per-slot bonuses (a "Tier 3 Recharge" slot might give 8% instead of 5%).

### 19.5 Implementation Note

Slot state is per-player (not per-pet). Stored in player ProfileStore as:

```lua
slots = {
  ["stone_skin"] = {
    {type = "recharge", tier = 2},
    {type = "strength", tier = 1},
    {type = "duration", tier = 3},
  },
  ["bless"] = {
    {type = "recharge", tier = 1},
    {type = "recharge", tier = 2},
    {type = "recharge", tier = 3}, -- set bonus 3x recharge active
  },
  -- ...
}
```

Compute total bonuses at power-cast time via modifier pipeline (same pattern as enchant providers).

---

## 20. Hotbar / Command Bar

### 20.1 Layout

20-slot command bar, modeled on City of Heroes:
- **Primary tray:** keys 1–9, 0 (10 slots)
- **Secondary tray:** Shift+1–9, Shift+0 (10 slots)

Each slot can hold any of four bind types (Section 20.2). Players customize freely.

**[TEMPLATE]** Slot count per tray and number of trays are config-driven.

### 20.2 Bind Types

Each hotbar slot holds one of:

1. **Player Power** — an archetype power the player has unlocked. Has cooldown shown on slot.
2. **Swap Macro** — calls a named **roster** (Section 21), swapping the active squad to that roster's pets.
3. **Specific Pet Bind** — swap a specific pet (by ID) into the active squad. For micromanagement.
4. **Tactical Command** — universal commands like "Focus Fire on target", "Scatter", "Recall all", "Hold position".

### 20.3 Per-Slot UI Requirements

Each slot shows:
- Icon (power icon, pet portrait, macro symbol, or command icon)
- Keybind label (1, 2, …, Shift+1, etc.)
- Cooldown overlay (radial sweep)
- Ready/cooling/unavailable state indicator
- Tooltip on hover with full description
- Drag-and-drop support for rebinding

### 20.4 Customization Workflow

Out-of-combat hotbar editor:
- Side menu (the tab system planned) lists all bind candidates:
  - All unlocked powers
  - All defined rosters
  - All owned pets (for specific binds)
  - All available tactical commands
- Drag from menu to hotbar slot
- Save loadouts: "Hell raid loadout", "farming loadout", etc.
- Multiple loadouts swap-able with one click

### 20.5 Default Loadouts Per Archetype

New players ship with sensible defaults:
- Slots 1–4: starting archetype powers
- Slots 5–7: common swap macros ("best healer", "best DPS", "best buffer")
- Slots 8–10: tactical commands (recall, scatter, focus fire)
- Shift+1–0: empty by default

This gives new players a functional kit without forcing customization.

### 20.6 Mobile Adaptation

Roblox is ~50% mobile. The 20-slot hotbar doesn't fit a phone screen.

**Mobile UI mode:**
- 5–6 visible slots at a time
- Swipe to access secondary tray
- Optionally: smart-bar that auto-prioritizes the most relevant 6 slots for current context (combat vs farming)
- Same underlying bindings, different presentation layer

**[TEMPLATE]** Mobile presentation is a config flag + alternate UI implementation. The bind system itself is platform-agnostic.

---

## 21. Roster System (Player-Defined Teams)

### 21.1 Replaces Smart Resolution

The hotbar's "swap macros" don't compute "best pet" via system heuristics. Instead, they call **player-defined rosters** — named lists of pets the player has designated as their healing team, attack team, etc.

This is intentional design:
- No mystery about which pet was swapped in
- Players express their own opinions about pet roles
- Rosters are part of build identity
- System doesn't need fuzzy scoring heuristics
- Easy to share/discuss in community

### 21.2 Roster Data Structure

```lua
roster = {
    name = "Healer Team",
    ordered_pets = {"frost_drake_001", "aurora_002", "phantom_mender_003", ...},
    max_to_deploy = 3,
    injury_rule = "ready_only",  -- or "best_available" or "deploy_anyway"
}
```

Each player can have many rosters. They can be named anything.

### 21.3 Roster Operations

**Add pets to roster:** drag from inventory in roster editor. Order matters (priority 1 first).

**Remove pets:** drag out, or click ✕.

**Edit roster:** rename, reorder via drag, adjust max_to_deploy, change injury_rule.

**Cross-reference:** a pet can be in multiple rosters (your Frost Drake is in "Healers" and "Hell Squad" — both reference the same pet record by ID).

**Default rosters for new players:** create empty starter rosters named "Healer Team", "Attack Team", "Buff Team", "Tank Team" — player fills in as they collect pets.

### 21.4 Injury Rule Options

Per-roster setting controlling how the system handles spirit-form pets when the roster is invoked:

1. **"ready_only"** (default, predictable)
   - Skip any pet in spirit form
   - If top 3 are downed, only the 4th deploys
   - Empty slots if not enough ready pets in roster

2. **"best_available"**
   - Deploy the most-recovered pets, even if partial spirit
   - Useful when you need *someone* healing right now
   - For stacks: deploys whichever has highest `ready_count`

3. **"deploy_anyway"**
   - Use ordered list regardless of recharge state
   - Reduced effectiveness from down pets (still tied to ready_count for stacks)
   - For players who want A-team out there, even tired

### 21.5 Call Semantics: Replace vs Additive

When a roster is called via hotbar:
- **Replace mode (recommended default):** active squad is cleared, roster's pets are deployed up to `max_to_deploy`
- **Additive mode (alternative):** roster's pets are added to existing active squad; if squad exceeds capacity, oldest are recalled

Replace is simpler and more predictable. Additive enables creative play but can be confusing.

**[TEMPLATE]** Call semantics is a config flag, possibly per-roster.

### 21.6 Common Player-Created Rosters

Examples of what players will naturally create:
- "Heaven Farm Squad" (Shadow-aligned for max farm yield in Heaven)
- "Hell Raid Squad" (Light-aligned for combat in Hell)
- "Chaos Rift Squad" (Chaotic pets only)
- "Boss Killer: Inferno Lord" (specific composition for one fight)
- "Casual Loadout" (just pets they like the look of)

### 21.7 Smart Roster Suggestions (Optional Feature)

The system can *suggest* rosters at certain milestones:
- "You've collected enough healer-tagged pets to build a Healing Roster. Auto-create?"
- "Your Shadow pet collection is strong — auto-create 'Heaven Farm Squad'?"

These are convenience prompts; players always have final say.

---

## 22. Active Squad Architecture (Three-Tier)

### 22.1 The Three Tiers

Pet management is hierarchical:

1. **Inventory** — all pets the player owns. Hundreds or thousands. Browsable, sortable, filterable in side menu. Not actively contributing.

2. **Equipped (Bench, ~10)** — pets that follow the player in the world, contribute to farming buffs/idle benefits. Same as RBX-Template's existing "equipped" concept.

3. **Active Combat Squad (3–5)** — the pets actually deployed and fighting in the current encounter. A subset of the Equipped pool.

### 22.2 Sizes

**[PROTOTYPE]** Suggested sizes:
- Inventory: unlimited (or generous cap, say 1000)
- Equipped: 10 (matches existing RBX-Template)
- Active Combat Squad: 5

**[TEMPLATE]** All three sizes are config-driven. Other games might pick different.

### 22.3 Swap Mechanics

**Inventory ↔ Equipped:** done out of combat. Player drags from inventory into one of 10 equip slots.

**Equipped ↔ Active Squad:** done in or out of combat:
- Out of combat: free, instant
- In combat: pet swap has a brief cooldown (~5s) to prevent infinite shuffling
- Pets that just entered spirit form auto-recall to Equipped (no manual swap needed)

### 22.4 Why 3–5 for Active Squad

- **Performance:** 4 players × 5 active = 20 active pets in a multiplayer encounter. Manageable for Roblox.
- **Tactical clarity:** players can read and react to 5 pets at once. 10 would be visual chaos.
- **Decision weight:** smaller squad means each pet matters. Mirrors City of Heroes Mastermind (6 pets max, very tactical).
- **Equip pool flexibility:** larger equipped pool (10) lets players bench backups for in-combat swapping.

### 22.5 Stacked Pets in Active Squad

A stacked pet entry (e.g., "Frost Drake x30") occupies **one** active squad slot. The stack contributes scaled damage per `ready_count / total_count`.

**Visual:** stacked pets appear as a single ethereal/aura presence (sized with stack count) rather than 30 individual entities. Performance-friendly and lore-consistent (spirit of the species).

Unique pets always appear individually with full models.

### 22.6 Slot UI in Active Squad

Each of the 3–5 active squad slots shows:
- Pet portrait (or stack aura icon)
- Pet name (or "Frost Drake x30")
- Stamina/HP bar (for unique pets) or `ready_count / total_count` (for stacks)
- State indicator (Healthy/Strained/Critical)
- Tap to recall, drag to reorder

Empty slots show "Empty" with a button to deploy from bench.

---

## 23. Multiplayer / Group Play

### 23.1 Party Sizes

**[PROTOTYPE]** Group up to 4 players for shared content. **[TEMPLATE]** Configurable, supports any reasonable group size.

### 23.2 Active Squad Scaling

To keep total pet count manageable in groups, active squad caps may be reduced in groups (or stay fixed — design call). Two models:

- **Fixed:** every player has 5 active regardless of group size. 4 players = 20 pets. Manageable.
- **Scaling:** group of 4 = 4 active per player (16 pets total). Solo = 5 active. Tighter.

**Recommendation:** fixed 5 per player. Simpler to communicate. 20 pets is workable.

### 23.3 Cross-Player Support Powers

**Critical for group cohesion:** player powers can target other players' pets.

- A Geomancer's Stone Skin can shield an ally's pet
- A Pyromancer's Forge Heat applies to all squad members' attacks, including allies
- A Cryomancer's Frost Bind controls enemies attacking any player

This turns group play into **true team play**, not parallel solo. Without this, players are just farming in shared instances — boring.

### 23.4 Trinity Composition Emerges

With 4 archetypes and cross-player support, group composition matters:

- **Tank:** Geomancer (protects pets)
- **Crowd Control:** Cryomancer (locks down enemies)
- **DPS Amplifier:** Pyromancer (boosts pet damage)
- **Utility:** Sandwalker (positioning, debuffs)

A balanced raid party uses all four. Players will recruit by archetype: "LF Geomancer for Inferno raid." That's MMO social dynamics in a pet game.

### 23.5 Difficulty Scaling

Encounters scale with group size to maintain challenge:
- Boss HP/damage scales by group size
- Add count scales (more enemies for bigger groups)
- Boss mechanics may add new requirements with bigger groups (e.g., 4-player raids have an extra adds phase)

Without scaling, 4-player groups trivialize solo content. With scaling, group content remains challenging.

### 23.6 Loot Attribution

Standard MMO conventions:
- Drops split among party (or shared, configurable)
- MVP bonus for the player who contributed most (pet damage + support uptime)
- Rare/unique drops use need-or-greed or shared instance loot

**[TEMPLATE]** Loot rules config-driven.

### 23.7 Cooldowns Are Personal

A pet that's downed for Player A doesn't affect Player B's pets. Each player's pet pools recharge independently. This means:
- One player wiping doesn't kill the group
- A second player can continue with their pets, finish the encounter, wait for others
- Less harsh group failure cascades

---

## 24. Chaos Rifts & Endgame

### 24.1 Concept

Endgame content for players who've engaged both paths (or at least one to maximum). Chaos Rifts are:
- Time-limited events (open at certain hours or triggered by world conditions)
- Located in the Central Hub or specific biomes during the event
- Require **Chaotic pets** to be effective (other pets penalized)
- Drop unique rewards: Chaotic essences, Aether, rare cosmetics

### 24.2 Why Chaotic Pets Matter Here

In Chaos Rifts:
- Light pets: 0.5× (penalized — out of place)
- Shadow pets: 0.5× (penalized — out of place)
- Chaotic pets: 2.0× or more (thrive)

This gives Chaotic pets a clear gameplay niche even though they're moderate in regular content. Players grind to fuse Chaotic pets specifically to access Rift content.

### 24.3 Convergence Content

Beyond Rifts, the central arena hosts **convergence raids** — bosses both Heaven and Hell-aligned players need to defeat together. These reward unique tokens that can be traded for cross-faction items (the asymmetric trade market we discussed in trade economy).

### 24.4 Capstone: The Realm Lords

The deepest layers (Heaven 3, Hell 3) each have a **Realm Lord** boss — capstone fights for path completion. After defeating both Realm Lords, the player unlocks **Ascendant** content (post-game) where Light/Shadow distinctions blur and Chaotic dominance takes over.

---

## 25. Trade Economy Summary

### 25.1 Tradeable vs Non-Tradeable

**Tradeable:**
- Pets (any type, including Chaotic)
- Most consumables
- Augmentation slots (probably — design call)
- Cosmetics

**Non-tradeable:**
- All hatching currencies (Earth, Desert, Ice, Lava coins)
- All alignment tokens (Light, Shadow)
- Aether (Chaotic-tied)
- Player level / XP
- Power selections, augmentation allocations
- Personal soulbound items

### 25.2 Why Pets Are Tradeable

The cross-realm dominance design **requires** pet trading:
- Heaven players hatch Light pets, but want Shadow pets to farm Heaven biomes
- Hell players hatch Shadow pets, but want Light pets to farm Hell biomes
- Without trading, each side can't access optimal farming pets
- Trading is the **structural** solution, not a bolt-on feature

### 25.3 Trading Infrastructure

Standard secure trade UI with:
- Two-party confirmation
- Anti-duplication safeguards
- Audit log for high-value trades
- Trade history for player records

**[FROM RBX-TEMPLATE roadmap]** Existing planned feature: "Trading/marketplace with Roblox-native escrow and anti-duplication guarantees." This design assumes that feature.

### 25.4 Marketplace vs Direct Trade

Both should exist eventually:
- **Direct trade:** two players agree on a swap, do it in person
- **Marketplace:** asynchronous listings (sell pet for X gems, browse other players' listings)

Direct trade is cheaper to build; marketplace is the long-term retention loop.

### 25.5 No Currency Trading

Reiterated: hatching currencies are non-tradeable. This prevents:
- Bot farms transferring earned currency to main accounts
- New-player exploitation
- Power-leveling shortcuts that break progression

---

## 26. UI / Side Menu System

### 26.1 The Persistent Side Menu

Tab-based side menu accessible at all times, containing:

| Tab | Purpose |
|---|---|
| **Active** | Current combat squad (3–5 slots) with status |
| **Bench** | Equipped pets not currently in active squad |
| **Inventory** | Full pet collection, filterable |
| **Rosters** | List of player-defined rosters, edit/manage |
| **Powers** | Equipped archetype powers, slot allocations |
| **Hotbar** | Hotbar editor (drag bindings) |
| **Achievements** | Existing achievement system from RBX-Template |
| **Pet Index** | Existing pet index (collection completion) |

### 26.2 Inventory Filtering

The inventory tab needs strong filters because players will have hundreds of pets:

- **By alignment:** Light / Shadow / Chaotic / Neutral
- **By theme:** Earth / Desert / Ice / Lava
- **By rarity:** Common / Rare / Epic / Legendary / Eternal / Huge
- **By status:** Ready / Recharging / Equipped / Bench / Inactive
- **By role tag:** Healer / DPS / Tank / Utility (player-defined or inferred)
- **By recently obtained**
- **By favorite/locked**

Combine filters freely. Save filter presets.

### 26.3 In-Combat UI Mode

When combat starts, the side menu adapts:
- **Active tab** auto-focuses
- **Bench tab** stays accessible for quick swaps
- **Other tabs** read-only or hidden (no editing rosters mid-fight)
- **Hotbar overlay** prominent at bottom of screen
- **Focus meter** visible
- **Pet status bars** prominent

### 26.4 Out-of-Combat UI Mode

Full editing capability:
- Roster management
- Hotbar customization
- Power selection
- Augmentation slot allocation
- Inventory organization

### 26.5 Mobile Adaptations

**[TEMPLATE]** Mobile UI mode is configurable. Recommended adaptations:
- Side menu collapses to bottom drawer
- Hotbar shows 5–6 slots, swipe for more
- Combat HUD simplified (smaller, fewer indicators)
- Touch-friendly larger hit targets
- Roster editor accessible but optimized for smaller screen

---

## 27. Existing Codebase Integration Plan

### 27.1 Configs to Extend

| Existing file | What to add |
|---|---|
| `configs/areas.lua` | Add `realm_alignment` field per area (light/shadow/neutral); add layer/loop level field |
| `configs/markers.lua` | Add portal marker types for ascend/descend |
| `configs/pets.lua` | Add `element` field per pet family entry; add `blessed`/`corrupted` variants |
| `configs/player_progression.lua` | Add power-select levels, slot levels; integrate with new archetype system |
| `configs/breakables.lua` | Add per-layer reward multipliers; add Light/Shadow Token drops in aligned layers |
| `configs/enchants.lua` | Existing modifier pipeline — add element resonance and theme utility providers |

### 27.2 New Configs to Create

| New file | Purpose |
|---|---|
| `configs/elements.lua` | Element multiplier matrix (3×3 or configurable) |
| `configs/theme_utility.lua` | Biome dichotomy utility passives |
| `configs/archetypes.lua` | The four archetypes with their power pools |
| `configs/powers.lua` | All player powers with effects, cooldowns, costs |
| `configs/augmentation.lua` | Slot types, set bonuses, slot tiers |
| `configs/enemies.lua` | Enemy definitions for Hell content |
| `configs/cooldowns.lua` | Per-content-tier spirit form recharge rates |
| `configs/combat.lua` | Combat parameters: stack contribution curve, focus mechanics, etc. |
| `configs/rosters.lua` | Default rosters for new players; max roster count; etc. |
| `configs/portals.lua` | Portal endpoints, costs, layer destinations |

### 27.3 New Services to Build

| Service | Responsibility |
|---|---|
| `AlignmentService` | Track Soul stat, fire updates on biome conquest |
| `LayerService` | Manage stacked layer access, portal travel between layers |
| `ElementResonanceProvider` | Modifier provider for element × biome alignment multiplier |
| `ThemeUtilityProvider` | Modifier provider for theme × biome utility passives |
| `SpiritFormService` | Handle pet downed states, recharge timing, recovery |
| `StackPoolService` | Manage ready_count refill for stacked pets |
| `CombatService` | Enemy spawning, combat lifecycle, target/aggro |
| `PowerService` | Activate player powers, cooldowns, focus costs |
| `AugmentationService` | Apply augmentation slot bonuses to power effects |
| `RosterService` | Manage player rosters, resolve roster calls |
| `HotbarService` | Process hotbar input, dispatch to powers/macros/binds |
| `FocusService` | Track player Focus state, handle disruption |
| `FusionService` | Chaotic pet creation from Light + Shadow sacrifice |

### 27.4 Services to Extend (Existing)

| Existing service | Extensions |
|---|---|
| `PetGrantService` | Tag new pets with element on hatch based on layer |
| Existing equip service | Add active squad layer (3-tier hierarchy) |
| Existing portal/pad travel | Add layer-aware destinations |
| Modifier pipeline | Add new providers (element, theme, archetype power, augmentation) |
| Active-zone breakable spawning | Tie biome conquest events to AlignmentService |

### 27.5 Save Schema Additions

Player ProfileStore additions:
```lua
{
  -- existing fields...
  
  soul = 0,                    -- signed int, -100 to +100
  archetype = "geomancer",     -- or other archetype id
  powers = {                   -- ordered by tier
    "stone_skin", "bulwark", "mountain_strength", "earthen_resurgence", "living_fortress"
  },
  slots = {                    -- per-power slot allocations
    stone_skin = {
      {type = "recharge", tier = 2},
      {type = "strength", tier = 1},
    },
    -- ...
  },
  hotbar = {                   -- 20 slots, each a bind type + target
    [1] = {type = "power", target = "bless"},
    [2] = {type = "roster", target = "Healer Team"},
    -- ...
  },
  rosters = {                  -- player-defined teams
    {
      name = "Healer Team",
      ordered_pets = {...},
      max_to_deploy = 3,
      injury_rule = "ready_only",
    },
    -- ...
  },
  current_layer = "base",      -- or "heaven_1", "hell_2", etc.
  light_tokens = 0,
  shadow_tokens = 0,
  aether = 0,                  -- if Chaotic progression added
  
  -- pet records (existing) gain new fields:
  pets = {
    -- unique:
    {pet_id = "...", element = "light", lastDownedAt = nil, ...},
    -- stacked:
    {pet_id = "...", count = 30, ready_count = 30, last_update = nil, ...},
  },
}
```

---

## 28. Implementation Phasing Recommendation

### 28.1 Suggested Phase Order

**Phase 1: Foundations (existing or near-existing)**
- Ring topology with biomes (existing)
- Themed currencies (existing)
- Pet inventory hierarchy (existing, may need bench/active separation)
- Basic farming loop in base realm (existing)

**Phase 2: Soul & Heaven Layers**
- AlignmentService + Soul stat tracking
- HUD soul meter
- Heaven Layer 1 stacked geometry
- Portal system (ascend only first)
- Light Token currency
- Heaven-layer breakable drops scaled up

**Phase 3: Spirit Form + Active Squad**
- SpiritFormService (cooldowns)
- StackPoolService (ready_count refill)
- Active Squad layer in pet hierarchy (3-tier)
- Pet swap UI between Bench and Active

**Phase 4: Element System**
- ElementResonanceProvider modifier
- Pet element field on records
- Element-aware hatching (Heaven hatches Light)
- Trade-economy infrastructure (if not existing)

**Phase 5: Hell Layers + Basic Combat**
- Hell Layer 1 stacked geometry
- Shadow Token currency
- EnemyService (basic mob spawning + AI)
- Combat lifecycle (encounter start/end)
- Basic pet auto-attack behavior

**Phase 6: Archetypes & Powers**
- ArchetypeService
- Power configs and execution
- Focus stat (player resource)
- Power selection at level-up

**Phase 7: Hotbar & Rosters**
- HotbarService with 20 slots
- 4 bind types implemented
- RosterService with player-defined teams
- Side menu UI for management

**Phase 8: Augmentation System**
- Slot types and acquisition
- Set bonus computation
- Augmentation UI

**Phase 9: Multiplayer Group Play**
- Party system
- Cross-player support powers
- Difficulty scaling
- Loot attribution

**Phase 10: Deep Hell + Chaotic Content**
- Hell Layers 2 and 3
- Realm Lord bosses
- Fusion (Chaotic pet creation)
- Chaos Rifts

**Phase 11: Endgame & Polish**
- Convergence content
- Marketplace
- Cosmetic systems
- Long-tail retention features

### 28.2 Why This Order

- **Phase 2 ships value first.** Adding Heaven layers gives engaged players deeper farming immediately — most existing systems extend, little new is needed.
- **Phase 3 prepares for combat.** Spirit form is foundational; build it before combat needs it.
- **Phase 5 is the first major scope expansion.** Hell + basic combat is the first phase that genuinely adds new genre content.
- **Phases 6–8 are MMO-flavored systems.** They build on each other; ship them together.
- **Phase 9 unlocks social play.** Multiplayer becomes worthwhile once combat depth exists.
- **Phase 10–11 are the long tail.** Endgame and Chaotic are aspirational; ship them when the core is solid.

### 28.3 Critical Path Dependencies

```
Phase 1 (foundations) 
  → Phase 2 (Heaven) 
    → Phase 3 (spirit form, needed for combat) 
      → Phase 4 (element, expands trading)
      → Phase 5 (Hell + basic combat) 
        → Phase 6 (archetypes + powers, depends on combat existing)
          → Phase 7 (hotbar/rosters, depends on powers existing)
            → Phase 8 (augmentation)
              → Phase 9 (group play)
                → Phase 10 (deep Hell + Chaotic)
                  → Phase 11 (endgame)
```

---

## 29. Open Design Questions

The following decisions were deliberately deferred or marked for later resolution:

1. **Soul stat resettable or permanent?** Leaning resettable-but-costly, but pet sim conventions vary. Playtest to decide.

2. **Active Squad size: 3, 4, or 5?** 5 is suggested. CoH used 6 for Masterminds. May need playtest tuning.

3. **Stack contribution curve: linear, sqrt, or log?** All should be implemented at template level; prototype picks one. Likely sqrt_diminishing for balanced feel.

4. **Cross-player support: opt-in or always-on?** Recommendation: always-on for friendlies in the same party. May add toggle for trolls/grief prevention.

5. **Roster replace vs additive semantics?** Recommendation: replace by default, with optional additive mode in player settings.

6. **Number of archetypes: stick at 4 or expand?** Four is suggested for prototype. Adding more archetypes is content work, not architecture work — defer.

7. **Power selection branching depth.** Currently 5 tiers × 2 options each. Could be wider (3 options per tier) for more variety. Playtest balance.

8. **Mobile slot count.** Default 6 visible, swipe for more. May need tuning.

9. **Chaotic pet acquisition methods beyond fusion.** Should there be event-only Chaotic eggs? Probably yes, eventually. Deferred to endgame phase.

10. **Specific number of layers per realm.** Suggested 3 each (Heaven 1/2/3, Hell 1/2/3). Could expand to 9 each (Dante-style) at scale.

11. **Player level cap.** Suggested 50 for prototype. Test if 50 powers + augmentation is too short or too long.

12. **Augmentation slot maximum per power.** Suggested 6. Test for build depth feel.

13. **Whether Heaven/Hell base layer 1 is reachable by all or gated.** Probably gated weakly (small token cost) but accessible to all alignments.

14. **Permadeath PvP?** Almost certainly no, but worth explicitly ruling out in design docs to prevent it being added carelessly.

15. **Pet roles: explicit tags or inferred from theme?** Suggested inferred (Ice → CC, Lava → DPS, etc.) but could be explicit per-pet tags for finer control.

---

## 30. Glossary

| Term | Meaning |
|---|---|
| **Active Squad** | The 3–5 pets currently deployed in combat |
| **Alignment** | The Heaven/Hell axis tracked by the Soul stat |
| **Archetype** | Player's chosen class (Geomancer, Sandwalker, Cryomancer, Pyromancer) |
| **Augmentation Slot** | A slot placed on a power to enhance it (Recharge, Strength, etc.) |
| **Biome** | A themed region (Earth, Desert, Ice, Lava) |
| **Chaos Rift** | Endgame combat content requiring Chaotic pets |
| **Chaotic** | Third element, created via fusion of Light + Shadow pets |
| **Conquest** | Completing a biome's content for the first time in a loop (triggers Soul update) |
| **Dichotomy** | Opposing biome pairs (Earth↔Desert, Ice↔Lava) that grant utility passives |
| **Dominance** | The +1.5× multiplier pets get in their opposing realm |
| **Element** | Pet's alignment affinity (Light, Shadow, Chaotic, Neutral) |
| **Equipped** | The 10 pets following the player; superset of Active Squad |
| **Focus** | Player resource that can be disrupted (replaces HP) |
| **Fusion** | Sacrificing Light + Shadow pet to create Chaotic |
| **Hell** | Counterclockwise/descending path; combat-focused |
| **Heaven** | Clockwise/ascending path; farming-focused |
| **Inventory** | All owned pets, the full collection |
| **Layer** | A specific instance of the world (base, Heaven 1/2/3, Hell 1/2/3) |
| **Light Token** | Heaven alignment currency |
| **Loop** | One complete circuit around the ring; unlocks a new layer |
| **Realm** | Same as Layer in casual usage; also refers to the Heaven/Hell category |
| **Realm Lord** | Capstone boss at the deepest layer of each realm |
| **Resonance** | The +1.2× home-realm bonus for pets |
| **Roster** | Player-defined ordered list of pets called by hotbar macros |
| **Sanctuary** | Heaven-side safe zone where pets recharge faster |
| **Shadow Token** | Hell alignment currency |
| **Soul** | The alignment stat ranging from −100 (deep Hell) to +100 (deep Heaven) |
| **Spirit Form** | Downed pet state — pet is resting, not destroyed |
| **Theme** | Pet's biome category (Earth, Desert, Ice, Lava) |
| **Utility Passive** | Non-damage ability granted by biome dichotomy |

---

## 31. Final Notes for the Coding Agent

### 31.1 Wiki Workflow Reminder

This project uses `docs/wiki/` for persistent agent memory. Per the existing AGENTS.md workflow:
- Read `docs/wiki/INDEX.md` first
- Follow links to `CURRENT_STATUS.md`, `DECISIONS.md`, `ARCHITECTURE.md`, `STUDIO_WORKFLOW.md`, `MAP_INTEGRATION_CONTRACT.md`
- Update the wiki after any change that touches architecture, config shape, save fields, or project direction
- This design document should be **referenced from the wiki**, not pasted into it — keep wiki entries lightweight

### 31.2 Template vs Prototype Discipline

Throughout implementation, maintain the discipline:
- **Generic mechanics go in template-level code** (services that work for any game)
- **Specific values, names, content go in prototype configs**
- When in doubt, make it config-driven and pick a default

A future fork of RBX-Template should be able to:
- Replace `configs/archetypes.lua` with their own classes
- Replace `configs/elements.lua` with their own element system
- Replace `configs/pets.lua` with their own pet list
- Inherit all the systems (Soul, layers, spirit form, hotbar, rosters, etc.) without touching service code

### 31.3 Make the Modifier Pipeline the Backbone

Most of what's added here flows through the **existing modifier pipeline**. New providers:
- ElementResonanceProvider
- ThemeUtilityProvider
- PlayerPowerBuffProvider (when active powers buff pets)
- AugmentationProvider (when slots modify power effects)

Lean on the pipeline. Don't bypass it. If you find yourself writing direct stat math outside the pipeline, that's a signal to refactor.

### 31.4 Server Authority on Everything

Per existing RBX-Template patterns:
- Soul stat: server-authoritative
- Pet element assignments: server-authoritative at hatch
- Cooldown timing: server-authoritative
- Power activation: server-authoritative
- Layer access: server-authoritative
- Roster resolution: server-authoritative

Client renders state. Client suggests actions. Server validates and executes.

### 31.5 Smoke Tests

Add new smoke test files in `tests/studio/`:
- `AlignmentSoulSmoke` — verify Soul updates on biome conquest
- `LayerPortalSmoke` — verify portal access gating
- `ElementResonanceSmoke` — verify multipliers compute correctly
- `SpiritFormRechargeSmoke` — verify cooldowns and pool refill
- `RosterCallSmoke` — verify roster invocation with each injury_rule
- `PowerActivationSmoke` — verify cooldowns, focus costs, modifier application
- `MultiplayerGroupSmoke` — verify cross-player support, scaling, loot attribution

Follow the existing `Phase5AutoSystemsSmoke` pattern.

### 31.6 Don't Build Combat Before Spirit Form

A trap: it's tempting to build combat systems first because they feel exciting. **Build spirit form / pool model / active squad layer first.** Combat depends on knowing how downed pets are tracked. Skipping this leads to combat refactors later.

### 31.7 Don't Optimize Premature

The element multiplier table is a 3×3 lookup. The roster system is an ordered list. The hotbar is 20 slots. These are tiny data structures. Don't over-engineer caching, indexing, or optimization until you've shipped and measured.

### 31.8 Closing Thought

This design has internal cohesion — most decisions reinforce each other. The ring topology supports loop overlays. Loop overlays support directional progression. Directional progression supports alignment. Alignment supports trade economy. Trade economy supports cross-realm dominance. Dominance supports element tagging. Element tagging supports Chaotic fusion. Chaotic fusion supports endgame.

The danger is breaking that cohesion by changing one piece without checking the cascade. If you find yourself wanting to change something fundamental (e.g., "what if Heaven also has combat?"), trace what else that decision affects before committing.

The spine of the design:
1. **Pets are the unit of power. Player is invulnerable conductor.**
2. **Direction determines playstyle. Heaven farms, Hell fights.**
3. **Cross-realm dominance creates the trade economy.**
4. **Spirit form replaces death. Player commitment via Soul replaces respec churn.**
5. **Template stays generic. Prototype defines content.**

Hold the spine. Everything else can flex.

---

## 32. Zone Economy & Mineable Currencies (locked 2026-06)

Decisions locked with the user. This supersedes any earlier "themed currency" notes that
implied beach as a fifth coin or tradeable biome coins.

### 32.1 The five currencies
- **Four zone coins — one per elemental zone, SOULBOUND (non-tradeable):**
  `grass_coins` 🌿, `desert_coins` 🏜️, `lava_coins` 🌋, `ice_coins` 🧊.
  (`grass_coins` was renamed from `earth_coins`; the biome id is still internally `earth`.)
- **`gems` 💎 — the ONLY tradeable currency** (premium + the trade medium). Player-to-player
  trading moves gems, never zone coins.
- These four wallets **persist across Heaven/Hell layers** — currency is profile-global, so
  ascending/descending never resets them. The `light_tokens`/`shadow_tokens` remain a SEPARATE
  vertical-progression axis (how high in Heaven / deep in Hell), not "money".

### 32.2 What you mine — one themed ore family per zone, 3 tiers
Mirror the existing Small/Medium/Big crystal tiering, reskinned per element; each pays that
zone's coins. No new art required to ship the loop (reskin the existing crystal mesh).

| Zone (element) | Ore | Pays |
|---|---|---|
| Grass (earth) | **Bloomstone** (mossy green geode) | `grass_coins` |
| Desert | **Sunglass** (amber heat-fused shard) | `desert_coins` |
| Lava | **Emberstone** (cracked obsidian) | `lava_coins` |
| Ice | **Frostshard** (the existing blue crystal) | `ice_coins` |

Generic `coins` / `crystals` are **retired as mine outputs**; `gems` stays premium. (Full removal
of `coins`/`crystals` from the template shop/upgrades/enchants/auto-target is a deferred phased
migration — they're load-bearing in ~20 template files.)

### 32.3 Beach — dropped
Beach is removed from the design's currency set (no `beach_coins` as a mined currency). Trading
is **global** (not zone-gated); a dedicated trading zone may come later but is not required.
NOTE: physically removing `beach` from the biome ring (`biomes.lua` + RingTopology/conquest
specs that hardcode beach's soul-math) is a deferred cleanup — it has no functional payoff for
the mining economy.

### 32.4 Implementation status
- **Slice A (done):** gems-only trade rule (`TradeLogic` + `configs/trade.lua tradeable_currencies`),
  `earth_coins`→`grass_coins` rename. Headless-tested.
- **Slice B (next):** `breakables.lua` 4 ore families + per-element reskin field + spawner support;
  4 in-world mining zones; live verify each zone pays its coin and persists cross-layer.
- **Deferred:** beach removal from the ring; full `coins`/`crystals` retirement across the template.

---

*End of design document. Total target word count: ~15,000 words. Designed for handoff to coding agent or split into multiple architecture docs as needed.*

---

## Dragons, Secrets, and Player Class (Rebirth) — Jason, 2026-06-10

### Dragons are SECRET-tier, permanently

Dragons are and will always be **secret** pets. Secret is one of the special rarities
(`configs/inventory.lua special_rarities`), which means every dragon is a **per-instance
uid record** — never a common quantity-stack. Each unique pet record carries:

- `uid` — per-instance UUID (minted at hatch)
- `obtained_at` — timestamp
- `hatched_by` — UserId of the original hatcher (new mints from 2026-06-10; legacy
  records pre-date the field and leave it unset, since trades make it unknowable)
- `player_class` — the **hatcher's** player class at hatch time (see below). Legacy
  unique pets (the huges) are retrofitted to `player_class = 1` on join.

### Player Class (number, default 1)

`data.PlayerClass` on the player (default 1, implied when absent) and `player_class`
on every unique pet record. The pet's field is stamped from the **hatcher's** class at
the moment of hatch and never changes afterward — provenance, not state.

### The Rebirth design (directional, not yet built)

- Reaching **Level 50** unlocks **Rebirth**. Rebirthing raises the player's class
  (1 → 2 → …) and resets the climb.
- The rebirth reward: **one HUGE dragon**.
- Post-rebirth, **only dragons work for you** — the class-2 climb is hatched on
  dragon teams.
- To reach the *next* Level 50, you must hatch a **full team of dragons** yourself.
- **The anti-shortcut rule (why player_class exists):** progression checks count only
  dragons whose `player_class` matches your current class. A dragon hatched by a
  class-1 player (or bought/traded from one) can NEVER satisfy a class-2 requirement —
  you cannot stockpile dragons before rebirthing, and you cannot buy your way up.
- Rainbow/golden ladders may join the same structure later; the class stamp is the
  general mechanism, not a dragon-only hack.

### The 11 Dragons — one per realm (the rebirth collection)

There are exactly **11 realms** (Base/Earth + Heaven 1–5 + Hell 1–5), and **exactly one
signature dragon per realm** — so the dragon roster is a fixed set of **11**. Each realm's
dragon is that realm's SECRET-tier chase pet (its hatch odds anchor the realm's egg pool),
and together the 11 form the rebirth collection. The 4 origins repeat up and down the stack,
capped by two pure apexes (Seraph at Heaven 5, Void at Hell 5).

| #  | Realm        | Dragon (working name) | Origin            | Note               |
|----|--------------|-----------------------|-------------------|--------------------|
| 1  | Base (Earth) | *(existing grass dragon)* | Grass         | the starter        |
| 2  | Heaven 1     | Empyrean Dragon       | Fire (solar)      | first ascended     |
| 3  | Heaven 2     | Aurora Dragon         | Ice               |                    |
| 4  | Heaven 3     | Verdant Dragon        | Grass (bloom)     |                    |
| 5  | Heaven 4     | Alabaster Dragon      | Desert            | was "Gilded" (no-gold rule) |
| 6  | Heaven 5     | Seraph Dragon         | radiant apex      | grandest ascended  |
| 7  | Hell 1       | Abyssal Wyrm          | Fire (infernal)   | Empyrean's mirror  |
| 8  | Hell 2       | Rimewraith Dragon     | Ice (black-ice)   |                    |
| 9  | Hell 3       | Blight Dragon         | Grass (rot)       |                    |
| 10 | Hell 4       | Glass Dragon          | Desert (scorched) |                    |
| 11 | Hell 5       | Void Dragon           | shadow apex       | grandest fallen    |

Names are working titles; the **structure (one dragon per realm, 11 total)** is the locked
part. Full per-realm pet rosters (the farmable supporting cast around each dragon) live in
[PET_REALM_HEAVEN_HELL_ROSTER.md](PET_REALM_HEAVEN_HELL_ROSTER.md).

### Dragon design rules (locked)

- **Always SECRET — forever.** Every dragon is secret-tier, with no exceptions; no dragon is
  ever common/rare/epic. This is load-bearing, not flavor: "dragon ⇒ secret" is what makes each
  a per-instance uid record carrying `player_class`/`hatched_by`, which is the only thing that
  makes the rebirth gate and its anti-shortcut rule work.
- **One per realm, origin rotates.** Exactly 11 (table above); the origin marches Grass (base)
  → Fire → Ice → Grass → Desert → apex up each side of the stack.
- **Dragons need NOT be ranged.** Every dragon shipped so far happens to be ranged (the
  Empyrean / Abyssal wyrms), but that is *incidental, not a rule*. A dragon takes whatever
  role/archetype its realm's origin leans. The **Ice tier-2 pair — Aurora Dragon (Heaven 2) /
  Rimewraith Dragon (Hell 2) — are deliberately MELEE / CONTROL**: they wade *in* and their
  frost-breath roots and freezes, claws in melee. They are the first non-ranged dragons, on
  purpose, to make this concrete. Future dragons may be tanks, melee, or support as the origin
  dictates.

### Realm aesthetic gradient & palette (locked)

Each tier pushes the **same four origins one step further from base reality**, along the
light/dark axis — the element stops being a *place* and becomes the *idea*:

- **Earth (base):** the literal element.
- **Heaven 1 / Hell 1:** the *idealized* (gilded paradise) / *corrupted* (ash & rot) element —
  still recognizably a place.
- **Heaven 2+ / Hell 2+:** the element **de-materializes** — heaven into prismatic/auroral and
  then pure radiant light; hell into black-ice, then ash, then void. Ground gives way to
  cloud-sea/cosmos going up, or a crumbling abyss going down.

Per-tier "farther from reality" levers (the checklist you crank each step): lighting (soft →
blooming radiance vs lit → near-black), physics (grounded → floating vs grounded → sinking),
palette saturation (real → pure white vs real → pure black), skybox, ambient.

**Palette rule — gold & rainbow are RESERVED for the shiny VARIANT tiers.** Golden and rainbow
are cross-cutting shiny variants that apply to *every* pet (a golden Aurora Dragon, a rainbow
bunny exist). So **no realm uses gold or rainbow as its dominant/signature palette** — otherwise
a realm-native pet reads as "the gold/rainbow variant" and the rarity signal blurs. Consequences:

- **Heaven** leans **white / silver / pearl / prismatic / aurora** — radiance, not metal.
  (Heaven 1's *gilded* accents are grandfathered as "earthly-paradise gold leaf"; from Heaven 2
  up, the gradient deliberately moves *off* gold into pure light — which also makes a gold shiny
  *pop* harder against a white realm.)
- **Hell** leans **black / obsidian / ash / ember-on-black / sickly-violet.**

### The all-11 self-hatch gate

The class-N climb requires hatching **all 11 dragon species yourself, at your current class**,
to rebirth again — not "a full team" loosely, but the **complete set of 11**. This makes
"playing for dragons" literal: late game is a tour of all 11 realms to complete the set before
each rebirth. Combined with the anti-shortcut rule above (a dragon's `player_class` is stamped
from the hatcher; progression counts only matching-class dragons), you cannot trade, buy, or
stockpile your way past it — every rebirth is re-earned across the whole realm stack. The gate
check is `hatched_dragon_species(at current class) ⊇ {all 11 realm dragons}`.

### Implementation status

- ✅ `player_class` + `hatched_by` stamped on all new unique-pet mints
  (`InventoryService:_addPetRecords`)
- ✅ Join-time retrofit: legacy uid records get `player_class = 1`
- ⏳ Rebirth action, class increment, **all-11-dragon** progression check, huge-dragon
  reward: future epic (design above is the SoT)
