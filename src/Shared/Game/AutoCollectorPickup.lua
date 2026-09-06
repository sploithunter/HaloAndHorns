-- Shared eligibility for target selection, cached targets, and the final server pickup check.
-- Granting remains exclusively in DropService:_collect; this does not alter player Magnet.
local AutoCollectorPickup = {}

function AutoCollectorPickup.eligible(rec, userId, kinds)
    if not rec or rec._done or rec.owner ~= userId or rec.settling then
        return false
    end
    if not (rec.part and rec.part.Parent) then
        return false
    end
    -- Currency records historically have no kind. Do not mistake malformed/unrecognized records
    -- for money, or opt boss-egg drops into the collector as a side effect of adding consumables.
    if rec.kind == nil then
        return rec.currency ~= nil and kinds.currency == true
    end
    return kinds[rec.kind] == true
end

return AutoCollectorPickup
