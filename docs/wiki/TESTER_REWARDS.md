# Beta Tester Reward Campaigns

Status: week-one Beta Byte content is wired. The real claim flow is enabled in Studio while public
claiming remains disabled pending the advertised Friday/Saturday UTC window.

## Player contract

- A player who joins during an active campaign reserves eligibility.
- The campaign grants exactly **one held egg** when that player reaches claimed level 2.
- That same egg, or the one pet hatched from it, becomes Golden at claimed level 5 and Rainbow at
  claimed level 10. The hatch has a configured 1% chance to make that pet Huge; Huge is an outcome,
  never a second pet.
- Both egg and pet remain tradeable. The immutable `awarded_to_user_id` controls progression: a
  different owner freezes the stored tier; returning it to its awarded player catches it up.
- `hatcher_user_id` remains ordinary hatch provenance and is intentionally separate from the award
  recipient.

## Configuration and persistence

`configs/tester_rewards.lua` is the campaign SSOT. Each campaign authors its egg/pet ids, claim
window, claim limit, level thresholds, Huge chance, and version. Keep closed campaign definitions in
the file so old awards can continue to reconcile. Turning `claim.enabled` off stops new eligibility;
it does not invalidate existing awards.

The once-only ledger lives at `GameData.TesterRewards.campaigns[award_id]`. The held egg uses a
unique inventory record key (`tester_reward|award_id|user_id`) while retaining its authored `id` for
the normal egg config and hatch UI. Egg and pet records carry `award_id`, `awarded_to_user_id`,
`award_tier`, and `award_version` through hatch and full-record trade escrow.

Do not enable a campaign until its egg source and pet variants exist in `configs/pets.lua`; config
validation rejects dangling content ids. `huge_pet_id` is optional because the normal Huge treatment
can resize the same species, but a campaign may name a distinct Huge species.

## Week one: Beta Byte

- Campaign id: `beta_week_1_2026`; public `claim.enabled = false` until the advertised session.
- `claim.studio_enabled = true` opens the same reservation and level-gated grant flow only when
  `RunService:IsStudio()` is true; it never opens production claiming.
- One Beta Tester Egg at claimed level 2 hatches the exclusive Grass/Melee robot dog **Beta Byte**;
  the same held egg or resulting pet becomes Golden at 5
  and Rainbow at 10. The hatch has a 1% same-species Huge roll.
- Regular and Golden use authored models/textures and transparent flat card art. Rainbow deliberately
  reuses regular assets plus the standard runtime Rainbow treatment.
- The Admin panel can replace the current test copy with Basic, Golden, Rainbow, or forced-Huge
  Rainbow eggs while the campaign is closed. Admin Reset to Beginning removes any held/hatched
  tester award and clears its ledger so the full claim flow can be replayed.
