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
    return type(rec) == "table" and rec.seenAt ~= nil
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
    local room = self:_ensureRoom()
    if not room then
        return false, "room_unavailable"
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

    local target = self:_stageCFrame(room)
    pcall(function()
        player:RequestStreamAroundAsync(target.Position, STREAM_WAIT)
    end)
    if not root.Parent then
        return false, "left_during_stream"
    end
    character:PivotTo(target)

    self._active[player] = { startedAt = os.clock() }
    player:SetAttribute("InPrologue", true)
    self:_log("Info", "Prologue begun", { player = player.Name })
    return true, { room = room:GetPivot().Position }
end

-- Land them in the real world. The beat sequence will call this at the cut; for now it's the
-- manual/administrative exit.
function PrologueService:Finish(player)
    local rec = self._active[player]
    self._active[player] = nil
    player:SetAttribute("InPrologue", nil)
    local data = self._dataService and self._dataService:GetData(player)
    if data and type(data.Prologue) == "table" then
        data.Prologue.completed = true
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
        self._active[player] = nil
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
                        player:SetAttribute(
                            "PrologueGate",
                            eligible and "eligible" or tostring(why)
                        )
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
                            self:_log(ok and "Info" or "Warn", "[PROLOGUE GATE] begin", {
                                player = player.Name,
                                ok = ok,
                                detail = (not ok) and tostring(info) or nil,
                            })
                            if ok then
                                self:_stageCreator(player)
                            end
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
