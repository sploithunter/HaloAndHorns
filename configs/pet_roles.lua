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
        bunny = "support", -- Grass buffer (LUCK — lucky rabbit/clover) — see support_auras
        cat = "ranged",
        kitty = "ranged", -- the actual pet id ("cat" above was the intended mapping)
        dragon = "ranged", -- Jason: it flies and breathes fire — the rare early ranged chase
        bird = "ranged",
        colorado = "ranged",
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
        brimstone_salamander = "melee",
        ashmane_lion = "tank",
        ashfeather_phoenix = "ranged",
        abyssal_wyrm = "ranged",
        carrion_scarab = "support",
        phantom_jackal = "melee",
        dust_camel = "tank",
        glass_sphinx = "ranged",
        ash_roc = "ranged",
        rimelight_hare = "support",
        rimewraith_fox = "melee",
        dread_owl = "ranged",
        black_seraph = "tank",
        black_ice_leviathan = "ranged",
        blightlamb = "support",
        dread_hare = "melee",
        rotleaf_stag = "tank",
        wither_sprite = "ranged",
        gravewood_ent = "tank",
        radiant_salamander = "melee", -- ground bruiser
        sunmane_lion = "tank", -- front-line soak/taunt
        solar_phoenix = "ranged", -- flies + fires from range
        empyrean_dragon = "ranged", -- the secret apex: flies + breathes fire (like the earth dragon)
        aurora_leviathan = "ranged", -- Heaven ice apex: blaster (matches its twin black_ice_leviathan)
        worldroot_ent = "tank", -- Heaven grass apex: tank (matches its twin gravewood_ent / the ent-stag line)
        -- ===== Layer 2 (Heaven 2 / Hell 2) — roles per PET_REALM_HEAVEN_HELL_ROSTER.md =====
        -- (blaster→"ranged", bruiser→"tank", per the established mapping above.)
        -- Heaven 2
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
        frostbrand_salamander = "support", -- curse (combat aura pending build)
        deadfire_phoenix = "ranged", -- blaster apex
        rimegloom_hare = "melee",
        dread_fox = "control",
        gravefrost_owl = "ranged", -- blaster
        rimeguard_bear = "tank",
        rimewraith_dragon = "melee", -- secret; freeze-AoE power pending build
        frostblight_lamb = "support", -- drain-heal (pending build)
        gloom_hare = "melee",
        icerot_stag = "tank",
        rimewither_sprite = "support", -- wither-curse (pending build)
        frostgrave_ent = "tank", -- tank/drain apex
        wraith_dove = "support", -- drain-heal (pending build)
        rime_scarab = "support", -- armor-shred (pending build)
        gloom_jackal = "support", -- debuff (pending build)
        frostdust_camel = "support", -- regen-denial (pending build)
        dread_couatl = "support", -- apex curse (pending build)
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
        hold = "single",
        heal = "single",
        drain = "single", -- Hell's life-drain heal (routes through the heal path)
        shred = "single", -- Hell combat debuff — stamps the squad's focus enemy (VulnerableMult)
        curse = "single", -- Hell combat debuff — stamps the squad's focus enemy (WeakenMult)
        rage = "single",
        offense = "aura",
        haste = "aura", -- team attack-speed aura (efficiency-as-aura)
        defense = "aura",
        yield = "aura",
        luck = "aura",
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
        penguin = { kind = "defense", interval = 2.0, amount = 53.3, duration = 6 }, -- Ice
        emberimp = { kind = "offense", interval = 2.0, mult = 1.1667, duration = 6 }, -- Lava
        -- CONTROLLER (Jason): the meerkat is the game's CONTROL archetype (by_type = "control"). It
        -- HOLDS the focused enemy — a full mez (can't move OR attack), 10s hold firing every 30s
        -- (recharge). Targets the player's focus (assist target → most-targeted-by-pets → nearest).
        -- The hold IS its identity; CC is the fifth archetype the squad diversifies around (the old
        -- Desert yield aura it replaced now lives on the Desert scarabs).
        meerkat = { kind = "hold", interval = 30, duration = 10 }, -- Desert controller (full mez)
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
        blightlamb = { kind = "defense", interval = 2.0, amount = 53.3, duration = 6 },
        -- ===== Heaven 2 supports — FARMING lean (heal / shield / yield / luck / offense). =====
        -- Hell 2 supports are COMBAT lean (drain / shred / curse) — their aura kinds don't exist
        -- yet, so they're role-tagged support but wired in the combat-aura build pass, not here.
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
        -- The COMBAT debuff supports (shred/curse on rime_scarab, rimewither_sprite,
        -- frostbrand_salamander, gloom_jackal, frostdust_camel, dread_couatl) await the
        -- enemy-debuff-aura build (new aura kinds + combat-path consumers) — role-tagged, not wired.
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
        -- Bear: RAGE — an inherent power the pet casts on ITSELF (Jason: per-SPECIES
        -- assignment like the zone buffers, NOT a tank-role trait — "I don't want all
        -- tanks to have rage"). The starter tank gets angry as it soaks: at or below
        -- half health (enrage_below, endurance fraction) it pulses a self damage buff.
        -- mult 1.5 = +50% basic; the variant multipliers scale the fraction (golden
        -- +62.5%, rainbow +75%), so a raging bear claws back the tank role's 0.6
        -- haircut exactly while it's doing its job (0.6 × 1.5 = 0.9; rainbow 1.05).
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
