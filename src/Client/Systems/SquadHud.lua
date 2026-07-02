--[[
    SquadHud — City-of-Heroes-style right-side squad strip (Feature 10 HUD, slice 3).

    A persistent vertical strip of cards, one per equipped pet in PositionNumber order
    (stable, so players keep a preferred arrangement). Each card shows the pet's name,
    a state badge (Healthy/Strained/Critical/Recharging/Ready), a health bar, and a
    recharge countdown when it's out of the fight.

    Selection drives "assist" targeting (the CoH elegance): click a card OR the pet in
    the world to select that slot. Ally/support actions act on the selected pet; an
    enemy/debuff power would act on the enemy that pet is targeting (shown as the assist
    target). v1 wires Recall + Summon (Squad_Recall/Squad_Summon); Heal/Buff are stubbed
    until the player-power system is online.

    Reads slot state straight off the workspace pet attributes (no server UI feed):
    PetType / Variant / Power / CombatDamageTaken / CombatDowned / CooldownUntil /
    PositionNumber / TargetID. Pure visualisation + the two slot remotes.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local PetEndurance = require(ReplicatedStorage.Shared.Game.PetEndurance)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local POWER_ICONS = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("power_icons"))
local PET_ROLES = require(ReplicatedStorage.Configs:WaitForChild("pet_roles"))
local PETS = require(ReplicatedStorage.Configs:WaitForChild("pets"))

-- Card name = the pet's DISPLAY name (configs/pets.lua), NOT the PetType key ("dragon" not the key),
-- and the VARIANT is shown by COLOURING the word (gold / rainbow) instead of a "(golden)" suffix —
-- saves a lot of width. Falls back to a capitalised key if a pet has no display_name.
-- Blue (left) -> red (right). Starts COOL on purpose: a warm/gold start read as the golden
-- variant (Jason), so the rainbow now opens blue and only reaches red/orange at the far right.
local RAINBOW_NAME = ColorSequence.new({
    ColorSequenceKeypoint.new(0.0, Color3.fromRGB(80, 170, 255)), -- blue
    ColorSequenceKeypoint.new(0.3, Color3.fromRGB(95, 225, 220)), -- cyan
    ColorSequenceKeypoint.new(0.55, Color3.fromRGB(120, 235, 110)), -- green
    ColorSequenceKeypoint.new(0.8, Color3.fromRGB(255, 150, 70)), -- orange
    ColorSequenceKeypoint.new(1.0, Color3.fromRGB(255, 70, 70)), -- red
})
local GOLD_NAME = Color3.fromRGB(255, 215, 0)
local WHITE_NAME = Color3.fromRGB(255, 255, 255)

local function petDisplayName(key)
    local def = PETS.pets and PETS.pets[key]
    if def and type(def.display_name) == "string" then
        return def.display_name
    end
    return (tostring(key):gsub("^%l", string.upper)) -- fallback: capitalise the key
end

-- Set the card name to `displayName`, coloured by variant (golden = solid gold, rainbow = gradient,
-- basic = white). The rainbow gradient is a child the label keeps/drops as the variant changes.
local function applyVariantName(label, displayName, variant)
    label.Text = displayName
    local grad = label:FindFirstChild("VariantGrad")
    if variant == "rainbow" then
        label.TextColor3 = WHITE_NAME -- gradient tints the white base
        if not grad then
            grad = Instance.new("UIGradient")
            grad.Name = "VariantGrad"
            grad.Parent = label
        end
        grad.Color = RAINBOW_NAME
    else
        if grad then
            grad:Destroy()
        end
        label.TextColor3 = (variant == "golden") and GOLD_NAME or WHITE_NAME
    end
end
local PetBadge = require(script.Parent.Parent.UI.PetBadge)
local PetTargeting = require(ReplicatedStorage.Shared.Game.PetTargeting) -- damage scope → role-badge ring
local HudCard = require(script.Parent.Parent.UI.HudCard)
local StatusBadges = require(script.Parent.Parent.UI.StatusBadges)

local SquadHud = {}

local localPlayer = Players.LocalPlayer

-- Resolve a pet's archetype/role chip: PetRole attribute -> by_type[PetType] -> default.
-- Returns { glyph, icon, color (Color3) }, cached per role id.
local ROLE_CACHE = {}
local function roleFor(pet)
    local id = pet:GetAttribute("PetRole")
        or (PET_ROLES.by_type and PET_ROLES.by_type[pet:GetAttribute("PetType")])
        or PET_ROLES.default
    local cached = ROLE_CACHE[id]
    if cached then
        return cached
    end
    local def = (PET_ROLES.roles and PET_ROLES.roles[id]) or {}
    local c = def.color or { 90, 95, 110 }
    cached = {
        glyph = def.glyph or "?",
        icon = def.icon or "",
        color = Color3.fromRGB(c[1] or 90, c[2] or 95, c[3] or 110),
    }
    ROLE_CACHE[id] = cached
    return cached
end

local STATE_COLOR = {
    Healthy = Color3.fromRGB(90, 210, 110),
    Strained = Color3.fromRGB(225, 200, 70),
    Critical = Color3.fromRGB(225, 90, 70),
    Recharging = Color3.fromRGB(120, 130, 150),
    Ready = Color3.fromRGB(95, 170, 235),
    Empty = Color3.fromRGB(70, 70, 80),
}
local SLOT_BAR_COLOR = Color3.fromRGB(235, 150, 70) -- the SLOT timer (thin bar) when a pet is downed
local SHIELD_BAR_COLOR = Color3.fromRGB(95, 170, 235) -- the shield-pool thin bar when alive

-- Card chrome (frame/chip/health bar), the colour palette, and the green→red health curve all
-- live in HudCard, shared with the enemy strip so the two HUDs stay pixel-identical.
local formatTime = HudCard.formatTime
local healthColor = HudCard.healthColor

local function petsFolder()
    local pp = Workspace:FindFirstChild("PlayerPets")
    return pp and pp:FindFirstChild(localPlayer.Name)
end

local function petPower(pet)
    local nv = pet:FindFirstChild("Power")
    local p = (nv and tonumber(nv.Value)) or pet:GetAttribute("EffectivePower") or 1
    return (p and p >= 1) and p or 1
end

local function petSlot(pet)
    local pn = pet:FindFirstChild("PositionNumber")
    return pn and pn.Value or 0
end

-- The model a pet is currently attacking/mining: its TargetID resolves to an enemy (or crystal) by
-- matching that id to the target's BreakableID child — the same id space the server assigns. Scans
-- only the relevant folder (Enemies vs Breakables) via TargetType. nil when the pet has no target.
local function resolveTargetModel(pet)
    local tid = pet:FindFirstChild("TargetID")
    if not tid or tid.Value == 0 then
        return nil
    end
    local id = tid.Value
    local game = Workspace:FindFirstChild("Game")
    if not game then
        return nil
    end
    local tt = pet:FindFirstChild("TargetType")
    local isEnemy = tt and tostring(tt.Value) == "Enemy"
    if isEnemy then
        local enemies = game:FindFirstChild("Enemies")
        if enemies then
            for _, m in ipairs(enemies:GetChildren()) do
                local bid = m:FindFirstChild("BreakableID")
                if bid and bid.Value == id then
                    return m
                end
            end
        end
    else
        local breakables = game:FindFirstChild("Breakables")
        if breakables then
            for _, m in ipairs(breakables:GetDescendants()) do
                if m:IsA("Model") then
                    local bid = m:FindFirstChild("BreakableID")
                    if bid and bid.Value == id then
                        return m
                    end
                end
            end
        end
    end
    return nil
end

-- Resolve the live state the HUD renders for one pet.
local function readSlot(pet, factor, thresholds)
    local power = petPower(pet)
    local damage = pet:GetAttribute("CombatDamageTaken") or 0
    local downed = pet:GetAttribute("CombatDowned") == true
    local cdRemaining = 0
    local state
    if downed then
        cdRemaining = math.max(0, (pet:GetAttribute("CooldownUntil") or 0) - os.time())
        state = cdRemaining > 0 and "Recharging" or "Ready"
    else
        state = PetEndurance.state(damage, power, factor, thresholds)
    end
    local maxEnd = PetEndurance.maxEndurance(power, factor)
    local shield = pet:GetAttribute("CombatShield") or 0
    return {
        slot = petSlot(pet),
        name = tostring(pet:GetAttribute("PetType") or pet.Name),
        variant = tostring(pet:GetAttribute("Variant") or "basic"),
        healthFraction = PetEndurance.healthFraction(damage, power, factor),
        -- Shield (absorption pool) as a fraction of the pet's endurance ceiling, for the
        -- thin secondary bar. Capped at 1 so a big shield just fills it.
        shieldFraction = maxEnd > 0 and math.clamp(shield / maxEnd, 0, 1) or 0,
        downed = downed,
        state = state,
        cdRemaining = cdRemaining,
        -- #179 down-lockout: the SLOT's own (shorter) timer + whether this pet is a unique special
        -- (so the recovery bar scales to the 5-min pet lockout, not the 1-min slot).
        slotRemaining = math.max(0, (pet:GetAttribute("SlotLockUntil") or 0) - os.time()),
        special = pet:GetAttribute("LockoutSpecial") == true,
    }
end

-- Timed buffs/debuffs to show as badges on a pet's card. Read off the pet (or the
-- player, for squad-wide buffs). Placeholder colour + short label now; set `icon`
-- to an asset id later to swap the label for the real art.
-- `powerIdAttr`: the attribute PowerService stamps with the power that applied this buff. When
-- present, the badge resolves THAT power's disc (PetBadge) so it matches the hotbar + world icon;
-- `icon` is only the fallback when no power tagged it.
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

-- (badge engine extracted to src/Client/UI/StatusBadges.lua — shared with EnemyHud). Pet effects
-- resolve against the pet (most attrs) + the player (squad-wide buffs) via the sources map below.

function SquadHud.start()
    local config = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("combat"))
    local squadCfg = require(ReplicatedStorage.Configs:WaitForChild("squad"))
    local lockoutDur = {
        -- the EXACT special pet's recovery (5 min); a stack pet rides the slot timer
        petSpecial = (squadCfg.down_lockout and squadCfg.down_lockout.pet_lockout_seconds) or 300,
        slot = (squadCfg.slot_recovery and squadCfg.slot_recovery.down_cooldown_seconds) or 60,
    }
    local factor = config.pet_down_threshold_factor or 1
    local thresholds = config.degradation or { strained_at = 0.6, critical_at = 0.3 }
    local badgeCfg = config.status_badges or {}
    local blinkLead = badgeCfg.blink_lead_seconds or 5
    local blinkPeriod = badgeCfg.blink_period_seconds or 0.5

    local gui = Instance.new("ScreenGui")
    gui.Name = "SquadHud"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
    gui.Parent = localPlayer:WaitForChild("PlayerGui")

    -- Right-edge container, vertically centred.
    local root = Instance.new("Frame")
    root.Name = "Strip"
    root.AnchorPoint = Vector2.new(1, 0.5)
    root.Position = UDim2.new(1, -8, 0.5, 0)
    root.Size = UDim2.fromOffset(186, 10)
    root.AutomaticSize = Enum.AutomaticSize.Y
    root.BackgroundTransparency = 1
    root.Parent = gui
    -- pixel-designed strip: shrink on small viewports (anchored right-center, stays docked)
    require(script.Parent.Parent.UI.UIViewportScale).attach(root)
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    layout.Padding = UDim.new(0, 4)
    layout.Parent = root

    local selectedSlot = nil
    -- TEAM scope sentinel: selecting the top-of-strip TEAM header sets selectedSlot to this and tells
    -- the server CombatBuffTarget = -1, so a single_pet power (shield/heal/buff) lands on the WHOLE
    -- squad. Matches PowerService._targetPets/_tauntHolders' -1 handling. (Forward-declared so
    -- setSelected — defined above the header build — can refresh the header's highlight.)
    local TEAM_SEL = -1
    local teamCard -- { frame, stroke }; the header card, built below
    local function refreshTeamHighlight()
        if teamCard then
            HudCard.applyHighlight(teamCard, (selectedSlot == TEAM_SEL) and "select" or nil)
        end
    end
    local assistTargetBid = nil -- the enemy BreakableID the squad is directed to focus (Z / click)
    local cards = {} -- slot -> { frame, refs... }
    local worldHighlight = Instance.new("Highlight")
    worldHighlight.Name = "SquadSelectHighlight"
    worldHighlight.FillTransparency = 0.6
    worldHighlight.OutlineColor = Color3.fromRGB(95, 170, 235)
    worldHighlight.Enabled = false
    worldHighlight.Parent = gui

    -- The selected pet's TARGET (what it's attacking/mining) — a warmer amber outline, distinct from
    -- the blue pet selection, so "this pet → that enemy" reads at a glance. Follows the live target.
    local targetHighlight = Instance.new("Highlight")
    targetHighlight.Name = "SquadTargetHighlight"
    targetHighlight.FillTransparency = 0.75
    targetHighlight.FillColor = Color3.fromRGB(255, 180, 70)
    targetHighlight.OutlineColor = Color3.fromRGB(255, 160, 40)
    targetHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    targetHighlight.Enabled = false
    targetHighlight.Parent = gui

    local function setSelected(slot)
        selectedSlot = slot
        -- Tell the server which pet is selected, so single-target buffs (aegis / ironclad) land on
        -- it. The slot IS the pet's PositionNumber, which the server matches in _targetPets.
        pcall(function()
            Signals.Combat_SelectPetTarget:FireServer({ slot = slot or 0 })
        end)
        -- world highlight follows the selected pet
        worldHighlight.Adornee = nil
        worldHighlight.Enabled = false
        local folder = petsFolder()
        if folder then
            for _, pet in ipairs(folder:GetChildren()) do
                if pet:IsA("Model") and petSlot(pet) == slot then
                    worldHighlight.Adornee = pet
                    worldHighlight.Enabled = not pet:GetAttribute("CombatDowned")
                end
            end
        end
        -- keep the TEAM header lit only while team scope is the active pick (else a single pet is)
        refreshTeamHighlight()
    end

    -- Keep the target highlight on whatever the SELECTED pet is currently attacking/mining. Polled
    -- (~6 Hz) rather than per-frame — the pet's target only changes occasionally, and resolving it
    -- scans a folder. Clears when nothing is selected or the selected pet has no target.
    task.spawn(function()
        while gui.Parent do
            task.wait(0.15)
            local foe
            -- gated by the "Target Highlight" setting (on by default; toggled in SettingsPanel)
            if selectedSlot and localPlayer:GetAttribute("TargetHighlightOn") ~= false then
                local folder = petsFolder()
                if folder then
                    for _, pet in ipairs(folder:GetChildren()) do
                        if pet:IsA("Model") and petSlot(pet) == selectedSlot then
                            if not pet:GetAttribute("CombatDowned") then
                                foe = resolveTargetModel(pet)
                            end
                            break
                        end
                    end
                end
            end
            if foe and foe.Parent then
                targetHighlight.Adornee = foe
                targetHighlight.Enabled = true
            else
                targetHighlight.Adornee = nil
                targetHighlight.Enabled = false
            end
        end
    end)

    -- Build one card (returns refs for live updates). The chrome (frame/chip/health bar/status
    -- row) comes from the shared HudCard builder; the squad card then adds its pet-only extras:
    -- the thin shield bar, the admin kill button, and the summon/select click.
    local function makeCard(slot)
        local card = HudCard.createCard(root, { name = "Slot_" .. slot, layoutOrder = slot })
        local frame = card.frame
        local nameLbl, noteLbl, fill = card.name, card.note, card.fill
        local roleChip, roleGlyph, roleIcon, roleRing =
            card.roleChip, card.roleGlyph, card.roleIcon, card.roleRing
        local stroke, status = card.stroke, card.status

        -- SPREAD MARKER (contagion): a small glyph on the role badge when the deployed pet's burn
        -- spreads — so the HUD reads AoE-contagion apart from plain AoE, matching the inventory card.
        -- Built hidden; the update loop sets its element-tinted image + visibility from the live pet.
        local spreadMarker = Instance.new("ImageLabel")
        spreadMarker.Name = "SpreadMarker"
        spreadMarker.AnchorPoint = Vector2.new(1, 0)
        spreadMarker.Position = UDim2.fromScale(1.05, -0.05)
        spreadMarker.Size = UDim2.fromScale(0.5, 0.5)
        spreadMarker.BackgroundTransparency = 1
        spreadMarker.ScaleType = Enum.ScaleType.Fit
        spreadMarker.Visible = false
        spreadMarker.ZIndex = (roleIcon and roleIcon.ZIndex or 1) + 2
        spreadMarker.Parent = roleChip
        local spreadAspect = Instance.new("UIAspectRatioConstraint")
        spreadAspect.AspectRatio = 1
        spreadAspect.Parent = spreadMarker

        -- Thin secondary bar = shield absorption pool (blue), CoH endurance-bar style.
        -- Hidden when the pet has no shield; rounded (pill) corners.
        local shieldBg = Instance.new("Frame")
        shieldBg.Name = "ShieldBg"
        shieldBg.Position = UDim2.fromOffset(40, 31)
        shieldBg.Size = UDim2.new(1, -48, 0, 4)
        shieldBg.BackgroundColor3 = Color3.fromRGB(12, 13, 18)
        shieldBg.BorderSizePixel = 0
        shieldBg.ClipsDescendants = true
        shieldBg.Visible = false
        shieldBg.Parent = frame
        local shieldCorner = Instance.new("UICorner")
        shieldCorner.CornerRadius = UDim.new(1, 0)
        shieldCorner.Parent = shieldBg
        local shieldFill = Instance.new("Frame")
        shieldFill.Name = "ShieldFill"
        shieldFill.Size = UDim2.fromScale(0, 1)
        shieldFill.BackgroundColor3 = Color3.fromRGB(95, 170, 235)
        shieldFill.BorderSizePixel = 0
        shieldFill.Parent = shieldBg
        local shieldFillCorner = Instance.new("UICorner")
        shieldFillCorner.CornerRadius = UDim.new(1, 0)
        shieldFillCorner.Parent = shieldFill

        -- Admin-only ✕ KILL button (top-right): force THIS slot's pet down so the lockout / Spirit
        -- Form fires with no enemies — fast testing. Shown only while admin mode is ON (the same
        -- AdminOverlaysOn toggle that reveals the dev overlays).
        local killBtn = Instance.new("TextButton")
        killBtn.Name = "AdminKill"
        killBtn.Size = UDim2.fromOffset(20, 20)
        killBtn.AnchorPoint = Vector2.new(1, 0)
        killBtn.Position = UDim2.new(1, -2, 0, 2)
        killBtn.BackgroundColor3 = Color3.fromRGB(185, 45, 45)
        killBtn.Text = "X" -- (was "✕"; the glyph tofu-boxes in Gotham)
        killBtn.Font = Enum.Font.GothamBold
        killBtn.TextSize = 13
        killBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        killBtn.ZIndex = 10
        killBtn.Visible = localPlayer:GetAttribute("AdminOverlaysOn") == true
        local killCorner = Instance.new("UICorner")
        killCorner.CornerRadius = UDim.new(1, 0)
        killCorner.Parent = killBtn
        killBtn.Parent = frame
        killBtn.Activated:Connect(function()
            Signals.Squad_AdminKill:FireServer({ slot = slot })
        end)
        localPlayer:GetAttributeChangedSignal("AdminOverlaysOn"):Connect(function()
            killBtn.Visible = localPlayer:GetAttribute("AdminOverlaysOn") == true
        end)

        frame.MouseButton1Click:Connect(function()
            -- A downed pet whose cooldown has elapsed shows "Summon" — clicking the card
            -- re-summons it. Otherwise a click just selects the slot (assist target).
            local c = cards[slot]
            if c and c.summonReady then
                Signals.Squad_Summon:FireServer({ slot = slot })
            else
                setSelected(slot)
            end
        end)

        return {
            frame = frame,
            stroke = stroke,
            name = nameLbl,
            note = noteLbl,
            fill = fill,
            shieldBg = shieldBg,
            shieldFill = shieldFill,
            roleChip = roleChip,
            roleGlyph = roleGlyph,
            roleIcon = roleIcon,
            roleRing = roleRing,
            spreadMarker = spreadMarker,
            status = status,
            badges = {},
        }
    end

    -- TEAM HEADER (Jason): a player-icon card pinned to the TOP of the squad strip. Selecting it puts
    -- power targeting in TEAM scope — a single_pet buff/shield/heal then lands on the WHOLE squad, and
    -- it clears any single-pet pick (the reachable "select everyone" state we were missing). This is
    -- the seed of the future multiplayer roster: each teamed player becomes a header like this with
    -- their pets grouped beneath. Styled to match HudCard chrome (same bg / corner / stroke).
    do
        local frame = Instance.new("TextButton")
        frame.Name = "TeamHeader"
        frame.AutoButtonColor = false
        frame.Text = ""
        frame.Size = UDim2.fromOffset(186, 34)
        frame.BackgroundColor3 = Color3.fromRGB(28, 30, 40)
        frame.BackgroundTransparency = 0.1
        frame.BorderSizePixel = 0
        frame.LayoutOrder = -1 -- above every pet card (pet slots are >= 1)
        frame.Parent = root
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = frame
        local stroke = Instance.new("UIStroke")
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Color = HudCard.STROKE_IDLE
        stroke.Thickness = 1.5
        stroke.Transparency = 0.4
        stroke.Parent = frame
        -- circular player HEADSHOT on the inner edge, poking off like the pet role chip. rbxthumb is a
        -- lazily-resolved content URL — no async thumbnail call.
        local avatarChip = Instance.new("Frame")
        avatarChip.Name = "Avatar"
        avatarChip.AnchorPoint = Vector2.new(HudCard.BADGE_OVERHANG, 0.5)
        avatarChip.Position = UDim2.new(0, 0, 0.5, 0)
        avatarChip.Size = UDim2.new(1, 0, 1, 0)
        avatarChip.BackgroundColor3 = Color3.fromRGB(55, 110, 190)
        avatarChip.BorderSizePixel = 0
        avatarChip.Parent = frame
        local avAspect = Instance.new("UIAspectRatioConstraint")
        avAspect.AspectRatio = 1
        avAspect.AspectType = Enum.AspectType.FitWithinMaxSize
        avAspect.Parent = avatarChip
        local avCorner = Instance.new("UICorner")
        avCorner.CornerRadius = UDim.new(1, 0) -- circle
        avCorner.Parent = avatarChip
        local headshot = Instance.new("ImageLabel")
        headshot.Name = "Headshot"
        headshot.BackgroundTransparency = 1
        headshot.AnchorPoint = Vector2.new(0.5, 0.5)
        headshot.Position = UDim2.fromScale(0.5, 0.5)
        headshot.Size = UDim2.fromScale(1, 1)
        headshot.Image = "rbxthumb://type=AvatarHeadShot&id="
            .. tostring(localPlayer.UserId)
            .. "&w=150&h=150"
        headshot.Parent = avatarChip
        local hsCorner = Instance.new("UICorner")
        hsCorner.CornerRadius = UDim.new(1, 0)
        hsCorner.Parent = headshot
        local lbl = Instance.new("TextLabel")
        lbl.Name = "Label"
        lbl.BackgroundTransparency = 1
        lbl.Position = UDim2.fromOffset(40, 0)
        lbl.Size = UDim2.new(1, -48, 1, 0)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 14
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextColor3 = Color3.fromRGB(235, 240, 255)
        lbl.Text = "MY TEAM"
        lbl.Parent = frame
        teamCard = { frame = frame, stroke = stroke }
        frame.MouseButton1Click:Connect(function()
            -- toggle: pick TEAM scope, or if it's already the pick, clear back to no selection
            setSelected(selectedSlot == TEAM_SEL and nil or TEAM_SEL)
        end)
        refreshTeamHighlight()
    end

    -- (Removed the per-slot Recall/Summon/Heal/Buff action row — squad control now
    -- lives on the bottom hotbar. Card selection still drives assist-target + cycle.)

    -- World click: clicking a pet selects its slot; clicking an ENEMY directs the squad
    -- to focus it (assist target). Clicking empty space clears the assist.
    local function enemiesFolder()
        local g = Workspace:FindFirstChild("Game")
        return g and g:FindFirstChild("Enemies")
    end
    local mouse = localPlayer:GetMouse()
    mouse.Button1Down:Connect(function()
        local target = mouse.Target
        local model = target and target:FindFirstAncestorWhichIsA("Model")
        local pets = petsFolder()
        if model and pets and model:IsDescendantOf(pets) then
            setSelected(petSlot(model))
            return
        end
        local enemies = enemiesFolder()
        if model and enemies and model:IsDescendantOf(enemies) then
            local bid = model:FindFirstChild("BreakableID")
            assistTargetBid = bid and bid.Value or nil
            Signals.Combat_SetAssist:FireServer({ targetId = bid and bid.Value or 0 })
        elseif not model then
            assistTargetBid = nil
            Signals.Combat_SetAssist:FireServer({ targetId = 0 }) -- clicked empty -> clear
        end
    end)

    -- Keyboard cycle (default Tab, config-assignable; hold Shift to go backward).
    local controls = require(ReplicatedStorage.Configs:WaitForChild("controls"))
    local cycleName = (controls.keybinds and controls.keybinds.squad_cycle) or "Tab"
    local okKey, cycleKey = pcall(function()
        return Enum.KeyCode[cycleName]
    end)
    if not okKey or not cycleKey then
        cycleKey = Enum.KeyCode.Tab
    end

    local function orderedSlots()
        local slots = {}
        local folder = petsFolder()
        if folder then
            for _, pet in ipairs(folder:GetChildren()) do
                if pet:IsA("Model") and pet.PrimaryPart then
                    slots[#slots + 1] = petSlot(pet)
                end
            end
        end
        table.sort(slots)
        return slots
    end

    local function cycle(dir)
        local slots = orderedSlots()
        -- fold the TEAM header in as the last cycle stop (Jason): pet1 → … → petN → TEAM → pet1, so
        -- Tab reaches team scope on desktop too. (Even with no pets, TEAM is a reachable stop.)
        slots[#slots + 1] = TEAM_SEL
        local idx
        for i, s in ipairs(slots) do
            if s == selectedSlot then
                idx = i
                break
            end
        end
        if not idx then
            idx = dir > 0 and 1 or #slots
        else
            idx = ((idx - 1 + dir) % #slots) + 1
        end
        setSelected(slots[idx])
    end

    -- Enemy assist cycle (Z): step the assist target through nearby enemies (and, if
    -- configured, mining targets), directing the squad to focus one. Mirrors the Q cycle.
    local enemyCycleName = (controls.keybinds and controls.keybinds.enemy_cycle) or "Z"
    local okE, enemyCycleKey = pcall(function()
        return Enum.KeyCode[enemyCycleName]
    end)
    if not okE or not enemyCycleKey then
        enemyCycleKey = Enum.KeyCode.Z
    end
    local ecCfg = controls.enemy_cycle or {}
    local cycleRange = ecCfg.range or 80
    local includeMining = ecCfg.include_mining == true

    local function orderedEnemies()
        local out = {}
        local char = localPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then
            return out
        end
        local function add(m)
            if m and m:IsA("Model") and m.PrimaryPart and (m:GetAttribute("HP") or 0) > 0 then
                local bid = m:FindFirstChild("BreakableID")
                if bid then
                    local d = (m.PrimaryPart.Position - hrp.Position).Magnitude
                    if d <= cycleRange then
                        out[#out + 1] = { bid = bid.Value, dist = d }
                    end
                end
            end
        end
        local enemies = enemiesFolder()
        if enemies then
            for _, m in ipairs(enemies:GetChildren()) do
                add(m)
            end
        end
        if includeMining then
            local g = Workspace:FindFirstChild("Game")
            local breakables = g and g:FindFirstChild("Breakables")
            if breakables then
                for _, d in ipairs(breakables:GetDescendants()) do
                    if d.Name == "BreakableID" and d:IsA("NumberValue") then
                        add(d.Parent)
                    end
                end
            end
        end
        table.sort(out, function(a, b)
            return a.dist < b.dist
        end)
        return out
    end

    local function cycleEnemy(dir)
        local list = orderedEnemies()
        if #list == 0 then
            assistTargetBid = nil
            Signals.Combat_SetAssist:FireServer({ targetId = 0 })
            return
        end
        local idx
        for i, e in ipairs(list) do
            if e.bid == assistTargetBid then
                idx = i
                break
            end
        end
        if not idx then
            idx = (dir > 0) and 1 or #list
        else
            idx = ((idx - 1 + dir) % #list) + 1
        end
        assistTargetBid = list[idx].bid
        Signals.Combat_SetAssist:FireServer({ targetId = assistTargetBid })
    end

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then
            return -- don't cycle while typing in a TextBox, etc.
        end
        local reverse = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
            or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
        if input.KeyCode == cycleKey then
            cycle(reverse and -1 or 1)
        elseif input.KeyCode == enemyCycleKey then
            cycleEnemy(reverse and -1 or 1)
        end
    end)

    -- Reconcile + refresh the strip.
    local accum = 0
    RunService.RenderStepped:Connect(function(dt)
        accum += dt
        if accum < 0.2 then
            return
        end
        accum = 0
        local folder = petsFolder()
        local present = {}
        if folder then
            for _, pet in ipairs(folder:GetChildren()) do
                if pet:IsA("Model") and pet.PrimaryPart then
                    local s = readSlot(pet, factor, thresholds)
                    present[s.slot] = true
                    local card = cards[s.slot]
                    if not card then
                        card = makeCard(s.slot)
                        cards[s.slot] = card
                    end
                    applyVariantName(card.name, petDisplayName(s.name), s.variant)
                    -- Archetype/role badge: element DISC + tinted aura RING (the universal
                    -- PetBadge). Element from the pet's origin; role from PetRole/by_type. Falls
                    -- back to the coloured letter glyph when that (element, role) has no disc art.
                    local role = roleFor(pet)
                    local roleId = pet:GetAttribute("PetRole")
                        or (PET_ROLES.by_type and PET_ROLES.by_type[pet:GetAttribute("PetType")])
                        or PET_ROLES.default
                    local element = PetBadge.elementForPetType(pet:GetAttribute("PetType"))
                    -- DAMAGE-targeting ring: the archetype badge wears the ring for how its attack
                    -- hits (PetTargeting.attackScope → power_icons.targeting_ring). Per-pet override
                    -- via the AttackTargeting attribute, else the role default. SSOT with the card.
                    local atkScope = PetTargeting.attackScope(
                        pet:GetAttribute("AttackTargeting"),
                        roleId,
                        PET_ROLES
                    )
                    local hasBadge = PetBadge.apply(
                        card.roleIcon,
                        card.roleRing,
                        element,
                        roleId,
                        { ring = POWER_ICONS.targeting_ring[atkScope] }
                    )
                    card.roleChip.BackgroundColor3 = role.color
                    card.roleChip.BackgroundTransparency = hasBadge and 1 or 0
                    card.roleGlyph.Visible = not hasBadge
                    card.roleGlyph.Text = role.glyph
                    -- spread marker: contagious burn (DotSpreadMax stamped at spawn, or the legacy
                    -- "contagion" scope) wears a contagion glyph over the geometry ring. SSOT with the
                    -- combat loop (it arms spread from the same DotSpreadMax) and the inventory card.
                    if card.spreadMarker then
                        local contagious = hasBadge
                            and PetTargeting.isContagious(
                                nil,
                                ((tonumber(pet:GetAttribute("DotSpreadMax")) or 0) > 0)
                                        and "contagion"
                                    or pet:GetAttribute("AttackTargeting")
                            )
                        local disc = contagious
                            and POWER_ICONS.discFor
                            and POWER_ICONS.discFor(element, "contagion")
                        if disc then
                            card.spreadMarker.Image = disc
                            card.spreadMarker.Visible = true
                        else
                            card.spreadMarker.Visible = false
                        end
                    end
                    if s.downed then
                        -- TWO BARS (down-lockout). Main = THIS pet's recovery (drains as it heals; a
                        -- unique special scales to the 5-min lockout, a stack to the 1-min slot). The
                        -- thin bar below = the SLOT's 1-min timer, so you can see when to re-summon
                        -- this pet vs. when the slot frees for a different / stack pet.
                        local petTotal = (s.special and lockoutDur.petSpecial) or lockoutDur.slot
                        local petFrac = (petTotal > 0 and s.cdRemaining > 0)
                                and math.clamp(s.cdRemaining / petTotal, 0, 1)
                            or (s.cdRemaining > 0 and 1 or 0)
                        card.fill.Size = UDim2.fromScale(s.cdRemaining > 0 and petFrac or 1, 1)
                        card.fill.BackgroundColor3 = s.cdRemaining > 0 and STATE_COLOR.Recharging
                            or STATE_COLOR.Ready
                        card.note.Text = s.cdRemaining > 0 and formatTime(s.cdRemaining) or "Summon"
                        card.summonReady = s.cdRemaining <= 0
                    else
                        -- Health fill drains + recolours green->yellow->red.
                        card.fill.Size = UDim2.fromScale(math.clamp(s.healthFraction, 0, 1), 1)
                        card.fill.BackgroundColor3 = healthColor(s.healthFraction)
                        card.note.Text = ""
                        card.summonReady = false
                    end
                    -- Thin secondary bar: the SLOT timer (orange) when downed, else the shield pool (blue).
                    if s.downed then
                        local slotFrac = lockoutDur.slot > 0
                                and math.clamp(s.slotRemaining / lockoutDur.slot, 0, 1)
                            or 0
                        card.shieldBg.Visible = s.slotRemaining > 0
                        card.shieldFill.Size = UDim2.fromScale(slotFrac, 1)
                        card.shieldFill.BackgroundColor3 = SLOT_BAR_COLOR
                    else
                        local shieldF = s.shieldFraction or 0
                        card.shieldBg.Visible = shieldF > 0
                        card.shieldFill.Size = UDim2.fromScale(shieldF, 1)
                        card.shieldFill.BackgroundColor3 = SHIELD_BAR_COLOR
                    end
                    -- Selection = an OUTLINE only (the gems-pill look): the dark bar stays dark, just
                    -- the stroke pops to bright blue. No background colour change (that swamped it).
                    HudCard.applyHighlight(card, (selectedSlot == s.slot) and "select" or nil)
                    StatusBadges.update(
                        card,
                        StatusBadges.resolveEffects(
                            PET_EFFECTS,
                            { pet = pet, player = localPlayer },
                            os.time()
                        ),
                        blinkLead
                    )
                end
            end
        end
        -- drop cards for unequipped slots
        for slot, card in pairs(cards) do
            if not present[slot] then
                card.frame:Destroy()
                cards[slot] = nil
            end
        end
        -- keep the world highlight tracking the selected pet's downed visibility
        if selectedSlot and worldHighlight.Adornee then
            worldHighlight.Enabled = not worldHighlight.Adornee:GetAttribute("CombatDowned")
        end
    end)

    -- Expiry blink: runs every frame (not the 0.2s reconcile) so the flash is smooth (shared engine).
    RunService.RenderStepped:Connect(function()
        StatusBadges.applyBlink(cards, blinkPeriod)
    end)
end

return SquadHud
