--[[
    ClaimLogic — pure anti-replay gate for the reward spine (Phase 7).

    Decides whether a reward may be claimed right now, given (a) whether its gate
    is satisfied (`met`, precomputed by the caller via Condition) and (b) how many
    times it has already been claimed. Self-contained (no requires) so it loads in
    the headless harness; the service holds the per-player claim ledger (defId -> count).

      canClaim(met, claimedCount, def) -> { ok, reason? }

    `def` carries the claim policy:
      def.repeatable = true   -> may be claimed any number of times (gate permitting)
      def.limit = N           -> may be claimed at most N times
      (neither)               -> claim-once

    reasons: "not_met" | "already_claimed" | "out_of_stock"
]]

local ClaimLogic = {}

function ClaimLogic.canClaim(met, claimedCount, def)
    def = def or {}
    claimedCount = claimedCount or 0

    if not met then
        return { ok = false, reason = "not_met" }
    end

    if def.limit ~= nil then
        if claimedCount >= def.limit then
            return { ok = false, reason = "out_of_stock" }
        end
        return { ok = true }
    end

    if not def.repeatable and claimedCount >= 1 then
        return { ok = false, reason = "already_claimed" }
    end

    return { ok = true }
end

return ClaimLogic
