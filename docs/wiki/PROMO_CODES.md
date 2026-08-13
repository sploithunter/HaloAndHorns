# Promo / Reward Codes

Last updated: 2026-08-10

## Contract

- `PromoCodeService` is the server authority for code lookup, eligibility, throttling, durable
  per-player claims, reward grants, and attribution.
- `configs/promo_codes.lua` authors each public spelling under a stable lowercase ID. The stable ID
  remains the claim and analytics identity when a spelling changes or gains aliases.
- Rewards use the standard `RewardBundle`: origin currency or gems, pets, inventory items,
  temporary effects, titles, XP, and permanent slots all terminate in `RewardService`.
- Published codes may set a level floor, UTC start/end timestamps, a per-player limit, a campaign,
  and a custom success banner. Dates use half-open windows: start is inclusive, end is exclusive.
- Profiles persist `GameData.PromoCodes.claims` and first-touch launch attribution. Admin Reset and
  the Studio-only `promo.reset` command clear both for repeat testing.

## Player Surface

The Settings panel opens the shared-chrome **Redeem Code** menu. Input is case-insensitive and
ignores whitespace. Successful claims use the normal floating reward banner and fanfare.

A Roblox launch link may pass `LaunchData` as a plain code or query payload such as
`code=KADEWEEK1`. This prefills the menu and records its campaign; it never silently claims a
reward. This makes distinct official-X and partner-link campaigns measurable without creating
different reward logic.

## Analytics

Every successful claim increments `promo_codes_redeemed` and emits `promo_code_redeemed`.
Attributed launch links emit `promo_link_attributed` as soon as profile data is ready, whether or
not the code is later redeemed. `RetentionDashboard_v1` aggregates attributed joins, total claims,
`promoCodes.byCode`, `promoCodes.byCampaign`, and `promoCodes.attributedByCampaign`, so partner and
official-X link-to-redemption conversion can be read without raw event scans.

## Operational Safety

Shared configs replicate to clients. Weekly codes are public by design, but **do not pre-stage an
unannounced secret spelling** in `configs/promo_codes.lua`. Add it when announced, or move future
secret definitions to a server-only source. Rewards, eligibility, dates, and claim ledgers remain
server-authoritative even when the public spelling is known.

`CODETEST` (alias `TESTCODE`) is the only code currently authored; it grants 25 gems and is hard
gated to Studio. Add a production definition only after its spelling, campaign, reward, window, and
minimum level have been chosen.
