# HH menus on Spawn: source audit

2026-11-09. Companion to [shared account assessment](SPAWN_SHARED_ACCOUNT.md).
This is an implementation/contract review with creator-supplied visual references, not a shipped
menu or a visual-parity claim. The open Merge Studio session was in Edit (`IsRunning=false`);
the creator subsequently supplied three client screenshots, recorded below.

## How HH builds menus

The UI is mostly constructed at runtime in Luau, not a set of Studio frames to export.
[Client boot](../../src/Client/init.client.lua) creates BaseUI first, releases the HUD-ready gate,
then constructs/registers panels in isolated tasks so one failed or stalled panel does not block
the HUD or the others. Panels expose `Show(parent)`, `Hide()` and `GetFrame()` to
[MenuManager](../../src/Client/UI/MenuManager.lua).

BaseUI actions can route to differently named panels: the Pets button opens **Inventory**.
Some tray buttons perform gameplay actions rather than opening a panel. Do not infer routing from
visible labels. The boot registers Inventory, Powers, shops, quests, daily/achievement panels,
trade/team, enchantment, promo/admin and related surfaces; they are not all simple grid variants.

The manager owns one main panel, the dim/click-blocking scrim, transition state and focus lifecycle.
`LargeMenuOpen` tells tutorials and other HUD surfaces to yield. Panels destroy/recreate their
frames on close/open and notify the manager when self-closing. It validates a requested destination
before closing the existing panel and cleans up failed construction to release transition locks.

Visual assembly comes from [BaseUI](../../src/Client/UI/BaseUI.lua),
[PanelChrome](../../src/Client/UI/Components/PanelChrome.lua),
[UITheme](../../src/Client/UI/UITheme.lua), [UIViewportScale](../../src/Client/UI/UIViewportScale.lua)
and config. Area/home-area palettes tint shared chrome; many pill borders/fills are nine-sliced
images with transparent centers. Inventory has substantial custom header/grid layout rather than
using precisely the same shell as Settings/Admin. Review actual output before standardizing it.
See [layout policy](UI_LAYOUT_POLICY.md) and [console status](CONSOLE_SUPPORT.md).

## The Pets menu is a squad editor

[InventoryPanel](../../src/Client/UI/Menus/InventoryPanel.lua) is approximately 9,800 lines and also
handles eggs, enhancements, consumables, gifts, quantity pickers, context actions, training/range
catalogs, tutorial guides and live replicated updates. A literal renderer translation would couple
the Spawn account interface to Roblox GUI instances, folders, attributes and global input listeners.

| Surface/interaction | Actual source behavior to preserve |
| --- | --- |
| Header | Close, relevant navigation/settings controls and card-size choices; responsive near-fullscreen panel, not a small floating buy/deploy HUD. |
| Categories/search | Configured buckets/counts, context-aware sorting/search including pet roles/abilities. Owned inventory and a loaned Range catalog have separate data sources. |
| Squad strip | A local working draft seeded from the currently deployed squad on every opening. Unlocked empty slots, future level milestone and recovery rings communicate capacity. |
| Pet tap | Inventory card adds one available copy to the draft; draft card removes one. It does not immediately change the deployed squad. Unique UID once; each complete enchant stack key independently counted. |
| Best Pets | Ranged/Melee/Tank/Support/Control add one eligible pet per click using source role-specific ranking. They do not deploy or silently replace an existing squad. |
| Reset | Restore the local draft from the live deployed squad. |
| Activate | One atomic squad replacement with request ID. Show pending, wait for result; success closes, rejection/timeout keeps the draft editable. A deliberately empty squad is valid. |
| Close while dirty | Inventory's guarded controls offer Activate-and-close, discard or keep editing. Unconfirmed deployment must not be painted as successful. |
| Pet information | Rich hover tooltip and configured right-click context menu. `_showItemInfo` itself only logs; it is not evidence of a working dedicated details window. Mobile needs an explicit accessible details/action control. |
| Quantity/destructive actions | Separate quantity/confirmation flows and protected-item rules. Rename/upgrade/sell/multi-hatch placeholders disabled in config are not implemented capabilities. |

Counts need special care: Roblox's replicated stack `Quantity` is **unequipped** stock, whereas
the shared ownership core stores **total** stock. Existing
[InventoryDraftView](../../src/Client/UI/Menus/InventoryDraftView.lua) reconstructs total as
unequipped + deployed, then subtracts drafted copies. If Spawn receives canonical total ownership,
do not add deployed copies a second time. Keep the full `id:variant:enchant` identity and retain
metadata for fully equipped zero-available stacks so removing a draft copy restores its card.

Source cards use flat thumbnails, even when an item flag is named `use3DModel`; the old viewport
helper remains in the file but the active renderer calls the image path. Inventory rows are
virtualized/recycled through [VirtualGridWindow](../../src/Shared/UI/VirtualGridWindow.lua), with
visible rows plus overscan. Preserve bounded rendering and avoid per-card global input handlers.

Merge's observer explicitly reserves the ordinary Squad HUD for the player's deployable team and
uses separate floor-mounted hatcher surfaces for NPC squads. Owned Pets, temporary Simple escort,
hatcher rosters and the physical egg board must retain distinct identities and command paths.
An egg dropped onto a hatcher is not an owned-pet equip or permanent inventory grant.

## Mapping to Spawn

Reviewed the authenticated Game UI guide at engine-doc revision
`45303e2434b43467e261cbe2a690ca9fe36faa31`, the API reference and the existing lab UI/input modules.
[Public contract](https://www.spawn.co/llms.txt) documents the HTML UI and authenticated docs doors;
[Game UI guide](https://www.spawn.co/api/sdk/v1/a19e63cf-decf-46c7-9912-6505c59515d5/agent/skills/game-ui)
contains the specific modal/input/layout contract. These capabilities require runtime verification
in our eventual menu; this audit does not claim that verification has happened.

| Roblox implementation | Spawn adaptation |
| --- | --- |
| ScreenGui + scrim + display order | One HTML menu root using native `data-modal` ownership. It releases the cursor and dims/disables siblings. Hide conflicting HH HUD surfaces and suspend egg-world gestures; do not layer several competing modal roots. |
| MenuManager lifecycle | A small page-local menu controller with open/switch/close, panel construction/error cleanup, dirty/pending guards and opener focus restoration. View preferences/drafts stay local; only authoritative account mutations persist. |
| UDim2, UIScale, layout objects | CSS grid/flex, responsive constraints and scrolling. Account for Spawn's rail reservation, safe-area and touch-corner CSS variables; validate actual available space, not only viewport width. |
| Nine-sliced Roblox images | Export authorized image bytes and map skin semantics using supported CSS/image composition (for example border-image after testing). `rbxassetid://` references are not browser assets. Preserve HH's visual reference; builder style advice is not an engine limitation on rounded artwork. |
| MouseEnter/right click + global UIS | Scoped delegated pointer handlers with cleanup; tap/keyboard-accessible details/actions. Keep text inputs and scroll gestures from moving the body/camera or dropping eggs. |
| Escape/ButtonB | Spawn owns Escape for chat/cursor release. Declare an HH menu action and visible close/back controls. Test a compatible close-only policy; never open a menu on Escape or pointer-lock loss. |
| RemoteEvent + result | Declared page action → player input → authoritative account handler → matching result/projection. Local button animation or optimism is not acknowledgement of saved ownership/equip. |
| Folder/attribute subscriptions | Stable account/view selectors and keyed DOM nodes. Avoid rebuilding the whole grid or restarting animations on every combat tick; mount/unmount listeners cleanly. |
| GuiService focus/controller routing | DOM focus containment/return and declared gamepad actions must be implemented/tested. Existing Roblox controller code is retained but disabled in current `configs/game.lua`; do not call it a proven console baseline. |

Opening a multiplayer inventory is not a reason to set `ctx.place.timeScale=0`: that pauses the
whole place for everyone. The personal menu should manage its own input, while authoritative
combat/recovery continues according to game rules. Private draft selection belongs to its owner;
do not broadcast the complete account merely to simplify the menu renderer.

## Close-path finding and implementation order

The source X and Trade navigation use `_requestClose`, but MenuManager's ordinary close/toggle
and panel-switch paths call `Hide` directly. That bypasses the panel's dirty-draft prompt on those
routes. Treat this as a **source-level finding**, not a newly reproduced Roblox visual bug.
The Spawn menu should route all user dismiss/switch requests through one draft/pending policy.

First implement the shared menu shell and its input/close policy. Then the flat owned-pet grid,
bounded scrolling, information/actions and squad draft/Reset/Activate flow against the shared
account interface. Keep temporary Merge roster/egg interactions in their existing game adapters.
Full/Simple lifecycle and genuine personal hatch/reward grants remain separate implementation work.

Validate desktop and narrow/short touch viewports, Spawn rail/safe edges, large inventories, search
focus, drag cancellation, loss/reacquisition of cursor, delayed/rejected/duplicate acknowledgements,
dirty close/switch/reopen, recovering slots and ownership changes while editing. Existing Roblox
smoke suites are useful scenario inventories, not evidence that these work in Spawn.

## Creator screenshots, 2026-11-09

The three original PNGs are preserved unmodified in the local ignored archive
`test-results/spawn-menu-references/2026-11-09/`, with dimensions and SHA-256 in `manifest.json`.
They are visual references, not runtime game assets. The archive is not included in the PR.

| Reference | Observed presentation | Port consequence |
| --- | --- | --- |
| `wall-and-hotbar.png` (1286×1005) | Physical wall management board, gold-framed bottom action bar, Pets/Powers/Board flanks. The board has Rebirth, Buy Egg, Spawn Level and multiple gem upgrades. | Keep world management at the wall and player actions in the HUD. The current Spawn wall only implements the lab's Buy/Spawn actions; the other source upgrades are still outside that slice. Screenshot prices/progress are a particular account state, not default tuning. |
| `merge-hud-and-team.png` (1664×1082) | Separate top player/progression readout, upper-right wave/People panels, right-side MY TEAM list, bottom hotbar and left-side combat rows. | Preserve distinct player-team and hatcher-combat information. The image alone does not identify every left-side row's owner; use source bindings. Reflow panels around Spawn's rail rather than copying Roblox screen coordinates. |
| `inventory-overview.png` (1624×1040) | Near-fullscreen charcoal inventory with gold pill borders, white type and dimmed world. Header: Delete, Cards S, Hatch Auto, Hatch count, Trade, X. All/Pets/Items/Enhancements/Eggs tabs; Search, five Best Pets buttons, Reset, Activate; squad strip above a dense scrolling flat-card grid. | Use this hierarchy and HH artwork/palette as the first visual target. All is selected in this capture. Responsive card density must follow the chosen size and usable space, not fixed columns inferred from this one screenshot. |

Pet cards carry several simultaneous signals: portrait, colored borders, role/identity badges,
quantity and stat/ability indicators. Preserve the source badge meanings and exact pet identity;
do not replace the cards with text-only tier buttons or invent missing ability outcomes. The small
card setting is visibly dense; readable information/actions and bounded rendering remain necessary.
The header counts 1805 = 428 Pets + 16 Items + 1353 Enhancements + 8 Eggs. These are category display
counts, not a proof of 428 total owned pet copies. Source config counts stacks as single display
items, and the projected equipped-stack ghost rows also contribute to the Pets tab count.

**Capacity correction prompted by the image:** `Squad (deployed) — 11/11` is valid. In
[InventoryService](../../src/Server/Services/InventoryService.lua), earned/perk/upgrade/progression
bonus and replicated compatibility bonus feed
[PetEquipCapacity](../../src/Shared/Game/PetEquipCapacity.lua); it takes the larger of those axes,
then adds the paid slot delta to both current capacity and the progression ceiling. With base 3,
earned 7, progression cap 10 and extra-pet feature 1, the result is 11; a new player with that
feature gets 4. `max_slots=10` alone is not the final universal cap. The screenshot does not prove
which entitlement this particular account has, and Roblox purchases do not automatically carry
over to Spawn. The portable resolver now matches 36 executed Luau cases and validates an 11-slot
squad through the existing ownership/equip core.

These establish enough of the overview/hierarchy to begin the menu implementation. Hover details,
dirty-close prompts, pending/rejected Activate states and mobile layout are not shown; their
behavior remains source-backed and needs later runtime/visual checks. No such behavior can be
inferred solely from these still images.
