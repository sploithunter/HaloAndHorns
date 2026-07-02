--[[
    Zone Tracker configuration (Pet Realm location awareness).

    A server service (ZoneTrackerService) resolves which authored "area" each player is
    standing in by testing their position against the area bounding boxes already defined in
    configs/areas.lua (synthetic.center / synthetic.size). The result is written to a single
    SSOT player attribute (`CurrentArea`), which farming (AutoTargetService), area music, and
    future zone activation all read. No map touch-parts required — robust to falls/teleports.

    Detection is FOOTPRINT-based (X/Z): area boxes in areas.lua are thin floor slabs
    (size.y ~= 4), but a standing player's HRP sits several studs above the floor, so a strict
    Y test would never match. We match the X/Z footprint and apply a generous vertical band so
    a player anywhere in the play volume above an area counts as "in" it. (When stacked
    heaven/hell layers arrive at very different Y, tighten vertical_band per-layer.)
]]

return {
    -- How often (seconds) the server re-resolves each player's area. ~4x/sec is plenty for
    -- music + farm scoping and is cheap (a handful of box tests per player).
    poll_interval = 0.25,

    -- Vertical half-band (studs) added around an area box's Y centre so a standing player
    -- (HRP above the thin floor slab) still resolves as inside. Large by design.
    vertical_band = 80,

    -- Hysteresis (studs): once you're in an area you stay in it until you're this far OUTSIDE
    -- its footprint, even if another area would also match. Prevents flicker at shared edges.
    boundary_margin = 6,

    -- Area to report when the player is outside every authored area box (e.g. mid-jump between
    -- islands, or on un-zoned geometry). Keeps a sane default for farming/music.
    default_area = "Spawn",

    -- PRIMARY detection: raycast straight down and map the baseplate part we land on to an area.
    -- This is the same surface approach the crystal spawner uses (surface_match_name) and is
    -- robust to the irregular, overlapping authored baseplates — the axis-aligned boxes above
    -- mis-resolve at the seams (e.g. the grass field extends into Lava's oversized box). The box
    -- test is only a fallback for when the player isn't standing on a known baseplate.
    baseplate_area = {
        Grass = "Spawn",
        Lava = "Lava",
        Ice = "Ice",
        Desert = "Desert",
    },
    -- How far down (studs) to look for a biome baseplate beneath the HumanoidRootPart. Generous
    -- so a raised path/structure over a biome still resolves to that biome (Include filter makes
    -- the long cast cheap — it only tests the baseplates).
    raycast_depth = 120,

    -- Only FLAT parts count as baseplates. Some biome-named parts are tall structures/pillars
    -- (e.g. a 94-stud "Lava" rock), not the floor — including them would mis-detect the area near
    -- them. Real baseplates are thin slabs (size.y ~= 0-1), so reject anything thicker than this.
    baseplate_max_thickness = 5,
}
