--[[
    AllianceRules — pure eligibility + level math for TEMPORARY ALLIANCES (Jason, 2026-07-08).

    The scenario: two UNTEAMED players stand at the same home spawn cave. The higher-level
    player trips the wave, so the enemies tune high — and the lower player would be fodder.
    Instead, everyone co-present at the TRIGGER moment allies for the encounter: the lower
    player sidekicks UP to (triggerer + sidekick offset) on the existing EffectiveLevel path,
    a "TEMPORARY ALLIANCE" banner shows on both, and the alliance dissolves when the fight
    ends. SIDEKICK-UP ONLY — the anchor is never pulled down (that would impose an exemplar
    on a bystander who didn't opt in; formal teams remain the consensual way to exemplar).
    Walking into an ALREADY-RUNNING fight forms nothing — "purple enemies are your problem" —
    the alliance exists only between players present when the wave spawns.

    Pure so it headless-specs (tests/headless/specs/alliance_rules.spec.luau).
]]

local AllianceRules = {}

-- Deterministically choose the highest-level nearby player. Roblox does not promise that
-- Players:GetPlayers() is level-sorted; using its first result made a lower player trigger Home
-- cave content, after which the sidekick-UP-only rule correctly refused to pull the higher player
-- down. `tieOf` keeps equal-level selection stable (UserId in runtime).
function AllianceRules.pickHighest(candidates, levelOf, tieOf)
    local best, bestLevel, bestTie
    for index, candidate in ipairs(candidates or {}) do
        local level = tonumber(levelOf and levelOf(candidate))
            or tonumber(type(candidate) == "table" and candidate.level)
            or 1
        local tie = tonumber(tieOf and tieOf(candidate))
            or tonumber(type(candidate) == "table" and (candidate.tie or candidate.userId))
            or index
        if best == nil or level > bestLevel or (level == bestLevel and tie < bestTie) then
            best, bestLevel, bestTie = candidate, level, tie
        end
    end
    return best
end

-- Should `bystander` ally to `triggerer` at spawn time?
-- cfg: { enabled, min_level_gap, min_engage_level (accepted, unused) }
--   • enabled=false kills the feature
--   • the triggerer must be meaningfully higher (min_level_gap) — near-equals gain nothing
--     and the banner would be noise
--   • sub-onramp newbies ALLY TOO (Jason 2026-07-21: "preferably they get to experience a
--     team right off the bat... right now it feels like I'm being left out") — the alliance
--     lifts them and EnemyService treats allied players as combat-engaged, so joining the
--     camp's fight REPLACES the solo First-Fight pushover while the alliance lasts.
function AllianceRules.shouldAlly(triggerLevel, bystanderLevel, cfg)
    cfg = cfg or {}
    if cfg.enabled == false then
        return false
    end
    triggerLevel = tonumber(triggerLevel) or 1
    bystanderLevel = tonumber(bystanderLevel) or 1
    local gap = tonumber(cfg.min_level_gap) or 3
    return (triggerLevel - bystanderLevel) >= gap
end

-- The allied player's combat level: lifted UP to just below the anchor, never down.
-- offset is the sidekick offset (teaming.sidekick.level_offset, typically -1).
function AllianceRules.effectiveLevel(ownLevel, anchorLevel, offset)
    ownLevel = tonumber(ownLevel) or 1
    anchorLevel = tonumber(anchorLevel) or 1
    local lift = math.max(1, anchorLevel + (tonumber(offset) or -1))
    if ownLevel < lift then
        return lift
    end
    return ownLevel -- UP only: an equal-or-higher player is untouched
end

return AllianceRules
