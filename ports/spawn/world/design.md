# Halo & Horns: Merge Bay Lab

Claim Heaven bay 01, collect Waycoins, buy and merge eggs, install four hatcher teams, defend
against the ten canonical opening waves and collect rewards. Escapes cost the reserve eggs;
wave 10 saves a checkpoint. Completed progress belongs to the player's protected save.
Only one player owns this bay per room; visitors can watch, and departure releases it.

2026-11-09: ColoradoPlays requested a Spawn capability assessment and playable Merge bay.
The generic isometric arena was rejected. Preserve the authored Roblox bay's geometry,
scale and third-person presentation, importing source art rather than inventing a new arena.
The current slice has source prices, rewards, wave composition, basic attacks and recovery.
Full combat roles, powers, hatcher endurance, workshops, equipment and player migration remain
later work. Use no runtime inference for deterministic combat or economy.

2026-11-09: ColoradoPlays requested Roblox-style egg dragging and stacking. Drag from the board
onto an empty stand to install; stack equal tiers on the board or an occupied stand to upgrade.
Drops cancel safely; stands are locked during combat. The original Tier-4 lab cap is superseded by the decision below.

2026-11-09: ColoradoPlays requested HH's egg tiers/upgrade progression and combat presentation,
and clarified that attack means formation, spacing, lunging and damage streaming, not a walk clip.
Use all 56 source tiers (28 normal + 28 prototype Huge), source prices and 3–9 team positions,
and the 28 actual source egg models. Equal pairs advance until the configured terminal tier.
Use real Walk and Attack actions, source role formation math, stable targets, separated slots,
hit-driven contact/recovery, alternating Doggy sidesteps and hit flinches. Drive numeric damage
and elemental impact/death FX from applied damage only; merge actions sparkle. The lab still uses
Doggy/Bear stand-ins and basic ten-wave rules; full species drafts, powers and combat balance are
not yet a faithful port. Cosmetic root offsets must never accumulate into authoritative positions.

2026-11-09: ColoradoPlays identified the blank authored side wall as the upgrade-board location.
Mount the working Buy Egg / Upgrade Spawn board on Heaven_01_WallBoard, flat against its inward
face at HH's 14x8-stud size and source bottom height. Remove the floating generator HUD control.
Wall clicks use native object UI events and the presser's own command path; upgrades require the
owner to stand near the board. Other Gem upgrades/rebirth are still outside this lab's scope.
