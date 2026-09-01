-- Cannon owned/install is its own persist slice. Waves, eggs, and the rest of
-- MergeDefense are not inputs. Callers write these keys onto the live profile
-- table; they must not replace that table and must not compare-and-swap the
-- encounter record against a rebuilt onboarding blob.

local MergeTowerProgression = require(script.Parent.MergeTowerProgression)
local MergeTowerSlots = require(script.Parent.MergeTowerSlots)

local MergeCannonPersist = {}

function MergeCannonPersist.inputFrom(source)
    source = type(source) == "table" and source or {}
    local input = {
        owned = source.towerOwned or source.tower_owned,
        slots = source.towerSlots or source.tower_slots,
    }
    for _, def in ipairs(MergeTowerSlots.all()) do
        input[def.persistFamily] = source[def.persistFamily] or source[def.recordFamily]
        input[def.persistTier] = source[def.persistTier] or source[def.recordTier]
    end
    return input
end

function MergeCannonPersist.read(source, config)
    config = type(config) == "table" and config or {}
    local state =
        MergeTowerProgression.normalize(MergeCannonPersist.inputFrom(source), config.maximum_tier)
    if config.visual_catalog_owned == true then
        return MergeTowerProgression.withCatalogOwned(
            state,
            config.available_roles,
            config.starter_tier,
            config.maximum_tier
        )
    end
    return state
end

function MergeCannonPersist.write(record, progress, state)
    local persisted = MergeTowerProgression.persistFields(state)
    if record then
        for _, def in ipairs(MergeTowerSlots.all()) do
            local family, tier = MergeTowerProgression.slotFamily(state, def.id)
            record[def.recordFamily] = family
            record[def.recordTier] = tier
            record[def.aliasFamily] = nil
            record[def.aliasTier] = nil
        end
        record.towerOwned = table.clone(state.owned or {})
        record.towerSlots = table.clone(persisted.tower_slots or {})
    end
    if progress then
        for key, value in pairs(persisted) do
            progress[key] = value
        end
    end
    return persisted
end

function MergeCannonPersist.apply(state, action, family, config, slot)
    -- Live wave is not an input. Unlock is the authored policy wave.
    local unlockAt = MergeTowerProgression.unlockWave(config)
    return MergeTowerProgression.apply(state, action, family, unlockAt, config, slot)
end

function MergeCannonPersist.addSpent(record, progress, charged)
    charged = math.max(0, math.floor(tonumber(charged) or 0))
    if record then
        record.towerWaycoinsSpent = math.max(
            0,
            math.floor(tonumber(record.towerWaycoinsSpent) or 0)
        ) + charged
    end
    if progress then
        progress.tower_waycoins_spent = math.max(
            0,
            math.floor(tonumber(progress.tower_waycoins_spent) or 0)
        ) + charged
    end
end

return MergeCannonPersist
