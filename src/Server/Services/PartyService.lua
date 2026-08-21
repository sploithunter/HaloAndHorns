--[[
    PartyService — Feature 18 (Multiplayer / Group Play).

    Session-scoped party membership (not persisted) + the group math (difficulty
    scaling, loot split, damage attribution) via the pure PartyMath core. Live
    cross-player support powers + party UI are [studio]; the math is bus-testable
    solo via party.simulate.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PartyMath = require(ReplicatedStorage.Shared.Game.PartyMath)
local ChallengeRun = require(ReplicatedStorage.Shared.Game.ChallengeRun)

local PartyService = {}
PartyService.__index = PartyService

function PartyService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._layerService = self._modules and self._modules.LayerService
    self._playerProgressionService = self._modules and self._modules.PlayerProgressionService
    self._chatAnnouncementService = self._modules and self._modules.ChatAnnouncementService
    self._zoneService = self._modules and self._modules.ZoneService
    self._config = self._configLoader:LoadConfig("party")
    local okChallenge, challenge = pcall(function()
        return self._configLoader:LoadConfig("challenge_runs")
    end)
    self._challengeConfig = (okChallenge and type(challenge) == "table") and challenge or nil
    local combat = self._configLoader:LoadConfig("combat")
    self._perExtra = (combat and combat.group_scaling and combat.group_scaling.per_extra_player)
        or 0.5
    self._parties = {} -- partyId -> { members = { [userId]=true }, lead = userId }
    self._playerParty = {} -- userId -> partyId
    self._invites = {} -- target userId -> invite record; at most one pending invite per target
    self._inviteSweepElapsed = 0
    self._nextId = 0
    Players.PlayerRemoving:Connect(function(player)
        -- A recipient leaving is still a terminal outcome for the requester; expire it now rather
        -- than recreating the old silent failure. The invite identity check keeps this race-safe
        -- with the heartbeat expiry sweep.
        local receivedInvite = self._invites[player.UserId]
        if receivedInvite then
            self:_expireInvite(player.UserId, receivedInvite)
        end

        -- Requests sent by the departing player need no requester-side outcome, but the recipient
        -- popup must disappear immediately.
        for targetUserId, invite in pairs(self._invites) do
            if invite.fromUserId == player.UserId then
                self._invites[targetUserId] = nil
                local target = Players:GetPlayerByUserId(targetUserId)
                if target and target:GetAttribute("TeamInviteFrom") == invite.from then
                    target:SetAttribute("TeamInviteFrom", nil)
                end
            end
        end
        self:Leave(player)
    end)
end

function PartyService:Start()
    -- One lightweight sweep serves every invitation and follows the same lifecycle pattern as
    -- TradeService. Avoid one scheduled task per request and keep expiry server-authoritative.
    self._inviteConnection = RunService.Heartbeat:Connect(function(deltaTime)
        self._inviteSweepElapsed += deltaTime
        if self._inviteSweepElapsed >= 0.5 then
            self._inviteSweepElapsed %= 0.5
            self:_expireInvites(os.clock())
        end
    end)
    local function watch(player)
        self:_watchPlayer(player)
    end
    Players.PlayerAdded:Connect(watch)
    for _, player in ipairs(Players:GetPlayers()) do
        watch(player)
    end
end

function PartyService:_watchPlayer(player)
    player:GetAttributeChangedSignal("GauntletMode"):Connect(function()
        if self:_inSoloChallenge(player) then
            self:_blockInvitesForRange(player)
        end
    end)
    if self:_inSoloChallenge(player) then
        self:_blockInvitesForRange(player)
    end
end

function PartyService:_inSoloChallenge(player)
    if not player then
        return false
    end
    local mode = player:GetAttribute("GauntletMode")
    local modes = self._challengeConfig and self._challengeConfig.modes
    if ChallengeRun.soloOnly(modes and modes[mode]) then
        return true
    end
    return mode == "range"
end

function PartyService:_privacyOf(player)
    return PartyMath.invitePrivacy(
        player and player:GetAttribute("TeamInvitePrivacy"),
        self._config
    )
end

function PartyService:_areFriends(a, b)
    if not (a and b) then
        return false
    end
    local ok, result = pcall(function()
        return a:IsFriendsWith(b.UserId)
    end)
    return ok and result == true
end

function PartyService:_blockInvitesForRange(player)
    local incoming = self._invites[player.UserId]
    if incoming then
        self._invites[player.UserId] = nil
        if player:GetAttribute("TeamInviteFrom") == incoming.from then
            player:SetAttribute("TeamInviteFrom", nil)
        end
        self:_notifyInviteOutcome(incoming, "in_range")
    end
    for targetUserId, invite in pairs(self._invites) do
        if invite.fromUserId == player.UserId then
            self._invites[targetUserId] = nil
            local target = Players:GetPlayerByUserId(targetUserId)
            if target and target:GetAttribute("TeamInviteFrom") == invite.from then
                target:SetAttribute("TeamInviteFrom", nil)
            end
        end
    end
end

function PartyService:SetInvitePrivacy(player, mode)
    local settings = self._modules and self._modules.SettingsService
    if settings and settings.SetTeamInvitePrivacy then
        local saved = settings:SetTeamInvitePrivacy(player, mode)
        if saved then
            return { ok = true, mode = self:_privacyOf(player) }
        end
    end
    local sanitized = PartyMath.invitePrivacy(mode, self._config)
    player:SetAttribute("TeamInvitePrivacy", sanitized)
    return { ok = true, mode = sanitized }
end

function PartyService:_partyOf(player)
    local id = self._playerParty[player.UserId]
    return id, id and self._parties[id]
end

local function partySize(party)
    local n = 0
    for _ in pairs(party.members) do
        n += 1
    end
    return n
end

function PartyService:GetState(player)
    local id, party = self:_partyOf(player)
    if not party then
        return { ok = true, partyId = nil, size = 1, members = { player.UserId } }
    end
    local members = {}
    for userId in pairs(party.members) do
        table.insert(members, userId)
    end
    return { ok = true, partyId = id, size = partySize(party), members = members }
end

function PartyService:Create(player)
    local existing = self:_partyOf(player)
    if existing then
        return { ok = true, partyId = existing }
    end
    self._nextId += 1
    local id = self._nextId
    self._parties[id] = { members = { [player.UserId] = true } }
    self._playerParty[player.UserId] = id
    return { ok = true, partyId = id }
end

-- Join a party (the cross-player invite/accept handshake is [studio]; this is the
-- server-authoritative join used by Accept).
function PartyService:Join(player, partyId)
    local party = self._parties[partyId]
    if not party then
        return { ok = false, reason = "party_not_found" }
    end
    if party.members[player.UserId] then
        return { ok = true, partyId = partyId, joined = false }
    end
    if not PartyMath.canJoin(partySize(party), self._config.max_size) then
        return { ok = false, reason = "party_full" }
    end
    party.members[player.UserId] = true
    self._playerParty[player.UserId] = partyId
    return { ok = true, partyId = partyId, size = partySize(party), joined = true }
end

function PartyService:Leave(player)
    local id, party = self:_partyOf(player)
    if party then
        party.members[player.UserId] = nil
        self._playerParty[player.UserId] = nil
        if partySize(party) == 0 then
            self._parties[id] = nil
        elseif party.lead == player.UserId then
            party.lead = next(party.members) -- promote any remaining member
        end
        player:SetAttribute("TeamId", nil)
        player:SetAttribute("TeamLead", nil)
        player:SetAttribute("TeamMembers", nil)
        if self._zoneService and self._zoneService.EndHallGuestVisit then
            self._zoneService:EndHallGuestVisit(player)
        end
        if self._parties[id] then
            self:_publish(id)
        end
    end
    return { ok = true }
end

-- Publish team membership as replicated PLAYER attributes so every client (HUD) renders the
-- roster without a remote round-trip: TeamId, TeamLead (name), TeamMembers (csv of names).
function PartyService:_publish(partyId)
    local party = self._parties[partyId]
    if not party then
        return
    end
    local names = {}
    for userId in pairs(party.members) do
        local p = Players:GetPlayerByUserId(userId)
        if p then
            names[#names + 1] = p.Name
        end
    end
    table.sort(names)
    local lead = party.lead and Players:GetPlayerByUserId(party.lead)
    local csv = table.concat(names, ",")
    for userId in pairs(party.members) do
        local p = Players:GetPlayerByUserId(userId)
        if p then
            p:SetAttribute("TeamId", partyId)
            p:SetAttribute("TeamLead", lead and lead.Name or p.Name)
            p:SetAttribute("TeamMembers", csv)
        end
    end
end

-- The invite/accept dance (docs/TEAMING.md). Invite stamps a replicated attribute on the
-- TARGET (TeamInviteFrom) so their client surfaces accept/decline; Accept consumes it.
function PartyService:_notifyInviteOutcome(invite, outcome)
    local requester = invite and Players:GetPlayerByUserId(invite.fromUserId)
    if not requester then
        return
    end
    requester:SetAttribute("TeamInviteOutcome", outcome)
    requester:SetAttribute("TeamInviteTarget", invite.targetName or "Player")
    requester:SetAttribute(
        "TeamInviteOutcomeSerial",
        (tonumber(requester:GetAttribute("TeamInviteOutcomeSerial")) or 0) + 1
    )
end

function PartyService:_expireInvite(targetUserId, invite)
    if self._invites[targetUserId] ~= invite then
        return false
    end
    self._invites[targetUserId] = nil
    local target = Players:GetPlayerByUserId(targetUserId)
    if target and target:GetAttribute("TeamInviteFrom") == invite.from then
        target:SetAttribute("TeamInviteFrom", nil)
    end
    self:_notifyInviteOutcome(invite, "timed_out")
    return true
end

function PartyService:_expireInvites(now)
    local timeout = tonumber(self._config.invite_timeout_seconds) or 30
    for targetUserId, invite in pairs(self._invites) do
        if PartyMath.inviteExpired(invite, now, timeout) then
            self:_expireInvite(targetUserId, invite)
        end
    end
end

function PartyService:Invite(player, targetName)
    local target = Players:FindFirstChild(tostring(targetName))
    if not target or target == player then
        return { ok = false, reason = "target_not_found" }
    end
    local allowed, reason = PartyMath.canSendInvite({
        fromInRange = self:_inSoloChallenge(player),
        targetInRange = self:_inSoloChallenge(target),
        targetPrivacy = self:_privacyOf(target),
        areFriends = self:_areFriends(player, target),
        cfg = self._config,
    })
    if not allowed then
        return { ok = false, reason = reason }
    end
    local id = select(1, self:_partyOf(player))
    if not id then
        id = self:Create(player).partyId
        self._parties[id].lead = player.UserId
        self:_publish(id)
    end
    if not PartyMath.canJoin(partySize(self._parties[id]), self._config.max_size) then
        return { ok = false, reason = "party_full" }
    end
    local existing = self._invites[target.UserId]
    local timeout = tonumber(self._config.invite_timeout_seconds) or 30
    if existing and not PartyMath.inviteExpired(existing, os.clock(), timeout) then
        return { ok = false, reason = "target_has_pending_invite" }
    elseif existing then
        self:_expireInvite(target.UserId, existing)
    end

    local invite = {
        partyId = id,
        from = player.Name,
        fromUserId = player.UserId,
        targetName = target.Name,
        at = os.clock(),
    }
    self._invites[target.UserId] = invite
    target:SetAttribute("TeamInviteFrom", player.Name)
    return { ok = true, partyId = id }
end

function PartyService:Accept(player)
    local invite = self._invites[player.UserId]
    if not invite then
        return { ok = false, reason = "no_invite" }
    end
    if
        PartyMath.inviteExpired(
            invite,
            os.clock(),
            tonumber(self._config.invite_timeout_seconds) or 30
        )
    then
        self:_expireInvite(player.UserId, invite)
        return { ok = false, reason = "invite_expired" }
    end
    local from = Players:GetPlayerByUserId(invite.fromUserId)
    local allowed, reason = PartyMath.canAcceptInvite({
        fromInRange = self:_inSoloChallenge(from),
        targetInRange = self:_inSoloChallenge(player),
    })
    if not allowed then
        return { ok = false, reason = reason }
    end
    self._invites[player.UserId] = nil
    player:SetAttribute("TeamInviteFrom", nil)
    local joined = self:Join(player, invite.partyId)
    if joined.ok then
        self:_publish(invite.partyId)
        local party = self._parties[invite.partyId]
        local lead = party and party.lead and Players:GetPlayerByUserId(party.lead)
        local progression = self._playerProgressionService
        if joined.joined and lead and progression and self._chatAnnouncementService then
            local earnedLevel = progression:GetEarnedLevel(player)
            local effectiveLevel = progression:GetEffectiveLevel(player)
            player:SetAttribute("EffectiveLevel", effectiveLevel)
            self._chatAnnouncementService:AnnounceSidekick(
                player,
                lead,
                earnedLevel,
                effectiveLevel
            )
        end
        -- Unfinished Hall player joining a teammate already in Crystal World / a
        -- realm: session guest visit only. Do not stamp Hall completion.
        if
            joined.joined
            and lead
            and self._zoneService
            and self._zoneService.BeginHallGuestVisit
            and not self._zoneService:HasEnteredCrystalWorld(player)
            and not self._zoneService:IsInHall(lead)
        then
            self._zoneService:BeginHallGuestVisit(player)
        end
    end
    return joined
end

function PartyService:Decline(player)
    local invite = self._invites[player.UserId]
    self._invites[player.UserId] = nil
    player:SetAttribute("TeamInviteFrom", nil)
    if invite then
        self:_notifyInviteOutcome(invite, "declined")
    end
    return { ok = true }
end

-- True when two players share a party — the server-side gate for cross-player support.
function PartyService:SameTeam(a, b)
    local idA = self._playerParty[a.UserId]
    return idA ~= nil and idA == self._playerParty[b.UserId]
end

-- TEAM FOLLOW across realm portals (Jason: follow must account for portal hops between realms):
-- the client walk-follow (TeamFollowController) can't cross a portal — realm worlds sit at ±Y
-- offsets — so when the followed teammate's CurrentLayer changes, the follower requests this
-- warp. Deliberately NOT a free teleport (teleport-to-teammate stays a future POWER, per
-- docs/TEAMING.md): it only fires on a LAYER mismatch and passes the same gates as touching the
-- portal — built geometry + requires_level against EffectiveLevel (the sidekick guest pass).
local FOLLOW_WARP_COOLDOWN = 4 -- seconds between accepted warps per player

function PartyService:FollowWarp(player, targetName)
    local target = type(targetName) == "string" and Players:FindFirstChild(targetName) or nil
    if not target or target == player then
        return { ok = false, reason = "no_target" }
    end
    if not self:SameTeam(player, target) then
        return { ok = false, reason = "not_teamed" }
    end
    self._followWarpAt = self._followWarpAt or {}
    local last = self._followWarpAt[player.UserId] or 0
    if os.clock() - last < FOLLOW_WARP_COOLDOWN then
        return { ok = false, reason = "cooldown" }
    end
    local layers = self._layerService
    if not layers then
        return { ok = false, reason = "service_unavailable" }
    end
    local myLayer = layers:GetCurrentLayer(player) or "base"
    local destLayer = layers:GetCurrentLayer(target) or "base"
    local zone = self._zoneService
    local unfinishedHall = zone
        and zone.HasEnteredCrystalWorld
        and not zone:HasEnteredCrystalWorld(player)
    if unfinishedHall then
        if destLayer ~= "base" then
            return { ok = false, reason = "hall_route_required" }
        end
        if zone.IsInHall and zone:IsInHall(target) then
            return { ok = false, reason = "same_layer" }
        end
        local visit = zone:BeginHallGuestVisit(player)
        if type(visit) == "table" and visit.ok == true then
            self._followWarpAt[player.UserId] = os.clock()
            return { ok = true, layer = "base", guest = true }
        end
        return visit or { ok = false, reason = "guest_place_failed" }
    end
    if myLayer == destLayer then
        return { ok = false, reason = "same_layer" }
    end
    if destLayer ~= "base" then
        -- never warp into unbuilt geometry (the void fall), same as RealmPortalService
        local folderName = destLayer:gsub("^%l", string.upper) -- heaven_1 -> Heaven_1
        local maps = workspace:FindFirstChild("Maps")
        if not (maps and maps:FindFirstChild(folderName)) then
            return { ok = false, reason = "no_geometry" }
        end
        local layersConfig = (self._configLoader and self._configLoader:LoadConfig("layers")) or {}
        local access = layersConfig.access and layersConfig.access[destLayer]
        local required = access and tonumber(access.requires_level)
        if required and required > 1 then
            local level = tonumber(player:GetAttribute("EffectiveLevel"))
                or tonumber(player:GetAttribute("Level"))
                or 1
            if level < required then
                return { ok = false, reason = "level_too_low", required = required }
            end
        end
    end
    -- force = the portal's bypass_access semantic (skip the soul/token economy; gates ran above)
    local res = layers:UseLayer(player, destLayer, { force = true })
    if type(res) == "table" and res.ok == false then
        return res
    end
    self._followWarpAt[player.UserId] = os.clock()
    if self._logger then
        self._logger:Info(
            "Follow warp",
            { player = player.Name, target = target.Name, layer = destLayer }
        )
    end
    return { ok = true, layer = destLayer }
end

-- Pure group math (difficulty scaling / loot split / attribution) for tests + UI.
function PartyService:Simulate(opts)
    opts = opts or {}
    return {
        ok = true,
        scaledHp = PartyMath.scaledHp(opts.baseHp or 0, opts.partySize or 1, self._perExtra),
        loot = PartyMath.splitLoot(opts.loot or {}, opts.partySize or 1),
        attribution = PartyMath.attribution(opts.contributions or {}),
    }
end

return PartyService
