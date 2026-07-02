--[[
    enemy_leash — per-area enemy movement leash, sourced from the live map parts (the floor each
    biome is built on), NOT the player-area zones (those didn't line up with the real geometry).

    Each region is a UNION of shapes; an enemy spawned inside a region's union is confined to it
    (it can chase up to the boundary but no further — a hard wall). Shapes reference a map part by
    its path under workspace; EnemyService resolves them at boot:
        box    — the part's X/Z footprint (axis-aligned). Use for the biome floor meshes.
        circle — a disc at the part's position, radius = half its largest horizontal dimension.

    GrassSpawn is the one true union: the Grass mesh PLUS the SpawnCircle disc, so starter-area
    foes roam the whole grass+spawn pen (Jason: "a union of the Spawn Circle and grass").
]]

return {
    inset = 2, -- stop this many studs inside every boundary

    -- name -> list of shapes. Order doesn't matter (union). part = dotted path under Workspace.
    regions = {
        Desert = { { part = "Maps.Home.Desert", shape = "box" } },
        Ice = { { part = "Maps.Home.Ice", shape = "box" } },
        Lava = { { part = "Maps.Home.Lava", shape = "box" } },
        GrassSpawn = {
            { part = "Maps.Home.Grass", shape = "box" },
            { part = "Maps.Home.SpawnCircle", shape = "circle" },
        },
    },
}
