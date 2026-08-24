--[[
    Server-authored messages shown in Roblox's TextChatService window.

    Hatch threshold is an EFFECTIVE rarity id from configs/pets.lua. Huge messages are
    relayed between live servers with MessagingService; lower qualifying tiers stay in the
    hatcher's server. Never put player-authored free text in this channel.
]]

return {
    version = 1,
    hatch = {
        minimum_rarity = "mythic",
        global_rarity = "huge",
        messaging_topic = "HaloAndHorns_HugeHatches_v1",
    },
    team = {
        color_hex = "#62D8FF",
    },
    level_up = {
        color_hex = "#FFD95A",
        prefixes = { "Grats", "Congratulations", "GG" },
    },
    creator_luck = {
        color_hex = "#AA5AFF",
    },
    founders_legacy = {
        color_hex = "#FFC637",
    },
    gift = {
        minimum_rarity = "mythic",
    },
    limits = {
        text_characters = 240,
        id_characters = 128,
        remembered_ids = 256,
    },
}
