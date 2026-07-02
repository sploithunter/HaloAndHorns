--[[
    WorldContext — resolve WHICH WORLD (realm + depth) any instance lives in, from its ANCESTRY.

    Every world is a folder under Workspace.Maps: `Home` (base), `Heaven_1..5` (up), `Hell_1..5`
    (down). Duplicating a world folder tags every descendant for free — the folder NAME (or an
    explicit `Realm`/`Depth` attribute on it) identifies the world, so no per-part editing.

    Any content system — enemy spawners, egg hatchers, crystal markers, enemy/pet model pickers —
    calls WorldContext.of(inst) to learn { realm, depth }, then selects its content set + difficulty
    FROM that (in config). One resolver, so heaven and hell never fork into parallel code paths:
    the same service runs everywhere; only the resolved realm/depth changes what it produces.

    Pure parts (parseName, difficultyFor) are headless-tested; of() is the thin instance walk.
]]

local WorldContext = {}

-- Parse a world-folder NAME into { realm, depth }. Convention (case-insensitive, separator
-- optional): "Home"/"Base" -> base/0, "Heaven_<n>" -> heaven/n, "Hell_<n>" -> hell/n. A bare
-- "Heaven"/"Hell" with no number defaults to depth 1. Returns nil if the name isn't a world.
function WorldContext.parseName(name)
    if type(name) ~= "string" then
        return nil
    end
    local lower = name:lower()
    if lower == "home" or lower == "base" then
        return { realm = "base", depth = 0 }
    end
    local realm, num = lower:match("^(%a+)[_%s]*(%d*)$")
    if realm == "heaven" then
        return { realm = "heaven", depth = tonumber(num) or 1 }
    elseif realm == "hell" then
        return { realm = "hell", depth = tonumber(num) or 1 }
    end
    return nil
end

-- Realm of a ZONE/AREA id. Homeworld zones are bare biome names ("Lava", "Ice", "Desert",
-- "Grass", "Spawn") -> base. Realm zones are "<World>_<Floor>" (e.g. "Heaven_1_Lava",
-- "Hell_1_Ice") per configs/areas.lua, so the leading "<World>" parses to heaven/hell. Pure;
-- returns "base" / "heaven" / "hell". Used to credit realm-scoped quests (visit/unlock a realm).
function WorldContext.realmOfZoneId(zoneId)
    if type(zoneId) ~= "string" then
        return "base"
    end
    -- Try the whole id, then drop trailing "_<segment>" pieces until a world name parses.
    local name = zoneId
    while name ~= "" do
        local parsed = WorldContext.parseName(name)
        if parsed then
            return parsed.realm
        end
        local trimmed = name:match("^(.*)_[^_]*$")
        if not trimmed or trimmed == name then
            break
        end
        name = trimmed
    end
    return "base"
end

-- Difficulty multiplier for a realm+depth. Pure; config-driven so balance lives in one place.
--   cfg.realm_base[realm] = starting multiplier for that realm (default 1.0)
--   cfg.step              = per-depth increment (default 0.5)
-- e.g. step 0.5, hell depth 3 with realm_base.hell = 1.0 -> 1.0 + 3*0.5 = 2.5x.
function WorldContext.difficultyFor(realm, depth, cfg)
    cfg = cfg or {}
    local base = (cfg.realm_base and cfg.realm_base[realm]) or 1.0
    local step = tonumber(cfg.step) or 0.5
    return base + (tonumber(depth) or 0) * step
end

-- Resolve the world an INSTANCE lives in by walking its ancestry to the nearest world folder (a
-- direct child of `Maps` whose name parses, OR any ancestor carrying a `Realm` attribute — the
-- attribute wins so you can override naming). Falls back to base/home if nothing matches.
function WorldContext.of(instance)
    local node = instance
    while node and node.Parent do
        local attrRealm = node:GetAttribute("Realm")
        if attrRealm then
            return { realm = attrRealm, depth = node:GetAttribute("Depth") or 0, folder = node }
        end
        local parent = node.Parent
        if parent.Name == "Maps" then
            local parsed = WorldContext.parseName(node.Name)
            if parsed then
                return { realm = parsed.realm, depth = parsed.depth, folder = node }
            end
        end
        node = parent
    end
    return { realm = "base", depth = 0 }
end

return WorldContext
