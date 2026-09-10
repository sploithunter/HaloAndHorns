-- Recognition counters and receipts mutate the same session-owned profile without yielding.
local Progress = {}

function Progress.apply(data, cfg, kind, receipt, wave, provenance)
    if type(receipt) ~= "string" or receipt == "" then
        return nil
    end
    if kind ~= "boss" and kind ~= "wave" then
        return nil
    end
    if kind == "wave" and (type(wave) ~= "number" or wave < 1 or wave % 1 ~= 0) then
        return nil
    end
    data.GameData = data.GameData or {}
    local state = data.GameData.BraggProgress or { receipts = {}, online = {}, offline = {} }
    data.GameData.BraggProgress = state
    for _, id in ipairs(state.receipts) do
        if id == receipt then
            return nil
        end
    end
    data.Stats = data.Stats or {}
    data.Stats.Counters = data.Stats.Counters or {}
    local counters, changes = data.Stats.Counters, {}
    local function set(id, value)
        local old = counters[id] or 0
        counters[id] = value
        changes[#changes + 1] = { id = id, old = old, value = value }
    end
    if kind == "boss" then
        set(cfg.boss_counter, (counters[cfg.boss_counter] or 0) + 1)
    else
        set(cfg.total_counter, (counters[cfg.total_counter] or 0) + 1)
        set(cfg.highest_counter, math.max(counters[cfg.highest_counter] or 0, wave))
    end
    local source = provenance == "offline" and state.offline or state.online
    source[kind] = (source[kind] or 0) + 1
    table.insert(state.receipts, receipt)
    if #state.receipts > cfg.receipt_limit then
        table.remove(state.receipts, 1)
    end
    return changes
end

function Progress.record(dataService, statsService, player, kind, receipt, wave)
    local cfg = require(game.ReplicatedStorage.Configs.leaderboards).bragg_tracking
    if
        not cfg.enabled or (game:GetService("RunService"):IsStudio() and not cfg.studio_tracking)
    then
        return false
    end
    if not player or not player.Parent or player.UserId <= 0 then
        return false
    end
    local data = dataService and dataService:GetData(player)
    if not data then
        return false
    end
    local changes = Progress.apply(
        data,
        cfg,
        kind,
        receipt,
        wave,
        type(player) == "table" and player.OfflineActor and "offline" or "online"
    )
    if not changes then
        return false
    end
    dataService:RequestSave(
        player,
        cfg.save_reason,
        { debounceSeconds = cfg.save_debounce_seconds }
    )
    if statsService and statsService.CounterChanged then
        for _, change in ipairs(changes) do
            statsService.CounterChanged:Fire(player, change.id, change.value, change.old)
        end
    end
    return true
end

return Progress
