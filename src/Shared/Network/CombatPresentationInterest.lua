-- Pure audience policy. Runtime resolves Instances to these facts once per published record.
local CombatPresentationInterest = {}
CombatPresentationInterest.__index = CombatPresentationInterest

function CombatPresentationInterest.new(config)
    return setmetatable({ _config = config, _fights = {} }, CombatPresentationInterest)
end

function CombatPresentationInterest:observe(facts, now)
    if not facts.fight then
        return
    end
    local members = self._fights[facts.fight]
    if not members then
        members = {}
        self._fights[facts.fight] = members
    end
    for userId in pairs(facts.participants) do
        members[userId] = now + self._config.participation_grace_seconds
    end
end

function CombatPresentationInterest:allows(channel, facts, viewer, now)
    if channel ~= "Combat_Result" then
        return facts.direct[viewer.userId] == true
            or (viewer.distance ~= nil and viewer.distance <= self._config.animation_radius)
    end
    if facts.direct[viewer.userId] or facts.owners[viewer.userId] then
        return true
    end
    local members = facts.fight and self._fights[facts.fight]
    return members ~= nil and (members[viewer.userId] or 0) > now
end

function CombatPresentationInterest:prune(now, removedUserId)
    for fight, members in pairs(self._fights) do
        for userId, expires in pairs(members) do
            if userId == removedUserId or expires <= now then
                members[userId] = nil
            end
        end
        if next(members) == nil then
            self._fights[fight] = nil
        end
    end
end

return CombatPresentationInterest
