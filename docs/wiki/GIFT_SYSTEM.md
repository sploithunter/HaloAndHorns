# One-Way Pet Gifts

Status: implemented 2026-08-23.

Gifts share the Trade menu but are not trade sessions. The giver selects one online player and one
unlocked, tradeable pet; the receiver never sees an approval prompt. The receiver's persistent
`Settings.GiftAcceptance` policy is `any`, `uncommon_plus`, `rare_plus`, `mythic_plus`, or `off`.
The player picker displays the current policy, and `GiftService` revalidates it at send time so a
stale client cannot bypass a changed threshold. Missing settings default to `any`.

## Durable ownership transfer

The sender removes one exact pet record into `GameData.Gifts.outbox`, then waits for ProfileStore to
confirm that save before `ProfileStore:MessageAsync` queues a versioned `gift_delivery` message.
This ordering prevents the receiver from claiming a pet whose removal was not durable. Queue or
save timeouts leave the outbox intact and retry with the same gift id.

The receiver validates the message, inserts an unopened `Inventory.gifts` record containing the
exact pet snapshot, records the gift id in a permanent received ledger, confirms the profile save,
and only then acknowledges the message. Repeated messages cannot create a second present. Opening a
present inserts the exact pet through `PetTransferService` before removing the wrapped record; full
pet storage leaves the gift unopened. Sender and receiver idempotency ledgers do not expire.

## Presentation and rankings

- Inventory has a Gifts category. A present hides the pet identity until opened, previews the
  wrapped model, then uses the existing pet-reveal animation.
- The supplied icon was keyed with `scripts/remove_image_background.py --mode edge-magenta`, not
  regenerated. The group-owned icon and model ids are traced in `scripts/gift_icon_ids.json` and
  `scripts/gift_model_ids.json`.
- Three independent lifetime OrderedDataStore rankings publish the top three givers: Mythicals,
  Secrets, and Exclusives. Huge pets count with Exclusives. The board ids are `gift_mythicals`,
  `gift_secrets`, and `gift_exclusives`; an authored combined physical host can bind them later.

## Verification boundary

Headless tests cover every preference threshold, malformed rarities, exact-record message copying,
message validation, permanent deduplication ledgers, save-before-message ordering,
open-before-consume ordering, command/UI wiring, top-three board configuration, and uploaded-asset
traceability. A true delivery smoke still needs two live Studio clients because the production path
uses cross-profile ProfileStore messages.
