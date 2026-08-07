# Named-Trial Egg Rewards

Status: implemented 2026-08-07; Studio and live trade-return verification remain.

Each of the eight named trial tracks (Heaven/Hell × Grass/Desert/Ice/Lava) awards exactly one
evolving inventory egg. `configs/trial_rewards.lua` is the milestone SSOT.

| Claimed milestone | Held egg state | Huge chance |
| --- | --- | ---: |
| 10 | Base Celestial/Obsidian | 5% |
| 25 | Golden | 5% |
| 50 | Rainbow | 5% |
| 90 | Rainbow, charged | 10% |
| 100 and Level 50 | Huge Celestial/Obsidian Egg | 100% |

The 100-clear egg guarantees Huge independently of its normal 5% Golden and 0.5% Rainbow variant
roll. Hatching at any earlier stage is permanent: the pet received is final and never participates
in later reconciliation. The inventory UI therefore requires a deliberate hold confirmation before
hatching an egg that can still evolve.

## Identity and anti-duplication contract

- The one-time ledger is `GameData.TrialEggRewards.tracks[award_id]`.
- The canonical inventory key is `trial_reward|<award_id>|<awarded_to_user_id>`.
- Only that exact record key, with matching immutable award metadata, can use the trial hatch or
  evolution path. A copied record under any other key is rejected.
- Trading transfers the exact key and snapshot through escrow. A different owner may hatch the
  frozen egg but cannot advance it. If the exact egg returns to the original recipient, it catches
  up to that account's claimed milestone.
- A missing, traded, or already-hatched egg is never re-granted after the ledger records its grant.
- Admin reset removes award eggs/pets and clears the ledger so creators can retest safely.

Existing accounts reconcile from claimed named-trial quests. Displayed sequence numbers and direct
counter edits do not award a stage unless the corresponding quest reward was actually claimed.
Legacy Platinum egg definitions remain loadable for old inventory records, but named-trial quests no
longer award new Platinum eggs.
