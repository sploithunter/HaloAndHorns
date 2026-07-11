--[[
    BaddieSpawnerService — proximity-triggered enemy waves at map-authored spawner parts.

    Jason placed parts named BaddieSpawner* (Lava + Desert) in the map: walk within
    `radius` studs and a wave spawns at the part (picked from the weighted `waves`
    table in configs/enemies.lua `spawners`), then THAT spawner cools down for
    `cooldown` seconds. Gives players a taste of combat before choosing a direction
    on the Heaven/Hell tree. Enemies use the normal EnemyService chase/aggro/loot
    path, credited to the triggering player. No bosses by design.

    Spawner parts are found by NAME PREFIX anywhere under Workspace at Start (re-scan
    on a slow timer so newly synced map edits are picked up without a restart).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PackScale = require(ReplicatedStorage.Shared.Game.PackScale)

local BaddieSpawnerService = {}
BaddieSpawnerService.__index = BaddieSpawnerService

function BaddieSpawnerService.new()
    return setmetatable({}, BaddieSpawnerService)
end

function BaddieSpawnerService:Init()
    self._logger = self._modules.Logger
    self._enemyService = self._modules.EnemyService
    local configLoader = self._modules.ConfigLoader
    local ok, cfg = pcall(function()
        return configLoader:LoadConfig("enemies")
    end)
    self._config = (ok and cfg and cfg.spawners) or nil
    self._enemyDefs = (ok and cfg and cfg.enemies) or {} -- onramp melee pick reads defs
    self._spawners = {} -- part -> { cooldownUntil }
end

function BaddieSpawnerService:_scan()
    local prefix = self._config.part_prefix or "BaddieSpawner"
    for _, inst in ipairs(Workspace:GetDescendants()) do
        if inst:IsA("BasePart") and inst.Name:sub(1, #prefix) == prefix then
            if not self._spawners[inst] then
                self._spawners[inst] = { cooldownUntil = 0, alive = {} }
                self._logger:Info("Baddie spawner armed", { part = inst.Name })
            end
        end
    end
end

-- Arm any newly present spawner parts NOW — mission instances stamp spawners
-- mid-session and shouldn't wait out the slow 15s rescan timer.
function BaddieSpawnerService:Rescan()
    if self._config then
        self:_scan()
    end
end

-- The faction a spawner draws from, keyed off its name SUFFIX (after part_prefix). The map has
-- BaddieSpawnerLava + BaddieSpawnerDesert; zone_faction maps "Lava" -> "lava", and everything else
-- falls back to default_faction. So a lava-zone spawner only rolls lava packs, never Earth bears.
function BaddieSpawnerService:_factionFor(part)
    local prefix = self._config.part_prefix or "BaddieSpawner"
    local suffix = part.Name:sub(#prefix + 1)
    local map = self._config.zone_faction or {}
    return map[suffix] or self._config.default_faction or "earth"
end

-- Weighted pick among the waves of the given faction. A wave with no `faction` counts as the
-- default faction (earth), so untagged legacy waves still resolve.
function BaddieSpawnerService:_pickWave(rng, faction)
    local waves = self._config.waves or {}
    local default = self._config.default_faction or "earth"
    local pool = {}
    local total = 0
    for _, w in ipairs(waves) do
        if (w.faction or default) == faction then
            local weight = tonumber(w.weight) or 0
            if weight > 0 then
                pool[#pool + 1] = w
                total += weight
            end
        end
    end
    if total <= 0 then
        return nil
    end
    local roll = rng:NextNumber() * total
    for _, w in ipairs(pool) do
        roll -= (tonumber(w.weight) or 0)
        if roll <= 0 then
            return w
        end
    end
    return pool[#pool]
end

-- configs/teaming.lua, lazily (safe default = no scaling).
function BaddieSpawnerService:_teamingConfig()
    if not self._teaming then
        local ok, cfg = pcall(function()
            return require(ReplicatedStorage.Configs:WaitForChild("teaming"))
        end)
        self._teaming = (ok and cfg) or { pack = {} }
    end
    return self._teaming
end

-- How many of the triggering player's TEAM are engaged here: the player plus any teammate
-- whose character stands within pack.engaged_radius of the spawn point. Unteamed = 1.
function BaddieSpawnerService:_engagedTeamCount(player, position)
    local members = player:GetAttribute("TeamMembers")
    if type(members) ~= "string" or members == "" then
        return 1
    end
    local radius = tonumber(self:_teamingConfig().pack.engaged_radius) or 60
    local engaged = 1
    for name in members:gmatch("[^,]+") do
        if name ~= player.Name then
            local mate = Players:FindFirstChild(name)
            local hrp = mate
                and mate.Character
                and mate.Character:FindFirstChild("HumanoidRootPart")
            if hrp and (hrp.Position - position).Magnitude <= radius then
                engaged += 1
            end
        end
    end
    return engaged
end

function BaddieSpawnerService:_trigger(part, player, rng)
    local wave = self:_pickWave(rng, self:_factionFor(part))
    if not wave then
        return
    end
    local enemySvc = self._enemyService
    if not enemySvc then
        return
    end
    local scatter = tonumber(self._config.scatter) or 8
    local state = self._spawners[part]
    -- PACK SCALING (docs/TEAMING.md): waves grow with the ENGAGED team — the triggering
    -- player's teammates within pack.engaged_radius of the spawner. Unit counts AND the
    -- alive cap scale together (else the cap defeats the pack). Config: configs/teaming.lua.
    local engaged = self:_engagedTeamCount(player, part.Position)
    local teamingCfg = self:_teamingConfig()
    local cap = PackScale.count(tonumber(self._config.max_alive) or 6, engaged, nil, teamingCfg)
    -- COMBAT ONRAMP CAVE (Jason: "open up combat immediately at the caves...
    -- only ONE enemy ever spawns from that cave at level one — the odds of
    -- being defeated are pretty low"): a sub-onramp player triggers a SOLO
    -- wave — one unit of the wave's first entry, spawned UNGATED so it may
    -- engage its sub-threshold triggerer (enemy level already follows the
    -- spawning player's combat level, so a level-1 player meets a level-1
    -- creature). Ambient rules everywhere else are unchanged.
    local onramp = false
    do
        local okCfg, combat = pcall(function()
            return require(
                game:GetService("ReplicatedStorage"):WaitForChild("Configs"):WaitForChild("combat")
            )
        end)
        local minEngage = (
            okCfg
            and combat.engagement
            and tonumber(combat.engagement.min_engage_level)
        ) or 5
        onramp = (tonumber(player:GetAttribute("Level")) or 1) < minEngage
    end
    if onramp then
        -- CATCHABLE PUSHOVER ONLY (Jason's fresh-save walkthrough: a kiting
        -- blaster spawned and the starter bunny+dog "could not catch up to
        -- it" — both died). The First Fight unit must be MELEE trash: scan
        -- this faction's waves for the first unit whose def has no
        -- attack_range (melee closes to bite range) and trash_mob tier.
        local pick, pickDef = nil, nil
        local faction = self:_factionFor(part)
        for _, w in ipairs(self._config.waves or {}) do
            if (w.faction or "earth") == faction then
                for _, unit in ipairs(w.units or {}) do
                    local def = self._enemyDefs[unit.enemy]
                    if def and def.attack_range == nil and def.tier == "trash_mob" then
                        -- weakest melee trash wins (lowest hp)
                        if
                            not pickDef
                            or (tonumber(def.hp) or math.huge)
                                < (tonumber(pickDef.hp) or math.huge)
                        then
                            pick, pickDef = unit.enemy, def
                        end
                    end
                end
            end
        end
        if not pick then
            pick = wave.units and wave.units[1] and wave.units[1].enemy
            self._logger:Warn("onramp cave: no melee trash unit in faction — falling back", {
                faction = faction,
                fallback = tostring(pick),
            })
        end
        if not pick then
            return
        end
        wave = { units = { { enemy = pick } } }
        cap = 1
    end
    for _, unit in ipairs(wave.units or {}) do
        for _ = 1, (onramp and 1 or PackScale.count(unit.count, engaged, nil, teamingCfg)) do
            if #state.alive >= cap then
                break -- never bury the player / stockpile for the next one
            end
            local offset = Vector3.new(
                (rng:NextNumber() * 2 - 1) * scatter,
                3,
                (rng:NextNumber() * 2 - 1) * scatter
            )
            pcall(function()
                -- FIRST FIGHT NERF: the onramp creature spawns from a scaled
                -- def clone (combat.engagement.onramp hp/dmg mults) — dies
                -- fast, barely scratches (Jason: a stock trash mob wiped the
                -- starter squad; "no possible way a bunny can beat this")
                local defOverride = nil
                if onramp then
                    local base = self._enemyDefs[unit.enemy]
                    if base then
                        local okCfg2, combat2 = pcall(function()
                            return require(
                                game:GetService("ReplicatedStorage")
                                    :WaitForChild("Configs")
                                    :WaitForChild("combat")
                            )
                        end)
                        local knobs = (okCfg2 and combat2.engagement and combat2.engagement.onramp)
                            or {}
                        defOverride = table.clone(base)
                        defOverride.hp = math.max(
                            50,
                            math.floor(
                                (tonumber(base.hp) or 500) * (tonumber(knobs.hp_mult) or 0.25)
                            )
                        )
                        if type(base.attack) == "table" then
                            defOverride.attack = table.clone(base.attack)
                            defOverride.attack.damage = math.max(
                                1,
                                math.floor(
                                    (tonumber(base.attack.damage) or 5)
                                        * (tonumber(knobs.dmg_mult) or 0.2)
                                )
                            )
                        end
                    end
                end
                local r = enemySvc:SpawnEnemy(player, unit.enemy, {
                    position = part.Position + offset,
                    home = part.Position, -- loiter anchor
                    ungated = onramp, -- the First Fight may engage a sub-threshold player
                    def = defOverride, -- nil outside the onramp = stock def
                })
                if r and r.ok and r.model then
                    table.insert(state.alive, r.model)
                end
            end)
        end
    end
    self._logger:Info("Baddie wave spawned", {
        spawner = part.Name,
        player = player.Name,
        units = #(wave.units or {}),
    })
end

-- True if this spawner part lives inside a realm map folder (Maps/Heaven_N or Maps/Hell_N). Those
-- caves are driven by the EnemyService roaming patrol, not this homeworld proximity-wave system.
function BaddieSpawnerService:_isRealmCave(part)
    local node = part.Parent
    while node and node ~= game do
        local name = node.Name
        if type(name) == "string" and (name:match("^Heaven_%d") or name:match("^Hell_%d")) then
            return true
        end
        node = node.Parent
    end
    return false
end

function BaddieSpawnerService:Start()
    if not self._config then
        self._logger:Warn("BaddieSpawnerService: no spawners config; idle")
        return
    end
    local radius = tonumber(self._config.radius) or 50
    local cd = self._config.cooldown
    local cdMin = (type(cd) == "table" and tonumber(cd.min)) or tonumber(cd) or 60
    local cdMax = (type(cd) == "table" and tonumber(cd.max)) or cdMin
    local cap = tonumber(self._config.max_alive) or 6
    -- onramp threshold (combat.engagement.min_engage_level): sub-threshold
    -- players get the FIRST-FIGHT cadence — no 30-120s ambient roll
    local minEngage = 5
    pcall(function()
        local combat = require(
            game:GetService("ReplicatedStorage"):WaitForChild("Configs"):WaitForChild("combat")
        )
        minEngage = tonumber(combat.engagement and combat.engagement.min_engage_level) or 5
    end)
    local rng = Random.new()
    task.spawn(function()
        local rescanAt = 0
        while true do
            local now = os.clock()
            if now >= rescanAt then
                self:_scan()
                rescanAt = now + 15 -- pick up newly synced map parts
            end
            for part, state in pairs(self._spawners) do
                -- prune dead/cleaned baddies from the spawner's alive list
                for i = #state.alive, 1, -1 do
                    local m = state.alive[i]
                    if not m.Parent then
                        table.remove(state.alive, i)
                    end
                end
                if not part.Parent then
                    self._spawners[part] = nil
                elseif self:_isRealmCave(part) then
                    -- REALM CAVES belong to the roaming patrol (EnemyService), which fields
                    -- realm-appropriate enemies (heaven enemies in heaven, hell in hell). The homeworld
                    -- proximity-wave system stays OUT of realms so it never spawns neutral earth packs
                    -- (raging_bear etc.) in heaven/hell (Jason: "in heaven only spawn heaven enemies").
                elseif now >= state.cooldownUntil and #state.alive < cap then
                    for _, player in ipairs(Players:GetPlayers()) do
                        local hrp = player.Character
                            and player.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - part.Position).Magnitude <= radius then
                            -- FIRST FIGHT cadence (Jason: "spawn the neutered
                            -- enemies ENDLESSLY until I defeat one"): a
                            -- sub-onramp player near the cave restocks on a
                            -- 3s beat — the ambient 30-120s roll is for the
                            -- real world, not the tutorial gate
                            local sub = (tonumber(player:GetAttribute("Level")) or 1) < minEngage
                            state.cooldownUntil = now + (sub and 3 or rng:NextNumber(cdMin, cdMax))
                            self:_trigger(part, player, rng)
                            break
                        end
                    end
                end
            end
            task.wait(0.5)
        end
    end)
end

return BaddieSpawnerService
