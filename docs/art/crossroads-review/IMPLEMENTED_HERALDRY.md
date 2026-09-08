# Arrival seal and native Bragg heraldry

2026-09-08. Source ready; root owns Edit application. This agent made only read-only Client queries during Play for current positions/native mesh bounds. No live mutation or asset upload.

## Exact contract

Config `configs/realm_crossroads_polish_heraldry.json`; ModuleScript-shaped source `tools/realm_crossroads/polish_heraldry.luau` returns `function(world,cfg)`.

```lua
local result = require(module)(workspace.RealmCrossroadsR4, cfg)
print(game:GetService("HttpService"):JSONEncode(result))
```

Run in Edit **after** shared core and Bragg geometry/polish passes. Requires `CrossroadsCraftR11.ArrivalSeal.SealInset` (or its prior retained backup) and `BraggRotundaR6.PodiumAlcoves`. Native Client query measured current seal center (0,0.29,100), radius3.75, thickness0.3, top0.44; cornice top19.6. Config matches these measured values. The original `SealRing` and `SealSurround` pieces are never changed.

Generated output `workspace.RealmCrossroadsR4.CrossroadsHeraldryR1`. Only the replaced original `SealInset` moves to `ServerStorage.CrossroadsHeraldryBackup`. All CSG/emblem preparation completes before that move or removal of previous output. A failure destroys the temporary assembly and preserves the live inset/current output. Reapplication computes from the original inset and replaces output, avoiding cumulative cuts. If core is rebuilt first, a fresh `SealInset` takes priority and supersedes the backup after successful preparation.

## Arrival seal

Three fitted visible pieces replace one blank inner disk:

- Negative-X ivory Heaven stone.
- Positive-X dark Hell stone.
- A bronze compass cross and central meeting diamond, plus geometric feather strokes left and cleft horn strokes right.

The strokes are abstract architectural inlay, not fabricated pet meshes or typography. Four booleans: unite all metal strokes; subtract that union from the disk; split remaining disk into west/east halves. Every rectangular motif corner is validated within the inset radius before CSG. No new top face rests on the old disk: it is removed only after all three disjoint replacements exist. All three have the same top0.44 and simplified static authored behavior. Existing outer gold ring, fitted surrounding pavers and invisible spawn remain unchanged. No glow, prompt, pulse or runtime geometry.

## Bragg category sculptures

Only three semantically matched native Models are proposed in this pass:

| Existing BoardId | Native cache model | Orientation |
| --- | --- | --- |
| crystal_crusher | pearl_quartz | yaw0; no directional face |
| eggs_hatched | wayfinder_egg | yaw180, consistent with native pavilion use |
| bosses_defeated | animal_skull | yaw180, consistent with approved Bragg skull placements |

Each native template is cloned from existing caches, scripts/prompts/GUI/tags stripped, dimensions bounded to height2.4/width3/depth2.4 and seated on a small stone mount atop its original cornice. The native artwork/texture remains intact. No new asset IDs, synthetic egg, pet silhouette or font. No model loading/upload fallback: missing cache means an explicit skip.

Safety checks require a supported header/cornice, width/depth sufficient for the mount, cornice at least0.2 above header bounds, and sculpture top below23. Headers, scopes, ranks, figures and 2/1/3 positions are untouched. Three is deliberate: other ranking categories do not receive misleading duplicate skull/egg symbols. Most Dragons, Enemies Defeated, Team Power, Highest Wave Cleared and Total Waves Cleared retain their exact existing text until appropriate native assets or bespoke heraldic art is reviewed. Decorative bays stay untouched.

Native Client inspection confirmed egg/skull models are upright and current skull instances use the same180° relationship specified here. Final direction from the inner viewing lane still requires the root screenshot check. A pedestal sculpture is an extra category cue; it does not replace or abbreviate the player's ranking name.

## Results and review

Returned table: `sealParts` (expected3), `emblems` (up to3), `skipped` with reasons. No external dependency is inferred from a skipped asset; report it explicitly. Approximate additions are three floor unions, three tiny mounts, and three native models, minus the old disk. No extra lights, particles, Humanoids or client loops.

StyLua and Selene executed on the owned source: zero errors/warnings/parse errors. JSON parsed with Python. Native application is not claimed.

Root native checks: top-down and eye-height seal capture; verify gold strokes read as one design, ivory is left/negative-X, dark is right/positive-X, and no metal reaches into the retained outer ring. Orbit at shallow angle to check no blinking. Walk all cardinal/diagonal crossings at24. Inspect all three emblem bays from the promenade and the entrance, ensuring no title overlap or odd asset orientation; skip/remove an emblem if it appears cluttered despite numeric checks. Reapply once in Edit, compare counts, unchanged routes and figure transforms. Shared frame-time/FX budget is unaffected by new animation because none is introduced.
