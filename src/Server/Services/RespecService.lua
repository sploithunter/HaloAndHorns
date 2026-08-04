--[[
    Full build respec.

    The player's exact Experience is preserved. ClaimedLevel is rewound to 1, while the prior
    claimed level becomes the replay boundary. The ordinary Ascension Altar then rebuilds every
    historical origin/power/slot choice in order. Replayed levels pay no rewards and do not count
    as newly gained levels. Installed enhancements are returned intact before the build is cleared.
]]

local RespecService = {}
RespecService.__index = RespecService

local function deepCopy(value, seen)
    if type(value) ~= "table" then
        return value
    end
    seen = seen or {}
    if seen[value] then
        return seen[value]
    end
    local copy = {}
    seen[value] = copy
    for key, child in pairs(value) do
        copy[deepCopy(key, seen)] = deepCopy(child, seen)
    end
    return copy
end

function RespecService:Init()
    self._logger = self._modules and self._modules.Logger
    self._dataService = self._modules and self._modules.DataService
    self._archetypeService = self._modules and self._modules.ArchetypeService
    self._enhancementService = self._modules and self._modules.EnhancementService
    self._progressionService = self._modules and self._modules.PlayerProgressionService
    self._powerService = self._modules and self._modules.PowerService
    self._inventoryService = self._modules and self._modules.InventoryService
end

function RespecService:GetState(player)
    local data = self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded" }
    end
    local replay = data.RespecReplay
    return {
        ok = true,
        active = type(replay) == "table" and replay.active == true,
        targetClaimedLevel = type(replay) == "table" and replay.targetClaimedLevel or nil,
        experience = type(replay) == "table" and replay.experience or nil,
    }
end

function RespecService:Begin(player)
    local data = self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded" }
    end
    if type(data.RespecReplay) == "table" and data.RespecReplay.active == true then
        return { ok = false, reason = "already_respeccing", state = self:GetState(player) }
    end

    local target = self._progressionService:GetClaimedLevel(player)
    if target <= 1 then
        return { ok = false, reason = "nothing_to_respec" }
    end
    local experience = self._progressionService:GetExperience(player)
    local refund = self._enhancementService:PrepareRespecRefund(player)
    if not refund.ok then
        return refund
    end

    local before = {
        archetype = data.Archetype,
        powers = deepCopy(data.Powers),
        slots = deepCopy(data.Slots),
        hotbar = deepCopy(data.Hotbar),
        replay = deepCopy(data.RespecReplay),
        claimedLevel = self._progressionService:GetClaimedLevel(player),
    }

    local ok, err = pcall(function()
        data.RespecReplay = {
            active = true,
            targetClaimedLevel = target,
            experience = experience,
            startedAt = os.time(),
            enhancementsReturned = refund.returned,
        }
        local reset = self._archetypeService:Respec(player, nil, { deferSave = true })
        assert(reset and reset.ok, reset and reset.reason or "build_reset_failed")
        assert(self._dataService:SetStat(player, "ClaimedLevel", 1), "claim_reset_failed")
        self._progressionService:RefreshPublishedState(player)
        if self._powerService and self._powerService.ReapplyPassives then
            self._powerService:ReapplyPassives(player)
        end
        if self._inventoryService and self._inventoryService.RebuildPetProjections then
            self._inventoryService:RebuildPetProjections(player)
        end
        assert(self._enhancementService:CommitRespecRefund(refund), "refund_commit_failed")
        self._dataService:RequestSave(player, "full_respec_begin", { critical = true })
    end)

    if not ok then
        data.Archetype = before.archetype
        data.Powers = before.powers
        data.Slots = before.slots
        data.Hotbar = before.hotbar
        data.RespecReplay = before.replay
        self._dataService:SetStat(player, "ClaimedLevel", before.claimedLevel)
        self._enhancementService:RollbackRespecRefund(refund)
        self._archetypeService:RefreshAttributes(player)
        self._progressionService:RefreshPublishedState(player)
        if self._powerService and self._powerService.ReapplyPassives then
            self._powerService:ReapplyPassives(player)
        end
        return { ok = false, reason = "respec_failed", detail = tostring(err) }
    end

    if self._logger then
        self._logger:Info("Full respec replay started", {
            player = player.Name,
            targetClaimedLevel = target,
            experience = experience,
            enhancementsReturned = refund.returned,
        })
    end
    return {
        ok = true,
        targetClaimedLevel = target,
        experience = experience,
        enhancementsReturned = refund.returned,
    }
end

return RespecService
