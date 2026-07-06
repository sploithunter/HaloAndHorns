--[[
    PartyService — Feature 18 (Multiplayer / Group Play).

    Session-scoped party membership (not persisted) + the group math (difficulty
    scaling, loot split, damage attribution) via the pure PartyMath core. Live
    cross-player support powers + party UI are [studio]; the math is bus-testable
    solo via party.simulate.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PartyMath = require(ReplicatedStorage.Shared.Game.PartyMath)

local PartyService = {}
PartyService.__index = PartyService

function PartyService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._config = self._configLoader:LoadConfig("party")
    local combat = self._configLoader:LoadConfig("combat")
    self._perExtra = (combat and combat.group_scaling and combat.group_scaling.per_extra_player)
        or 0.5
    self._parties = {} -- partyId -> { members = { [userId]=true }, lead = userId }
    self._playerParty = {} -- userId -> partyId
    self._invites = {} -- target userId -> { partyId, from = name, at = os.time() }
    self._nextId = 0
    Players.PlayerRemoving:Connect(function(player)
        self._invites[player.UserId] = nil
        self:Leave(player)
    end)
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
        return { ok = true, partyId = partyId }
    end
    if not PartyMath.canJoin(partySize(party), self._config.max_size) then
        return { ok = false, reason = "party_full" }
    end
    party.members[player.UserId] = true
    self._playerParty[player.UserId] = partyId
    return { ok = true, partyId = partyId, size = partySize(party) }
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
function PartyService:Invite(player, targetName)
    local target = Players:FindFirstChild(tostring(targetName))
    if not target or target == player then
        return { ok = false, reason = "target_not_found" }
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
    self._invites[target.UserId] = { partyId = id, from = player.Name, at = os.time() }
    target:SetAttribute("TeamInviteFrom", player.Name)
    return { ok = true, partyId = id }
end

function PartyService:Accept(player)
    local invite = self._invites[player.UserId]
    self._invites[player.UserId] = nil
    player:SetAttribute("TeamInviteFrom", nil)
    if not invite or (os.time() - invite.at) > 120 then
        return { ok = false, reason = "no_invite" }
    end
    local joined = self:Join(player, invite.partyId)
    if joined.ok then
        self:_publish(invite.partyId)
    end
    return joined
end

function PartyService:Decline(player)
    self._invites[player.UserId] = nil
    player:SetAttribute("TeamInviteFrom", nil)
    return { ok = true }
end

-- True when two players share a party — the server-side gate for cross-player support.
function PartyService:SameTeam(a, b)
    local idA = self._playerParty[a.UserId]
    return idA ~= nil and idA == self._playerParty[b.UserId]
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
