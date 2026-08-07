-- Pure preparation for the client-side post-trade pet reveal.
--
-- The completed trade packet is recipient-relative: state.them.items is the
-- partner's committed offer, which is exactly what the local player received.
-- Keep packet interpretation here so the UI presenter only receives pets and
-- never accidentally shows the player's outgoing offer.

local TradeReveal = {}

TradeReveal.MAX_PETS = 99

local function positiveQuantity(item)
    local quantity = math.floor(tonumber(item.quantity) or 1)
    return math.max(0, quantity)
end

function TradeReveal.receivedPets(items, requestedCap)
    local cap = math.floor(tonumber(requestedCap) or TradeReveal.MAX_PETS)
    cap = math.max(0, math.min(TradeReveal.MAX_PETS, cap))

    local pets = {}
    local total = 0

    for _, item in ipairs(type(items) == "table" and items or {}) do
        if type(item) == "table" and (item.category == nil or item.category == "pets") then
            local record = type(item.record) == "table" and item.record or {}
            local petType = item.id or record.id or item.petType or record.petType
            if petType then
                local quantity = positiveQuantity(item)
                total += quantity

                for _ = 1, quantity do
                    if #pets < cap then
                        pets[#pets + 1] = {
                            petType = tostring(petType),
                            variant = item.variant or record.variant or "basic",
                            rarityId = item.rarity_id
                                or item.rarityId
                                or record.rarity_id
                                or record.rarityId,
                            huge = item.huge == true or record.huge == true,
                            petData = record,
                        }
                    end
                end
            end
        end
    end

    return {
        pets = pets,
        total = total,
        truncated = total > #pets,
    }
end

return TradeReveal
