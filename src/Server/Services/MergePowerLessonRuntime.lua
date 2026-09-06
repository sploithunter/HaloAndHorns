-- Invoked by Merge's existing per-bay tutorial lifecycle, not a separate polling service.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lessons = require(ReplicatedStorage.Shared.Game.MergePowerLessons)
local Enhancements = require(ReplicatedStorage.Shared.Game.Enhancements)
local Runtime = {}

local function context(service, record)
    local cfg = service:_tutorialConfig().power_lessons
    local data = service._dataService:GetData(record.player)
    if not cfg or not cfg.enabled or not data then
        return nil
    end
    data.GameData = data.GameData or {}
    data.GameData.MergePowerLessons = data.GameData.MergePowerLessons or { completed = {} }
    local state = data.GameData.MergePowerLessons
    state.completed = state.completed or {}
    return cfg, data, state
end

local function hasEnhancement(service, data, level)
    local cfg = service._modules.EnhancementService._config
    local powers = service._modules.EnhancementService._powersConfig
    for powerId, list in pairs(data.Slots or {}) do
        for _, slot in ipairs(list) do
            local rec = slot.enh
            if
                rec
                and Enhancements.isValid(cfg, rec)
                and Enhancements.usableBy(rec, data.Archetype)
                and Enhancements.levelFactor(cfg, rec.level, level) > 0
                and Enhancements.compatibleWith(
                    cfg,
                    rec.type,
                    powers.powers[powerId],
                    powers.effect_kinds
                )
            then
                return true
            end
        end
    end
    return false
end

local function completed(service, record, stage, data)
    local progression = service._modules.PlayerProgressionService
    if stage.id == "power" then
        return progression:GetClaimedLevel(record.player) >= stage.level
            and #(data.Powers or {}) > 0
    elseif stage.id == "slots" then
        return progression:GetClaimedLevel(record.player) >= stage.level
            and Lessons.allocated(data.Slots) >= stage.slots
    end
    return hasEnhancement(service, data, progression:GetEarnedLevel(record.player))
end

local function save(service, record)
    service._dataService:RequestSave(record.player, "merge_power_lesson", { critical = true })
end

function Runtime.clear(record)
    record.powerLessonId = nil
    record.player:SetAttribute("MergePowerLesson", nil)
    record.player:SetAttribute("MergePowerRecommendation", nil)
end

function Runtime.update(service, record)
    if not record or not record.powerLessonId then
        return false
    end
    if not service:_isRecordActive(record) then
        return false
    end
    if record.powerLessonBusy then
        return true
    end
    record.powerLessonBusy = true
    local ok, err = pcall(function()
        local cfg, data, state = context(service, record)
        if not cfg then
            return
        end
        local stage
        for _, candidate in ipairs(cfg.stages) do
            if candidate.id == record.powerLessonId then
                stage = candidate
                break
            end
        end
        if not stage then
            return
        end
        local progression = service._modules.PlayerProgressionService
        if stage.level and not state[stage.id .. "LevelGranted"] then
            state.unlocked = true
            progression:EnsureEarnedLevel(record.player, stage.level)
            progression:RefreshPublishedState(record.player)
            state[stage.id .. "LevelGranted"] = true
            save(service, record)
        end
        if not service:_isRecordActive(record) then
            return
        end
        if completed(service, record, stage, data) or Lessons.graduate(data) then
            state.completed[stage.id] = true
            save(service, record)
            Runtime.clear(record)
            record.tutorialActive = false
            record.tutorialStep = "quartermaster_waves"
            record.tutorialStepReadyAt = nil
            service:_scheduleTutorialWaveResume(record)
            return
        end
        if stage.id == "enhance" and not state.enhancementGranted then
            local enh = service._modules.EnhancementService
            local snapshot = enh:GetState(record.player)
            local level = progression:GetEarnedLevel(record.player)
            local usable = false
            for _, item in ipairs(snapshot.inventory or {}) do
                if
                    Enhancements.usableBy(item, data.Archetype)
                    and Enhancements.canSlotAtLevel(enh._config, item.level, level)
                    and Enhancements.levelFactor(enh._config, item.level, level) > 0
                then
                    for _, id in ipairs(data.Powers or {}) do
                        if
                            Enhancements.compatibleWith(
                                enh._config,
                                item.type,
                                enh._powersConfig.powers[id],
                                enh._powersConfig.effect_kinds
                            )
                        then
                            usable = true
                            break
                        end
                    end
                end
                if usable then
                    break
                end
            end
            if not usable then
                local gift = cfg.starter_enhancement
                local result = enh:Grant(record.player, {
                    type = gift.type,
                    origins = {},
                    level = math.min(enh._config.drops.levels.max, level + gift.level_offset),
                }, { deferFlush = true })
                if result and result.ok then
                    -- Receipt and item are in the same profile before the first flush/save.
                    state.enhancementGranted = result.uid
                    enh:_inventoryService()
                        :FlushBucket(record.player, "enhancements", "merge_power_lesson_gift")
                    save(service, record)
                end
            end
        end
    end)
    record.powerLessonBusy = nil
    if not ok then
        service:_log("Warn", "Merge power lesson retry", { error = tostring(err) })
    end
    return true
end

function Runtime.tryStart(service, record)
    if
        not record
        or record.tutorialActive
        or record.terminal
        or (record.aliveEnemies or 0) > 0
        or (record.pendingEnemySpawns or 0) > 0
        or (type(record.player) == "table" and record.player.OfflineActor == true)
    then
        return false
    end
    local cfg, data, state = context(service, record)
    if not cfg or Lessons.graduate(data) or not service._modules.PlayerProgressionService then
        return false
    end
    local progress = service:_mergeDefenseProgress(record.player)
    if progress.tutorial_completed or (progress.rebirths or 0) > 0 then
        return false
    end
    for _, stage in ipairs(cfg.stages) do
        if (record.waveIndex or 0) >= stage.wave and not state.completed[stage.id] then
            if completed(service, record, stage, data) then
                state.completed[stage.id] = true
                save(service, record)
            else
                record.powerLessonId = stage.id
                record.nextWaveAt = nil
                record.tutorialActive = true
                record.player:SetAttribute("MergePowerLesson", stage.id)
                record.player:SetAttribute(
                    "MergePowerRecommendation",
                    Lessons.recommended(cfg, service:_tutorialUsesAutoCollector(record))
                )
                service:_setTutorialStep(record, stage.id .. "_lesson")
                service:_setWorldState("TutorialIntermission", record)
                Runtime.update(service, record)
                return true
            end
        end
    end
    return false
end

return Runtime
