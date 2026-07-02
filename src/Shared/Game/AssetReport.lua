--[[
    AssetReport — ONE consolidated boot-time asset-load report.

    Every server-side asset load site (pet/crystal/egg models, mesh pets, sounds) records an
    entry here as it loads. After the boot preload pass, AssetReport.flush(logger) prints a SINGLE
    readable block: a one-line summary plus, for every asset that FAILED, its id, what it is, where
    it was being placed, and the error. So instead of scraping scattered "Failed to load" warnings,
    you read one place to see exactly which asset ids didn't load and what/where they are.

    Why this exists: a non-owner account in Studio (or a fork) can't load assets still owned by a
    personal account — those failures need to be obvious and enumerable in one log, not hunted for.

    Entry shape: { id, kind, name, target, ok, err }
      id     — the rbxassetid (string of digits)
      kind   — pet_model / crystal_model / egg_model / pet_mesh / sound / ... (best-effort label)
      name   — what it is (debugName / config key, e.g. "bear/basic")
      target — where it's placed (full instance path, e.g. "…Assets.Models.Pets.bear")
      ok     — true if loaded, false if it failed
      err    — failure reason (string) when ok == false

    Also stashed on _G.AssetReport for live console inspection (AssetReport.failures(), .all()).
]]

local AssetReport = {}

local entries = {}

function AssetReport.reset()
    entries = {}
end

-- Record one load attempt. Tolerant of missing fields so call sites stay terse.
function AssetReport.record(entry)
    if type(entry) ~= "table" or entry.id == nil then
        return
    end
    entries[#entries + 1] = {
        id = tostring(entry.id),
        kind = entry.kind and tostring(entry.kind) or "asset",
        name = entry.name and tostring(entry.name) or "",
        target = entry.target and tostring(entry.target) or "?",
        ok = entry.ok == true,
        err = entry.err and tostring(entry.err) or nil,
    }
end

function AssetReport.all()
    return entries
end

function AssetReport.failures()
    local out = {}
    for _, e in ipairs(entries) do
        if not e.ok then
            out[#out + 1] = e
        end
    end
    return out
end

-- Print the single consolidated block. Always logs the one-line summary; logs the detailed
-- failure list (one Warn carrying the whole block) only when something actually failed.
function AssetReport.flush(logger)
    local total, okCount = #entries, 0
    for _, e in ipairs(entries) do
        if e.ok then
            okCount += 1
        end
    end
    local fails = AssetReport.failures()

    if logger then
        logger:Info(
            string.format(
                "📦 [AssetReport] BOOT ASSET LOAD SUMMARY — %d attempted · %d ok · %d FAILED",
                total,
                okCount,
                #fails
            )
        )
    end

    if #fails == 0 then
        if logger then
            logger:Info("📦 [AssetReport] ✅ every asset loaded — none missing")
        end
        return total, 0
    end

    -- Sort failures by kind then name so the block reads in a stable order.
    table.sort(fails, function(a, b)
        if a.kind ~= b.kind then
            return a.kind < b.kind
        end
        return a.name < b.name
    end)

    local lines = {
        string.format(
            "📦 [AssetReport] %d ASSET(S) FAILED TO LOAD  (id · kind · name · where · error):",
            #fails
        ),
    }
    for _, e in ipairs(fails) do
        lines[#lines + 1] = string.format(
            "   ❌ %s · %s · %s · %s · %s",
            e.id,
            e.kind,
            e.name ~= "" and e.name or "(unnamed)",
            e.target,
            e.err or "load failed"
        )
    end
    if logger then
        logger:Warn(table.concat(lines, "\n"))
    end
    return total, #fails
end

_G.AssetReport = AssetReport
return AssetReport
