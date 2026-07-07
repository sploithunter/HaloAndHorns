--[[
    StatusEffectsRegistry — THE single descriptor vocabulary for entity status badges (#244 S4).

    One table per entity kind; every HUD surface (SquadHud own cards, teammate pet cards,
    EnemyHud rail cards — and any future boss frame) consumes these through
    StatusBadges.resolve(kind, sources, now). Nothing may keep a private copy: a channel added
    here (or, for power-stamped buffs, simply stamped as Power_<id>_Until server-side) shows on
    EVERY surface at once — the "badge doesn't show on surface X" bug class is retired.

    Descriptor field reference lives at the top of StatusBadges.lua.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local POWER_ICONS = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("power_icons"))

local PET_EFFECTS = {
    {
        key = "defense",
        source = "pet",
        untilAttr = "DefenseBuffUntil",
        powerIdAttr = "DefenseBuffPowerId",
        color = Color3.fromRGB(235, 190, 70),
        label = "DEF",
        icon = POWER_ICONS.status.defense,
    },
    {
        key = "damage",
        source = "player",
        untilAttr = "PetDamageBuffUntil",
        powerIdAttr = "PetDamageBuffPowerId",
        color = Color3.fromRGB(235, 90, 90),
        label = "DMG",
        icon = POWER_ICONS.status.damage,
    },
    -- Swift buffs PET speed too (self+pets by design) — pets consume the player's
    -- MoveSpeedBuff in the follow loop, so every card wears the badge (Jason: "there's
    -- an icon for speed for me but none for the pets"). steady: Swift is a permanent
    -- passive, so no countdown/blink.
    {
        key = "speed",
        source = "player",
        untilAttr = "MoveSpeedBuffUntil",
        powerIdAttr = "MoveSpeedBuffPowerId",
        steady = true,
        color = Color3.fromRGB(95, 180, 235),
        label = "SPD",
        icon = POWER_ICONS.discFor("neutral", "arrow_right"),
    },
    -- Potion buffs are their OWN source (PotionService writes <axis>Potion so they ADD to the power
    -- instead of clobbering it), so they need their own card entries — same disc/ring via PowerId.
    {
        key = "damage_potion",
        source = "player",
        untilAttr = "PetDamageBuffPotionUntil",
        powerIdAttr = "PetDamageBuffPotionPowerId",
        color = Color3.fromRGB(235, 90, 90),
        label = "DMG",
        icon = POWER_ICONS.status.damage,
    },
    {
        key = "speed_potion",
        source = "player",
        untilAttr = "MoveSpeedBuffPotionUntil",
        powerIdAttr = "MoveSpeedBuffPotionPowerId",
        color = Color3.fromRGB(95, 180, 235),
        label = "SPD",
        icon = POWER_ICONS.discFor("neutral", "arrow_right"),
    },
    -- Instant effects flash a blinking pulse badge (no countdown) for their FX window so
    -- you can see what just happened. heal = the support/heal-power tell (HealFxUntil).
    {
        key = "heal",
        source = "pet",
        untilAttr = "HealFxUntil",
        color = Color3.fromRGB(90, 210, 110),
        label = "HEAL",
        icon = POWER_ICONS.discFor("earth", "plus"), -- green heal cross (bunny support)
        pulse = true,
    },
    {
        key = "luck",
        source = "pet",
        untilAttr = "LuckFxUntil",
        stacksAttr = "LuckFxUntilStacks", -- # of bunny buffers
        steady = true, -- constant aura = SOLID badge (Jason: "constant should be constant")
        color = Color3.fromRGB(120, 230, 120),
        label = "LCK",
        icon = POWER_ICONS.discFor("earth", "clover_lucky"), -- lucky-rabbit aura (bunny)
    },
    -- Support-pet AURAS a pet currently HAS (every affected pet, not just the buffer). Fixed
    -- element-disc per kind so the badge reads the providing biome: defense=ice, offense=lava,
    -- yield=desert. The buffer pet itself wears its badge too (it's one of the allies).
    -- `steady = true`: this buff is CONTINUOUSLY REFRESHED while the buffer pet is deployed (it's
    -- effectively permanent), so the badge sits solid — no countdown, no near-expiry blink. (Timed
    -- powers below keep their countdown + blink-when-about-to-expire.)
    {
        key = "teamdef",
        source = "pet",
        untilAttr = "TeamDefenseBuffUntil",
        stacksAttr = "TeamDefenseBuffStacks", -- # of penguin buffers -> badge pile + xN
        steady = true,
        color = Color3.fromRGB(120, 180, 255),
        label = "DEF",
        icon = POWER_ICONS.discFor("ice", "armor_chest"),
    },
    {
        key = "offense",
        source = "pet",
        untilAttr = "OffenseFxUntil",
        stacksAttr = "OffenseFxUntilStacks", -- # of lava buffers -> badge pile + xN
        steady = true,
        color = Color3.fromRGB(235, 120, 90),
        label = "ATK",
        icon = POWER_ICONS.discFor("fire", "chevrons_up"),
    },
    {
        key = "haste",
        source = "pet",
        untilAttr = "HasteFxUntil", -- team attack-speed aura (efficiency-as-aura)
        stacksAttr = "HasteFxUntilStacks",
        steady = true,
        color = Color3.fromRGB(255, 200, 90),
        label = "SPD",
        icon = POWER_ICONS.discFor("fire", "history"),
    },
    {
        key = "yield",
        source = "pet",
        untilAttr = "YieldFxUntil",
        stacksAttr = "YieldFxUntilStacks", -- # of desert buffers -> badge pile + xN
        steady = true,
        color = Color3.fromRGB(235, 205, 90),
        label = "COIN",
        icon = POWER_ICONS.discFor("desert", "coins_up"),
    },
    -- EMPOWER (single-target damage buffer — pet_roles kind "empower"): only the ONE buffed carry
    -- wears it (the aura picks the squad's strongest ally), so unlike the team auras it marks a
    -- single pet. Hotter red than the team ATK badge to read as "focused" damage.
    {
        key = "empower",
        source = "pet",
        untilAttr = "EmpowerFxUntil",
        stacksAttr = "EmpowerFxUntilStacks",
        steady = true,
        color = Color3.fromRGB(245, 80, 70),
        label = "EMP",
        icon = POWER_ICONS.discFor("fire", "chevrons_up"),
        -- single-target inward ring (target_in) frames the damage-up disc so the empowered carry
        -- reads as ONE-target, distinct from the team offense badge (which wears no ring).
        ringElement = "fire",
        ringShape = "target_in",
    },
    -- RAGE (inherent self power — bear, pet_roles support_auras kind "rage"): only the
    -- raging pet wears it, and only while hurt past its enrage threshold. Conditional,
    -- not permanent, so it pulses instead of sitting steady like the buffer auras.
    {
        key = "rage",
        source = "pet",
        untilAttr = "RageFxUntil",
        color = Color3.fromRGB(235, 80, 60),
        label = "RAGE",
        icon = POWER_ICONS.discFor("fire", "rage"),
        pulse = true,
    },
    -- Armor/absorb shield: now time-limited (CombatShieldUntil), so it shows as a countdown badge
    -- on the card (the thin blue bar still shows the remaining pool magnitude).
    {
        key = "shield",
        source = "pet",
        untilAttr = "CombatShieldUntil",
        powerIdAttr = "CombatShieldPowerId",
        color = Color3.fromRGB(235, 200, 70),
        label = "ARM",
        icon = POWER_ICONS.status.shield,
    },
    -- TAUNT: while a pet is actively taunting (the active Taunt power lands on it), its card wears
    -- the taunt disc for the duration — the pet HUD read that "this tank is holding aggro" (Jason).
    -- powerIdAttr resolves the real taunt disc via PetBadge (same as the hotbar + enemy nameplate).
    {
        key = "taunt",
        source = "pet",
        untilAttr = "TauntingUntil",
        powerIdAttr = "TauntingPowerId",
        color = Color3.fromRGB(120, 235, 130),
        label = "TAUNT",
        icon = POWER_ICONS.discFor("earth", "taunt"),
    },
}

local ENEMY_EFFECTS = {
    {
        key = "heal",
        source = "enemy",
        untilAttr = "HealFxUntil",
        pulse = true,
        color = Color3.fromRGB(90, 210, 110),
        label = "HEAL",
        icon = POWER_ICONS.discFor("earth", "plus"), -- green heal cross (same disc the pets show)
        ringElement = "earth", -- standard tinted ring (no more ringless disc)
    },
    {
        key = "hex",
        source = "enemy",
        untilAttr = "DebuffUntil",
        -- Resolve the ACTUAL power's disc + tinted ring via PetBadge (the one canonical path —
        -- identical to the overhead badge, the hotbar, and the pet cards). The server stamps
        -- DebuffPowerId alongside DebuffUntil, so Sandstorm reads as the desert sand_storm disc, not a
        -- generic chip. The "HEX" label below is only the fallback for an untagged/unresolvable debuff.
        powerIdAttr = "DebuffPowerId",
        color = Color3.fromRGB(175, 110, 215),
        label = "HEX",
    },
    {
        key = "held",
        source = "enemy",
        untilAttr = "HeldUntil", -- controller HOLD pinning this foe (no move/attack) — timed countdown
        color = Color3.fromRGB(150, 110, 215), -- control violet (matches the world HELD badge)
        label = "HELD",
        icon = POWER_ICONS.discFor("ice", "capacitor"), -- hold glyph (capacitor IS the hold art)
        ringElement = "ice", -- standard tinted ring (matches the world HELD badge) — was ringless
    },
}

return {
    pet = PET_EFFECTS,
    enemy = ENEMY_EFFECTS,
}
