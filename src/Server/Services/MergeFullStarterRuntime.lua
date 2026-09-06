-- Welcome pets use canonical hatch/grant/inventory paths. The receipt and ownership live in
-- the same locked profile; mode switches and rebirths never reset the receipt.
local Runtime = {}
local busy = setmetatable({}, { __mode = "k" })

function Runtime.grant(service, record)
    local player = record.player
    if
        (type(player) == "table" and player.OfflineActor == true)
        or record.playerCombatMode ~= "full"
        or not service:_isRecordActive(record)
        or busy[player]
    then
        return false
    end
    local rules = service._config.player_reserve.full_mode.starter_grant
    local dataService, inventory = service._dataService, service._inventoryService
    local grants = service._petGrantService
    local data = dataService and dataService:GetData(player)
    if not rules or not data or not inventory or not grants then
        return false
    end
    data.GameData = data.GameData or {}
    local receipt = data.GameData.MergeFullStarterPets
    if not receipt then
        receipt = { refs = {} }
        data.GameData.MergeFullStarterPets = receipt
    end
    if #receipt.refs >= rules.count then
        return true
    end
    busy[player] = true
    local changed = false
    local function valid()
        return service:_isRecordActive(record)
            and record.playerCombatMode == "full"
            and dataService:GetData(player) == data
            and data.GameData.MergeFullStarterPets == receipt
    end
    local ok, err = pcall(function()
        local source = service:_buildHatchSource(record, rules.egg_id)
        if not source then
            return
        end
        while #receipt.refs < rules.count and valid() do
            -- simulateHatch consumes firstHatchLuck. A fresh snapshot makes ALL four lucky,
            -- without changing normal hatching or consuming the player's FTUE hatch bonus.
            local hatchData = table.clone(source.hatchPlayerData)
            hatchData.firstHatchLuck = rules.first_hatch_luck
            local result = service._petsConfig.simulateHatch(source.eggId, hatchData)
            if not result or not result.pet then
                break
            end
            local petData = grants:BuildPetData({
                petType = result.pet,
                variant = result.variant or "basic",
                huge = result.huge == true,
                source = "merge_full_starter",
            }, player)
            -- Serial allocation can yield. Do not insert into a reset/replaced profile or
            -- a departed player's new bay after that yield.
            if not petData or not valid() then
                break
            end
            local uid = inventory:AddItem(player, "pets", petData, { deferFlush = true })
            if not uid then
                break
            end
            table.insert(receipt.refs, uid)
            changed = true
        end
    end)
    -- Flush partial success too; a retry on the next Full activation grants ONLY the remainder.
    local flushed, flushError = pcall(function()
        if
            changed
            and dataService:GetData(player) == data
            and data.GameData.MergeFullStarterPets == receipt
        then
            inventory:FlushBucket(player, "pets", "merge_full_starter")
            if valid() then
                inventory:FillEmptyPetSlots(player, receipt.refs, "merge_full_starter_auto_fill")
                if #receipt.refs >= rules.count then
                    service:_analytics(record, "full_starter_pets_granted")
                end
            end
        end
    end)
    busy[player] = nil
    if not ok or not flushed then
        service:_log(
            "Warn",
            "Full starter pet grant incomplete",
            { player = player.Name, error = tostring(err or flushError) }
        )
    end
    return #receipt.refs >= rules.count
end

function Runtime.start(service, record)
    task.defer(function()
        if service:_isRecordActive(record) and record.playerCombatMode == "full" then
            service:_analytics(record, "full_mode_active")
            Runtime.grant(service, record)
        end
    end)
end

return Runtime
