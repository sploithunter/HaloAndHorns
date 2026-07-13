--[[
    Canonical authored-landmark asset configuration.

    This lives outside ReplicatedStorage.Configs on purpose: ConfigLoader owns runtime gameplay
    configs and requires an explicit schema for every entry, while these targets are consumed only
    by the Edit-mode repair tool. Keeping the data in a ModuleScript still gives Studio/Rojo one
    configurable source of truth without adding dead runtime config surface.

    Each landmark is a four-part SCENE. `triangle_budget_per_part` applies independently to every
    MeshPart (roughly 40k triangles total), never to the whole scene.

    Collision is explicit because these landmarks are playable architecture, not background art.
    PreciseConvexDecomposition preserves stairs, platforms, arches, and openings without reducing
    the whole scene to one broad box.
]]

return {
    version = "2.0.0",
    assets = {
        golden_halo_cathedral = {
            source = "assets/source/landmarks/golden_halo_cathedral.glb",
            export = "assets/exports/landmarks/golden_halo_cathedral/golden_halo_cathedral_4x10k.fbx",
            scene_parts = 4,
            triangle_budget_per_part = 10000,
            collision = {
                can_collide = true,
                fidelity = "PreciseConvexDecomposition",
            },
            model_asset_id = "129820085989007",
            mesh_ids = {
                "rbxassetid://127053095895949",
                "rbxassetid://124003797501179",
                "rbxassetid://79315645757809",
                "rbxassetid://97309641090328",
            },
            surface = {
                color_map = "rbxassetid://82696652371531",
                normal_map = "rbxassetid://133775478428688",
                roughness_map = "rbxassetid://84828665089495",
                metalness_map = "rbxassetid://101164403459134",
            },
            targets = {
                "Workspace.Maps.Heaven_1.GoldenHaloCathedral",
                "Workspace.Maps.Heaven_2.GoldenHaloCathedral",
            },
        },

        winged_portal_of_light = {
            source = "assets/source/landmarks/winged_portal_of_light.glb",
            export = "assets/exports/landmarks/winged_portal_of_light/winged_portal_of_light_4x10k.fbx",
            scene_parts = 4,
            triangle_budget_per_part = 10000,
            collision = {
                can_collide = true,
                fidelity = "PreciseConvexDecomposition",
            },
            model_asset_id = "76383615823518",
            mesh_ids = {
                "rbxassetid://80755936707598",
                "rbxassetid://75430684341700",
                "rbxassetid://103927852430951",
                "rbxassetid://127340787782635",
            },
            surface = {
                color_map = "rbxassetid://92282503652898",
                normal_map = "rbxassetid://82692855259607",
                roughness_map = "rbxassetid://99342671261435",
                metalness_map = "rbxassetid://104374982365559",
            },
            targets = {
                "Workspace.Maps.Heaven_2.MissionGate_Heaven",
            },
        },
    },
}
