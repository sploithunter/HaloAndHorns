--[[
    Gem drop assets + mapping (#177) — Halo & Horns.

    Mined coins drop as physical GEMS (DropService). 3 form SHAPES (single / pile / bag) recolored
    per origin — but each colour+form is its OWN mesh+texture PAIR (every Meshy gem generation has a
    distinct UV unwrap, so the shape-shared "one mesh, swap texture" idea does NOT hold: a colour's
    texture only maps onto its own mesh). Color is chosen by the biome currency; gem FORM steps up
    with the chunk a gem carries (single = small, pile = medium, bag = big). A large award SPLITS into
    several gems (payout by count), so a fat node bursts a fistful instead of one. All ids are real,
    uploaded assets (meshes+textures are GROUP-owned so the group place can load them).
]]

return {
    -- Meshes keyed [color][form]. NOTE: despite identical bag/pile/single SHAPES, each Meshy gem
    -- generation has its OWN UV layout, so a colour's texture only maps correctly onto ITS OWN mesh
    -- (no shared mesh — applying emerald's texture to sapphire's mesh produces UV-garble). Re-uploaded
    -- from assets/exports/gems to GROUP 15872767 (a group-owned place can't LoadAsset user-owned
    -- assets). Mesh ids resolved from scripts/gem_model_ids.json model uploads.
    meshes = {
        sapphire = {
            single = "rbxassetid://119448447976045",
            pile = "rbxassetid://138947095989808",
            bag = "rbxassetid://103222091262127",
        },
        emerald = {
            single = "rbxassetid://121524530289303",
            pile = "rbxassetid://123279435186787",
            bag = "rbxassetid://110828032637100",
        },
        ruby = {
            single = "rbxassetid://97487158573784",
            pile = "rbxassetid://140222025908512",
            bag = "rbxassetid://125117518808413",
        },
        citrine = {
            single = "rbxassetid://92909442829259",
            pile = "rbxassetid://137953217640306",
            bag = "rbxassetid://121787443101874",
        },
    },

    -- 12 UV-atlas textures keyed [color][form] (the real Meshy map_Kd images — NOT the flat UI gem
    -- icons that were wired here before, which garbled when wrapped on the mesh). Resolved from the
    -- gem_decals.json decals -> Image ids.
    textures = {
        sapphire = {
            single = "rbxassetid://92087344212010",
            pile = "rbxassetid://140074573067134",
            bag = "rbxassetid://111577083207352",
        },
        emerald = {
            single = "rbxassetid://89849279170806",
            pile = "rbxassetid://110721051431892",
            bag = "rbxassetid://91612068059535",
        },
        ruby = {
            single = "rbxassetid://106984872505048",
            pile = "rbxassetid://89319434061596",
            bag = "rbxassetid://80309644035251",
        },
        citrine = {
            single = "rbxassetid://88555005076540",
            pile = "rbxassetid://130117829099103",
            bag = "rbxassetid://115145476379087",
        },
        -- PREMIUM amethyst (the `gems` currency): mesh not uploaded yet (OBJ-only in exports, no FBX),
        -- so amethyst has NO meshes[] entry and falls back to a tinted purple ball in DropService.
        -- Textures kept for when its mesh is uploaded. TODO: upload amethyst mesh -> add meshes.amethyst.
        amethyst = {
            single = "rbxassetid://97110236926395",
            pile = "rbxassetid://115584169887230",
            bag = "rbxassetid://122020476621862",
        },
    },

    -- Internal PointLight tint per color (the glow inside each gem).
    light_color = {
        sapphire = { 60, 140, 255 },
        emerald = { 80, 230, 90 },
        ruby = { 235, 45, 95 },
        citrine = { 245, 185, 45 },
        amethyst = { 170, 90, 255 },
    },

    -- Biome currency -> gem color (ice=sapphire, grass/earth=emerald, lava=ruby, desert=citrine).
    currency_color = {
        ice_coins = "sapphire",
        grass_coins = "emerald",
        earth_coins = "emerald",
        meadow_coins = "emerald",
        lava_coins = "ruby",
        desert_coins = "citrine",
        beach_coins = "citrine",
        coins = "emerald",
        gems = "amethyst", -- premium currency drops (crystal-break bonus roll) read as amethyst
    },
    default_color = "emerald",

    -- Form chosen by the amount a single gem carries (descending min).
    form_tiers = {
        { min = 500, form = "bag" },
        { min = 100, form = "pile" },
        { min = 0, form = "single" },
    },

    -- Payout-by-count split: one extra gem per `split_step` of award, clamped to `max_gems`.
    split_step = 250,
    max_gems = 6,

    -- Visual: scale each gem so its widest side is ~`size[form]` studs (a pile/bag is a whole
    -- cluster, so it needs to be bigger than a single to read at the same gem scale). PointLight
    -- range/brightness for the internal glow.
    size = {
        single = 1.25, -- a touch smaller than the pile/bag (Jason: shrink the single, not grow the rest)
        pile = 3.0, -- ~2x a single (Jason: piles looked small at the shared size)
        bag = 4.0, -- the jackpot form — chunkiest
    },
    default_size = 1.5,
    light_range = 9,
    light_brightness = 2.5,
}
