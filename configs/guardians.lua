--[[
    Summon-guardian config (#178) — the capstone "call a pet" powers.

    Gaia's Colossus (geomancer) and the Genie of the Dunes (sandwalker) summon a temporary GUARDIAN
    that stands with your squad for `duration`s, then despawns. To keep it firewall-safe (§16.5) the
    guardian doesn't deal player damage directly — it expresses its fantasy through squad buffs while
    it's on the field:
      • Colossus = a WALL + a FIST: big squad +Defense and x pet-damage while it stands (tank identity).
      • Djinn    = a FOUNT: revives every downed pet on arrival, full-heals, then a heal-over-time tick.

    Model: Jason is making real guardian models — drop their asset ids in `model_asset`. Until then the
    service clones a scaled-up squad pet as a placeholder (so the power is fully functional now).
]]

return {
    -- Real guardian models (Open Cloud Model asset ids). nil = clone a scaled+tinted squad pet.
    model_asset = {
        colossus = 95238379643484, -- moss-stone titan (tree + waterfall crown)
        djinn = 88120936939949, -- gold genie
    },

    colossus = {
        scale = 8, -- PLACEHOLDER only: enlarge the cloned pet (ignored when a real asset loads)
        height = 30, -- real asset: scale so it stands this many studs tall — a true COLOSSUS (~6x player)
        hover = 2, -- lift above standing-on-ground (a touch off the dirt for presence)
        tint = { 120, 132, 110 }, -- placeholder tint only (real model keeps its own textures)
        light = { 110, 200, 90 }, -- earth-green glow
        squad_defense = 220, -- +Defense on the squad while it stands (the WALL)
        squad_damage = 1.6, -- x pet damage while it stands (the FIST, via PetDamageBuff)
        offset = { x = 16, y = 0, z = 9 }, -- stands well out to the side so the giant doesn't clip the camera
    },
    -- GENIE v2 (Jason 2026-07-02): the RESURRECTION capstone. While it floats:
    --   revive_during — any pet that goes DOWN rises right back up (the unique hook; downs cost
    --                   nothing inside the window — "death is refused")
    --   heal_per_tick — a BLEND HoT (softens, doesn't immortalize; the resurrection is the show)
    --   focus_regen   — the WISH aura: +N player focus/sec on top of base regen (the genie grants
    --                   wishes — the healer casts without counting for the window)
    --   follow="fight"— trails the FIGHT centroid (the player's aggro'd enemies), not the player;
    --                   the genie belongs over the battle, not hovering at your shoulder
    djinn = {
        scale = 6,
        height = 18, -- a towering TITAN genie (~3.5x player), floating
        tint = { 245, 200, 90 },
        light = { 245, 185, 60 },
        heal_per_tick = 60,
        tick_seconds = 1.5,
        revive_during = true,
        focus_regen = 5, -- tripled regen (base 2.5/s) while the genie floats
        follow = "fight",
        hover = 7, -- floats this high off the ground
        offset = { x = -15, y = 0, z = 9 },
    },

    follow_lerp = 0.18, -- 0..1: how snappily the guardian trails the player each frame
}
