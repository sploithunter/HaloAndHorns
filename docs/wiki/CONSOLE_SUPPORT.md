# Console Support

## Dynamic menu focus performance

`FocusNavigator` must coalesce descendant changes before rebuilding directional neighbors. Inventory
draft selection destroys and recreates many card buttons in one batch; rewiring once per added card is
cubic work on large inventories and can hang Studio. Mouse/touch mode performs no directional-neighbor
work. Gamepad mode schedules at most one deferred rewire for the batch.

Status: implementation retained but runtime-disabled (2026-08-15) after the first published console
build was rolled back. `configs/game.lua` owns the `console_support` kill switch. When false, the
client does not install console actions or enter gamepad/ten-foot presentation; established touch
and keyboard/mouse behavior remains active. Re-enable only after the verification matrix below.

## Controller Contract

| Input | Action |
| --- | --- |
| Left stick | Roblox character movement |
| `X` | World interaction: hatch, gate, altar, shop, beacon |
| `A` | Confirm or activate the selected UI control |
| `B` | Close the top custom menu and restore focus to its opener |
| `LB` / `RB` | Select previous / next bound hotbar slot |
| `RT` | Cast or consume the selected hotbar slot |
| `LT` | Toggle autocast for the selected power |
| `Y` | Cycle Farm Off / Near / Far |
| D-pad left / right / up / down | Pets / Powers / Quest / Settings |

The hotbar shows the selected slot with a strong gold outline and publishes a compact controller
legend. Native Roblox `Activated` remains the confirm seam for buttons so mouse, touch, and gamepad
share one implementation.

## Runtime Architecture

- `InputContext` classifies input mode (`keyboard_mouse`, `touch`, `gamepad`) independently from
  display class (`phone`, `tablet`, `desktop`, `ten_foot`). It publishes both on `LocalPlayer`; a
  controller connected to a desktop does not accidentally force console sizing.
- `ConsoleActionRouter` owns semantic gameplay actions through `ContextActionService`. It calls the
  established menu and hotbar seams instead of duplicating gameplay logic.
- `FocusNavigator` contains selection inside the active custom modal, computes geometric neighbors,
  scrolls the selected control into view, and restores the opener when the menu closes.
  Custom focus artwork is assigned through each `GuiObject.SelectionImageObject`; `GuiService`
  does not expose a global selection-image member in the live Studio/client API.
- `InputGlyphs` is the single source for controller-facing labels and tutorial substitutions.
- `ConsoleHotbar` is pure selection/wraparound logic, covered by headless tests including a binding
  disappearing while selected.

## Ten-Foot Presentation

Console-sized displays use larger safe-edge margins, a slightly larger viewport scale ceiling, and
a raised hotbar/player/squad layout to stay out of television overscan. Game announcements are
mirrored to the existing floating banner on ten-foot displays because the Roblox chat window is not
a reliable primary notification surface from couch distance. Ordinary player chat is not disabled.

Tutorial copy swaps to controller language at runtime and refreshes if the player changes input
method mid-session. Every authored `ProximityPrompt` uses `ButtonX` on gamepad.

## Verification Matrix

Automated coverage validates input/display classification, glyph text, and hotbar selection. Before
a console release, manually verify on Roblox's console/device emulator and one physical controller:

1. fresh-player companion choice and all tutorial interactions;
2. altar, realm/trial gates, shops, eggs, and mission beacon prompts;
3. every core menu, scrolling list, slider, close/back path, and opener-focus restoration;
4. hotbar selection, cast, consumables, autocast, Farm cycling, and rebinding;
5. couch-distance readability and safe margins at common 1080p overscan settings;
6. controller disconnect/reconnect and switching between controller and mouse without reopening UI.

Roblox's own system menus and chat entry retain platform-native behavior; game-authored announcements
use the banner mirror on console.
