--[[
    DecorFingerprints — blessed mesh fingerprints for the ROT ALARM (Jason
    2026-07-15: 'save a hash and compare on boot'). Roblox's delayed asset
    re-encode can silently mangle uploaded meshes HOURS after they verify
    clean (docs/ROBLOX_MESH_TEXTURE_KALEIDOSCOPE.md). Each entry is an
    FNV-1a hash over quantized vertex positions + vert/face counts,
    computed via EditableMesh at BLESS time (visually verified state).

    MissionInstanceService:_assetRotCheck() recomputes at boot (Studio
    sessions) and WARNs '[ROT ALARM]' on any drift. Legacy Synty props are
    absent: EditableMesh needs our own assets, and 2021 assets never rot.

    RE-BLESS (only after visual verification!): recompute via the same
    hash (see _assetRotCheck) and update the entry alongside the registry
    change in scripts/mission_decor_model_ids.json — same commit.

    The table was re-blessed 2026-07-15 from Workspace._MeshyLineup SHIP
    (MissionProps).
]]

return {
    heaven_archive = { mesh = "rbxassetid://78031900206735", hash = 2495831986, verts = 13542, faces = 4785 },
    heaven_compass_banner = { mesh = "rbxassetid://123934269734118", hash = 3561412988, verts = 6416, faces = 2339 },
    heaven_diamond_altar = { mesh = "rbxassetid://84842558046045", hash = 2021085032, verts = 13152, faces = 4494 },
    heaven_flamecrest_shield = { mesh = "rbxassetid://124667039413678", hash = 2946780474, verts = 10795, faces = 3867 },
    heaven_gilded_bookcase = { mesh = "rbxassetid://79109805720279", hash = 3849671704, verts = 25416, faces = 9999 }, -- TextureID 10k (verified good); others are SA/bone-armor shipping
    heaven_golden_codex = { mesh = "rbxassetid://79025906147334", hash = 3527805972, verts = 13916, faces = 5037 },
    heaven_golden_guardian = { mesh = "rbxassetid://77496157366357", hash = 3467473080, verts = 12996, faces = 4482 },
    heaven_golden_throne = { mesh = "rbxassetid://79404346104290", hash = 2140130448, verts = 24237, faces = 20000 },
    heaven_ivory_throne = { mesh = "rbxassetid://109650476169656", hash = 1428836976, verts = 15129, faces = 5446 },
    heaven_marble_throne = { mesh = "rbxassetid://121186869634374", hash = 1685550640, verts = 14374, faces = 5017 },
    heaven_star_fountain = { mesh = "rbxassetid://106893725310650", hash = 1610113280, verts = 11268, faces = 4430 },
    hell_gate_of_damned = { mesh = "rbxassetid://78769818741284", hash = 391225486, verts = 19096, faces = 6625 },
    hell_infernal_archive = { mesh = "rbxassetid://89717900211635", hash = 4250749176, verts = 16488, faces = 5805 },
    hell_infernal_crest = { mesh = "rbxassetid://127699320929775", hash = 1279409592, verts = 15966, faces = 5458 },
    hell_infernal_fountain = { mesh = "rbxassetid://94148201608679", hash = 2929148352, verts = 24081, faces = 19996 },
    hell_infernal_throne = { mesh = "rbxassetid://134390034169903", hash = 1412525528, verts = 27028, faces = 19994 },
    hell_infernal_throne_flat = { mesh = "rbxassetid://114077872717626", hash = 3764863264, verts = 19438, faces = 20000 },
    hell_skull_banner = { mesh = "rbxassetid://112401985756621", hash = 2514287888, verts = 13180, faces = 4665 },
    hell_skull_lantern = { mesh = "rbxassetid://121415762722335", hash = 1425553520, verts = 12488, faces = 4360 },
    hell_skull_sconce = { mesh = "rbxassetid://78199195680560", hash = 4044160128, verts = 14475, faces = 5104 },
}
