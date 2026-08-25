--[[
    Pet roles (archetypes) — Halo & Horns [PROTOTYPE].

    The City-of-Heroes-style squad card shows a small archetype chip on the left so you
    can read a pet's combat ROLE at a glance (tank / melee / ranged / support / control).

    Resolution order (SquadHud): the pet's `PetRole` attribute (per-pet override) ->
    `by_type[PetType]` -> `default`. Until real role art is uploaded, each role renders a
    coloured letter glyph; drop an `icon` asset id on a role to swap the glyph for art.

    Colours are {r, g, b} (0-255) so this stays plain data; the client builds the Color3.
]]

return {
    default = "melee",

    -- PetType -> role id. Extend as pets are designed; a pet can also override with a
    -- `PetRole` attribute on its model.
    by_type = {
        bear = "tank",
        -- Jason: "in real life a polar bear has no predators other than people and it
        -- actually hunts humans — top tier tough and scary." A HIGH-DAMAGE tank: the
        -- tank role brings the toughness + taunt; a per-pet aptitude override in
        -- pets.lua (mining/combat_mult 1.0) overcomes the tank damage debuff.
        polarbear = "tank",
        doggy = "melee",
        dog = "melee",
        -- ===== Base-egg species sweep (2026-07-13): 19 species had NO mapping and
        -- fell to default=melee SILENTLY — Jason's live probe caught snowfox with
        -- role=nil while two of three foxes idled. Explicit rows for every species;
        -- the pet_role_coverage spec now fails CI when a new species ships unmapped.
        -- The Ice fox line is CONTROL from base through realm 2; its designated power
        -- lives in support_auras so the lower-right card badge is also mechanical truth.
        snowfox = "control",
        emberfox = "melee",
        aurora_fox = "control",
        fennec = "melee",
        emberling = "melee",
        desertiguana = "melee",
        scorpion = "melee",
        snowleopard = "melee",
        halo_hare = "melee",
        frostlight_hare = "melee",
        emberowl = "ranged",
        snowflakeowl = "ranged",
        seraph_owl = "ranged",
        verdant_sprite = "support", -- harvest-yield support (formal Heaven Grass roster)
        emberlion = "tank",
        camel = "tank",
        goldleaf_stag = "tank",
        glacial_seraph = "tank",
        bloomlamb = "support", -- Heaven Grass healer (formal support-line identity)
        bunny = "support", -- Grass buffer (LUCK — lucky rabbit/clover) — see support_auras
        cat = "ranged",
        kitty = "ranged", -- the actual pet id ("cat" above was the intended mapping)
        dragon = "ranged", -- Jason: it flies and breathes fire — the rare early ranged chase
        bird = "ranged",
        colorado = "ranged",
        kade = "tank",
        -- Gauntlet Champion Egg: one complete five-role Exclusive squad.
        ribbon_ram = "tank",
        medal_moth = "support",
        laurel_lynx = "melee",
        victory_gryphon = "ranged",
        crowned_chimera = "control",
        beta_tester_bot = "melee", -- Beta Byte: exclusive Grass robot dog
        signal_seal = "support", -- week-two tester exclusive: Ice hatch-luck buffer
        patch_phoenix = "ranged", -- week-three tester exclusive: Lava Windfall blaster
        core_digger = "tank", -- week-four tester exclusive: Desert Prospector tank
        cache_bandit = "melee", -- week-five tester exclusive: Grass XP Surge melee
        -- Hall of Worlds / Wayfinder Egg: one readable starter-role spread.
        trail_pup = "melee",
        pack_tortoise = "tank",
        beacon_finch = "ranged",
        guide_moth = "support",
        compass_fox = "control",
        -- Hall of Worlds / Gilded Egg: vault-themed roster between Wayfinder and Vanguard.
        keytail_raccoon = "melee",
        vault_beetle = "tank",
        crownwing_falcon = "ranged",
        fortune_wisp = "support",
        lockbox_imp = "control",
        -- Hall of Worlds / Vanguard Egg: the same readable five-role spread, with stronger
        -- post-gate pets and explicit support/control gameplay rather than decorative badges.
        blade_lynx = "melee",
        bastion_ram = "tank",
        bolt_hawk = "ranged",
        banner_hare = "support",
        chain_serpent = "control",
        -- Hall of Worlds / Worldheart Egg: plaza roster, same five-role spread.
        rift_panther = "melee",
        atlas_golem = "tank",
        portal_drake = "ranged", -- Worldheart secret dragon; counts for Dragonlord
        star_moth = "support",
        clockwork_spider = "control",
        colorado_creator = "ranged", -- the apex is a BLASTER like its species twin (the
        -- two-species split missed this map and it fell to default=melee — Jason caught it)
        -- One BUFFER (support archetype) per zone — trades attack for a team aura. Their
        -- specific aura flavour lives in support_auras below.
        penguin = "support", -- Ice buffer (defense)
        emberimp = "support", -- Lava buffer (offense)
        meerkat = "control", -- Desert CONTROLLER — its support_aura is a full 10s hold (the fifth
        -- archetype, graduated out of support: the hold mez IS its identity, see support_auras below)
        -- Heaven (solar egg) — a full archetype spread so the first realm egg fields a real team:
        emberling_cherub = "support", -- Heaven buffer (HEAL — angelic healer; see support_auras)
        -- Realm pets (Heaven Desert + Hell) — generated
        sun_scarab = "support",
        mirage_jackal = "melee",
        dawn_camel = "tank",
        gilded_sphinx = "ranged",
        solar_roc = "ranged",
        cinderling_imp = "support",
        brimstone_salamander = "support", -- Hell Lava burn-curse support
        ashmane_lion = "tank",
        ashfeather_phoenix = "ranged",
        abyssal_wyrm = "ranged",
        carrion_scarab = "support",
        phantom_jackal = "melee",
        dust_camel = "tank",
        glass_sphinx = "ranged",
        ash_roc = "ranged",
        rimelight_hare = "support",
        rimewraith_fox = "control",
        dread_owl = "ranged",
        black_seraph = "tank",
        black_ice_leviathan = "tank", -- tank/control apex; on-hit slow lives in pets.lua
        blightlamb = "support",
        dread_hare = "melee",
        rotleaf_stag = "tank",
        wither_sprite = "support", -- Hell Grass wither-curse support
        gravewood_ent = "tank",
        radiant_salamander = "support", -- Heaven Lava offense support
        sunmane_lion = "tank", -- front-line soak/taunt
        solar_phoenix = "ranged", -- flies + fires from range
        empyrean_dragon = "ranged", -- the secret apex: flies + breathes fire (like the earth dragon)
        aurora_leviathan = "tank", -- tank/control apex; on-hit slow lives in pets.lua
        worldroot_ent = "tank", -- Heaven grass apex: tank (matches its twin gravewood_ent / the ent-stag line)
        -- ===== Layer 2 (Heaven 2 / Hell 2) — roles per PET_REALM_HEAVEN_HELL_ROSTER.md =====
        -- (blaster→"ranged", bruiser→"tank", per the established mapping above.)
        -- Heaven 2
        -- Boss exclusive egg family (obsidian/celestial eggs) — full archetype
        -- spread per egg; control = the rare chase (meerkat precedent)
        wyrmling = "ranged",
        obsidian_hound = "melee",
        cinder_golemite = "tank",
        ashwing = "support",
        cerberus_pup = "control",
        lumen_dove = "support", -- INNER LIGHT — focus-regen buffer + body light (the
        -- endurance archetype, Jason 2026-07-09: rare on purpose — celestial boss egg)
        archon_spark = "melee",
        cloudling = "tank",
        halo_fawn = "support",
        seraph_kit = "control",
        coronal_cherub = "melee",
        prism_lion = "tank", -- bruiser
        lance_seraph = "ranged", -- blaster
        lumen_salamander = "support", -- offense buff
        dawnfire_phoenix = "ranged", -- blaster apex
        frostlight_doe = "melee",
        prism_fox = "control",
        starlight_owl = "ranged", -- blaster
        glacial_bear = "tank",
        aurora_dragon = "melee", -- secret; wades in (control comes from its freeze-AoE power)
        bloomspirit_lamb = "support", -- heal
        lightleaf_hare = "melee",
        crystalbark_stag = "tank",
        radiant_sprite = "support", -- yield/luck
        worldbloom_ent = "tank", -- tank/heal apex
        aurora_dove = "support", -- heal
        prism_scarab = "support", -- shield
        mirage_meerkat = "support", -- yield (NB: distinct from base `meerkat` = control)
        sunwell_camel = "support", -- regen
        empyreal_couatl = "support", -- apex
        -- Hell 2 (mirror)
        frostcinder_imp = "melee",
        rimemane_lion = "tank", -- bruiser
        hoarfrost_phoenix = "ranged", -- blaster
        frostbrand_salamander = "support", -- curse
        deadfire_phoenix = "ranged", -- blaster apex
        rimegloom_hare = "melee",
        dread_fox = "control",
        gravefrost_owl = "ranged", -- blaster
        rimeguard_bear = "tank",
        rimewraith_dragon = "melee", -- secret; targeted AoE root lives in pets.lua
        frostblight_lamb = "support", -- drain-heal
        gloom_hare = "melee",
        icerot_stag = "tank",
        rimewither_sprite = "support", -- wither-curse
        frostgrave_ent = "tank", -- tank/drain apex
        wraith_dove = "support", -- drain-heal
        rime_scarab = "support", -- armor-shred
        gloom_jackal = "support", -- debuff
        frostdust_camel = "support", -- regen-denial
        dread_couatl = "support", -- apex curse
        -- ===== Layer 3 (Heaven 3 / Hell 3) =====
        -- Basic melee lines remain honest single-target pets; the roster's authored support,
        -- control, tank, and blaster hooks supply the complementary team choices. Exactly one
        -- dragon per realm: both Desert secrets are support capstones.
        gloryspark_cherub = "melee",
        seraph_lion = "tank", -- bruiser
        radiant_lance_seraph = "ranged",
        gloryscale_salamander = "support",
        empyrean_firehawk = "ranged",
        lumen_seal = "melee",
        halo_wisp = "control",
        celestial_moth = "ranged",
        halo_bear = "tank",
        empyrean_mammoth = "tank",
        gloryleaf_lamb = "support",
        halo_hart = "melee",
        lightbark_rhino = "tank",
        bloomlight_sprite = "support",
        empyrean_grovekeeper = "tank",
        bloom_ibis = "support",
        radiant_totem = "support",
        glory_mongoose = "support",
        light_tortoise = "support",
        oasis_dragon = "support",
        dreadcinder_imp = "melee",
        ruinmane_lion = "tank", -- bruiser
        dreadlance_seraph = "ranged",
        ruinscale_salamander = "support",
        dreadfire_hawk = "ranged",
        duskfrost_seal = "melee",
        dread_wisp = "control",
        dreadveil_moth = "ranged",
        dreadguard_bear = "tank",
        dreadspire_mammoth = "tank",
        thornleaf_lamb = "support",
        dread_hart = "melee",
        ironbark_rhino = "tank",
        dreadbloom_sprite = "support",
        dreadthorn_grovekeeper = "tank",
        ash_ibis = "support",
        obsidian_totem = "support",
        dread_mongoose = "support",
        obsidian_tortoise = "support",
        dreadglass_dragon = "support",
    },

    -- Per-zone BUFFER auras (City-of-Heroes support). Resolved by SupportAura.forPet
    -- (PetType key; a model `SupportAura` attribute can override later) and applied by
    -- EnemyService:_supportPass every `interval` seconds while the buffer is deployed +
    -- alive. The buff is short-lived (`duration`s) and refreshed each interval, so it
    -- fades a beat after the buffer is recalled/downed. These run on a SEPARATE channel
    -- from player Powers (Feature 14), so an aura STACKS with an activated power buff
    -- instead of clobbering it. Every number is a dev knob.
    --   heal     — mend the most-hurt non-downed ally; `fraction` of its pool (or flat `amount`).
    --   defense  — TeamDefenseBuff on every ally (added on the armor curve in _hitPet); `amount`.
    --   offense  — PetTeamDamageBuff on the owner; ×`mult` to mining AND combat damage (_mine).
    --   yield    — CoinYieldBuff on the owner; ×`mult` to mined-coin payout (BreakableSpawner).
    --   luck     — HatchLuckBuff on the owner; adds (mult-1) to hatch luck while deployed
    --              (EggService folds it into luckBoost — boosts rare species AND variants).
    --   buff     — GENERIC (Jason): { kind="buff", attr="<Attr>", mult, target="player"|
    --              "pets"|"both", interval, duration }. Player target stacks on the bar
    --              (xN); pets target badges each ally. The attr needs a CONSUMER (BuffStack
    --              axis / EggService / movement) — that's the only per-buff code.
    -- POWER/aura targeting SSOT (Jason): the scope an aura applies at, by kind — drives the ability
    -- badge ring (PetTargeting.auraScope → power_icons.targeting_ring) AND how the effect lands
    -- (one ally/enemy vs the whole team). single = empower carry / hold mez / heal most-hurt / self
    -- rage; aura = the team buffers (offense/defense/yield/luck) that lift everyone in range. An
    -- individual aura entry can override with its own `targeting`.
    aura_targeting_by_kind = {
        empower = "single",
        slow = "single",
        root = "single",
        hold = "single",
        heal = "single",
        drain = "single", -- Hell's life-drain heal (routes through the heal path)
        antiheal = "single", -- damage-free healing suppression; entries may widen to aura/AoE
        shred = "single", -- Hell combat debuff — stamps the squad's focus enemy (VulnerableMult)
        curse = "single", -- Hell combat debuff — stamps the squad's focus enemy (WeakenMult)
        rage = "single",
        offense = "aura",
        haste = "aura", -- team attack-speed aura (efficiency-as-aura)
        defense = "aura",
        yield = "aura",
        luck = "aura",
        xp = "aura",
        huge_luck = "aura",
        drop_rate = "aura",
        buff = "aura",
    },

    support_auras = {
        -- Grass: LUCK (Jason: heal was off-theme — lucky rabbit's foot + clover fields).
        -- durations sit WELL above intervals so the continuously-refreshed buffs never
        -- gap between stamps (a 3s window on a 2s tick flickered at the boundary)
        -- BASES REBASED for variant scaling (Jason: "rainbows should hit 25% — adjust
        -- the base accordingly... give people a reason to roll until they get rainbow
        -- bunnies"): rainbow (x1.5) lands exactly on the OLD value, so basic +16.7%,
        -- golden +20.8%, rainbow +25% (and defense ~53/67/80, heal 20%/25%/30%).
        bunny = { kind = "luck", interval = 2.0, mult = 1.1667, duration = 6 },
        guide_moth = { kind = "heal", interval = 2.0, fraction = 0.08, duration = 6 },
        compass_fox = { kind = "root", interval = 12, duration = 3 },
        fortune_wisp = { kind = "heal", interval = 2.0, fraction = 0.09, duration = 6 },
        lockbox_imp = { kind = "root", interval = 11, duration = 3.25 },
        star_moth = { kind = "heal", interval = 2.0, fraction = 0.1, duration = 6 },
        clockwork_spider = { kind = "root", interval = 10, duration = 3.5 },
        banner_hare = { kind = "offense", interval = 2.0, mult = 1.1667, duration = 6 },
        chain_serpent = { kind = "root", interval = 10, duration = 3.5 },
        penguin = { kind = "defense", interval = 2.0, amount = 53.3, duration = 6 }, -- Ice
        emberimp = { kind = "offense", interval = 2.0, mult = 1.1667, duration = 6 }, -- Lava
        -- CONTROLLER (Jason): the meerkat is the game's CONTROL archetype (by_type = "control"). It
        -- HOLDS the focused enemy — a full mez (can't move OR attack), 10s hold firing every 30s
        -- (recharge). Targets the player's focus (assist target → most-targeted-by-pets → nearest).
        -- The hold IS its identity; CC is the fifth archetype the squad diversifies around (the old
        -- Desert yield aura it replaced now lives on the Desert scarabs).
        meerkat = { kind = "hold", interval = 30, duration = 10 }, -- Desert controller (full mez)
        -- ICE CONTROLLER FOXES: designated powers are config-owned, real combat effects — never
        -- decorative inventory metadata. The base fox teaches graded control; the first realm pair
        -- improves the slow; the second realm pair graduates to a short root. EnemyService applies
        -- these to the squad's focus through the same SlowUntil/RootedUntil seams as player powers.
        snowfox = { kind = "slow", interval = 8, duration = 4, factor = 0.65 },
        aurora_fox = { kind = "slow", interval = 8, duration = 5, factor = 0.55 },
        rimewraith_fox = { kind = "slow", interval = 8, duration = 5, factor = 0.55 },
        prism_fox = { kind = "root", interval = 12, duration = 3 },
        dread_fox = { kind = "root", interval = 12, duration = 3 },
        -- Heaven (solar egg): the Emberling Cherub HEALS — an angelic healer, the realm's buffer.
        -- A gentle continuous mend of the most-hurt ally (fraction of its pool every 2s); kept well
        -- under Colorado's old 20%/1.5s that read as invulnerable. Tune freely.
        emberling_cherub = { kind = "heal", interval = 2.0, fraction = 0.08, duration = 6 },
        -- Realm support pets — generated
        sun_scarab = { kind = "yield", interval = 2.0, mult = 1.1667, duration = 6 },
        -- HASTE (efficiency-as-aura): a team ATTACK-SPEED buff — the first cadence buffer. Reassigned
        -- from a duplicate offense aura (emberimp already covers War-Cry) so Haste has a home. mult =
        -- speedup factor (1.25 base = pets swing ~25% faster; bounded in PetFollowService so it can't
        -- drive attacks to instant). Scales by variant like the other auras.
        cinderling_imp = { kind = "haste", interval = 2.0, mult = 1.25, duration = 6 },
        -- SINGLE-TARGET damage buffer (the first "empower" pet): concentrates +50% damage on the
        -- squad's STRONGEST ally instead of spreading like the team offense aura — the carry
        -- amplifier. Hell's aggressive theme fits it; it also frees Desert from double-yield (the
        -- sun_scarab still covers Heaven yield). Reassign freely.
        carrion_scarab = {
            kind = "empower",
            target = "highest_power",
            interval = 2.0,
            mult = 1.5,
            duration = 6,
        },
        rimelight_hare = { kind = "heal", interval = 2.0, fraction = 0.08, duration = 6 },
        -- Layer-one support mirrors. These were once assigned damage/tank roles with no ability,
        -- contradicting the formal roster and leaving their lower-right card power absent.
        radiant_salamander = { kind = "offense", interval = 2.0, mult = 1.1667, duration = 6 },
        brimstone_salamander = { kind = "curse", mult = 0.8, interval = 2.0, duration = 6 },
        bloomlamb = { kind = "heal", interval = 2.0, fraction = 0.08, duration = 6 },
        blightlamb = { kind = "drain", interval = 2.0, fraction = 0.08, duration = 6 },
        verdant_sprite = { kind = "yield", interval = 2.0, mult = 1.1667, duration = 6 },
        wither_sprite = { kind = "curse", mult = 0.8, interval = 2.0, duration = 6 },
        -- ===== Heaven 2 supports — FARMING lean (heal / shield / yield / luck / offense). =====
        -- Hell 2 supports are COMBAT lean (drain / shred / curse); all kinds below are live in
        -- EnemyService and share the same card-badge registry as the Heaven farming supports.
        bloomspirit_lamb = { kind = "heal", interval = 2.0, fraction = 0.08, duration = 6 }, -- grass heal
        radiant_sprite = { kind = "luck", interval = 2.0, mult = 1.1667, duration = 6 }, -- grass luck
        lumen_salamander = { kind = "offense", interval = 2.0, mult = 1.1667, duration = 6 }, -- fire +dmg
        aurora_dove = { kind = "heal", interval = 2.0, fraction = 0.08, duration = 6 }, -- desert heal
        prism_scarab = { kind = "defense", interval = 2.0, amount = 53.3, duration = 6 }, -- desert shield
        mirage_meerkat = { kind = "yield", interval = 2.0, mult = 1.1667, duration = 6 }, -- desert coin yield
        sunwell_camel = { kind = "heal", interval = 2.0, fraction = 0.05, duration = 6 }, -- desert regen (gentle HoT)
        -- Empyreal Couatl (apex): a team +damage aura — doubles as Heaven's combat-mix piece (the
        -- roster needs combat reachable in heaven for the invader fights). Strongest support aura.
        empyreal_couatl = { kind = "offense", interval = 2.0, mult = 1.25, duration = 6 },
        -- ===== Hell 2 — drain-heal supports (COMBAT realm's sustain; give→take flavor). =====
        -- The COMBAT debuff supports target the squad's focus enemy through the live
        -- VulnerableMult/WeakenMult combat seams.
        frostblight_lamb = { kind = "drain", interval = 2.0, fraction = 0.08, duration = 6 }, -- grass leech-heal
        wraith_dove = { kind = "drain", interval = 2.0, fraction = 0.08, duration = 6 }, -- desert leech-heal
        -- ===== Hell 2 — COMBAT debuff supports (the give→take inversion; enemy-targeting). =====
        -- shred = focus enemy takes +X% from everyone (amount = fraction). curse = focus enemy DEALS
        -- ×mult (mult < 1 weakens). Keep-stronger so multiple buffers refresh, never compound.
        rime_scarab = { kind = "shred", amount = 0.25, interval = 2.0, duration = 6 }, -- desert armor-shred
        rimewither_sprite = { kind = "curse", mult = 0.8, interval = 2.0, duration = 6 }, -- grass wither-curse
        frostbrand_salamander = { kind = "curse", mult = 0.8, interval = 2.0, duration = 6 }, -- fire frostbite-curse
        gloom_jackal = { kind = "curse", mult = 0.8, interval = 2.0, duration = 6 }, -- desert debuff
        frostdust_camel = { kind = "curse", mult = 0.85, interval = 2.0, duration = 6 }, -- desert regen-denial (light curse; no enemy regen yet)
        dread_couatl = { kind = "curse", mult = 0.7, interval = 2.0, duration = 6 }, -- desert apex curse (strongest)
        -- ===== Layer 3 support/control identities =====
        -- Heaven continues the farming/sustain vocabulary but spreads it across all four origin
        -- eggs. Hell mirrors those slots with drain and focus-enemy debuffs. The Desert dragons are
        -- the only dragons in this layer and act as multi-aura Secret capstones.
        gloryscale_salamander = {
            kind = "offense",
            interval = 2.0,
            mult = 1.2, -- Legendary: stronger focused roster value than the Rare mongoose's +16.7%
            duration = 6,
        },
        halo_wisp = { kind = "root", interval = 11, duration = 3.25 },
        gloryleaf_lamb = { kind = "heal", interval = 2.0, fraction = 0.08, duration = 6 },
        bloomlight_sprite = { kind = "luck", interval = 2.0, mult = 1.2, duration = 6 },
        empyrean_grovekeeper = {
            kind = "heal",
            interval = 2.0,
            fraction = 0.1,
            duration = 6,
        },
        bloom_ibis = { kind = "heal", interval = 2.0, fraction = 0.08, duration = 6 },
        radiant_totem = { kind = "defense", interval = 2.0, amount = 53.3, duration = 6 },
        glory_mongoose = { kind = "offense", interval = 2.0, mult = 1.1667, duration = 6 },
        -- Legendary discovery hybrid: intentionally weaker focused healing than the Common ibis,
        -- compensated by persistent radiant AoE attack geometry when its pets.lua record lands.
        light_tortoise = { kind = "heal", interval = 2.0, fraction = 0.05, duration = 6 },
        oasis_dragon = {
            { kind = "heal", interval = 2.0, fraction = 0.1, duration = 6 },
            { kind = "defense", interval = 2.0, amount = 53.3, duration = 6 },
        },
        ruinscale_salamander = { kind = "curse", mult = 0.75, interval = 2.0, duration = 6 },
        dread_wisp = { kind = "root", interval = 11, duration = 3.25 },
        thornleaf_lamb = { kind = "drain", interval = 2.0, fraction = 0.08, duration = 6 },
        dreadbloom_sprite = { kind = "curse", mult = 0.75, interval = 2.0, duration = 6 },
        dreadthorn_grovekeeper = {
            kind = "drain",
            interval = 2.0,
            fraction = 0.1,
            duration = 6,
            targeting = "aura",
            radius = 12,
            max_targets = 5,
            heal_suppression_duration = 3,
        },
        ash_ibis = { kind = "drain", interval = 2.0, fraction = 0.08, duration = 6 },
        obsidian_totem = { kind = "curse", mult = 0.85, interval = 2.0, duration = 6 },
        dread_mongoose = { kind = "curse", mult = 0.8, interval = 2.0, duration = 6 },
        -- Legendary discovery hybrid: its focused curse is deliberately lighter than the Rare
        -- mongoose, but it projects a damage-free anti-heal field around itself.
        obsidian_tortoise = {
            { kind = "curse", mult = 0.85, interval = 2.0, duration = 6 },
            {
                kind = "antiheal",
                interval = 2.0,
                duration = 3,
                targeting = "aura",
                radius = 12,
                max_targets = 5,
            },
        },
        dreadglass_dragon = {
            {
                kind = "drain",
                interval = 2.0,
                fraction = 0.1,
                duration = 6,
                targeting = "targeted_aoe",
                radius = 12,
                max_targets = 5,
                heal_suppression_duration = 3,
            },
            { kind = "shred", amount = 0.25, interval = 2.0, duration = 6 },
            { kind = "curse", mult = 0.7, interval = 2.0, duration = 6 },
        },
        -- Bear: RAGE — an inherent power the pet casts on ITSELF (Jason: per-SPECIES
        -- assignment like the zone buffers, NOT a tank-role trait — "I don't want all
        -- tanks to have rage"). The starter tank gets angry as it soaks: at or below
        -- half health (enrage_below, endurance fraction) it pulses a self damage buff.
        -- mult 1.5 = +50% basic; the variant multipliers scale the fraction (golden
        -- +62.5%, rainbow +75%), so a raging bear claws back the tank role's 0.6
        -- haircut exactly while it's doing its job (0.6 × 1.5 = 0.9; rainbow 1.05).
        -- Boss exclusive egg supports + controllers (2026-07-09)
        -- EMBER TEMPO (Ashwing — the obsidian egg's support, the dove's hell
        -- mirror; Jason: "something just as cool in hell... recharge"): shaves
        -- every power cooldown by `fraction` for the OWNER. Heaven feeds the
        -- BAR (dove focus), hell feeds the CLOCK. Variant law rides weight
        -- (golden 1.25 / rainbow 1.5); stacks additively with Hasten's
        -- RechargeBuff under the same 0.9 clamp.
        ashwing = { kind = "recharge", fraction = 0.1, interval = 2.0, duration = 6 },
        halo_fawn = { kind = "heal", interval = 2.0, fraction = 0.08, duration = 6 }, -- heaven healer
        -- INNER LIGHT (Lumen Dove): +focus/s for the OWNER on its own additive
        -- seam (FocusRegenAura) — stacks with the Genie's wish window instead of
        -- clobbering it. Deliberately WELL under the Genie's +5/s: the dove is
        -- the trickle, the Genie is the firehose. Variant law rides the weight
        -- (golden 1.25 / rainbow 1.5). Endurance-check trials key on this kind.
        lumen_dove = { kind = "focus", amount = 0.75, interval = 2.0, duration = 6 }, -- +30% of base 2.5/s (Jason-tuned: 2 was a regen-doubler)
        cerberus_pup = { kind = "hold", interval = 30, duration = 10 }, -- "Drowse": the sleepy head yawns, the target naps
        seraph_kit = { kind = "hold", interval = 30, duration = 10 }, -- "Dazzle": six wings flare, the target stands blinded
        bear = { kind = "rage", enrage_below = 0.5, mult = 1.5, interval = 2.0, duration = 6 },
        -- Colorado (meet-egg / wild): TWO buffs, not all — "all" was really meant for
        -- creator testing (Jason). Heal + luck: the creator's gift is lucky and kind,
        -- and neither duplicates a zone buffer's whole identity.
        colorado = {
            -- Heal on a long 15s cycle (was 1.5s): a 20%-pool heal every 1.5s let Colorado
            -- out-heal incoming damage and never go down — essentially invulnerable. 15s makes
            -- the heal a meaningful clutch, not passive immortality. (Tuning starting point.)
            { kind = "heal", interval = 15, fraction = 0.2 },
            { kind = "luck", interval = 2.0, mult = 1.1667, duration = 6 },
        },
        -- Kade is the second regular developer reward and follows Colorado's two-aura
        -- balance contract (not the all-buff Creator Colorado apex).
        kade = {
            { kind = "heal", interval = 15, fraction = 0.2 },
            { kind = "luck", interval = 2.0, mult = 1.1667, duration = 6 },
        },
        -- Champion utilities: Medal Moth protects the full squad; the 2% Chimera
        -- controls the focused enemy with the established 10s/30s full-hold cadence.
        medal_moth = { kind = "defense", interval = 2.0, amount = 53.3, duration = 6 },
        crowned_chimera = { kind = "hold", interval = 30, duration = 10 },
        -- Limited tester rewards each carry ONE deterministic Natural farming identity.
        -- They are player-facing support auras, not random enchants: the pet must be deployed,
        -- multiple providers stack additively, and variant scaling makes Basic/Golden/Rainbow
        -- worth +16.67% / +20.84% / +25% respectively.
        -- Week one deliberately avoids XP/coin acceleration so its balance feedback stays honest.
        beta_tester_bot = { kind = "huge_luck", interval = 2.0, mult = 1.1667, duration = 6 },
        -- Week two is reserved before its pet definition lands so the five-week rotation cannot
        -- drift. XP Surge is held for week five; Prospector is held for week four.
        signal_seal = { kind = "luck", interval = 2.0, mult = 1.1667, duration = 6 },
        patch_phoenix = { kind = "drop_rate", interval = 2.0, mult = 1.1667, duration = 6 },
        core_digger = { kind = "yield", interval = 2.0, mult = 1.1667, duration = 6 },
        cache_bandit = { kind = "xp", interval = 2.0, mult = 1.1667, duration = 6 },
        -- The colorado_creator SPECIES (the apex — different pet, same model): every
        -- buffer at once — the creator's testing/scaling tool.
        -- (the apex is a rainbow record, so x1.5 puts it at the old full values)
        colorado_creator = {
            { kind = "heal", interval = 1.5, fraction = 0.2 },
            { kind = "defense", interval = 2.0, amount = 53.3, duration = 6 },
            { kind = "offense", interval = 2.0, mult = 1.1667, duration = 6 },
            { kind = "yield", interval = 2.0, mult = 1.1667, duration = 6 },
            { kind = "luck", interval = 2.0, mult = 1.1667, duration = 6 },
        },
    },

    -- VARIANT EFFECT MULTIPLIERS (Jason: "would it make sense for a variant pet to be
    -- better? ...they give people a reason to roll"): scales aura/effect MAGNITUDE
    -- only — never duration or recharge (potency is containable, recharge compounds).
    -- One global knob; PowerModel P7 (pet-cast parity) reuses this same table.
    variant_effect_multipliers = {
        basic = 1.0,
        golden = 1.25,
        rainbow = 1.5,
    },

    -- Role definitions. glyph = placeholder letter (until art exists via `icon`).
    -- attack_range = how far the pet can deal damage (server mining gate, studs).
    -- standoff = how far back it holds in the attack formation (client), studs. Keep
    -- standoff < attack_range so the pet can still hit from where it stands. Melee/tank
    -- crowd in close (standoff 0); ranged hangs back and snipes; support/control sit at
    -- mid range. This is the melee-closes / ranged-kites dynamic.
    -- threat_mult scales the aggro a role generates (passive threat × this), so a tank
    -- holds the enemy's attention and soaks for the squad while dps/ranged stay safer.
    -- mining_mult / combat_mult: the role's DAMAGE knobs — the classic archetype curve
    -- (blasters/melee hit hardest at 1.0, tanks moderate, support/control trade damage for
    -- utility), split by target kind. Damage routes through PetPowerView.profile (the same
    -- resolver the inventory card runs — display = dealt, #132): a crystal swing uses
    -- mining_mult (the card's ⛏), an enemy swing combat_mult (the card's ⚔). pets.lua can
    -- override per pet — bump mining_mult on a "miner" and combat_mult on a "fighter" to
    -- create specialists (which spawn trades). The legacy single damage_mult is retired.
    -- auto_heal makes a support pet periodically heal the most-hurt ally (the bunny's
    -- grass-biome flavor; element-specific support variants can key off this later).
    -- defense = innate damage reduction (the role's "toughness"), added to the pet's
    -- own Defense attribute + any DefenseBuff before the armor curve in _hitPet. Tanks
    -- are naturally tough; melee a little; ranged/support are squishy. Tune freely.
    roles = {
        tank = {
            label = "Tank",
            tooltip = "High defense and threat; protects the squad but deals less damage.",
            glyph = "T",
            color = { 70, 130, 195 },
            icon = "",
            attack_range = 9,
            standoff = 0,
            threat_mult = 5,
            implicit_taunt = true,
            mining_mult = 0.6,
            combat_mult = 0.6,
            defense = 100,
            targeting = "single", -- DAMAGE targeting (rings the archetype badge). A damage-aura
            -- bruiser would set "aura" here; the attack fan-out reads it once we ship one.
        },
        melee = {
            label = "Melee",
            tooltip = "Close-range fighter with balanced mining and combat damage.",
            glyph = "M",
            color = { 205, 85, 70 },
            icon = "",
            attack_range = 9,
            standoff = 0,
            threat_mult = 1,
            mining_mult = 1.0,
            combat_mult = 1.0,
            defense = 20,
            targeting = "single", -- DAMAGE targeting (rings the archetype badge)
        },
        -- kite = true: holds near the player and snipes instead of orbiting the enemy, so
        -- an enemy chasing it has to close the gap (the melee-closes / ranged-kites loop).
        ranged = {
            label = "Blaster",
            tooltip = "Long-range damage dealer that fights from a safer distance.",
            glyph = "R",
            color = { 120, 180, 85 },
            icon = "",
            attack_range = 28,
            standoff = 17,
            kite = true,
            -- ACQUIRE range (Jason: "ranged pets just meander during a fight"): a blaster joins a
            -- fight happening anywhere within this radius, then advances to its standoff and fires.
            -- Without it, selection caps a kiter at its attack_range (28) — the SHORTEST of any role
            -- — so when the tank drags the fight 30-45 studs out the blaster never picks a target.
            -- Set > attack_range so it engages from range; the advance-to-standoff logic does the rest.
            engage_range = 60,
            mining_mult = 1.0,
            combat_mult = 1.0,
            defense = 0,
            targeting = "single", -- DAMAGE targeting (rings the archetype badge)
        },
        support = {
            label = "Buffer",
            tooltip = "Supports the squad with a special ability; lower personal damage.",
            glyph = "S",
            color = { 150, 110, 215 },
            icon = "",
            attack_range = 16,
            standoff = 9,
            -- ACQUIRE range — same fix as the `ranged` role: a support is a kiter (standoff > 0), so
            -- without engage_range target selection caps it at attack_range (16) and it just stands in
            -- formation when the fight is dragged a few studs out. Set > attack_range so it joins a
            -- nearby fight and advances to its standoff to contribute damage (its aura is separate).
            engage_range = 60,
            -- 0.35 -> 0.45 (Jason, 2026-06-12): the rainbow-imp buffer team only beat the
            -- three-strongest team 202 vs 194 (~4%) — "a little weak". The BODY aptitude is
            -- the safe lever to sweeten buffers: it's per-pet and linear. The AURA fractions
            -- stay put because they stack ADDITIVELY across multiple buff pets (BuffStack) —
            -- raising those raises the multi-buffer ceiling, "we don't want it to get crazy".
            mining_mult = 0.45,
            combat_mult = 0.45,
            auto_heal = { interval = 1.5, fraction = 0.3 },
            defense = 10,
            targeting = "single", -- DAMAGE targeting (rings the archetype badge); the buffer's
            -- AURA scope is separate (aura_targeting_by_kind) and rings its provides-badge.
        },
        control = {
            label = "Control",
            tooltip = "Disables or weakens enemies; trades personal damage for control.",
            glyph = "C",
            color = { 90, 185, 205 },
            icon = "",
            attack_range = 20,
            standoff = 12,
            -- ACQUIRE range — same fix as `ranged`/`support`: a controller kites (standoff > 0), so
            -- without engage_range it caps at attack_range (20) and won't join a fight pulled out of
            -- reach. Set > attack_range so it engages from range and advances to its standoff.
            engage_range = 60,
            mining_mult = 0.5,
            combat_mult = 0.5,
            defense = 40,
            targeting = "single", -- DAMAGE targeting (rings the archetype badge); the controller's
            -- POWER scope (e.g. the meerkat's single-target hold) rings its ability badge separately.
        },
    },
}
