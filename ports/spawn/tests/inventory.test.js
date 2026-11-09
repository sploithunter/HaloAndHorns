import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import {
  resolveEquipped,
  buildEquipped,
  fillEmptySlots,
  replaceEquipped,
  normalize,
} from "../world/scripts/lib/pet-inventory.js";
const fixtures = JSON.parse(
  fs.readFileSync(new URL("./inventory-fixtures.json", import.meta.url)),
);
const list = (value) => (Array.isArray(value) ? value : []);
test("owned-pet resolution matches 48 executed HH Luau cases, including enchant identity and phantom refs", () => {
  for (const f of fixtures.resolve) {
    const r = resolveEquipped(f.items, f.equipped, f.capacity);
    assert.deepEqual(r.slots, f.slots);
    assert.deepEqual(r.equippedByKey, f.counts);
  }
});
test("atomic squad builder matches HH locked-slot, quantity, unique and capacity rules", () => {
  for (const f of fixtures.build) {
    const r = buildEquipped(f.items, list(f.refs), f.capacity, {
      lockedSlots: f.locks,
      previous: f.previous,
    });
    assert.deepEqual(r.equipped, f.equipped);
    assert.deepEqual(r.summary, f.summary);
  }
});
test("fill-empty hatches match HH without replacing chosen or downed pets", () => {
  for (const f of fixtures.fill) {
    const r = fillEmptySlots(
      f.items,
      f.equipped,
      list(f.refs),
      f.capacity,
      f.locks,
    );
    assert.deepEqual(r.equipped, f.result);
    assert.deepEqual(r.summary, {
      ...f.summary,
      addedRefs: list(f.summary.addedRefs),
    });
  }
});
test("equip commits conserve ownership and reject a temporary pet or over-owned draft atomically", () => {
  const items = fixtures.build[0].items,
    account = {
      Inventory: { pets: { items } },
      Equipped: { pets: { slot_1: "owned-unique" } },
      Stats: { Experience: 748 },
      GameData: {
        MergeDefense: { rebirths: 2 },
        FarmAndFight: { areas: ["Grass", "Ice"] },
      },
    };
  const before = structuredClone(account);
  for (const refs of [
    ["temporary:run:hatcher:1"],
    ["owned-unique", "owned-unique"],
    Array(3).fill("stack|bear:basic:"),
  ]) {
    const r = replaceEquipped(account, refs, 3);
    assert.equal(r.ok, false);
    assert.deepEqual(r.account, before);
  }
  const r = replaceEquipped(
    account,
    ["stack|bear:basic:", "stack|bear:basic:luck_copper", "owned-unique"],
    3,
  );
  assert.equal(r.ok, true);
  assert.deepEqual(r.account.Inventory, before.Inventory);
  assert.deepEqual(r.account.Stats, before.Stats);
  assert.deepEqual(r.account.GameData, before.GameData);
  assert.deepEqual(account, before);
  assert.deepEqual(replaceEquipped(account, [], 3).account.Equipped.pets, {});
  assert.equal(replaceEquipped(account, null, 3).reason, "invalid_refs");
  assert.equal(replaceEquipped({}, [], 3).reason, "profile_unavailable");
  const legacy = structuredClone(items);
  legacy["bear:basic:"].equipped_slot = 2;
  legacy["bear:basic:"].uid = "wrong";
  const normal = normalize(legacy);
  assert.equal(normal["bear:basic:"].quantity, 2);
  assert.equal(normal["bear:basic:"].uid, undefined);
  assert.equal(normal["owned-unique"].level, 7);
  assert.equal(legacy["bear:basic:"].uid, "wrong");
});
