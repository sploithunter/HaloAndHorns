# Achievement banners

Two low-poly, bone-rigged cloth silhouettes intended for the outside of player bays:

- `champion_standard`: a formal shield-tail standard.
- `victory_swallowtail`: a more martial split-tail pennant.

Both assets use the same contract:

- The printable skinned mesh is named `Cloth`.
- UV0 fills the complete 0–1 square, front-facing and top-to-bottom.
- The armature is named `AchievementBannerRig`.
- Deform bones are `ClothUpper`, `ClothMidUpper`, `ClothMiddle`, `ClothMidLower`, and
  `ClothTip`, parented below the non-deforming `BannerRoot`.
- The rigid wall hardware is named `Mount`.
- Front faces point toward Blender -Y. Roblox's FBX importer receives -Z forward / Y up.

The cloth is deliberately neutral in the FBX. The included heraldic textures are previews and a
fallback only; `AchievementBannerRenderer` replaces the color map at runtime with a cached
`EditableImage`, so achievement copy is actually printed in the UV and deforms with the bones.

Rebuild everything with Blender 5.1+:

```sh
/Applications/Blender.app/Contents/MacOS/Blender \
  --background --factory-startup \
  --python scripts/blender/build_achievement_banners.py -- \
  --output-dir assets/source/props/achievement_banners/generated
```

The build writes one editable `.blend`, one Roblox-ready `.fbx`, two preview renders, and a JSON
integrity report per silhouette. Generated files are checked in because these small assets are the
actual source/import handoff, not disposable local workbench output.
