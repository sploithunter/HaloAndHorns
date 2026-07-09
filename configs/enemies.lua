--[[
    Enemies — Halo & Horns [PROTOTYPE] (Feature 10: Combat).

    Enemy archetypes. Each enemy has:
      role       — combat role, the MIRROR of the pet roles (configs/pet_roles.lua):
                   tank | melee | ranged | support. A TAG for now (drives the enemy HUD
                   threat read + future role-motion: tanks plant, ranged kite, etc.). Movement
                   is NOT yet role-driven — that lands as a separate A/B pass so we can compare.
      hp         — base health (10x world: pools x10 both sides, damage untouched —
                   see configs/combat.lua pet_down_threshold_factor; scaled by party size at spawn)
      tier       — Spirit Form cooldown tier applied to a pet this enemy downs
                   (maps to configs/spirit_form.lua cooldown_tiers)
      attack     — { damage, cadence, sundering }
                     damage    = damage dealt to a targeted pet per hit
                     cadence   = seconds between attacks
                     sundering = Focus drained from the player per hit (0 = none)
      auto_heal  — (support) { interval, amount, range }: mends the most-hurt nearby enemy.
      model_asset— uploaded model id (cloned via AssetFetch → PlaceAssets cache). Omit and the
                   service builds a procedural block (placeholder until the art is imported).
      drop_table — currency/token amounts on defeat (numeric = deterministic; *_chance = random).

    EARTH enemy faction (the starter biome's wild creatures, the dark mirror of your Earth pets):
      tank=bear · melee=rabid_dog · ranged=murder_crow + vicious_cat · support=rabid_bunny.
    Read by CombatService via ConfigLoader; pure math lives in `src/Shared/Game/CombatMath.lua`.
]]

return {
    -- Proximity baddie spawners (Jason): map parts named BaddieSpawner* spawn a wave when a
    -- player comes near — "a taste of combat before they decide to go up or down the tree."
    spawners = {
        part_prefix = "BaddieSpawner",
        radius = 50, -- studs: trigger distance from the part
        -- RANDOM cooldown (Jason: "sometimes you'll get more than one") — each trigger rolls a
        -- value in [min,max]; a short roll can land a second wave while the first is still up.
        cooldown = { min = 30, max = 120 },
        -- hard cap on LIVING baddies per spawner (don't bury the player / stockpile for the next).
        max_alive = 8,
        scatter = 8, -- studs: random spread around the part so the wave isn't a stack
        -- ZONE ROUTING (Jason: "I'm in lava but it's spawning bears"). A spawner draws only waves
        -- of its faction. The faction is keyed off the part-name SUFFIX (after part_prefix): the map
        -- has BaddieSpawnerLava + BaddieSpawnerDesert, so "Lava" -> the lava packs, everything else
        -- -> default_faction. A wave with no `faction` field counts as the default (earth).
        default_faction = "earth",
        -- each biome spawner draws its own faction (keyed off the BaddieSpawner<Suffix> part name).
        -- Ice is wired + ready for when a BaddieSpawnerIce part is placed in the map.
        zone_faction = { Lava = "lava", Desert = "desert", Ice = "ice" },
        -- VARIETY (Jason): weighted compositions, not just "3 imps / 1 bear". Mixed-role packs make
        -- the role + surround systems sing — a healer behind a tank reads totally differently from a
        -- melee swarm. Weight = relative frequency (rarer = scarier). NOTE: rabid_dog/murder_crow/
        -- vicious_cat render as PLACEHOLDER blocks until their meshes are uploaded — the comps are
        -- wired and play now; the art swaps in later.
        waves = {
            -- common: a fast melee swarm
            { weight = 10, units = { { enemy = "rabid_dog", count = 3 } } },
            -- common: a lone bruiser to soak
            { weight = 9, units = { { enemy = "raging_bear", count = 1 } } },
            -- a murder of crows — ranged harass, fragile (focus them down)
            { weight = 7, units = { { enemy = "murder_crow", count = 3 } } },
            -- backline healer + escorts: kill the bunny first or grind forever
            {
                weight = 6,
                units = {
                    { enemy = "rabid_bunny", count = 1 },
                    { enemy = "rabid_dog", count = 2 },
                },
            },
            -- warband: tank anchor + melee + a sniper
            {
                weight = 6,
                units = {
                    { enemy = "raging_bear", count = 1 },
                    { enemy = "rabid_dog", count = 2 },
                    { enemy = "murder_crow", count = 1 },
                },
            },
            -- ambush: ranged duo + a flanking cat
            {
                weight = 5,
                units = {
                    { enemy = "murder_crow", count = 2 },
                    { enemy = "vicious_cat", count = 1 },
                },
            },
            -- THE SCARY TEAM (Jason): a full role-balanced pack — a bruiser wall, a healer keeping
            -- it alive, melee crowding in, and a sniper picking off your backline. Rare, and a real
            -- check on a one-note squad (you want your OWN tank/heal to answer it).
            {
                weight = 2,
                units = {
                    -- tank wall = raging_bear (Earth, MODELED). Was ember_brute, but the Lava faction
                    -- is unmodeled so it spawned a placeholder block in the field; the rest of this
                    -- pack is Earth anyway, so the bear makes the apex wave coherent + fully-modeled.
                    { enemy = "raging_bear", count = 1 },
                    { enemy = "rabid_bunny", count = 1 }, -- healer (kill first)
                    { enemy = "rabid_dog", count = 3 }, -- melee crowd
                    { enemy = "murder_crow", count = 2 }, -- snipers
                },
            },
            -- LAVA / HELL faction packs (Jason: "get them all in, we'll test them"). The wave list
            -- is GLOBAL for now (not zone-routed), so these mix into every biome — variety while we
            -- test; zone-routing (Lava packs only in lava) is the clean follow-up.
            -- lava swarm: a darting whelp pack
            { weight = 5, faction = "lava", units = { { enemy = "cinder_whelp", count = 3 } } },
            -- lava warband: rhino wall + whelps + a moth healer
            {
                weight = 3,
                faction = "lava",
                units = {
                    { enemy = "ember_brute", count = 1 }, -- molten rhino tank
                    { enemy = "cinder_whelp", count = 2 }, -- melee
                    { enemy = "ember_acolyte", count = 1 }, -- moth healer
                },
            },
            -- NO BOSS in the proximity waves: a 50k-HP Magma Wyrm from a field spawner stacked to a
            -- death zone (Jason hit THREE at once, unkillable). Bosses are deliberate encounters —
            -- admin/special spawns only — never random field rolls.

            -- DESERT faction packs (BaddieSpawnerDesert). No boss (sand_scorpion = admin/special).
            -- jackal swarm: a fast pack hunt
            { weight = 6, faction = "desert", units = { { enemy = "sand_jackal", count = 3 } } },
            -- a wake of vultures: ranged harass, fragile (focus them)
            {
                weight = 5,
                faction = "desert",
                units = { { enemy = "carrion_vulture", count = 3 } },
            },
            -- caravan ambush: tortoise wall + jackals + a scarab healer (kill the scarab first)
            {
                weight = 4,
                faction = "desert",
                units = {
                    { enemy = "dune_tortoise", count = 1 }, -- shell wall
                    { enemy = "sand_jackal", count = 2 }, -- melee
                    { enemy = "golden_scarab", count = 1 }, -- healer
                },
            },
            -- ambush duo: vultures + a flanking jackal
            {
                weight = 4,
                faction = "desert",
                units = {
                    { enemy = "carrion_vulture", count = 2 },
                    { enemy = "sand_jackal", count = 1 },
                },
            },

            -- ICE faction packs (BaddieSpawnerIce, when placed). No boss (glacial_leviathan = special).
            -- fox swarm: a fast frozen pack
            { weight = 6, faction = "ice", units = { { enemy = "frost_fox", count = 3 } } },
            -- a parliament of owls: ranged ice harass
            { weight = 5, faction = "ice", units = { { enemy = "snowy_owl", count = 3 } } },
            -- glacial pack: mammoth wall + foxes + a seal healer (kill the seal first)
            {
                weight = 4,
                faction = "ice",
                units = {
                    { enemy = "glacial_mammoth", count = 1 }, -- tusked wall
                    { enemy = "frost_fox", count = 2 }, -- melee
                    { enemy = "aurora_seal", count = 1 }, -- healer
                },
            },
            -- snow ambush: owls + a flanking fox
            {
                weight = 4,
                faction = "ice",
                units = {
                    { enemy = "snowy_owl", count = 2 },
                    { enemy = "frost_fox", count = 1 },
                },
            },
        },
    },

    enemies = {
        -- ============================ EARTH FACTION ============================
        -- MELEE — fast, fragile, gets in your face (the new cube_dog art).
        rabid_dog = {
            role = "melee",
            hp = 1400,
            display_name = "Rabid Dog",
            tier = "trash_mob",
            move_speed = 16, -- quick + aggressive
            armor = 0,
            -- Real art (cube_dog): mesh + texture uploaded separately to the Open Simulator group,
            -- combined at spawn via CreateMeshPartAsync (the gem pattern) — no InsertService fetch.
            mesh_asset = "rbxassetid://139565210250366",
            texture_asset = "rbxassetid://87011938206497",
            model_scale = 4,
            gait = { style = "waddle", bob_height = 0.5, tilt_degrees = 14, stride_length = 4 },
            attack = { damage = 12, cadence = 1.3, sundering = 0 },
            drop_table = { grass_coins = 9, shadow_tokens = 1 },
        },
        -- RANGED — a murder of crows: hits a touch harder, very squishy (the new raven art).
        murder_crow = {
            role = "ranged",
            hp = 850,
            display_name = "Murder Crow",
            tier = "trash_mob",
            move_speed = 14,
            armor = 0,
            -- Real art (raven): mesh + texture combined at spawn via CreateMeshPartAsync.
            mesh_asset = "rbxassetid://79312260838341",
            texture_asset = "rbxassetid://120154730842284",
            model_scale = 2, -- Jason: scaled down 50% from 4
            hover_height = 7, -- a crow flies: float above the ground-snap floor
            -- flyer: smooth hover bounce that keeps bobbing even when floating in place.
            gait = {
                style = "flap",
                bob_height = 1.4,
                tilt_degrees = 8,
                stride_length = 5,
                hover = true,
                idle_amp = 0.8,
                flap_hz = 1.2,
            },
            -- RANGED: holds ~31 studs out and fires a dark plasma bolt (it doesn't close to bite).
            attack_range = 34,
            bolt_kind = "plasma",
            attack = { damage = 14, cadence = 1.6, sundering = 0 },
            drop_table = { grass_coins = 10, shadow_tokens = 1 },
        },
        -- RANGED — a vicious cat: a second ranged flavour, slightly tankier than the crow (grumpy_cat).
        vicious_cat = {
            role = "ranged",
            hp = 1000,
            display_name = "Vicious Cat",
            tier = "trash_mob",
            move_speed = 15,
            armor = 0,
            -- Real art (grumpy_cat): mesh + texture combined at spawn via CreateMeshPartAsync.
            mesh_asset = "rbxassetid://140220411587261",
            texture_asset = "rbxassetid://89093502801465",
            model_scale = 2.8, -- Jason: scaled down ~30% from 4
            gait = { style = "waddle", bob_height = 0.5, tilt_degrees = 10, stride_length = 4 },
            -- RANGED: shorter reach than the crow, spits a venom (poison) bolt; tankier up close.
            attack_range = 28,
            bolt_kind = "poison",
            attack = { damage = 13, cadence = 1.5, sundering = 0 },
            drop_table = { grass_coins = 10, shadow_tokens = 2 },
        },
        -- SUPPORT — the rabid bunny, now wearing its REAL art: the "Midnight Horned Rabbit"
        -- jackalope (a dark, antlered hare). An enemy HEALER that mends the most-hurt nearby enemy;
        -- kill it first to flip the fight. Mesh + texture combined at spawn via CreateMeshPartAsync
        -- (the gem pattern) — uploaded self-serve to the Open Simulator group (see the manifest /
        -- scripts/pet_pipeline.md). NB: texture_asset is the resolved IMAGE id, not the Decal id the
        -- Open Cloud upload returns (MeshPart.TextureID needs the underlying image, else it renders grey).
        rabid_bunny = {
            role = "support",
            hp = 1100,
            display_name = "Jackalope",
            tier = "trash_mob",
            move_speed = 13,
            armor = 0,
            mesh_asset = "rbxassetid://111943527947344",
            texture_asset = "rbxassetid://71212761122379",
            model_scale = 4,
            gait = { style = "waddle", bob_height = 0.5, tilt_degrees = 16, stride_length = 3.5 },
            attack = { damage = 6, cadence = 2.0, sundering = 0 },
            auto_heal = { interval = 2.5, amount = 100, range = 45 },
            drop_table = { grass_coins = 12, shadow_tokens = 2 },
        },
        -- TANK — the bear: thick hide, soaks for the pack (the bear art). The wall of the faction.
        raging_bear = {
            role = "tank",
            hp = 3500,
            display_name = "Raging Bear",
            tier = "mid_tier",
            move_speed = 11, -- charges in faster than the brute
            armor = 70, -- thick hide: ~41% pet-damage reduction at k=100
            model_asset = 99990991951749,
            model_scale = 5,
            needs_primary_part = true,
            gait = { style = "waddle", bob_height = 0.8, tilt_degrees = 12, stride_length = 6 },
            attack = { damage = 22, cadence = 1.8, sundering = 0 },
            drop_table = { grass_coins = 35, shadow_tokens = 4, rare_drop_chance = 0.12 },
        },

        -- ============================ DESERT FACTION ============================
        -- Sun-scorched wildlife of the Desert biome (BaddieSpawnerDesert). Role-balanced like the
        -- others: melee jackal · ranged vulture · support scarab · tank tortoise · boss scorpion.
        -- Self-serve mesh+texture (group 15872767, see scripts/pet_mesh_ids.json); dust-mote aura
        -- (def.dust). texture_asset = the resolved IMAGE id, not the Decal id (else grey).
        -- MELEE — the sand jackal: a fast, big-eared pack hunter (Desert's mirror of the rabid_dog).
        sand_jackal = {
            role = "melee",
            hp = 1300,
            display_name = "Sand Jackal",
            tier = "trash_mob",
            move_speed = 17, -- quick desert runner
            armor = 0,
            mesh_asset = "rbxassetid://133579601499458",
            texture_asset = "rbxassetid://81743984263831",
            model_scale = 4,
            dust = true,
            gait = { style = "waddle", bob_height = 0.5, tilt_degrees = 14, stride_length = 4 },
            attack = { damage = 12, cadence = 1.3, sundering = 0 },
            drop_table = { desert_coins = 9, shadow_tokens = 1 },
        },
        -- RANGED — the carrion vulture: dives + flings a rock/dust bolt from standoff (Desert's mirror
        -- of the murder_crow), bald-headed scavenger, very squishy.
        carrion_vulture = {
            role = "ranged",
            hp = 900,
            display_name = "Carrion Vulture",
            tier = "trash_mob",
            move_speed = 14,
            armor = 0,
            mesh_asset = "rbxassetid://72134348866721",
            texture_asset = "rbxassetid://109527952252689",
            model_scale = 4,
            dust = true,
            attack_range = 32, -- holds out and dives
            bolt_kind = "rock", -- the desert projectile (RangedFX rock launcher)
            hover_height = 8, -- a vulture circles: float above the ground-snap floor
            -- flyer: smooth hover bounce that keeps bobbing even when floating in place.
            gait = {
                style = "flap",
                bob_height = 1.4,
                tilt_degrees = 8,
                stride_length = 5,
                hover = true,
                idle_amp = 0.8,
                flap_hz = 1.2,
            },
            attack = { damage = 14, cadence = 1.6, sundering = 0 },
            drop_table = { desert_coins = 10, shadow_tokens = 1 },
        },
        -- SUPPORT — the golden scarab: an Egyptian rebirth beetle that mends the most-hurt ally.
        -- Kill it first to flip the fight (Desert's mirror of the jackalope / ember moth).
        golden_scarab = {
            role = "support",
            hp = 2000,
            display_name = "Golden Scarab",
            tier = "trash_mob",
            move_speed = 13,
            armor = 0,
            mesh_asset = "rbxassetid://113362318411916",
            texture_asset = "rbxassetid://91987727517751",
            model_scale = 3, -- small beetle
            dust = true,
            gait = { style = "waddle", bob_height = 0.4, tilt_degrees = 8, stride_length = 3 },
            attack = { damage = 8, cadence = 2.0, sundering = 0 },
            auto_heal = { interval = 2.0, amount = 120, range = 45 },
            drop_table = { desert_coins = 12, shadow_tokens = 2 },
        },
        -- TANK — the dune tortoise: a sandstone-shelled wall, slow + heavily armored (Desert's mirror
        -- of the raging_bear / ember_brute). The shell IS the armor tell.
        dune_tortoise = {
            role = "tank",
            hp = 3600,
            display_name = "Dune Tortoise",
            tier = "mid_tier",
            move_speed = 9, -- lumbering
            armor = 90, -- thick shell: ~47% pet-damage reduction at k=100
            mesh_asset = "rbxassetid://86038686611345",
            texture_asset = "rbxassetid://126431717175323",
            model_scale = 5,
            dust = true,
            gait = { style = "march", bob_height = 0.5, tilt_degrees = 4, stride_length = 5 },
            attack = { damage = 24, cadence = 2.0, sundering = 0 },
            drop_table = { desert_coins = 35, shadow_tokens = 4, rare_drop_chance = 0.12 },
        },
        -- BOSS — the sand scorpion: armored pincers + a Sundering stinger. The Desert apex (mirror of
        -- dire_bear / magma_wyrm). Boss = deliberate encounter (admin/special spawn), NOT field waves.
        sand_scorpion = {
            role = "tank",
            hp = 55000,
            display_name = "Sand Scorpion",
            tier = "boss",
            move_speed = 8,
            armor = 210, -- ~68% pet-damage reduction at k=100
            mesh_asset = "rbxassetid://83939345076794",
            texture_asset = "rbxassetid://113335145419297",
            model_scale = 14, -- boss-scale
            dust = true,
            gait = { style = "march", bob_height = 0.8, tilt_degrees = 3, stride_length = 9 },
            attack = { damage = 65, cadence = 2.4, sundering = 30 },
            drop_table = { desert_coins = 230, shadow_tokens = 28, rare_drop_chance = 0.5 },
        },

        -- ============================ ICE FACTION ============================
        -- Frozen wildlife of the Ice biome (BaddieSpawnerIce, when placed). Role-balanced: melee fox ·
        -- ranged owl · support seal · tank mammoth · boss leviathan. Self-serve mesh+texture (group
        -- 15872767, see scripts/pet_mesh_ids.json); frost-mote aura (def.frost). texture_asset = the
        -- resolved IMAGE id, not the Decal id (else grey).
        -- MELEE — the frost fox: a quick, frost-furred pack hunter (Ice's mirror of the rabid_dog).
        frost_fox = {
            role = "melee",
            hp = 1300,
            display_name = "Frost Fox",
            tier = "trash_mob",
            move_speed = 17,
            armor = 0,
            mesh_asset = "rbxassetid://73221295389959",
            texture_asset = "rbxassetid://79395384255362",
            model_scale = 2.8, -- Jason: scaled down ~30% from 4 (a small, quick fox)
            frost = true,
            gait = { style = "waddle", bob_height = 0.5, tilt_degrees = 14, stride_length = 4 },
            attack = { damage = 12, cadence = 1.3, sundering = 0 },
            drop_table = { ice_coins = 9, shadow_tokens = 1 },
        },
        -- RANGED — the snowy owl: dives + looses an ICE bolt from standoff (Ice's mirror of the crow).
        snowy_owl = {
            role = "ranged",
            hp = 900,
            display_name = "Snowy Owl",
            tier = "trash_mob",
            move_speed = 14,
            armor = 0,
            mesh_asset = "rbxassetid://78750320845033",
            texture_asset = "rbxassetid://98079418333409",
            model_scale = 2.8, -- Jason: scaled down ~30% from 4
            frost = true,
            attack_range = 32,
            bolt_kind = "frost", -- ice projectile (RangedFX frost theme)
            hover_height = 7, -- an owl flies: float above the ground-snap floor
            -- flyer: smooth hover bounce that keeps bobbing even when floating in place.
            gait = {
                style = "flap",
                bob_height = 1.4,
                tilt_degrees = 8,
                stride_length = 5,
                hover = true,
                idle_amp = 0.8,
                flap_hz = 1.2,
            },
            attack = { damage = 14, cadence = 1.6, sundering = 0 },
            drop_table = { ice_coins = 10, shadow_tokens = 1 },
        },
        -- SUPPORT — the aurora seal: a gentle glowing seal that mends the most-hurt ally. Kill it first.
        aurora_seal = {
            role = "support",
            hp = 2000,
            display_name = "Aurora Seal",
            tier = "trash_mob",
            move_speed = 12, -- waddles
            armor = 0,
            mesh_asset = "rbxassetid://107376865437053",
            texture_asset = "rbxassetid://102794256383293",
            model_scale = 2.7, -- Jason: scaled down ~10% from 3
            frost = true,
            gait = { style = "waddle", bob_height = 0.4, tilt_degrees = 10, stride_length = 3 },
            attack = { damage = 8, cadence = 2.0, sundering = 0 },
            auto_heal = { interval = 2.0, amount = 120, range = 45 },
            drop_table = { ice_coins = 12, shadow_tokens = 2 },
        },
        -- TANK — the glacial mammoth: a tusked woolly wall, slow + armored (Ice's mirror of the bear).
        glacial_mammoth = {
            role = "tank",
            hp = 3600,
            display_name = "Glacial Mammoth",
            tier = "mid_tier",
            move_speed = 9,
            armor = 90, -- thick coat: ~47% pet-damage reduction at k=100
            mesh_asset = "rbxassetid://112055300686821",
            texture_asset = "rbxassetid://100199878594533",
            model_scale = 8, -- Jason: sized up ~30% from 6 (a proper mammoth bulk)
            frost = true,
            gait = { style = "march", bob_height = 0.9, tilt_degrees = 4, stride_length = 7 },
            attack = { damage = 24, cadence = 2.0, sundering = 0 },
            drop_table = { ice_coins = 35, shadow_tokens = 4, rare_drop_chance = 0.12 },
        },
        -- BOSS — the glacial leviathan: a crystal-plated ice titan, Sundering. The Ice apex (mirror of
        -- dire_bear / magma_wyrm / sand_scorpion). Boss = deliberate encounter, NOT field waves.
        glacial_leviathan = {
            role = "tank",
            hp = 58000,
            display_name = "Glacial Leviathan",
            tier = "boss",
            move_speed = 8,
            armor = 220, -- ~69% pet-damage reduction at k=100
            mesh_asset = "rbxassetid://71215778120863",
            texture_asset = "rbxassetid://131210888307665",
            model_scale = 15, -- boss-scale, dwarfs everything
            frost = true,
            gait = { style = "march", bob_height = 1.2, tilt_degrees = 3, stride_length = 10 },
            attack = { damage = 68, cadence = 2.4, sundering = 30 },
            drop_table = { ice_coins = 250, shadow_tokens = 30, rare_drop_chance = 0.5 },
        },

        -- ============================ LAVA / HELL FACTION ============================
        -- Now fully MODELED (self-serve mesh+texture, group 15872767 — see scripts/pet_mesh_ids.json):
        -- a role-balanced beast pack mirroring Earth — melee=cinder_whelp · tank=ember_brute(rhino) ·
        -- ranged TBD · support=ember_acolyte(moth) · boss=infernal_boss(wyrm). All non-humanoid by
        -- design (semi-humanoid look is reserved for Creator pets). texture_asset = the resolved IMAGE
        -- id, not the Decal id the upload returns (else grey). See scripts/pet_pipeline.md.
        lava_imp = {
            role = "melee",
            hp = 1200,
            display_name = "Cinder Whelp", -- the fast molten salamander (Lava's mirror of the dog)
            tier = "trash_mob",
            move_speed = 15,
            armor = 0,
            mesh_asset = "rbxassetid://131428937593668",
            texture_asset = "rbxassetid://113493690033768",
            model_scale = 3, -- small + quick (Jason: a touch smaller than the dogs)
            embers = true,
            gait = { style = "waddle", bob_height = 0.5, tilt_degrees = 16, stride_length = 3.5 },
            attack = { damage = 10, cadence = 1.5, sundering = 0 },
            drop_table = { lava_coins = 8, shadow_tokens = 1 },
        },
        ember_brute = {
            role = "tank",
            hp = 4000,
            display_name = "Ember Brute", -- the molten rhino: obsidian plates, lava cracks, horned charge
            tier = "mid_tier",
            move_speed = 10, -- heavier, slower
            armor = 80, -- tougher: ~44% pet-damage reduction at k=100
            mesh_asset = "rbxassetid://80444941740535",
            texture_asset = "rbxassetid://84646732890800",
            model_scale = 5,
            embers = true,
            gait = { style = "march", bob_height = 0.9, tilt_degrees = 4, stride_length = 7 },
            -- A Sundering attacker: drains player Focus on hit (Feature 12).
            attack = { damage = 25, cadence = 2.0, sundering = 20 },
            drop_table = { lava_coins = 30, shadow_tokens = 4, rare_drop_chance = 0.1 },
        },
        ember_acolyte = {
            role = "support",
            hp = 2000,
            display_name = "Ember Moth", -- the drifting lava moth healer (Lava's mirror of the jackalope)
            tier = "trash_mob",
            move_speed = 13,
            armor = 0,
            mesh_asset = "rbxassetid://119015123255528",
            texture_asset = "rbxassetid://129651164618641",
            model_scale = 2, -- Jason: scaled down 50% from 4
            hover_height = 6, -- a moth drifts: float above the ground-snap floor
            -- flyer: a slower, daintier flutter than the birds.
            gait = {
                style = "flap",
                bob_height = 1.1,
                tilt_degrees = 6,
                stride_length = 5,
                hover = true,
                idle_amp = 0.85,
                flap_hz = 1.6,
            },
            embers = true,
            attack = { damage = 8, cadence = 2.0, sundering = 0 },
            -- Enemy HEALER: restores HP to the most-hurt nearby enemy (mirrors the support role).
            auto_heal = { interval = 2.0, amount = 120, range = 45 },
            drop_table = { lava_coins = 12, shadow_tokens = 2 },
        },
        -- ============================ CELESTIAL FACTION ============================
        -- Heaven's own host — the HEAVEN TRIAL opposition (each realm's trial pits
        -- you against that realm's kind, mirroring hell_trial's lava natives).
        -- Role-balanced mirrors of the lava set; meshes reuse the uploaded heaven
        -- pet art (configs/pets.lua layer-2 heaven ids) at enemy scale.
        -- MELEE — the zealous cherub: a darting winged zealot (mirror of lava_imp).
        zealous_cherub = {
            role = "melee",
            hp = 1200,
            display_name = "Zealous Cherub",
            tier = "trash_mob",
            move_speed = 15,
            armor = 0,
            mesh_asset = "rbxassetid://79030931956866",
            texture_asset = "rbxassetid://121269488238630",
            model_scale = 3,
            hover_height = 3, -- a cherub skims above the marble
            gait = {
                style = "flap",
                bob_height = 0.8,
                tilt_degrees = 10,
                stride_length = 4,
                hover = true,
                idle_amp = 0.7,
                flap_hz = 1.8,
            },
            attack = { damage = 10, cadence = 1.5, sundering = 0 },
            drop_table = { grass_coins = 8, light_tokens = 1 },
        },
        -- RANGED — the lance seraph: holds range and hurls radiant bolts (mirror of murder_crow).
        lance_seraph_guard = {
            role = "ranged",
            hp = 900,
            display_name = "Lance Seraph",
            tier = "trash_mob",
            move_speed = 14,
            armor = 0,
            mesh_asset = "rbxassetid://110233728542561",
            texture_asset = "rbxassetid://135315232548196",
            model_scale = 3,
            attack_range = 32,
            bolt_kind = "plasma",
            gait = { style = "waddle", bob_height = 0.6, tilt_degrees = 8, stride_length = 4 },
            attack = { damage = 14, cadence = 1.6, sundering = 0 },
            drop_table = { grass_coins = 10, light_tokens = 1 },
        },
        -- SUPPORT — the radiant sprite: heaven's healer (mirror of ember_acolyte).
        radiant_sprite_guard = {
            role = "support",
            hp = 2000,
            display_name = "Radiant Sprite",
            tier = "trash_mob",
            move_speed = 13,
            armor = 0,
            mesh_asset = "rbxassetid://125507964197992",
            texture_asset = "rbxassetid://89212554084933",
            model_scale = 2.5,
            hover_height = 6,
            gait = {
                style = "flap",
                bob_height = 1.1,
                tilt_degrees = 6,
                stride_length = 5,
                hover = true,
                idle_amp = 0.85,
                flap_hz = 1.6,
            },
            attack = { damage = 8, cadence = 2.0, sundering = 0 },
            auto_heal = { interval = 2.0, amount = 120, range = 45 },
            drop_table = { grass_coins = 12, light_tokens = 2 },
        },
        -- TANK — the prism warden: the crystalline lion wall (mirror of ember_brute).
        prism_warden = {
            role = "tank",
            hp = 4000,
            display_name = "Prism Warden",
            tier = "mid_tier",
            move_speed = 10,
            armor = 80,
            mesh_asset = "rbxassetid://78217294385117",
            texture_asset = "rbxassetid://92965017950964",
            model_scale = 5,
            gait = { style = "march", bob_height = 0.9, tilt_degrees = 4, stride_length = 7 },
            attack = { damage = 25, cadence = 2.0, sundering = 20 },
            drop_table = { grass_coins = 30, light_tokens = 4, rare_drop_chance = 0.1 },
        },
        dire_bear = {
            role = "tank",
            hp = 65000,
            display_name = "Dire Bear",
            tier = "boss",
            move_speed = 8, -- lumbering colossus
            armor = 230, -- ~70% pet-damage reduction at k=100
            model_asset = 99990991951749,
            model_scale = 11,
            needs_primary_part = true,
            gait = { style = "march", bob_height = 1.4, tilt_degrees = 3, stride_length = 11 },
            -- same 2026-07-02 re-tier as the Magma Wyrm (boss = hard-but-beatable)
            attack = {
                damage = 110,
                cadence = 2.6,
                sundering = 35,
                splash = { radius = 10, frac = 0.3 },
            },
            abilities = {
                slam = { damage = 150, radius = 14, cooldown = 12, telegraph = 1.4, range = 40 },
                pulse = { damage = 22, radius = 30, interval = 4, element = "lava" },
            },
            drop_table = { lava_coins = 280, shadow_tokens = 32, rare_drop_chance = 0.5 },
        },
        infernal_boss = {
            role = "tank",
            hp = 50000,
            display_name = "Magma Wyrm", -- the serpentine lava dragon: the Lava apex (mirror of dire_bear)
            tier = "boss",
            move_speed = 8, -- lumbering
            armor = 200, -- heavily armored (~67% reduction at k=100)
            mesh_asset = "rbxassetid://73070415401707",
            texture_asset = "rbxassetid://120005508573070",
            model_scale = 16, -- BOSS: dwarfs everything (Jason: much bigger; dire_bear is 11)
            embers = true,
            gait = { style = "march", bob_height = 1.3, tilt_degrees = 3, stride_length = 10 },
            -- DAMAGE 60→150 + splash (2026-07-02 live read, Jason: "tough but not dangerous" —
            -- at 60/2.5s one healer out-sustained it against a 10-pet pile-on; enraged ×1.5 needs
            -- a base worth amplifying). Splash makes crowding a boss cost something.
            -- RE-TIERED (Jason live, 2026-07-02): the 150/slam-200/pulse-30 kit WIPED a 10-pet
            -- squad + healer — "that was Archvillain level craziness". That kit moved UP to the
            -- Archfiend; the boss steps back to "hard, downs pets, beatable with good play".
            attack = {
                damage = 100,
                cadence = 2.5,
                sundering = 40,
                splash = { radius = 10, frac = 0.3 },
            },
            -- BOSS AoE kit: a telegraphed slam (the burst — red rune, dodge it) + a pulse aura
            -- chipping EVERY pet in 30 studs every 4s (the ambience — backline included).
            abilities = {
                slam = { damage = 140, radius = 14, cooldown = 12, telegraph = 1.4, range = 40 },
                pulse = { damage = 20, radius = 30, interval = 4, element = "lava" },
            },
            drop_table = { lava_coins = 200, shadow_tokens = 25 },
        },

        -- ARCH-VILLAIN (Jason 2026-07-02: "think of it as a super boss") — the tier ABOVE boss
        -- (rank_offset 3, ×6 XP/coins). The IMPACT reads through the knobs, all tunable here:
        --   model_scale — capital baddies are physically bigger (22 vs the Magma Wyrm's 16)
        --   armor      — the DEFENSE knob (armor-curve damage reduction, like pet Defense)
        --   attack.damage / cadence — the POWER knobs
        --   attack.splash — melee CLEAVE: every landed bite also splashes `frac` of the damage
        --                   to other pets within `radius` studs (crowding an AV is dangerous)
        --   abilities.slam — a TELEGRAPHED targeted AoE: every `cooldown`s it marks a red rune
        --                   under its top-threat pet, then `telegraph`s later slams everything
        --                   inside `radius` for `damage` (rolls accuracy/crit per pet; rage amp
        --                   applies — an ENRAGED arch-villain slam is a squad-wiper)
        -- v1 reuses the Magma Wyrm art at arch scale; bespoke art can swap in later.
        infernal_archvillain = {
            role = "tank",
            hp = 150000,
            display_name = "Infernal Archfiend",
            tier = "archvillain",
            move_speed = 9,
            armor = 300, -- the defense knob (~75% reduction at k=100)
            mesh_asset = "rbxassetid://73070415401707",
            texture_asset = "rbxassetid://120005508573070",
            model_scale = 22, -- ARCH-VILLAIN: dwarfs the boss
            embers = true,
            gait = { style = "march", bob_height = 1.5, tilt_degrees = 4, stride_length = 12 },
            -- 2026-07-02 re-tier: this IS the kit that wiped Jason's 10-pet double-squad wearing
            -- the boss's name tag ("that was Archvillain level craziness") — 150 bites + slam 200
            -- + pulse 30, now backed by AV HP (150k) and armor (300) so it's the same storm for
            -- three times as long. Enraged ×1.5 on top = the raid check.
            attack = {
                damage = 150,
                cadence = 2.4,
                sundering = 45,
                splash = { radius = 12, frac = 0.5 },
            },
            abilities = {
                slam = { damage = 200, radius = 16, cooldown = 10, telegraph = 1.4, range = 40 },
                pulse = { damage = 30, radius = 34, interval = 4, element = "lava" },
            },
            drop_table = { lava_coins = 600, shadow_tokens = 80, rare_drop_chance = 1 },
        },

        -- [TEST] Tanky harmless dummy for measuring damage/AoE. Enormous HP, zero attack, stationary.
        training_dummy = {
            role = "tank",
            hp = 1000000,
            display_name = "Training Dummy",
            tier = "trash_mob",
            move_speed = 0,
            armor = 0,
            attack = { damage = 0, cadence = 999, sundering = 0 },
            gait = { style = "march", bob_height = 0, tilt_degrees = 0, stride_length = 0 },
            drop_table = {},
        },
    },
}
