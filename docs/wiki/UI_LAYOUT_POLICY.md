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

The quest/tutorial upper-right surfaces illustrate the boundary: their shared `{1,0},{0,0}` dock and
right anchor perform placement. The quest tracker's measured 14px top and 4px right adjustments only
match Roblox's rounded-screen People-list inset; they do not carry the panel across the screen.
