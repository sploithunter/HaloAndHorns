--[[
    Principal — the thing that can own pets, anchor an alliance, and hold a combat level.

    Until now that was always a Roblox `Player`, and the codebase says so in ~38 places
    (`Players:FindFirstChild(folder.Name)`, `GetEarnedLevel(player)`, `_tick` over
    `Players:GetPlayers()`). The Creator summon (docs/CREATOR_SUMMON.md) needs a SECOND kind:
    an NPC that owns a squad, casts, and anchors a real TEMPORARY ALLIANCE so nearby low
    players sidekick up to it.

    Two kinds, one interface:
      • "player" — wraps a live Roblox Player; level comes from the profile (GetEarnedLevel)
      • "npc"    — a registered NPC; level is an authored config number

    MIGRATION CONTRACT (this is why the shape looks like it does): resolving a real player's
    name returns a principal whose `.instance` IS the Player and whose `.level` matches what
    the old code computed. Behaviour for players is unchanged by construction, so the ~25 call
    sites that must learn about NPCs can migrate ONE AT A TIME instead of in a single risky
    cut through live, recently-hardened teaming code.

    Roblox-free by injection: every lookup arrives in `ctx`, so this headless-specs
    (tests/headless/specs/principal.spec.luau).

    ctx = {
        findPlayer  = function(name) -> Player?          -- Players:FindFirstChild
        earnedLevel = function(Player) -> number?        -- PlayerProgressionService:GetEarnedLevel
        players     = function() -> { Player }           -- Players:GetPlayers (for `all`)
    }
]]

local Principal = {}

Principal.KIND_PLAYER = "player"
Principal.KIND_NPC = "npc"

-- ── NPC registry ────────────────────────────────────────────────────────────────────
-- Server-runtime state: which NPC principals are alive right now. Keyed by name so a
-- name-based reference (AllianceAnchor, AllianceWith csv, a pet folder's name) resolves
-- identically whether it points at a player or an NPC.

local npcs = {}

-- rec = { name, level, character?, petFolderName? }
-- `petFolderName` defaults to `name` — the same convention players use
-- (workspace.PlayerPets/<name>), so the folder-owner lookups stay uniform.
function Principal.register(rec)
    if type(rec) ~= "table" then
        return nil, "principal record must be a table"
    end
    local name = tostring(rec.name or "")
    if name == "" then
        return nil, "principal needs a name"
    end
    -- A registered NPC must never shadow a real player: name collisions would make
    -- AllianceWith/AllianceAnchor references ambiguous and silently mis-resolve.
    npcs[name] = {
        kind = Principal.KIND_NPC,
        name = name,
        level = math.max(1, tonumber(rec.level) or 1),
        character = rec.character,
        petFolderName = tostring(rec.petFolderName or name),
        instance = rec.character, -- parity with the player principal's `.instance`
    }
    return npcs[name]
end

function Principal.unregister(name)
    local key = tostring(name or "")
    local had = npcs[key] ~= nil
    npcs[key] = nil
    return had
end

function Principal.isRegistered(name)
    return npcs[tostring(name or "")] ~= nil
end

-- Live NPC principals (registration order is not meaningful — callers that need
-- determinism should sort by name).
function Principal.registered()
    local out = {}
    for _, rec in pairs(npcs) do
        out[#out + 1] = rec
    end
    return out
end

-- Test seam only: drop all NPC registrations.
function Principal.reset()
    npcs = {}
end

-- ── Resolution ──────────────────────────────────────────────────────────────────────

local function playerPrincipal(player, ctx)
    local level
    if ctx and ctx.earnedLevel then
        level = tonumber(ctx.earnedLevel(player))
    end
    return {
        kind = Principal.KIND_PLAYER,
        name = player.Name,
        level = math.max(1, level or 1),
        character = player.Character,
        instance = player, -- the Player object — call sites mid-migration still want this
    }
end

-- Resolve a NAME to a principal. Players win over NPCs (a real player is always the real
-- referent; see the collision note in `register`).
function Principal.resolve(name, ctx)
    local key = tostring(name or "")
    if key == "" then
        return nil
    end
    local player = ctx and ctx.findPlayer and ctx.findPlayer(key)
    if player then
        return playerPrincipal(player, ctx)
    end
    return npcs[key]
end

-- Every principal that should be TICKED (pet movement, combat, support passes): all live
-- players plus all registered NPCs. This is what replaces `for _, p in Players:GetPlayers()`
-- in PetFollowService:_tick — an NPC's pet folder is otherwise never driven at all.
function Principal.all(ctx)
    local out = {}
    if ctx and ctx.players then
        for _, player in ipairs(ctx.players()) do
            out[#out + 1] = playerPrincipal(player, ctx)
        end
    end
    for _, rec in pairs(npcs) do
        out[#out + 1] = rec
    end
    return out
end

-- The world folder that holds this principal's pets (workspace.PlayerPets/<this>).
function Principal.petFolderName(principal)
    if type(principal) ~= "table" then
        return nil
    end
    return principal.petFolderName or principal.name
end

-- Combat level. Players read the profile (already resolved at construction); NPCs read their
-- authored config level. Callers use this instead of GetEarnedLevel so an NPC can anchor.
function Principal.levelOf(principal)
    if type(principal) ~= "table" then
        return 1
    end
    return math.max(1, tonumber(principal.level) or 1)
end

function Principal.isPlayer(principal)
    return type(principal) == "table" and principal.kind == Principal.KIND_PLAYER
end

function Principal.isNpc(principal)
    return type(principal) == "table" and principal.kind == Principal.KIND_NPC
end

return Principal
