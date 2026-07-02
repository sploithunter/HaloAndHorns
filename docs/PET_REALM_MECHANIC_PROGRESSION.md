# Pet Mechanic Progression — when pets stop being reskins

Status: design (Jason + Claude, 2026-06). Companion to
[PET_REALM_HEAVEN_HELL_ROSTER.md](PET_REALM_HEAVEN_HELL_ROSTER.md) (the lineup) and
[PET_REALM_DESIGN_DOCUMENT.md](PET_REALM_DESIGN_DOCUMENT.md).

## The question

A pet's **power number is fully fungible** — output = `base_power × variant × archetype × element ×
shiny`, clamped at `max_pet_power`, plus *contextual* biome-RPS and heaven/hell resonance at fight
time. **The source egg/layer is nowhere in it.** So a power-30 lava blaster is a power-30 lava
blaster no matter where it hatched. Good for trade fairness — but it means *vertical* progression
(base → L1 → L2 → … → L5) risks being **number + art reskins** unless something else differentiates.

That "something else" is **mechanics** — AoE, spreading DoT (contagion), on-hit riders (slow/shred/
execute), tank taunt/pull, support auras. These change *effective throughput and behavior* without
touching the fungible number, so a deep pet plays differently, not just looks different.

## Two reskin axes — only one is a problem

- **Horizontal (heaven ↔ hell mirror):** Coronal Cherub ↔ Frostcinder Imp. **Reskinning here is
  fine and intended** — they're differentiated by *where they live* (realm income/toughness curve)
  and *realm vulnerability* (attack asymmetry: heaven only hits hell, hell hits all). Variety is
  welcome but not required. **Not a foul.**
- **Vertical (same origin × archetype, deeper layer):** Emberling → Coronal → Gloryspark → Sunspark
  → Seraph Cherub (all "Fire common melee"). **This is the axis to watch.** If layer 5's fire-melee
  is just a bigger-number recolor of layer 1's, the climb feels hollow.

## The recurring archetype slots (the reskin lattice)

Each origin egg fields ~5 pets spanning roles, and the **same ~5 slots recur every layer**:

| Origin (lean) | Slot A | Slot B | Slot C | Slot D | Apex (Mythic) |
|---|---|---|---|---|---|
| 🔥 Fire (damage) | Melee (Cherub/Imp) | Bruiser (Lion) | Blaster (Phoenix/Lance) | Offense-buff (Salamander) | Blaster apex (Phoenix/Firehawk/Ifrit) |
| ❄️ Ice (control) | Melee (Hare/Seal) | Control (Fox/Wisp/Jelly) | Blaster (Owl/Moth/Petrel) | **Tank** (the Bear) | Tank/control apex (Leviathan/Mammoth/Yeti) |
| 🌿 Grass (tank) | Heal (Lamb) | Melee (Hare/Hart) | Tank (Stag/Rhino/Beetle/Tortoise) | Yield (Sprite) | Tank/heal apex (Ent/Colossus) |
| 🏜️ Desert (support) | Heal (Dove/Ibis/Lark) | Shield/buff (Idol/Totem) | Yield/buff (Meerkat/Mongoose) | Regen (Camel) | Support apex (Couatl/Sphinx/Lammasu) |

Plus the **Secret dragon** (one per realm; origin rotates Fire→Ice→Grass→Desert→apex by layer).

That's ~20 recurring slots, each appearing ~5× down the stack. The design job is: give each slot a
**signature mechanic**, decide **which layer it debuts**, and **escalate it with depth** — so the
5th instance of a slot is mechanically richer than the 1st, not just numerically.

## Designated powers — the variety that's already in the system

The cleanest unit of differentiation isn't an abstract "mechanic" — it's a **designated power**, the
exact mechanism the support and control pets already carry:

- **Support pets** ship with a designated power *by nature*: the heal / shield / buff / yield / regen
  (heaven) or drain / curse / shred (hell) aura. That's a **significant** effect, not flavor — a
  yield aura measurably changes income, a shield aura changes survivability. So **support pets are
  differentiated from Common up**: two power-30 supports with different auras play completely
  differently. Not reskins, ever.
- **Control pets** likewise carry a designated power — slow / root / freeze / fear. Also significant
  (kiting flyers, holding a pull). So **control pets are already differentiated too**.

So the reskin risk is concentrated on the archetypes that **don't yet carry a designated power: the
pure damage line (melee / bruiser / blaster) and the plain tank.** Those are the stat-sticks.

**The precedent and the lever:** support + control prove that *"a pet = its number + its designated
power"* produces real variety at equal power. So the anti-reskin move for the damage/tank line is
simply **to give them designated powers too** — a blaster's splash volley, a bruiser's lifesteal, a
tank's taunt/thorns are all just *designated powers* sitting in the same slot the support aura
occupies. The **16 signature powers (4 per origin)** are the ready library to draw from. We don't
need a new system — we extend the one support/control already use. (This is what the per-slot table
below is really listing: which designated power each non-support/non-control slot earns, and when.)

### The power doesn't have to be combat — and that's the strongest knob

A designated power can be **any** power, not just AoE / contagion / control. The **economy &
utility** powers — coin yield, luck, XP, magnet radius, drop-rate (Windfall) — work on **any pet of
any archetype**. That makes them a uniquely powerful anti-reskin lever:

> Drop a **+coins** power onto an otherwise-identical mid-tier melee pet and it becomes a **keeper** —
> hugely valuable late-game even though its combat stats match a hundred other melee pets. The pet is
> differentiated *and* chase-worthy purely by the grafted utility power.

This is the escape hatch if we ever hit a reskin wall at higher layers: we don't have to invent new
combat mechanics for every slot. We can **plop a boosting power onto a plain pet** — a fire-melee
that also boosts coins, a tank that also widens the magnet, a blaster that also bumps luck. It costs
nothing mechanically (the powers exist), reads instantly to the player ("oh, this one earns more"),
and creates the "same body, different *value*" variety that keeps deep pools from feeling samey. So
the toolbox is really: **combat signatures (AoE/contagion/on-hit/control)** *plus* **graftable
economy/utility powers** — and the latter can rescue any slot, any layer, cheaply.

## Design rules

1. **Filler stays filler.** Commons + Uncommons (the bulk of every pool) are **vanilla single-target
   at every layer** — they carry only their origin element and (for support uncommons) their aura.
   They're stack fodder + squad-coverage bodies; reskinning them vertically *and* across heaven/hell
   is correct. Mechanics on every common would dilute readability and the chase. **Do not gate
   these — reskins here are intended.**
2. **Mechanics ride the top of the pool.** The **Rare** (the role-definer — esp. the Ice Bear wall
   and the Grass Tank) gets ONE light signature; the **Mythic apex** gets the full signature; the
   **Secret dragon** is the showcase. That's where differentiation should live and be felt.
3. **One signature per slot, escalating — not a new gimmick each layer.** A slot keeps its identity
   verb the whole way down; depth *amplifies* it (bigger radius, more hops, an added rider), so it
   reads as "the same pet, grown up," not a random new toy.
4. **Power number stays the truth.** Mechanics are deliberately *not* folded into the displayed
   power — they're the axis the fungible number doesn't capture. (Keeps trade fairness; lets a
   "weaker-number" AoE pet still be worth more situationally — desirable depth.)

## When to start — the cadence

The dragon-origin rotates by layer (Fire L1 · Ice L2 · Grass L3 · Desert L4 · apex L5), which gives
a natural ramp for *when mechanics phase in*:

| Layer | Mechanic posture | What carries a mechanic |
|---|---|---|
| **Base + L1** | **Teaching — vanilla.** Players learn the loop; everything single-target. | Nothing (dragon may have a plain ranged volley, no AoE). **Current state is correct — leave L1 alone.** |
| **L2** | **Debut.** First real mechanic appears, on the chase only. | **Secret dragon** (Aurora/Rimewraith = melee **freeze-AoE** — already designed as wade-in/freeze) + a *light* rider on the 3 Mythic apexes. Pool stays vanilla. |
| **L3** | **Broaden.** Mechanics become standard on apex + the Rare role-definer; contagion/AoE enter the pool. | Dragon (Verdant/Blight tank-aura), all 3 Mythic apexes, the Rare Tank + Rare Control. |
| **L4** | **Express.** Every apex distinct; rares carry signatures; support dragon (Alabaster/Glass) makes auras the star. | Dragon + apexes + both rares + the support uncommons' auras strengthen. |
| **L5** | **Peak.** Hybrid dragon showcase; full mechanic expression across the apex pool. | Everything top-of-pool; the grand finale where the lattice is fully realized. |

**Answer to "when do we start": mechanics debut at L2 (dragon only), broaden at L3, peak at L5 —
and base/L1 deliberately stay vanilla as the teaching layers.** So nothing needs retrofitting below
L2; the work is (a) author the L2 dragon's freeze-AoE now, and (b) **design L3–L5 with mechanics
baked in from the start** rather than shipping them as reskins and patching later.

## Per-slot signature + escalation

Mechanics drawn from the **already-built toolbox**: `attack_targeting=targeted_aoe` (splash radius),
`attack_dot` + `spread` (contagion), OnHitEffects (slow/shred/execute), target-priority modes, tank
taunt/pull, support auras, the 16 signature powers.

| Slot | Signature verb | Debut | L-by-L escalation |
|---|---|---|---|
| Fire Blaster (apex line) | **Splash volley** (`targeted_aoe`) | L2 | L2 small splash → L3 +chain/2nd target → L4 bigger radius → L5 radius + on-hit burn |
| Fire Bruiser (Lion) | **Lifesteal on hit** | L3 | L3 small leech → L5 leech + brief rage (atk↑) |
| Fire Offense-buff (Salamander) | **Squad +damage aura** (exists) | (aura now) | scale aura %; L4+ add a short on-cast burst |
| Ice Control (Fox/Wisp) | **Slow → root → freeze** (OnHitEffects) | L2 (light) | L2 slow → L3 stronger slow → L4 brief root → L5 freeze |
| Ice Tank (the Bear) | **Taunt/pull + damage-reduction aura** | L3 | L3 pull + small DR → L5 DR aura + thorns/reflect |
| Ice Blaster (Owl) | **Pierce/line shot** | L4 | L4 hits 2 in a line → L5 full pierce |
| Grass Tank (Stag/Rhino/Beetle/Tortoise) | **Taunt + thorns** | L3 | L3 thorns → L4 + brief team DR → L5 big thorns + DR |
| Grass Heal (Lamb) | **Heal pulse** (aura) | (aura now) | scale; L4+ cleanse a debuff |
| Grass DoT (rot/contagion) | **Spreading rot** (`attack_dot`+`spread`) | L3 | L3 1 hop → L4 2 hops → L5 3 hops + stack |
| Desert Support (heal/shield/buff/yield) | **Team auras** (exist) | (auras now) | scale magnitude; L4 support **dragon** = whole-team multi-axis aura (the buffer-dragon) |
| Desert Regen (Camel) | **Heal-over-time aura** (exists) | (aura now) | scale; L5 + small overheal shield |
| **Secret dragons** | per dragon-archetype (already distinct) | their layer | Fire=blaster splash · Ice=melee freeze-AoE · Grass=tank heal/drain aura · Desert=team support aura · Apex(L5)=hybrid (all of the above, lighter) |

## Build implications (what to do, in order)

1. **L1 / base: nothing.** Confirmed correct as vanilla teaching layers.
2. **L2 now:** author the **Aurora / Rimewraith dragon** as `targeted_aoe` + a freeze/root rider
   (its design already says "wades in, frostbite-breath holds & freezes"). This is the single
   highest-value anti-reskin authoring task today — it makes the L2 chase *play* like a dragon, not
   a big number. (The mechanics are built + tested; this is config authoring + a freeze rider.)
   Optional: a light splash on Dawnfire/Deadfire Phoenix so the fire apex reads as AoE.
3. **L3–L5: design with mechanics in the spec.** When those layers are built, assign each apex +
   rare its signature from the table above so they ship differentiated, not retrofitted.
4. **Don't touch commons/uncommons.** They stay vanilla by design.

## Open knobs (decide later, by feel)

- Exact escalation magnitudes (radius, hop count, slow %, DR %) — tune live like the economy.
- Whether the **Rare role-definer** (Bear / Tank) gets its mechanic at L2 instead of L3 (pulls the
  first non-dragon mechanic one layer earlier).
- Whether any **uncommon** ever earns a mechanic (current rule: no — keep them vanilla filler).
