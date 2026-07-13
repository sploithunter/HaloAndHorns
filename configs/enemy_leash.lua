--[[
    enemy_leash — per-area enemy movement leash, sourced from the live map parts (the floor each
    biome is built on), NOT the player-area zones (those didn't line up with the real geometry).

    Each region is a UNION of shapes; an enemy spawned inside a region's union is confined to it
    (it can chase up to the boundary but no further — a hard wall). Shapes reference a map part by
    its path under workspace; EnemyService resolves them at boot:
        surface — exact downward raycast against the authored part. Use for irregular biome meshes;
                  their broad bounding boxes overlap several other biomes and are not authoritative.
        box     — the part's axis-aligned X/Z footprint (legacy/simple rectangular pens only).
        circle  — a disc at the part's position, radius = half its largest horizontal dimension.

    GrassSpawn is the one true union: the Grass mesh PLUS the SpawnCircle disc, so starter-area
    foes roam the whole grass+spawn pen (Jason: "a union of the Spawn Circle and grass").
]]

return {
    inset = 2, -- stop this many studs inside every boundary

    -- Exact surface containment is a scene query, but its behavior remains config-owned. A movement
    -- destination is valid only when this downward probe hits one of the region's configured parts.
    surface_probe = {
        above = 100,
        depth = 1000,
    },

    -- Deterministic fallback order for position-resolved spawns. Exact surface probes normally make
    -- the match unique; this resolves a true authored seam consistently.
    region_order = { "GrassSpawn", "Ice", "Lava", "Desert" },

    -- Homeworld cave spawners bind their wave directly to the intended territory. The exact-surface
    -- check in EnemyService still validates the spawn, so mission/realm spawners cannot inherit a
    -- Home leash accidentally.
    spawner_root = "Maps.Home",
    spawner_bindings = {
        Earth = { region = "GrassSpawn", area = "Spawn" },
        Grass = { region = "GrassSpawn", area = "Spawn" },
        Ice = { region = "Ice", area = "Ice" },
        Lava = { region = "Lava", area = "Lava" },
        Desert = { region = "Desert", area = "Desert" },
    },

    -- name -> list of shapes. Order doesn't matter (union). part = dotted path under Workspace.
    regions = {
        Desert = { { part = "Maps.Home.Desert", shape = "surface" } },
        Ice = { { part = "Maps.Home.Ice", shape = "surface" } },
        Lava = { { part = "Maps.Home.Lava", shape = "surface" } },
        GrassSpawn = {
            { part = "Maps.Home.Grass", shape = "surface" },
            { part = "Maps.Home.SpawnCircle", shape = "surface" },
        },
    },
}
