--[[
    NPC PRINCIPALS — summonable allies that own a squad and anchor a real alliance.

    Design: docs/CREATOR_SUMMON.md. Unlike a GUARDIAN (configs/guardians.lua — one model
    expressing itself through squad buff auras), a principal is a second *player-shaped*
    entity: it owns pets in workspace.PlayerPets/<name>, it holds a combat level, and it can
    anchor a TEMPORARY ALLIANCE so nearby lower players sidekick UP to it.

    Jason: "It summons essentially an NPC version of me with all of my best pets. All of my
    powers. Let's give it a 1,000-second recharge." And the keystone: "my level 50 Colorado
    would sidekick somebody to level 49... we essentially become a team."

    THE LOADOUT IS AUTHORED, NOT LIVE. It is deliberately NOT a read of Jason's real profile:
    a live read would depend on his data being resolvable on a server he isn't playing on, it
    would drift silently every time he re-equips, it couldn't be balanced, and it would leak
    account state into other players' sessions. This table is the Creator, as designed.
]]

return {
    enabled = true,

    creator = {
        -- The principal's NAME is its identity everywhere: the pet folder
        -- (workspace.PlayerPets/<name>), the AllianceAnchor attribute a lifted player
        -- carries, and the AllianceWith csv on both sides. Must never collide with a real
        -- player's username — Principal.resolve deliberately lets a real player win, so a
        -- collision would silently mis-resolve someone's alliance.
        name = "Colorado",
        display_name = "Colorado — the Creator",

        -- Combat level. This is what a nearby low player sidekicks UP to (minus the
        -- teaming.sidekick.level_offset, so 50 → they fight at 49).
        level = 50,

        -- AVATAR: built from a real Roblox user's appearance via HumanoidDescription rather
        -- than an authored lookalike — zero asset work, always current, and "that's literally
        -- him" reads harder than a resemblance. nil = a plain placeholder rig.
        avatar_user_id = 873359641, -- MacrosGodOfMagic

        -- Seconds the summon stands before it despawns.
        duration = 20,

        -- THE SQUAD. Pet types are ids from configs/pets.lua; `variant` picks the model skin.
        -- Kept small on purpose: this spawns while the rest of the world is still streaming
        -- on whatever phone the player is holding, and count is what costs.
        squad = {
            { pet = "empyrean_dragon", variant = "rainbow" },
            { pet = "abyssal_wyrm", variant = "golden" },
            { pet = "colorado_creator", variant = "basic" },
        },

        -- Formation spacing behind the summoner, in studs.
        follow_offset = { x = -8, y = 0, z = 6 },
        follow_lerp = 0.18, -- matches guardians.follow_lerp so the motion reads the same

        -- ALLIANCE: on summon, nearby unteamed players below the Creator ally to him and
        -- sidekick up for the window. Radius in studs. The gap gate + the lift math are the
        -- SHIPPING ones (Shared/Game/AllianceRules) — this is not a parallel implementation.
        alliance = {
            enabled = true,
            radius = 90, -- matches teaming pack.engaged_radius
        },
    },
}
