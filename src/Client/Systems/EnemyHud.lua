--[[
    EnemyHud — the foes side of the combat HUD. A top-right strip that appears the moment a fight
    starts and lists every enemy aggro'd onto YOUR squad, sorted nearest-first. Built from the
    exact same HudCard chrome as the pet cards (SquadHud, right-centre), so "enemies up top, your
    squad below" both hug the right edge and read identically. (It started left-centre but collided
    with the currency stack, hiding the cards behind the coin pills — top-right keeps it clear.)

    The chain player → selected pet → enemy is made legible: the enemy your SELECTED pet is
    currently attacking — the indirect target — gets an amber border, the same colour the world
    SquadTargetHighlight already puts on that enemy. So selecting a pet and watching which enemy
    card lights up tells you exactly what your squad is hitting, and clicking an enemy card directs
    the squad to focus it (the same assist-target the world-click / Z-cycle set).

    Reads are pure off replicated state: enemy models in workspace.Game.Enemies carry HP / MaxHP /
    Level / DisplayName / AggroOwner (the player name the enemy is fighting, mirrored from the
    server's aggro table); the selected pet is the player's CombatBuffTarget slot; a pet's foe is
    its TargetID (matched to the enemy's BreakableID). No bespoke server feed.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local HudCard = require(script.Parent.Parent.UI.HudCard)
local StatusBadges = require(script.Parent.Parent.UI.StatusBadges)
local PetBadge = require(script.Parent.Parent.UI.PetBadge)
local EnemyCon = require(ReplicatedStorage.Shared.Game.EnemyCon)
local POWER_ICONS = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("power_icons"))

local EnemyHud = {}

local localPlayer = Players.LocalPlayer

-- Enemy NAME colour = the City-of-Heroes con scale (shared EnemyCon resolver): the enemy's level
-- relative to the local player (gray -3 / green -2 / blue -1 / white even / yellow +1 / orange +2 /
-- red +3 / purple +4+). Rank is already baked into the published Level. Replaces the old red box.
local function threatColor(enemyLvl)
    if not enemyLvl then
        return Color3.fromRGB(240, 240, 245)
    end
    return EnemyCon.colorForLevels(enemyLvl, localPlayer:GetAttribute("Level"))
end

-- Status badges shown on an enemy card — the SAME engine + chrome the squad cards use (the row
-- grows leftward out of the card's inner edge, "out to the left"). Enemies carry the pet status
-- vocabulary, so this is just a different descriptor table over the same renderer:
--   HEAL — an enemy SUPPORT cast: the rabid_bunny/acolyte mending a hurt ally (HealFxUntil). The
--          "kill the healer to flip the fight" tell, now on the card (matches the world heal splash).
--   HEX  — YOUR debuff landing on the foe (DebuffUntil; set by every vulnerable/sunder/expose power),
--          a timed countdown so you can read when it lapses.
-- New enemy casts drop in as one more row here — no new rendering code.
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
-- Expiry-blink cadence (matches SquadHud's defaults; a near-expiry timed badge flashes).
local BLINK_LEAD = 5
local BLINK_PERIOD = 0.5
-- Cap is a high BACKSTOP for absurd pulls, not a normal limit — every card the cap hid was a foe
-- actively hurting you (Jason: "you don't know the enemies that are hurting you"; 15 hitting him at
-- layer 2). The strip is already filtered to enemies ENGAGED with your squad, so we show them all
-- and let the layout (grow-down + money/menu collapse) make room; the cap only stops a runaway.
local MAX_CARDS = 20
-- Big-pull compaction: cards render full size up to DENSITY_FULL, then the whole strip scales down
-- (uniformly) so even a huge pull stays legible. Raised so the list stays FULL-SIZE longer and grows
-- DOWN into money's space (which collapses) instead of shrinking early — the density floor is the
-- last resort past that.
local DENSITY_FULL = 10
local DENSITY_MIN = 0.5

local function enemiesFolder()
    local g = Workspace:FindFirstChild("Game")
    return g and g:FindFirstChild("Enemies")
end

local function petsFolder()
    local pp = Workspace:FindFirstChild("PlayerPets")
    return pp and pp:FindFirstChild(localPlayer.Name)
end

local function petSlot(pet)
    local pn = pet:FindFirstChild("PositionNumber")
    return pn and pn.Value or 0
end

-- The enemy a pet is attacking: TargetID resolves to an enemy by BreakableID, but only while
-- TargetType is "Enemy" (a mining pet's TargetID points at a crystal). Returns the bid or nil.
local function petEnemyBid(pet)
    local tt = pet:FindFirstChild("TargetType")
    local tid = pet:FindFirstChild("TargetID")
    if tid and tid.Value ~= 0 and tt and tostring(tt.Value) == "Enemy" then
        return tid.Value
    end
    return nil
end

-- The INDIRECT target: the enemy the player's SELECTED pet (CombatBuffTarget slot) is attacking.
-- This is the card that lights amber — player → pet → enemy. nil when nothing is selected, the
-- selected pet is downed, or it isn't attacking an enemy.
local function indirectTargetBid()
    local slot = localPlayer:GetAttribute("CombatBuffTarget")
    if not slot or slot == 0 then
        return nil
    end
    local folder = petsFolder()
    if not folder then
        return nil
    end
    for _, pet in ipairs(folder:GetChildren()) do
        if pet:IsA("Model") and petSlot(pet) == slot then
            if pet:GetAttribute("CombatDowned") then
                return nil
            end
            return petEnemyBid(pet)
        end
    end
    return nil
end

-- How long an enemy's card lingers after it stops reading as "engaged" (seconds). The server
-- clears an enemy's aggro the instant its threat decays below the disengage line, then re-acquires
-- it on the next perception tick (~0.75s) — so AggroOwner flickers off/on for every foe the squad
-- isn't focus-firing. This grace rides through that blink so all aggro'd enemies stay on the strip,
-- and a card only drops when the enemy truly leaves (dies / leashes out for good).
local ENGAGE_GRACE = 3
local engagedUntil = {} -- bid -> os.clock() expiry (module-level: one local player)

-- Every enemy aggro'd onto MY squad, nearest first. An enemy is "engaged" when its server-mirrored
-- AggroOwner is me OR one of my pets is biting it; once engaged it stays on the strip for
-- ENGAGE_GRACE seconds (flicker-proof). Loitering enemies that never engaged my squad stay off it —
-- the HUD is the FIGHT, not the neighbourhood. A card drops the moment the enemy dies/despawns
-- (gated on the live model), regardless of grace.
local function engagedEnemies(now)
    local char = localPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local origin = hrp and hrp.Position

    local petTargets = {}
    local pf = petsFolder()
    if pf then
        for _, pet in ipairs(pf:GetChildren()) do
            if pet:IsA("Model") then
                local bid = petEnemyBid(pet)
                if bid then
                    petTargets[bid] = true
                end
            end
        end
    end

    local out, liveBids = {}, {}
    local enemies = enemiesFolder()
    if enemies then
        for _, m in ipairs(enemies:GetChildren()) do
            if m:IsA("Model") and m.PrimaryPart and (m:GetAttribute("HP") or 0) > 0 then
                local bidObj = m:FindFirstChild("BreakableID")
                if bidObj then
                    local bid = bidObj.Value
                    liveBids[bid] = true
                    -- engaged RIGHT NOW → refresh the grace window
                    if m:GetAttribute("AggroOwner") == localPlayer.Name or petTargets[bid] then
                        engagedUntil[bid] = now + ENGAGE_GRACE
                    end
                    -- shown if engaged within the grace window (rides the aggro flicker)
                    if (engagedUntil[bid] or 0) > now then
                        out[#out + 1] = {
                            bid = bid,
                            model = m,
                            dist = origin and (m.PrimaryPart.Position - origin).Magnitude or 0,
                        }
                    end
                end
            end
        end
    end
    -- forget enemies that have died/despawned so their grace can't resurrect a card
    for bid in pairs(engagedUntil) do
        if not liveBids[bid] then
            engagedUntil[bid] = nil
        end
    end
    table.sort(out, function(a, b)
        return a.dist < b.dist
    end)
    return out
end

function EnemyHud.start()
    local gui = Instance.new("ScreenGui")
    gui.Name = "EnemyHud"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = false -- respect the topbar inset so a top-left anchor sits under the ☰/chat row
    gui.Parent = localPlayer:WaitForChild("PlayerGui")

    -- LEFT rail — enemies own the TOP-LEFT and grow DOWNWARD (Jason's endgame HUD layout): the foes
    -- you CLICK live on the left (below the ☰/chat corner via IgnoreGuiInset=false), your team/
    -- teammate strips own the RIGHT rail. Money sits at the BOTTOM-left (above the menu buttons) and
    -- collapses when the growing enemy list reaches it — so enemies never depend on money's position.
    -- root = UNSCALED POSITIONER: a UIViewportScale on the positioning frame scales its position too,
    -- so the viewport scale lives on the inner `scaler` (composed with the density UIScale on the
    -- list — Roblox honours one UIScale per object, so they sit on separate frames).
    local root = Instance.new("Frame")
    root.Name = "Strip"
    root.AnchorPoint = Vector2.new(0, 0)
    root.Position = UDim2.new(0, 8, 0, 8) -- top-left, just under the topbar (inset respected)
    root.Size = UDim2.fromOffset(186, 10)
    root.AutomaticSize = Enum.AutomaticSize.Y
    root.BackgroundTransparency = 1
    root.Parent = gui

    local scaler = Instance.new("Frame")
    scaler.Name = "Scaler"
    scaler.AnchorPoint = Vector2.new(0, 0)
    scaler.Position = UDim2.fromScale(0, 0)
    scaler.Size = UDim2.fromOffset(186, 10)
    scaler.AutomaticSize = Enum.AutomaticSize.Y
    scaler.BackgroundTransparency = 1
    scaler.Parent = root
    require(script.Parent.Parent.UI.UIViewportScale).attach(scaler)

    -- Inner frame carries its OWN UIScale (DensityScale) so a big pull can shrink the cards
    -- independently of the viewport scaler on root — Roblox honours only one UIScale per object,
    -- so the two live on separate frames and compose (viewport × density).
    local listFrame = Instance.new("Frame")
    listFrame.Name = "List"
    listFrame.AnchorPoint = Vector2.new(0, 0)
    listFrame.Position = UDim2.fromScale(0, 0)
    listFrame.Size = UDim2.fromOffset(186, 10)
    listFrame.AutomaticSize = Enum.AutomaticSize.Y
    listFrame.BackgroundTransparency = 1
    listFrame.Parent = scaler
    local densityScale = Instance.new("UIScale")
    densityScale.Name = "DensityScale"
    densityScale.Parent = listFrame
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    layout.Padding = UDim.new(0, 4)
    layout.Parent = listFrame

    local cards = {} -- bid -> card refs

    -- World highlight on the player's chosen FOCUS enemy (the assist target). The inverse of the pet
    -- selection: clicking a pet highlights the enemy IT attacks; clicking an enemy card now selects
    -- THAT enemy — a blue border on the card + this glow on the world model — so you can see what you
    -- directed the squad at. (Jason: clicking an enemy should do the inverse and at least select it.)
    local assistHighlight = Instance.new("Highlight")
    assistHighlight.Name = "AssistTargetHighlight"
    assistHighlight.FillTransparency = 0.7
    assistHighlight.FillColor = Color3.fromRGB(95, 170, 235)
    assistHighlight.OutlineColor = Color3.fromRGB(125, 195, 255)
    assistHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    assistHighlight.Enabled = false
    assistHighlight.Parent = gui

    -- STABLE SLOTS (Jason: the strip re-sorted by distance every tick, so a card slid out from under
    -- the cursor and clicks missed the foe). Each enemy keeps a fixed slot (1..MAX_CARDS) for its
    -- whole life on the strip; a freed slot is reused by the nearest waiting foe. No live card ever
    -- moves, so clicking is reliable.
    local slotOf = {} -- bid -> slot
    local function assignSlot(bid)
        if slotOf[bid] then
            return slotOf[bid]
        end
        local used = {}
        for _, s in pairs(slotOf) do
            used[s] = true
        end
        for s = 1, MAX_CARDS do
            if not used[s] then
                slotOf[bid] = s
                return s
            end
        end
        return nil -- strip full; this foe waits for a slot to free
    end

    local function makeCard(bid)
        -- badgeSide="right": enemies live on the LEFT rail, so their debuff badges grow RIGHT toward
        -- screen centre instead of off-screen-left (Jason: the taunt badge went the wrong way).
        local card = HudCard.createCard(listFrame, { name = "Enemy_" .. bid, badgeSide = "right" })
        -- Enemy ARCHETYPE chip — the SAME PetBadge ringed disc the pet cards use (role symbol on a
        -- neutral disc + element ring), so foes read tank/melee/ranged/support at a glance just like
        -- pets. Standardized: no more ringless flat badge. Level moves into the name (threat-coloured).
        card.roleChip.BackgroundTransparency = 1
        card.roleGlyph.Visible = false
        -- Click an enemy card to direct the squad to focus it (same assist-target as a world click).
        card.frame.MouseButton1Click:Connect(function()
            Signals.Combat_SetAssist:FireServer({ targetId = bid })
        end)
        return card
    end

    -- COLLAPSE (Jason): as the enemy list grows DOWN into the bottom-left, money disappears first,
    -- then the menu buttons — freeing their space for the fight; both come back as the list shrinks up.
    -- It's SPATIAL (not an "in combat" flag): a lone off-screen support enemy = short list = money
    -- stays visible; a 20-enemy pull = list reaches the bottom = money + menus yield. A hysteresis
    -- margin stops flicker at the boundary. Refs resolved lazily (they persist once found).
    local moneyStack, menuPane
    local function collapseForList()
        if not (moneyStack and moneyStack.Parent) then
            for _, sg in ipairs(localPlayer.PlayerGui:GetChildren()) do
                local f = sg:FindFirstChild("CurrencyStack", true)
                if f then
                    moneyStack = f
                    break
                end
            end
        end
        if not (menuPane and menuPane.Parent) then
            local base = localPlayer.PlayerGui:FindFirstChild("ProfessionalBaseUI")
            local mc = base and base:FindFirstChild("MainContainer")
            menuPane = mc and mc:FindFirstChild("menu_buttons_pane")
        end
        local listBottom = root.AbsolutePosition.Y + root.AbsoluteSize.Y
        local function toggle(obj)
            if not obj then
                return
            end
            local top = obj.AbsolutePosition.Y
            if obj.Visible and listBottom > top then
                obj.Visible = false -- the list reached it → yield the space
            elseif (not obj.Visible) and listBottom < top - 24 then
                obj.Visible = true -- list shrank back (with margin so it doesn't flicker)
            end
        end
        toggle(moneyStack) -- money first (it's higher / bottom-left, above the menu buttons)
        toggle(menuPane) -- then the menu buttons if the list keeps growing
    end

    local accum = 0
    RunService.RenderStepped:Connect(function(dt)
        accum += dt
        if accum < 0.2 then
            return
        end
        accum = 0

        local list = engagedEnemies(os.clock())
        local focusBid = indirectTargetBid()
        -- The player's directed FOCUS (assist target) — set server-side when you click an enemy card
        -- (Combat_SetAssist), replicated back as this attribute. Drives the blue card + world select.
        local assistBid = localPlayer:GetAttribute("CombatAssistTarget")
        local assistModel = nil

        -- Free the slots of foes that have left so the nearest waiting foe can reuse them.
        local liveSet = {}
        for _, e in ipairs(list) do
            liveSet[e.bid] = true
        end
        for bid in pairs(slotOf) do
            if not liveSet[bid] then
                slotOf[bid] = nil
            end
        end

        -- Walk nearest-first ONLY to decide which foes claim freed slots; a foe that already has a
        -- slot keeps it (no re-sort), so the visual order is stable even as distances change.
        local present = {}
        local shown = 0
        for _, e in ipairs(list) do
            local slot = slotOf[e.bid] or assignSlot(e.bid)
            if slot then -- nil = strip full; this foe waits for a slot to free
                shown += 1
                present[e.bid] = true
                local card = cards[e.bid]
                if not card then
                    card = makeCard(e.bid)
                    cards[e.bid] = card
                end
                local m = e.model
                card.frame.LayoutOrder = slot
                local display =
                    tostring(m:GetAttribute("DisplayName") or m:GetAttribute("EnemyId") or "Enemy")
                local lvl = tonumber(m:GetAttribute("Level"))
                card.name.Text = lvl and (display .. "  (" .. lvl .. ")") or display
                card.name.TextColor3 = threatColor(lvl)
                -- archetype chip via the shared PetBadge (role symbol + ring), neutral disc colour
                PetBadge.apply(
                    card.roleIcon,
                    card.roleRing,
                    "neutral",
                    m:GetAttribute("Role") or "melee"
                )
                local hp = m:GetAttribute("HP") or 0
                local maxHp = math.max(1, m:GetAttribute("MaxHP") or 1)
                local frac = math.clamp(hp / maxHp, 0, 1)
                card.fill.Size = UDim2.fromScale(frac, 1)
                card.fill.BackgroundColor3 = HudCard.healthColor(frac)
                card.note.Text = ""
                -- Highlight precedence: your DIRECTED focus (assist target = you clicked it) wears the
                -- blue SELECT border (matches the pet-selection convention) + lights in the world; else
                -- the indirect target (the enemy your SELECTED pet is hitting) wears the amber border.
                local mode = (assistBid and assistBid ~= 0 and e.bid == assistBid and "select")
                    or (e.bid == focusBid and "target")
                    or nil
                HudCard.applyHighlight(card, mode)
                if assistBid and assistBid ~= 0 and e.bid == assistBid then
                    assistModel = m
                end
                -- Buff/debuff badges off the enemy's attributes — shared StatusBadges engine, growing
                -- leftward from the card's inner edge (a healed foe lights HEAL, a debuffed foe HEX).
                StatusBadges.update(
                    card,
                    StatusBadges.resolveEffects(ENEMY_EFFECTS, { enemy = m }, os.time()),
                    BLINK_LEAD
                )
            end
        end
        -- World glow on the directed focus enemy (off when nothing's selected / it's gone).
        assistHighlight.Adornee = assistModel
        assistHighlight.Enabled = assistModel ~= nil
        -- Shrink the strip uniformly once the pull exceeds DENSITY_FULL, so it stays bounded.
        densityScale.Scale = math.clamp(DENSITY_FULL / math.max(1, shown), DENSITY_MIN, 1)
        collapseForList() -- money → menus yield space as the list grows down into them (restore on shrink)
        for bid, card in pairs(cards) do
            if not present[bid] then
                card.frame:Destroy()
                cards[bid] = nil
            end
        end
    end)

    -- Expiry blink: every frame (not the 0.2s reconcile) for a smooth flash — same engine as SquadHud.
    RunService.RenderStepped:Connect(function()
        StatusBadges.applyBlink(cards, BLINK_PERIOD)
    end)
end

return EnemyHud
