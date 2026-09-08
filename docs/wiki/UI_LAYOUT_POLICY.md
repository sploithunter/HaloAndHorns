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
  into `UDim2.fromOffset`. Merge's lower hotbar is the reference implementation: one
  `GreaterHotbarFrame` owns the left controls, inner `Bar`, and right controls under one viewport
  scale, while the tutorial copies the inner `PillFrame`'s relative UDim geometry.
- When one independent HUD surface must follow another, use the leader's live rendered edge. In the
  Merge place, the People list docks beneath `MergeWaveBar.WaveMeter`, inherits its rendered width,
  right edge, and chrome scale, and adds a viewport-relative gap. Its per-device values are startup
  fallbacks only. Clamp followers to the viewport when the leader's safe-area coordinate extends
  slightly beyond an edge on a small device. `AbsolutePosition` includes Roblox's fullscreen safe-
  area extension (and can therefore be negative at the top); normalize the leader's rendered bounds
  into its `ScreenGui`-local viewport coordinates before deriving the follower's scale position.
  Never feed the raw rendered edge back into a `UDim2` pixel offset.

Farm & Fight's `UpperRightHudStack` is the reference for dependent HUD surfaces. The quest and
tutorial cards alternate at layout order 10, while the People list occupies order 20 in the same
full-viewport parent. A right-aligned vertical `UIListLayout` owns their relationship and naturally
uses each visible card's rendered `UIScale` and changing height. The shared `UIPadding` uses a
viewport-relative right inset; no surface measures another surface's screen coordinates.

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

The lower hotbar is a single responsive assembly in every HUD mode. `GreaterHotbarFrame` contains
`LeftControls`, the inner `Bar`, and `RightControls`; Pets and the compact Menu expander live on the
left, while Powers and Hoverboard live on the right. Only the outer frame owns `ViewportScale`.
Config-authored proportional spans partition the assembly, and internal button chrome uses the same
design canvas. Merge's tutorial replaces only the inner pill, leaving both flanks visible and
interactive. The full-screen `ResponsiveDock` is presentation-only and may host transient feedback;
it must not own persistent hotbar controls.

Trade's player picker keeps its fixed-height header and touch navigation above a flex-filled page.
Players and Preferences use separate vertical scrolling surfaces, so saved request/gift policies
cannot crowd out the player list on a short phone. Player rows put names above two full-width action
halves; no fixed button strip may subtract the name's entire width on portrait screens. Picker
geometry lives in `configs/trade.lua`. `TradeMobileLayoutSmoke.run()` checks rendered bounds, 44px
controls, final-row scroll reachability, disabled actions, and repeated empty refreshes in Studio
Client across five viewport sizes, using stubbed commands without sending real trades or gifts.

Live trading uses two columns on desktop and mobile: the local inventory includes highlighted
escrow cards first, followed by the selected category's available items; the partner column shows
only their offer. All offered categories stay visible when browsing Pets, Enhancements, or Eggs.
Partial stacks retain separate offered/available cards because escrow removes offered copies from
inventory. Tapping an offered card removes one copy; remaining copies keep the existing bulk-add
picker. The current gem offer is an explicit readout beside its editor.

Incoming requests respect the core UI safe inset; inventory-backed trade and gift flows use the device-safe area.
Fixed readable chrome surrounds flexible card areas, with 44px actions and a full-width category
selector. `TradeFlowLayoutSmoke.run()` exercises short landscape and desktop geometry plus local
escrow presentation, mixed-category highlights, state updates, and gift confirmation without real
inventory changes. Use `show("request")` or `show("gift")` for interactive emulator checks.

Live Trade and the gift picker temporarily use `DeviceSafeInsets` to reclaim the Roblox top-bar strip while retaining
notch/home-bar protection. The user allows their titles to run behind the top-left Roblox controls;
a 44px header keeps inventory controls below them, with the 44px close button inside the right edge.
Closing the final inventory window restores `CoreUISafeInsets` for other dialogs. Config owns the bounds/header;
native checks cover close containment, touch size, and restoration of the normal inset.
