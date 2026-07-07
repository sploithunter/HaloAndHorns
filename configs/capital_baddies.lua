--[[
    CAPITAL BADDIES — the authored anchor ladder for SCARY patrol bands (Jason, 2026-07-07):
    "lieutenants and bosses and arch-villains should be anchors and they should have POWERS —
    sometimes a healer, not necessarily a damage power. Trash just does damage. Not random —
    a bunch of lieutenants, a couple bosses/arch-villains — and make each tunable."

    Anchors are what make a band a FIGHT: trash screens, anchors pressure the whole squad
    (AoE kits) or sustain the band (healer), forcing powers/taunt/heals instead of parallel
    cleave. Kit numbers are calibrated off the 2026-07-02 capital kit — the one that wiped a
    10-pet squad (slam 140-150 / pulse 22-30 / splash 0.3) — dialled per tier below.

    MODEL SELECTION is deterministic, not random: the realm's invader roster sorted by power,
    sliced from the TOP — archvillain = #1 strongest, bosses = #2-3, lieutenants = #4-6.
    (Explicit per-origin pet authoring can override later; the slices keep every realm/origin
    working today with zero per-pet bookkeeping.)
]]

return {
    -- How many anchors a SCARY band fields, by engaged team size (index clamps to the table
    -- length, so 5+ player teams read the last row). PATROLS CAP AT BOSS (Jason): villains /
    -- arch-villains are reserved for MISSIONS (not built yet) — the archvillain kit below
    -- stays defined for that future content, patrol composition never rolls it.
    anchors_by_team = {
        { lieutenant = 1 }, -- solo
        { boss = 1, lieutenant = 1 }, -- duo
        { boss = 1, lieutenant = 2 }, -- trio
        { boss = 2, lieutenant = 2 }, -- full team
    },

    -- Which roster ranks (strongest-first) each tier draws its MODEL from.
    roster_slices = {
        archvillain = { 1, 1 },
        boss = { 2, 3 },
        lieutenant = { 4, 6 },
    },

    -- Tier KITS — the anchor's powers + statline scaling over the base invader synth.
    -- splash: melee cleave (frac of the hit to everything within radius of the target).
    -- slam:   telegraphed AoE (red rune, dodge it) every cooldown seconds.
    -- pulse:  aura tick around the anchor (element resolves to the cave origin at spawn).
    -- heal:   band-mender (enemy auto_heal — "kill the healer" gameplay). fraction of the
    --         anchor's OWN max hp healed to the most-hurt bandmate per interval.
    -- band_buff / single_buff:     WARCRY — bandmates deal ×mult for duration (band = boss,
    --                              single strongest mate = lieutenant).
    -- band_debuff / single_debuff: CURSE — pets within radius take ×mult from EVERY enemy
    --                              (band = boss, single nearest pet = lieutenant).
    kits = {
        lieutenant = {
            hp_mult = 2.0,
            dmg_mult = 1.3,
            splash = { radius = 10, frac = 0.3 },
            pulse = { damage = 12, radius = 20, interval = 5 },
            single_buff = { mult = 1.4, radius = 40, interval = 9, duration = 6 },
            single_debuff = { mult = 1.3, radius = 25, interval = 9, duration = 5 },
        },
        boss = {
            hp_mult = 4.0,
            dmg_mult = 1.6,
            splash = { radius = 10, frac = 0.3 },
            slam = { damage = 120, radius = 14, cooldown = 12, telegraph = 1.4, range = 40 },
            pulse = { damage = 22, radius = 30, interval = 4 },
            heal = { interval = 3.0, fraction = 0.05, range = 45 },
            band_buff = { mult = 1.25, radius = 40, interval = 10, duration = 6 },
            band_debuff = { mult = 1.2, radius = 28, interval = 10, duration = 5 },
        },
        archvillain = {
            hp_mult = 7.0,
            dmg_mult = 2.0,
            splash = { radius = 12, frac = 0.35 },
            slam = { damage = 150, radius = 16, cooldown = 10, telegraph = 1.4, range = 40 },
            pulse = { damage = 30, radius = 30, interval = 4 },
        },
    },

    -- ELEMENT THEMES (Jason: bands fight like OUR archetypes — earth tanky, fire damage-y,
    -- ice control, sand buff/debuff). Overlays merged over the base tier kits by the cave's
    -- origin, so an earth band's boss soaks while an ice band's boss ROOTS your pets.
    -- root: enemy CONTROL — freezes up to `targets` nearest pets in place for `duration`
    -- (movement root; they keep attacking what's in reach). Badge = the hold glyph, so
    -- "that one is the controller — kill it" reads on the enemy card.
    themes = {
        grass = { -- TANKY
            lieutenant = { hp_mult = 3.0, dmg_mult = 1.1 },
            boss = { hp_mult = 6.0, dmg_mult = 1.3 },
        },
        lava = { -- DAMAGE
            lieutenant = {
                dmg_mult = 1.6,
                pulse = { damage = 18, radius = 22, interval = 4 },
            },
            boss = {
                dmg_mult = 2.0,
                slam = { damage = 150, radius = 16, cooldown = 10, telegraph = 1.4, range = 40 },
                pulse = { damage = 30, radius = 30, interval = 4 },
            },
        },
        ice = { -- CONTROL
            lieutenant = { root = { duration = 2.0, radius = 20, interval = 9, targets = 1 } },
            boss = { root = { duration = 2.5, radius = 24, interval = 8, targets = 3 } },
        },
        desert = { -- BUFF/DEBUFF specialists
            lieutenant = {
                single_buff = { mult = 1.6, radius = 40, interval = 8, duration = 6 },
                single_debuff = { mult = 1.45, radius = 25, interval = 8, duration = 5 },
            },
            boss = {
                band_buff = { mult = 1.4, radius = 40, interval = 9, duration = 6 },
                band_debuff = { mult = 1.3, radius = 28, interval = 9, duration = 5 },
            },
        },
    },
}
