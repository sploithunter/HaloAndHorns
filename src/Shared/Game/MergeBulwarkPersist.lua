-- Bulwark owned/install is its own persist slice. Waves, eggs, cannons, and
-- the rest of MergeDefense are not inputs. Callers write these keys onto the
-- live profile table; they must not replace that table and must not
-- compare-and-swap the encounter record against a rebuilt onboarding blob.

local MergeBulwarkProgression = require(script.Parent.MergeBulwarkProgression)
local MergeBulwarkSlots = require(script.Parent.MergeBulwarkSlots)

local MergeBulwarkPersist = {}

function MergeBulwarkPersist.inputFrom(source)
    source = type(source) == "table" and source or {}
    local input = {
        owned = source.bulwarkOwned or source.bulwark_owned,
        slots = source.bulwarkSlots or source.bulwark_slots,
    }
    for _, def in ipairs(MergeBulwarkSlots.all()) do
        input[def.persistFamily] = source[def.persistFamily] or source[def.recordFamily]
        input[def.persistTier] = source[def.persistTier] or source[def.recordTier]
    end
    return input
end

function MergeBulwarkPersist.read(source, config)
    config = type(config) == "table" and config or {}
    return MergeBulwarkProgression.normalize(
        MergeBulwarkPersist.inputFrom(source),
        config.maximum_tier
    )
end

function MergeBulwarkPersist.write(record, progress, state)
    local persisted = MergeBulwarkProgression.persistFields(state)
    if record then
        for _, def in ipairs(MergeBulwarkSlots.all()) do
            local family, tier = MergeBulwarkProgression.slotFamily(state, def.id)
            record[def.recordFamily] = family
            record[def.recordTier] = tier
        end
        record.bulwarkOwned = table.clone(state.owned or {})
        record.bulwarkSlots = table.clone(persisted.bulwark_slots or {})
    end
    if progress then
        for key, value in pairs(persisted) do
            progress[key] = value
        end
    end
    return persisted
end

function MergeBulwarkPersist.apply(state, action, family, config, slot)
    -- Live wave is not an input. Unlock is the authored policy wave.
    local unlockAt = MergeBulwarkProgression.unlockWave(config)
    return MergeBulwarkProgression.apply(state, action, family, unlockAt, config, slot)
end

function MergeBulwarkPersist.addSpent(record, progress, charged)
    charged = math.max(0, math.floor(tonumber(charged) or 0))
    if record then
        record.bulwarkWaycoinsSpent = math.max(
            0,
            math.floor(tonumber(record.bulwarkWaycoinsSpent) or 0)
        ) + charged
    end
    if progress then
        progress.bulwark_waycoins_spent = math.max(
            0,
            math.floor(tonumber(progress.bulwark_waycoins_spent) or 0)
        ) + charged
    end
end

return MergeBulwarkPersist
