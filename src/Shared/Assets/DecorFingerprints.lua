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
]]

return {
    heaven_archive = { mesh = "rbxassetid://107064587581875", hash = 1169212968, verts = 13537, faces = 4785 },
    heaven_compass_banner = { mesh = "rbxassetid://126547680137901", hash = 3360793824, verts = 6337, faces = 2337 },
    heaven_diamond_altar = { mesh = "rbxassetid://126005129346568", hash = 3893299428, verts = 13132, faces = 4494 },
    heaven_flamecrest_shield = { mesh = "rbxassetid://121112483596299", hash = 3466807464, verts = 10794, faces = 3867 },
    heaven_gilded_bookcase = { mesh = "rbxassetid://79109805720279", hash = 3849671704, verts = 25416, faces = 9999 },
    heaven_golden_codex = { mesh = "rbxassetid://93357758110131", hash = 2159345648, verts = 13916, faces = 5037 },
    heaven_golden_guardian = { mesh = "rbxassetid://101340013975688", hash = 196760232, verts = 12996, faces = 4482 },
    heaven_golden_throne = { mesh = "rbxassetid://105280295005484", hash = 2171034234, verts = 20735, faces = 9999 },
    heaven_ivory_throne = { mesh = "rbxassetid://108019197890274", hash = 3454540152, verts = 15087, faces = 5446 },
    heaven_marble_throne = { mesh = "rbxassetid://106151763349044", hash = 4162372688, verts = 14354, faces = 5017 },
    heaven_star_fountain = { mesh = "rbxassetid://113501778730244", hash = 408469823, verts = 11268, faces = 4430 },
    hell_gate_of_damned = { mesh = "rbxassetid://117820702640265", hash = 2171985896, verts = 19096, faces = 6625 },
    hell_infernal_archive = { mesh = "rbxassetid://137121529248082", hash = 3985696440, verts = 16488, faces = 5805 },
    hell_infernal_crest = { mesh = "rbxassetid://96625994011225", hash = 2546386960, verts = 15966, faces = 5458 },
    hell_infernal_fountain = { mesh = "rbxassetid://111269812210249", hash = 321370480, verts = 24071, faces = 10000 },
    hell_infernal_throne = { mesh = "rbxassetid://106627197219124", hash = 4000159784, verts = 25198, faces = 10000 },
    hell_infernal_throne_flat = { mesh = "rbxassetid://114695375342832", hash = 1026404728, verts = 22200, faces = 9999 },
    hell_skull_banner = { mesh = "rbxassetid://102347044634165", hash = 1460936944, verts = 13137, faces = 4667 },
    hell_skull_lantern = { mesh = "rbxassetid://83676170999237", hash = 4162337856, verts = 12466, faces = 4360 },
    hell_skull_sconce = { mesh = "rbxassetid://139506418143371", hash = 2566585512, verts = 14475, faces = 5104 },
}
