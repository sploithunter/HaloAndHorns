# UI Layout Policy

Roblox UI must remain correct across phones, tablets, desktop windows, and ten-foot displays.
Responsive relationships—not guessed screen coordinates—own placement.

## Placement rule

- Use anchors, scale components, layout objects, constraints, safe-area/inset APIs, or measured
  parent-relative geometry for major placement and sizing.
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
- When one responsive surface replaces another, copy the live surface's measured final bounds after
  its constraints/UIScale have resolved. Do not duplicate its nominal design pixels in a second
  config. The Merge tutorial card replacing the central hotbar is the reference implementation. If
  a visible independent control occupies part of that footprint, preserve the replacement's aligned
  right edge and trim only its colliding left edge. Merge applies this clearance to both the classic
  menu pane and the expanded compact popup, so an explicit Classic preference remains usable in a
  narrow window.
- `FullscreenExtension` can shift a direct `ScreenGui` child by the live safe-area origin even when
  `IgnoreGuiInset` is true. When targeting absolute screen coordinates, derive that origin from the
  object's current assigned offset and rendered anchor, then make one idempotent assignment. The
  Merge tutorial uses this rule to avoid alternating between raw and corrected positions.
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

Classic mode's full utility tray and the Pets hotbar flank share the lower-left region. On constrained
screens, Pets docks immediately beside the tray's measured right edge; it is not allowed to remain
under tray buttons. The Merge tutorial then treats that live Pets control as a left blocker too, so
the complete order stays tray → Pets → tutorial without relying on a nominal viewport breakpoint.
