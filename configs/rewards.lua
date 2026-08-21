--[[
    Rewards — Halo & Horns [PROTOTYPE] (Phase 7).

    The reward spine's shared config. The grant ledger is a capped in-memory audit
    of every bundle granted (source-keyed), mirroring the trade/fusion logs. Pure
    cores: RewardBundle / Condition / ClaimLogic. Service: RewardService.
]]

return {
    grant_log_limit = 200,
    delivery = {
        -- Stable ids make retried ProfileStore messages idempotent. Keep a bounded profile ledger;
        -- producers must never reuse an id after it has aged out of this history.
        claimed_id_limit = 500,
    },
    -- Bucket used for reward items when an item entry omits its own bucket.
    default_item_bucket = "consumables",
    -- Upgrade ids that reward `slots` grants increment (capacity rewards).
    slot_upgrades = { "pet_equip_slots", "pet_storage" },
}
