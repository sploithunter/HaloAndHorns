return {
    tags = {
        Zone = {
            required_attributes = {
                ZoneId = "string",
                Kind = "string",
            },
            optional_attributes = {
                ParentZoneId = "string",
            },
            config = "areas.zones",
            id_attribute = "ZoneId",
        },
        AreaZone = {
            required_attributes = {
                AreaId = "string",
            },
            optional_attributes = {
                ParentZoneId = "string",
            },
            config = "areas.zones",
            id_attribute = "AreaId",
        },
        SpawnZone = {
            required_attributes = {
                AreaId = "string",
                SpawnerId = "string",
            },
            optional_attributes = {
                DepthOffset = "number",
                MaxCountOverride = "number",
                SurfaceOnly = "boolean",
                ClearanceMode = "string",
                ObstacleMode = "string",
                ClearanceRadius = "number",
                ClearanceHeight = "number",
                ClearanceYOffset = "number",
                RaySampleCount = "number",
                ObstacleRaycastHeight = "number",
                ObstacleRaycastDepth = "number",
                RaycastHeight = "number",
                NormalMinY = "number",
                SpawnAttempts = "number",
                SpawnAreaMargin = "number",
                MinDistance = "number",
                BalancedCells = "boolean",
                CellSize = "number",
            },
            config = "breakables.worlds",
            id_attribute = "SpawnerId",
        },
        PlayerSpawn = {
            required_attributes = {
                AreaId = "string",
            },
            optional_attributes = {
                ZoneId = "string",
            },
            config = "areas.zones",
            id_attribute = "AreaId",
        },
        TeleportPad = {
            required_attributes = {
                AreaId = "string",
                TargetZoneId = "string",
            },
            config = "areas.zones",
            id_attribute = "TargetZoneId",
        },
        Portal = {
            required_attributes = {
                ZoneId = "string",
                TargetZoneId = "string",
            },
            config = "areas.zones",
            id_attribute = "TargetZoneId",
        },
        EggStand = {
            required_attributes = {
                EggId = "string",
            },
            optional_attributes = {
                AreaId = "string",
                SpawnId = "string",
            },
            config = "pets.egg_sources",
            id_attribute = "EggId",
        },
        EnchanterStation = {
            required_attributes = {
                EnchanterId = "string",
            },
            optional_attributes = {
                AreaId = "string",
                TouchPartName = "string",
                AnimationRootName = "string",
            },
            config = "enchants.stations",
            id_attribute = "EnchanterId",
        },
        PODPodium = {
            required_attributes = {},
            optional_attributes = {
                Slot = "number",
                AreaId = "string",
            },
        },
        ChaseableRegion = {
            required_attributes = {
                AreaId = "string",
                ChaseableId = "string",
            },
            optional_attributes = {},
        },
        ShopAnchor = {
            required_attributes = {
                AnchorId = "string",
            },
            optional_attributes = {
                AreaId = "string",
            },
        },
        NPCAnchor = {
            required_attributes = {
                AnchorId = "string",
            },
            optional_attributes = {
                AreaId = "string",
            },
        },
    },

    contracted_names = {
        egg_stand_prefix = "EggStand_",
        pet_of_the_day_podium = "PetDisplay_Podium",
    },

    authoring_discovery = {
        EggStand = {
            candidate_names = {
                "EggStand",
                "Egg Stand",
                "Egg",
                "Egg hatcher",
            },
            candidate_name_prefixes = {
                "EggStand_",
                "Egg_",
            },
            required_config_attributes = {
                "EggId",
            },
            optional_config_attributes = {
                "AreaId",
                "SpawnId",
                "AuthoredVisual",
                "SpawnMode",
            },
        },
    },

    synthetic = {
        root_name = "SyntheticMap",
        map_root_attribute = "GeneratedByWorldBindingService",
        default_area_size = { x = 160, y = 4, z = 160 },
        area_spacing = 220,
        spawn_zone = {
            name = "SpawnArea",
            size = { x = 140, y = 1, z = 140 },
            y = 0,
            transparency = 1,
        },
    },
}
