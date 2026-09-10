# After atlas capture and visual QA

September 8, 2026. [Open the after atlas](after-atlas.html). **37 original camera positions and targets, plus five supplemental views**, captured through native Studio `screen_capture` after the complete 17-pass replay and subsequent installation/reapplication of the arena access ramp as pass 18. This records the authored preview, not production gameplay acceptance.

## Capture conditions

- Preview Studio `3c01a32c-1ba9-4e11-b43e-133bdf27dacb`, Edit mode throughout. Camera ownership was explicitly released after ramp QA. No geometry, scripts, assets, water settings, lighting or user graphics settings were modified for capture.
- Existing daylight: Lighting ClockTime 14, Brightness 2, ExposureCompensation 0. Client runtime is absent in Edit: no client-only pool mist, gate ember fields, swimming fish or fishing interaction feedback. Static native asset illumination remains present. This is an ambient-client-FX-off art atlas.
- The original manifest records FOV 100° only for the whole-map view; the other 36 use an explicitly documented 70° assumption. Position and look target match the original manifest exactly. Five supplemental positions are recorded separately, with `matched_manifest_camera: false`.
- Original graphics quality was **not recorded**. Native tool output now measures **1807×950**, versus original **1386×645**. The differing aspect ratio changes horizontal framing. No exact graphics-quality, resolution or pixel-framing equivalence is claimed.
- Tool-returned JPEG pixels were decoded into PNG without resizing, cropping, sharpening, repainting or other image edits. PNG storage does not recover JPEG detail. The contact sheets are resized derivatives for inspection only.
- Starting native camera CFrame, Focus, CameraType Fixed and FOV 70 were restored after the final supplemental view. Lighting was untouched; no user settings were changed.

## Inspection record

All 42 captures were inspected in five contact sheets, with the corrected Bragg annulus and added ramp also inspected full size. Full-size follow-up covered the obstructed Bragg camera, both arrival branch joints, Bragg east annulus, arena crest and ramp overview.

| Area | Observation |
|---|---|
| Arrival / gates | Main paths, branching landings, gate backs and readable gateway identities are present. Low angles show fitted paving boundaries and normal changes in texture across pieces; no visible open ground crack at the sampled joints. |
| Bragg | Ranking bays, mannequins, alternating displays and central split display are present. **04-bragg-5 is fully obstructed by the taller facade at the original camera**; retained rather than silently moved. Other matched views and the supplemental east-annulus view cover the composition. Annulus has a fitted faceted boundary, visible at low angle. |
| Garden | Full-span egg arch, landscape accents and garden approach read coherently; the large green field remains intentionally open. |
| Arena | Stand seats, facade, arena crest and added access ramp are visible. Low-angle crest view shows straight dark floor-panel joins through and below the crest. These are intentional recessed mortar/cleaved panel boundaries (confirmed by the owning implementation task); the circle uses two realm-colored inlays. Their visibility is not a demonstrated geometry fault or a temporal flicker result. |
| Heaven fishing | Real Terrain water, dock approaches, rods and tree perimeter are visible. Runtime fish are intentionally absent. |
| Hell fishing | Terrain water, eight dock positions, rear stand landscape and outer trees are visible. Runtime green mist is intentionally absent; these stills cannot accept its density or motion. |
| Ramp overview | Two flights, rails and the elevated crossing are readable against the stand and shoreline. Traversability results belong to the separate native ramp QA, not this image review. |
| Whole map | Useful layout overview. Distant asset visibility and apparent detail differ with viewport/FOV/render settings; use closer views for asset acceptance. |

Stills **do not certify absence of temporal z-fighting/flicker**, motion quality, collision, traversal, performance, fish visibility underwater, or mist appearance. The native movement, lifecycle and checkpoint validations are separate evidence documented by their owning tasks.

## Files and recommended presentation

- [Manifest](after-screenshots/capture-manifest.json): 37 original camera records plus arrival west/east joints, Bragg east annulus, arena crest and ramp overview.
- [Ramp hero](after-screenshots/09-arena-access-ramp.png): preferred final presentation image; shows new access, stands and shoreline together.
- [Whole map](after-screenshots/00-whole-map.png): layout summary.
- Contact sheets: [1](after-screenshots/contact-1.jpg), [2](after-screenshots/contact-2.jpg), [3](after-screenshots/contact-3.jpg), [4](after-screenshots/contact-4.jpg), [5](after-screenshots/contact-5.jpg).

The HTML offers original/after toggles for the 37 matched records and full-size image dialogs. Before images remain the original files; supplemental views have no invented before counterpart.
