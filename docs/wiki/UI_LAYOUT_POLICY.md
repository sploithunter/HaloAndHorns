# UI Layout Policy

Roblox UI must remain correct across phones, tablets, desktop windows, and ten-foot displays.
Responsive relationships—not guessed screen coordinates—own placement.

## Placement rule

- Use anchors, scale components, layout objects, constraints, and safe-area/inset APIs for major
  placement and sizing. Runtime pixel bounds are diagnostics, not layout inputs.
- A pixel offset is not a placement system. Do not use large X/Y offsets to move a panel across the
  viewport, compensate for the wrong parent, or approximate a screen corner.
- Non-zero pixel offsets are allowed only as small, local alignment corrections after the responsive
  layout is already correct: resolving a slight overlap, optically centering fixed panel chrome, or
  matching a measured external inset.
- Every non-zero placement offset needs an adjacent code comment explaining the stable reference and
  why scale/anchors/layout alone cannot express the correction. If that justification stops being
  true, remove the offset.
- Treat offsets as minute nudges, not coordinates: a large offset is evidence that the anchor,
  parent, or layout relationship is wrong and must be fixed instead.
- Prefer zero offsets. Fixed pixel sizes for icons, strokes, corner radii, and other internal chrome
  are separate from viewport placement, but still belong inside a responsively placed container.
- When one responsive surface replaces another, mount both in a shared responsive parent and author
  their relationship with scale components. Add `UISizeConstraint` and, where shape matters,
  `UIAspectRatioConstraint`; never read `AbsolutePosition`/`AbsoluteSize` and feed those pixels back
  into `UDim2.fromOffset`. Merge's lower `ResponsiveDock` is the reference implementation: Classic
  Pets and the tutorial own non-overlapping viewport shares, with explicit minimum and maximum sizes.
- When one independent HUD surface must follow another, use the leader's live rendered edge. In the
  Merge place, the People list docks beneath `MergeWaveBar.WaveMeter`, inherits its rendered width,
  right edge, and chrome scale, and adds a viewport-relative gap. Its per-device values are startup
  fallbacks only. Clamp followers to the viewport when the leader's safe-area coordinate extends
  slightly beyond an edge on a small device.

The quest/tutorial upper-right surfaces illustrate the boundary: their shared `{1,0},{0,0}` dock and
right anchor perform placement. The quest tracker's measured 14px top and 4px right adjustments only
match Roblox's rounded-screen People-list inset; they do not carry the panel across the screen.

World-space BillboardGuis are still viewport-facing UI. Pixel-designed billboard contents must use
the shared viewport `UIScale`, with bounds and scale limits authored in config. Merge hatcher-egg
health bars follow the same viewport factor as the wave meter, so they shrink on phones without
changing their world offset or maximum viewing distance.

Tutorial target callouts are part of the responsive HUD too. The Merge `CLICK HERE` cue keeps one
authored desktop footprint and applies a config-owned display-class scale; phone uses 0.5 for both
the unlock and install targets so the callout does not obscure the menu it explains.

Cross-`ScreenGui` overlap must use config-owned `DisplayOrder`; descendant `ZIndex` cannot establish
priority between independent screen roots. The compact expanded menu therefore owns a dedicated
overlay above ordinary HUD cards such as `SquadHud`, while the pet cards remain visible underneath.
Its config-owned two-column geometry must allocate all four rows of its eight utility actions, and
its minimum scale must retain 44px touch targets. Tutorials and true modal surfaces retain higher
display orders except where an intentionally open utility menu must remain actionable.

Classic mode's full utility tray, Pets control, and Merge tutorial share authored lower-dock regions.
Pets and the tutorial are siblings in `HotbarBar.ResponsiveDock`, use scale-only placement, and carry
touch/readability constraints. The config invariant is tray reserve → Pets share → tutorial share;
headless tests reject overlap between the Pets and tutorial proportions.
