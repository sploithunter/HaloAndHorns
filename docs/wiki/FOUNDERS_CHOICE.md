# Founder's Choice

Status: launch promotion implemented 2026-08-04; Founder’s Legacy fallback implemented 2026-08-08.

## Player contract

- The first **10,000 unique qualifying Roblox user IDs** may select one permanent game-pass-equivalent
  benefit after completing the tutorial. Existing veteran profiles qualify under the same claimed-level
  threshold used by the tutorial veteran skip.
- Eligible choices are Auto Collector, Speed Boost, Golden Touch, Rainbow Radiance, Huge Hunter,
  Deploy an Extra Pet, and Second Wind. VIP is deliberately excluded because it bundles several benefits.
- The selection grants gameplay benefit only. It does **not** claim or imitate Roblox Marketplace
  ownership, show a Robux price, or stack with the identical purchased pass.
- The in-game Robux shop treats the effective benefit as owned and blocks a duplicate prompt. If the
  player buys that exact pass outside the game, Marketplace becomes the source and their Founder's Choice
  is returned for another unowned selection.
- A qualifying Founder who already Marketplace-owns every pass in the seven-choice catalog receives
  **Founder’s Legacy** instead of a useless chooser. This is a hidden gameplay entitlement, not a Roblox
  game pass. While that Founder is present, the whole server receives **1.5x hatch luck** through the
  whole-hatch retry channel.

## Persistence and exact cohort limit

- Profile state: `GameData.FoundersChoice` (schema v14): cohort, eligibility decision, ordinal,
  selected pass, selection time, reselection count, and the permanent catalog-versioned Founder’s
  Legacy stamp.
- Atomic roster: DataStore `FoundersChoiceCohort_v1`, key `launch_10k`, one record containing
  `count` plus `claims[tostring(userId)] = ordinal`.
- Reservation uses `UpdateAsync`. Rejoin, retry, admin profile deletion, or a crash between reservation
  and profile save returns the same ordinal and cannot consume a second place.
- Studio uses an unlimited ordinal-0 reservation and does not consume the production roster.
- The explicit production test-ID allowlist (Colorado, Macros, SploitHunter, and SploitGiver) also
  uses ordinal 0 and never consults or consumes the production roster. Names/prefixes are never used
  for this entitlement decision. Existing roster claims are not deleted or renumbered.
- Legacy unlock stamps the current Founder catalog version. Later catalog additions do not revoke an
  already-earned Legacy or force the Founder to buy the new pass retroactively.

## Entitlement sources

`MonetizationService` recomputes one deduplicated `OwnedPasses` gameplay view from four distinct
sources: `marketplace`, `founder`, `creator`, and `test`. Client snapshots retain the source labels so
the shop can say **Founder Benefit** honestly. The creator no-pass balance gate suppresses automatic
Marketplace/creator/Studio-test sources while off, but retains an explicitly selected Founder
benefit. Admin Reset clears that selection, yielding a true no-pass baseline; choosing afterward
activates exactly one benefit for isolated testing.

Founder’s Legacy uses real `marketplace` ownership in production. Studio may use effective
creator/test ownership so the all-pass fallback can be tested; turning the creator game-pass gate off
suppresses those synthetic sources and restores the ordinary Founder chooser test path.

## UX and operations

- Eligibility fires the large gold launch banner and opens the responsive seven-choice modal.
- Selection requires a second confirmation. The modal can be dismissed and reopened through the
  **Founder's Gift** pill in the Robux Pet Shop.
- Founder’s Legacy suppresses the choice modal. Its first inactive-to-active server transition posts a
  gold chat announcement and large floating banner naming the entering Founder. The HUD shows the
  source-specific gold **1.5X** luck badge rather than mislabeling it as creator luck.
- Founder and creator presence never multiply. Each player receives the strongest eligible whole-hatch
  retry source: creator presence is 2x for non-creators; Legacy is 1.5x for everyone, including creators
  (who remain excluded from their own creator aura for balance testing).
- **Admin Reset to Beginning** re-arms Founder's Choice only for Studio or explicit test-ID players:
  it removes the selected benefit immediately, then tutorial completion opens a fresh chooser.
  Ordinary players retain their selection permanently.
- Configuration and allowlist live in `configs/monetization.lua`; changing the cohort ID/store key is a
  new promotion, not a routine tuning change.
