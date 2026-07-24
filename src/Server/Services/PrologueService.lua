--[[
    PrologueService — the playable cold open (docs/PROLOGUE.md, configs/prologue.lua).

    THIS SLICE: build the room and put the player in it. The beat sequencer, the tap moment,
    the captions and the reward land on top of this; getting a genuinely-new player standing
    in the mezzanine hall is the foundation everything else hangs off.

    ROOM: the graybox kit's `mezzanine_hall` — the same procedurally-generated large room the
    trials use (Jason's pick: "there is a procedurally generated large room that has a
    mezzanine; that's what we're going to spawn into"). Built ONCE per server, far below the
    playable world, and reused by every prologue rather than rebuilt per player.

    GATE: `data.Prologue`, written on START. Same one-time shape as StarterPetService's
    `data.StarterPet` — its absence IS the "new player" signal. Written before the sequence so
    a rage-quit three seconds in can't re-trigger it on rejoin; `completed` records whether
    they actually saw it through, for the funnel.

    PROFILE ISOLATION: the prologue grants nothing and spends nothing. Any reward lands AFTER
    the warp-out, in normal game state, so a crash mid-sequence can never half-pay anyone.
]]

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TileKitBuilder = require(ServerScriptService.Server.World.TileKitBuilder)
local GrayBoxKit = require(ReplicatedStorage.Shared.Worldgen.GrayBoxKit)
local BootReadiness = require(ReplicatedStorage.Shared.Boot.BootReadiness)

local PrologueService = {}
PrologueService.__index = PrologueService

local STREAM_WAIT = 8

function PrologueService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._dataService = self._modules and self._modules.DataService
    self._config = (self._configLoader and self._configLoader:LoadConfig("prologue"))
        or require(ReplicatedStorage.Configs:WaitForChild("prologue"))
    self._room = nil -- the built mezzanine hall, one per server
    self._active = {} -- player -> { startedAt }
    game:GetService("Workspace"):SetAttribute("PrologueServiceInit", true)
    self:_log("Info", "[PROLOGUE] Init", {
        enabled = self._config and self._config.enabled,
        hasDataService = self._dataService ~= nil,
        hasLogger = self._logger ~= nil,
    })
end

function PrologueService:_log(level, msg, data)
    if self._logger and self._logger[level] then
        self._logger[level](self._logger, msg, data)
        return
    end
    -- RAW FALLBACK. A silent _log is worse than none: the first live debug of this service
    -- produced no output at all and looked like "the code never ran", when the truth was
    -- simply that the injected Logger wasn't there. Never let a diagnostic depend on a
    -- dependency being wired.
    local parts = {}
    for k, v in pairs(data or {}) do
        parts[#parts + 1] = tostring(k) .. "=" .. tostring(v)
    end
    print(("[PROLOGUE][%s] %s %s"):format(level, msg, table.concat(parts, " ")))
end

-- ── The room ────────────────────────────────────────────────────────────────────────

-- Build (once) the mezzanine hall the prologue plays in. The kit builder emits EVERY tile as
-- a template folder, so we take the one we want and drop the rest — cheaper than a bespoke
-- room and guaranteed identical to what the trials generate.
function PrologueService:_ensureRoom()
    if self._room and self._room.Parent then
        return self._room
    end
    local cfg = self._config.room or {}
    local tileId = cfg.tile or "mezzanine_hall"

    local templates = ServerStorage:FindFirstChild("PrologueKit")
    if not templates then
        local ok, err = pcall(function()
            templates = TileKitBuilder.build(GrayBoxKit, ServerStorage)
        end)
        if not ok or not templates then
            self:_log("Error", "Prologue: kit build failed", { error = tostring(err) })
            return nil
        end
        templates.Name = "PrologueKit"
    end

    local proto = templates:FindFirstChild(tileId)
    if not proto then
        self:_log("Error", "Prologue: tile missing from kit", { tile = tileId })
        return nil
    end

    local room = proto:Clone()
    room.Name = "PrologueRoom"
    local o = cfg.origin or {}
    room:PivotTo(CFrame.new(tonumber(o.x) or 0, tonumber(o.y) or -8000, tonumber(o.z) or 0))
    room.Parent = Workspace
    self._room = room
    self:_log(
        "Info",
        "Prologue room built",
        { tile = tileId, pivot = tostring(room:GetPivot().Position) }
    )
    return room
end

-- Where the player stands when the curtain goes up: centre of the hall, on the floor.
function PrologueService:_stageCFrame(room)
    local pivot = room:GetPivot()
    -- The tile's own floor sits at the pivot plane (the worldgen floor-height fix); lift a
    -- little so the character settles onto it rather than through it.
    return pivot * CFrame.new(0, 4, 30) * CFrame.Angles(0, math.pi, 0)
end

-- ── Eligibility ─────────────────────────────────────────────────────────────────────

-- Has this player already had their prologue? Mirrors StarterPetService's data.StarterPet
-- gate: the record's ABSENCE is the "new player" signal.
function PrologueService:_alreadySeen(data)
    local rec = data and data.Prologue
    if type(rec) ~= "table" then
        return false
    end
    -- EXPLICIT REPLAY MARKER beats key deletion. Admin reset used to clear this by writing
    -- `data.Prologue = nil`, and the record kept coming back: a nil assignment is a DELETION,
    -- and deletions are exactly what merge-style persistence can silently drop, whereas a
    -- written value always survives. So the reset now writes { replay = true } and this reads
    -- it as "not seen" — same outcome, but it round-trips through the save layer.
    if rec.replay == true then
        return false
    end
    return rec.seenAt ~= nil
end

function PrologueService:IsEligible(player)
    if self._config.enabled == false then
        return false, "disabled"
    end
    local data = self._dataService and self._dataService:GetData(player)
    if not data then
        return false, "no_profile"
    end
    if self:_alreadySeen(data) then
        return false, "already_seen"
    end
    return true
end

-- ── Run ─────────────────────────────────────────────────────────────────────────────

-- Put `player` in the room. Returns ok, reason.
function PrologueService:Begin(player, opts)
    opts = opts or {}
    if not opts.force then
        local ok, reason = self:IsEligible(player)
        if not ok then
            return false, reason
        end
    end
    -- THE RACE (Jason: "sometimes my team is getting populated and sometimes it's not"):
    -- on the boot path Begin can outrun the models_ready milestone — the pet prototypes and
    -- the combat components AssetPreloadService stamps onto them (TargetID/TargetType/Power)
    -- don't exist yet, so the squads clone empty or inert and NOBODY fights. Await the
    -- milestone like every other consumer (boot doctrine: completion events, never timing).
    local modelsReady = BootReadiness.await("models_ready", 20)
    if not modelsReady then
        self:_log("Warn", "Prologue: models_ready never signalled — proceeding degraded")
    end

    local room = self:_ensureRoom()
    if not room then
        return false, "room_unavailable"
    end
    -- RE-ENTRY (replay while a run is active): quietly retire the previous run's encounter
    -- first, or its wave/ghosts stack on top of the new ones (live-caught: 30 enemies in the
    -- room — two waves) and its orphaned cut timer token-fails into a never-swept room.
    local prev = self._active[player]
    if prev then
        self._active[player] = nil
        if prev.charConn then
            prev.charConn:Disconnect()
        end
        self:_clearGhostSquad(player)
        self:_clearWave(prev.waveBounds)
    end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return false, "no_character"
    end

    -- Mark BEFORE the sequence: a player who quits three seconds in must not get it again.
    local data = self._dataService and self._dataService:GetData(player)
    if data and not opts.force then
        data.Prologue = { seenAt = os.time(), version = 1, completed = false }
        if self._dataService.RequestSave then
            self._dataService:RequestSave(player, "prologue_started", { critical = true })
        end
    end

    self:_sealDoors(room)
    local target = self:_stageCFrame(room)
    pcall(function()
        player:RequestStreamAroundAsync(target.Position, STREAM_WAIT)
    end)
    -- RE-RESOLVE after the stream yield: a BRAND-NEW profile's first join RESPAWNS the
    -- character after data creation (live-caught on a fresh alt: music + card played,
    -- Colorado summoned, but the player stood at Home while the wave fought the ghosts
    -- alone in the room below). The old abort ate the respawn as "left"; take whatever
    -- character exists now and warp THAT.
    character = player.Character or character
    local liveRoot = character and character:FindFirstChild("HumanoidRootPart")
    if not liveRoot then
        return false, "left_during_stream"
    end
    character:PivotTo(target)

    local rec = { startedAt = os.clock() }
    -- XP SNAPSHOT (Jason: "you're gonna have to wipe out XP when you go out of the trial —
    -- I've leveled up like three times in there"). The battle pays real combat XP; the
    -- preview must not. Restore the pre-prologue numbers at the cut.
    if self._dataService and self._dataService.GetStat then
        rec.xpSnapshot = tonumber(self._dataService:GetStat(player, "Experience")) or 0
        rec.claimSnapshot = tonumber(self._dataService:GetStat(player, "ClaimedLevel")) or 1
    end
    self._active[player] = rec
    player:SetAttribute("InPrologue", true)

    -- ANY respawn during the active window comes back to the stage (the fresh-profile
    -- first-join respawn can land AFTER the pivot above; a mid-battle death respawn must
    -- not strand the player at Home either). Token-guarded to this run.
    rec.charConn = player.CharacterAdded:Connect(function(newChar)
        task.defer(function()
            if self._active[player] ~= rec then
                return
            end
            local hrp = newChar:FindFirstChild("HumanoidRootPart")
                or newChar:WaitForChild("HumanoidRootPart", 5)
            if hrp and self._active[player] == rec then
                newChar:PivotTo(target)
            end
        end)
    end)
    -- ORDER IS THE FIX (Jason's screenshot: "Murder Crow Lv 1... spawned at my level"):
    -- the Creator summons FIRST so the alliance lift (EffectiveLevel 49) exists before the
    -- wave tunes itself — and so the enemies birth-aggro into a room that already holds
    -- both squads. The old call site (the watcher, after Begin returned) meant the boot
    -- path spawned a level-1 wave that never engaged; the replay path only worked because
    -- Colorado survived from the previous cycle.
    self:_stageCreator(player)
    self:_grantGhostSquad(player, target)
    rec.waveBounds = self:_spawnWave(player, room)

    -- THE CUT (Jason: "once the battle is over, it ends pretty quickly"): watch the wave —
    -- the moment it's wiped, VICTORY floats up and the warp follows after victory_hold.
    -- `duration` stays as the hard cap for a fight that drags. Token-checked so a manual
    -- Finish or a replay can't double-fire.
    local duration = tonumber(self._config.duration) or 8
    local hold = tonumber(self._config.victory_hold) or 3
    task.spawn(function()
        local t0 = os.clock()
        local fought = false
        while self._active[player] == rec and player.Parent do
            local elapsed = os.clock() - t0
            local alive = self:_waveAlive(rec.waveBounds)
            fought = fought or alive > 0
            if fought and alive == 0 and elapsed >= 4 then
                player:SetAttribute("PrologueVictory", true)
                task.wait(hold)
                break
            end
            if elapsed >= duration then
                break
            end
            task.wait(0.5)
        end
        if self._active[player] == rec and player.Parent then
            self:Finish(player)
        end
    end)

    self:_log("Info", "Prologue begun", { player = player.Name, duration = duration })
    return true, { room = room:GetPivot().Position }
end

-- Land them in the real world. The beat sequence will call this at the cut; for now it's the
-- manual/administrative exit.
function PrologueService:Finish(player)
    local rec = self._active[player]
    self._active[player] = nil
    if rec and rec.charConn then
        rec.charConn:Disconnect()
    end
    self:_clearGhostSquad(player)
    self:_clearWave(rec and rec.waveBounds)
    -- Colorado leaves with the LAST player out — another player mid-prologue keeps him.
    if next(self._active) == nil then
        local npc = self._modules and self._modules.NpcPrincipalService
        if npc then
            pcall(function()
                npc:Despawn("Colorado the Creator")
            end)
        end
    end
    player:SetAttribute("InPrologue", nil)
    player:SetAttribute("PrologueVictory", nil)
    -- Wipe the preview's XP: put the snapshot back and republish the level attributes
    -- (earned level derives from Experience, so restoring the stat restores the ring).
    if rec and rec.xpSnapshot ~= nil and self._dataService and self._dataService.SetStat then
        self._dataService:SetStat(player, "Experience", rec.xpSnapshot)
        self._dataService:SetStat(player, "ClaimedLevel", rec.claimSnapshot or 1)
        local prog = self._modules and self._modules.PlayerProgressionService
        if prog and prog._publish then
            pcall(function()
                prog:_publish(player)
            end)
        end
    end
    local data = self._dataService and self._dataService:GetData(player)
    if data then
        -- WRITE + SAVE, unconditionally (live-caught: "I turned Studio off and back on and
        -- ended up in the fight scene again" — hadRecord=false at the reboot). Replay nils
        -- the record and an in-flight reset save can serialize that record-less snapshot;
        -- Finish was the only writer of completed=true and it NEVER SAVED, so a Studio kill
        -- lost the completion entirely. A fresh critical save at the cut is the durability
        -- point: the prologue is once-ever the moment the player lands.
        data.Prologue = {
            seenAt = (type(data.Prologue) == "table" and data.Prologue.seenAt) or os.time(),
            version = 1,
            completed = true,
        }
        if self._dataService.RequestSave then
            self._dataService:RequestSave(player, "prologue_completed", { critical = true })
        end
    end
    local spawn = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
    local character = player.Character
    if character and spawn then
        character:PivotTo(spawn.CFrame * CFrame.new(0, 5, 0))
    end
    self:_log("Info", "Prologue finished", {
        player = player.Name,
        seconds = rec and (os.clock() - rec.startedAt) or -1,
    })
    return true
end

-- THE PLAYER'S TEMPORARY SQUAD (Jason: "one of every dragon, plus a huge Ent for a tank").
-- Ghost models in the player's OWN folder — the client drive gives them the real formations
-- exactly like owned pets, and the SquadHud shows them. GhostPet-marked, so Finish can strip
-- them without touching anything the player actually owns.
function PrologueService:_grantGhostSquad(player, originCf)
    local npc = self._modules and self._modules.NpcPrincipalService
    local squad = self._config.player_squad
    if not npc or type(squad) ~= "table" or #squad == 0 then
        return
    end
    local root = Workspace:FindFirstChild("PlayerPets")
    local folder = root and root:FindFirstChild(player.Name)
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = player.Name
        folder.Parent = root or Workspace
    end
    local n = npc:SpawnGhostSquad(folder, squad, originCf)
    self:_log("Info", "Prologue ghost squad granted", { player = player.Name, pets = n })
end

-- THE HELL WAVE — trials-style pre-fill (Jason: "the trial spawn method is probably more
-- appropriate"): dormant (no birth aggro; perception engages as the squads land), persistent
-- (immune to idle-despawn at Y=-8000), penned by a room-rect movementLeash. Enemy levels
-- auto-tune to the player's alliance-lifted EffectiveLevel. Returns the despawn bounds.
function PrologueService:_spawnWave(player, room)
    local enemySvc = self._modules and self._modules.EnemyService
    local wave = self._config.wave
    if not enemySvc or type(wave) ~= "table" or type(wave.units) ~= "table" then
        return nil
    end
    local center = room:GetPivot().Position
    local leash = {
        shapes = { { kind = "box", cx = center.X, cz = center.Z, halfX = 66, halfZ = 66 } },
        inset = 4,
        recovery = center + Vector3.new(0, 3, 0),
    }
    -- EXPLICIT LEVEL: never trust attribute replication timing again — the wave fights at
    -- the alliance level (EffectiveLevel, just lifted by the summon above) with a hard 49
    -- fallback, passed straight into the def.
    local waveLevel = tonumber(player:GetAttribute("EffectiveLevel")) or 49
    local enemiesCfg
    pcall(function()
        enemiesCfg = self._configLoader and self._configLoader:LoadConfig("enemies")
    end)
    local ringR = tonumber(wave.ring_radius) or 32
    local scatter = tonumber(wave.scatter) or 12
    local total, idx = 0, 0
    for _, unit in ipairs(wave.units) do
        total += tonumber(unit.count) or 0
    end
    local spawned = 0
    for _, unit in ipairs(wave.units) do
        for _ = 1, tonumber(unit.count) or 0 do
            idx += 1
            local a = (idx - 1) / math.max(total, 1) * math.pi * 2
            local r = ringR + (idx * 37) % scatter
            local ok, res = pcall(function()
                local baseDef = enemiesCfg and enemiesCfg.enemies and enemiesCfg.enemies[unit.enemy]
                local defOverride
                if type(baseDef) == "table" then
                    defOverride = table.clone(baseDef)
                    defOverride.level = waveLevel
                end
                return enemySvc:SpawnEnemy(player, unit.enemy, {
                    def = defOverride,
                    position = center + Vector3.new(math.cos(a) * r, 3, math.sin(a) * r),
                    home = center,
                    movementLeash = leash,
                    persistent = true, -- defeat or teardown only
                    ungated = true, -- the real player is level 1 under the lift
                    -- NO dormant flag (Jason: "three or four second meandering where the
                    -- enemies are not attacking"): trials pre-fill dormant because the team
                    -- arrives later — here the player lands IN the midst, so birth aggro is
                    -- the point. The fight is already raging when the black screen lifts.
                })
            end)
            if ok and type(res) == "table" and res.ok then
                spawned += 1
            end
        end
    end
    self:_log("Info", "Prologue wave spawned", { player = player.Name, enemies = spawned })
    return {
        min = center - Vector3.new(80, 60, 80),
        max = center + Vector3.new(80, 60, 80),
    }
end

-- Living wave members inside the room bounds — the victory condition reads zero.
function PrologueService:_waveAlive(bounds)
    if not bounds then
        return 0
    end
    local game_ = Workspace:FindFirstChild("Game")
    local enemies = game_ and game_:FindFirstChild("Enemies")
    local alive = 0
    for _, m in ipairs(enemies and enemies:GetChildren() or {}) do
        if (m:GetAttribute("HP") or 0) > 0 then
            local ok, pivot = pcall(m.GetPivot, m)
            if ok then
                local p = pivot.Position
                if
                    p.X >= bounds.min.X
                    and p.X <= bounds.max.X
                    and p.Y >= bounds.min.Y
                    and p.Y <= bounds.max.Y
                    and p.Z >= bounds.min.Z
                    and p.Z <= bounds.max.Z
                then
                    alive += 1
                end
            end
        end
    end
    return alive
end

-- Tear the wave down — bounds-scoped so only the prologue room is swept.
function PrologueService:_clearWave(bounds)
    local enemySvc = self._modules and self._modules.EnemyService
    if not enemySvc or not bounds or not enemySvc.DespawnEnemiesInBounds then
        return
    end
    pcall(function()
        enemySvc:DespawnEnemiesInBounds(bounds.min, bounds.max)
    end)
end

-- Strip the temporary squad — ONLY GhostPet-marked models; owned pets are untouched.
function PrologueService:_clearGhostSquad(player)
    local root = Workspace:FindFirstChild("PlayerPets")
    local folder = root and root:FindFirstChild(player.Name)
    if not folder then
        return
    end
    for _, m in ipairs(folder:GetChildren()) do
        if m:GetAttribute("GhostPet") then
            m:Destroy()
        end
    end
end

-- SEAL THE DOORWAYS (Jason: "close these doors up so somebody doesn't run out and fall
-- to their death — we have that already in the spawned trail code"). The trials mate cap
-- tiles onto unused apertures; the prologue's lone room gets the same visual language
-- directly: a full-height plug slab (the cap's Backing look) over every door connector.
function PrologueService:_sealDoors(room)
    if room:GetAttribute("DoorsSealed") then
        return
    end
    room:SetAttribute("DoorsSealed", true)
    local sealed = 0
    for _, d in ipairs(room:GetDescendants()) do
        if d:IsA("BasePart") and d:GetAttribute("DoorClass") ~= nil then
            local doorH = d.Size.Y
            local slab = Instance.new("Part")
            slab.Name = "PrologueDoorSeal"
            -- generous overlap: wider than the aperture, floor to the mezzanine wall top
            slab.Size = Vector3.new(d.Size.X + 4, 64, 2)
            slab.CFrame = d.CFrame * CFrame.new(0, 32 - doorH / 2, 0)
            slab.Anchored = true
            slab.CanCollide = true
            slab.Color = Color3.fromRGB(30, 28, 32) -- the cap Backing colour
            slab.Material = Enum.Material.SmoothPlastic
            slab.Parent = room
            sealed += 1
        end
    end
    self:_log("Info", "Prologue doors sealed", { count = sealed })
end

-- Re-run the cold open RIGHT NOW (Jason: "just throw you into that spawned battle...
-- so we don't have to stop and start Studio"): clear the one-time record and Begin in
-- place. The ONE code path for the admin reset AND the replay bus command.
function PrologueService:Replay(player)
    local data = self._dataService and self._dataService:GetData(player)
    if data then
        data.Prologue = nil
    end
    player:SetAttribute("PrologueChecked", nil)
    -- CLOSE THE GATE for the whole throw-in (live-caught: the admin reset re-arms the
    -- starter chooser, and its Refresh pushed the offer in the gap BEFORE Begin set
    -- InPrologue — "I have the choose your first companion menu up in front of me and I
    -- can't get rid of it", floating over the battle). Gate nil = "unresolved": the
    -- offer-only deferral holds every push until the cut; the re-stamp after Begin
    -- mirrors the boot watcher, so the chooser arrives at warp-out exactly like a
    -- real first run.
    player:SetAttribute("PrologueGate", nil)
    player:SetAttribute("PrologueVictory", nil)
    local ok, info = self:Begin(player, { force = true })
    if ok then
        player:SetAttribute("PrologueGate", "eligible") -- InPrologue is already true here
    else
        player:SetAttribute("PrologueGate", "replay_failed_" .. tostring(info))
    end
    return ok, info
end

-- Put the Creator in the room beside the player, with his full apex squad. Deliberately
-- summoned AFTER the warp so he builds at the destination rather than walking there from
-- wherever the player used to be.
function PrologueService:_stageCreator(player)
    local npc = self._modules and self._modules.NpcPrincipalService
    if not npc then
        self:_log("Warn", "Prologue: NpcPrincipalService unavailable — no Creator")
        return
    end
    -- The prologue runs its own length, so the summon must not expire mid-sequence.
    local ok, info = npc:Summon(player, "creator", {
        duration = (tonumber(self._config.duration) or 8) + 30,
    })
    if not ok then
        self:_log("Warn", "Prologue: Creator summon failed", { reason = tostring(info) })
    end
end

function PrologueService:Start()
    Players.PlayerRemoving:Connect(function(player)
        -- A mid-prologue quit must not leak the encounter: the wave is persistent=true
        -- (never idle-despawns) and Colorado holds a rolling grace while InPrologue.
        local rec = self._active[player]
        self._active[player] = nil
        if rec then
            if rec.charConn then
                rec.charConn:Disconnect()
            end
            self:_clearWave(rec.waveBounds)
            if next(self._active) == nil then
                local npc = self._modules and self._modules.NpcPrincipalService
                if npc then
                    pcall(function()
                        npc:Despawn("Colorado the Creator")
                    end)
                end
            end
        end
    end)

    -- NEW PLAYERS ONLY, on their first character. Everything is gated inside Begin (the
    -- data.Prologue record), so a returning player falls straight through to normal spawn.
    local function watch(player)
        local function onCharacter()
            if self._active[player] or player:GetAttribute("PrologueChecked") then
                return
            end
            player:SetAttribute("PrologueChecked", true)
            -- Profile has to be resolvable before eligibility means anything; IsEligible
            -- returns no_profile until then, so retry briefly rather than guessing a delay.
            task.spawn(function()
                for _ = 1, 40 do
                    local data = self._dataService and self._dataService:GetData(player)
                    if data then
                        local eligible, why = self:IsEligible(player)
                        -- TRACE (Jason: "put some tracing information in there and make sure
                        -- everything is gated correctly"). One line that answers "why didn't
                        -- the prologue fire?" without a debugging session.
                        -- ATTRIBUTE TRACE: console prints proved unreadable across the
                        -- Studio server/inspector VM split, and a diagnostic you can't read
                        -- is not a diagnostic. Attributes always replicate.
                        -- ORDER MATTERS: for an ELIGIBLE player the gate attribute is stamped
                        -- AFTER Begin (below). The starter/tutorial gates read "PrologueGate
                        -- set + InPrologue nil" as all-clear, and stamping first opened
                        -- exactly that window (Jason: tutorial 1/10 + a breadcrumb to
                        -- nowhere rendered inside the mezzanine).
                        if not eligible then
                            player:SetAttribute("PrologueGate", tostring(why))
                        end
                        player:SetAttribute("PrologueHadRecord", type(data.Prologue) == "table")
                        self:_log("Info", "[PROLOGUE GATE] decision", {
                            player = player.Name,
                            eligible = eligible,
                            reason = eligible and "ok" or tostring(why),
                            hasPrologueRecord = type(data.Prologue) == "table",
                            enabled = self._config.enabled ~= false,
                        })
                        if eligible then
                            local ok, info = self:Begin(player)
                            player:SetAttribute("PrologueBegin", ok and "ok" or tostring(info))
                            -- stamped AFTER Begin: on success InPrologue is already true, so
                            -- downstream gates never see a clear window mid-warp
                            player:SetAttribute("PrologueGate", "eligible")
                            self:_log(ok and "Info" or "Warn", "[PROLOGUE GATE] begin", {
                                player = player.Name,
                                ok = ok,
                                detail = (not ok) and tostring(info) or nil,
                            })
                            -- Creator staging moved INSIDE Begin (before the wave spawns)
                        end
                        return
                    end
                    task.wait(0.25)
                end
                player:SetAttribute("PrologueGate", "profile_never_resolved")
                self:_log("Warn", "[PROLOGUE GATE] profile never resolved — skipped", {
                    player = player.Name,
                })
            end)
        end
        player.CharacterAdded:Connect(onCharacter)
        if player.Character then
            onCharacter() -- character already existed when we connected
        end
    end

    -- BOTH paths: PlayerAdded only fires for players who join AFTER this connection, and in
    -- Studio Play the local player is frequently already present by the time services start.
    -- Missing that is the difference between "the prologue is broken" and "it never ran".
    Players.PlayerAdded:Connect(watch)
    for _, player in ipairs(Players:GetPlayers()) do
        watch(player)
    end
end

return PrologueService
