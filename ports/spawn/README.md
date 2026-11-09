# Halo & Horns: Spawn Merge bay

An isolated Spawn capability assessment and first playable Merge bay. Roblox production code,
profiles, purchases, and published places are outside this prototype's write boundary.

## First playable contract

- Use a source-backed subset of HH's Merge prices, opening waves, and pet assets.
- Buy eggs, merge equal tiers, deploy defenders, start waves, and earn rewards.
- Restore a completed checkpoint after leaving and rejoining.
- Exercise two clients, rejected actions, duplicate commands, and a disconnect.
- Record observed Spawn behavior separately from unverified assumptions.

## Implementation boundaries

Content and tuning remain config-owned. Engine-independent rules are JavaScript modules with
Luau-derived parity cases; Spawn behaviors adapt those rules to the pinned engine. UI calls
validated gameplay commands rather than writing wallet or ownership state directly.

Detailed findings, setup, limitations, and verification evidence will be recorded with the
working prototype. The prototype is not a migration of live Roblox player data.
