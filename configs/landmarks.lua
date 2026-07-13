--[[
    Canonical authored-landmark assets.

    These meshes are deliberately single, welded, Roblox-safe exports. Do not reimport the
    original million-triangle GLBs directly into Studio: Roblox's mesh processor can turn their
    split/degenerate geometry into the familiar "shredded" landmark failure.

    `scripts/studio/repair_landmarks.luau` is the one Edit-mode application path. It preserves
    authored placement, gameplay hosts/doors, and native effects while replacing only the visual
    mesh descendants. The source and generated exports live under assets/{source,exports}/landmarks.
]]

return {
    version = "1.0.0",

    golden_halo_cathedral = {
        source = "assets/source/landmarks/golden_halo_cathedral.glb",
        export = "assets/exports/landmarks/golden_halo_cathedral/golden_halo_cathedral_10k.fbx",
        triangle_budget = 10000,
        model_asset_id = "140651088118865",
        mesh_id = "rbxassetid://125770681066661",
        texture_asset_id = "75890962913613",
        texture_id = "rbxassetid://100420048146698",
        mesh_name = "GoldenHaloCathedralMesh",
        targets = {
            "Workspace.Maps.Heaven_1.GoldenHaloCathedral",
            "Workspace.Maps.Heaven_2.GoldenHaloCathedral",
        },
    },

    winged_portal_of_light = {
        source = "assets/source/landmarks/winged_portal_of_light.glb",
        export = "assets/exports/landmarks/winged_portal_of_light/winged_portal_of_light_10k.fbx",
        triangle_budget = 10000,
        model_asset_id = "91972102570553",
        mesh_id = "rbxassetid://110833360059124",
        texture_asset_id = "112250454917157",
        texture_id = "rbxassetid://138912051193725",
        mesh_name = "WingedPortalOfLightMesh",
        targets = {
            "Workspace.Maps.Heaven_2.MissionGate_Heaven",
        },
    },
}
