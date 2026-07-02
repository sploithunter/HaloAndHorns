# Reference Game Insights

Status: current

## Summary

The newer reference game at `/Users/jason/Documents/ColorfulClickers_exchange-rojo` contains many useful progression ideas, but its implementation is scattered across many one-off scripts. Use it as inspiration and translate concepts into config-driven services.

## Most Valuable Ideas

- Central global clock and deterministic daily behavior.
- Achievements over tracked counters.
- Rebirths as a reset-for-permanent-progress loop.
- Egg configs with costs, currencies, odds, secret/huge outcomes, and special pets.
- The reference developer-meet reward used a one-off `RewardPlayerForMeet` script that checks for `coloradoplays` on the server, then calls a special `DeveloperColorado` egg with Mini/normal/Huge Colorado outcomes. In this project, keep that as a config/service reward instead of a Workspace script.
- Pet team calculation with stats and enchants.
- Eternal/forever pet semantics: the newer reference game's equip-best logic treated an `Eternal` value as a percentage of the player's current top damage for the relevant damage type, rather than as a huge fixed stat. This keeps ultra-rare pets valuable forever without letting a traded/gifted endgame pet erase early progression.
- Huge Colorado in the reference was tied to rarity/eternal metadata, and the newer pet handler had scale helpers even though the active scaling call was commented out. In this project, model huge as an ownership trait with config-driven `huge_scale` so normal/golden/rainbow art can be reused.
- The reference spawner normalized spawned model parts by anchoring where needed and disabling `CanTouch` on non-star parts. For imported pet art in this project, keep a reusable normalizer instead of fixing each asset manually.
- Enchants such as HomeWorld, Efficiency, Tactics, Luck, Leadership, and SecretLuck.
- Reference enchants are tier-gated by rarity (`Legendary`, `Mythical`, `Secret`, `Exclusive`, `Huge`, `Colossal`) with `MaxEnchant`, `DefaultEnchant`, weighted chances, low/high value ranges, and a scale value. Keep that data shape, but add config-declared modifier semantics and store enchants only on unique pet instances.
- The reference enchanter used a procedural lightning burst through `ReplicatedStorage.SharedLib.Lightning` and a server `Lightning` remote. In this project the idea is translated into `Shared.Effects.EnchantLightning` and station config (`configs/enchants.lua`): successful rerolls can spawn a temporary copy of the selected pet and use its primary/first part as the lightning endpoint, making the animation portable across pet models without old Workspace remote scripts.
- Pet of the Day selected deterministically and displayed on a podium.
- Rare/dark breakable variants with low spawn weight and high value.
- Auto-targeting and auto-delete quality-of-life systems.
- Pet index and collection progress.
- The newer reference game's pet index records distinct pet name + type/variant combinations, not every owned copy. That maps well to a compact `PetIndex` profile table keyed by canonical pet/variant ids.
- The reference achievements are useful as tier ideas but are hardcoded around specific counters and polling. In this project they should become config tiers over K1 counters and react to `StatsService.CounterChanged`.
- The reference has several leaderboard families: total stat boards, daily/yesterday boards, and pet rarity boards for Huge/Eternal ownership. Port the concepts through `configs/leaderboards.lua` and a throttled `LeaderboardService`, not scattered OrderedDataStore scripts.
- Daily gifts, codes, and reward tracks.
- Limited stock pets/items.
- Seasonal chaseables and event currencies.
- Marketplace/exchange as a later, careful feature.

## Do Not Copy Directly

- Hardcoded Workspace paths.
- Workspace `Value` objects as source of truth.
- Scattered per-feature counters.
- External database/webhook marketplace design.
- One-off Workspace scripts for every area.
- Magic numbers buried in service logic.

## Translation Rule

For every reference feature, ask:

1. What config declares this content?
2. Which service owns the behavior?
3. Which profile fields persist it?
4. Which stats/counters observe it?
5. Which modifier pipeline stage affects it?
6. Which map hooks bind it to Studio geometry?

## Links

- [Decisions](DECISIONS.md)
- [Implementation Plan](../IMPLEMENTATION_PLAN.md)
