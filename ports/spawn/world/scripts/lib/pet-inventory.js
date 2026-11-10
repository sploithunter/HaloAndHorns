// HH ownership and equip rules. No engine or save-backend dependency.
// Inventory.pets.items owns pets; Equipped.pets contains only validated references.
const copy = (value) => JSON.parse(JSON.stringify(value));
const owns = (object, key) =>
  Object.prototype.hasOwnProperty.call(object ?? {}, key);
// PetEquipCapacity: the progression ceiling increases by the paid entitlement delta.
// Earned and replicated bonuses describe the same capacity axis, so they are not added.
export function resolveEquipCapacity(args = {}) {
  const number = (value, fallback) => {
    const n =
      typeof value === "number" || typeof value === "string"
        ? Number(value)
        : NaN;
    return Number.isNaN(n) ? fallback : n;
  };
  const base = Math.max(1, number(args.baseSlots, 1)),
    earned = Math.max(0, number(args.earnedSlots, 0)),
    replicated = Math.max(0, number(args.replicatedSlots, 0)),
    paid = Math.max(0, number(args.paidSlots, 0)),
    cap = Math.max(base, number(args.progressionCap, base));
  return Math.max(
    1,
    Math.min(base + Math.max(earned, replicated) + paid, cap + paid),
  );
}
export function isStackEntry(record, key) {
  if (!record || typeof record !== "object") return false;
  if (key != null) {
    const base = String(record.id) + ":" + (record.variant ?? "basic");
    return key === base || String(key).startsWith(base + ":");
  }
  return typeof record.quantity === "number" && record.uid == null;
}
export function parseRef(ref) {
  if (typeof ref !== "string" || !ref) return null;
  const parts = ref.split("|").filter(Boolean);
  if (parts[0] === "stack" && parts[1])
    return { kind: "stack", stackKey: parts[1] };
  if (parts[0] === "special" && parts[1])
    return { kind: "special", uid: parts[1] };
  return { kind: "special", uid: ref };
}
export function normalize(items) {
  const result = copy(items ?? {});
  for (const [key, record] of Object.entries(result))
    if (record && typeof record === "object") {
      if (isStackEntry(record, key)) {
        record.quantity = Math.max(0, Math.floor(Number(record.quantity) || 0));
        record.variant ??= "basic";
        delete record.uid;
      } else {
        record.uid = key;
        delete record.quantity;
      }
      delete record._kind;
      delete record.equipped_slot;
      delete record.equipped_slots;
    }
  return result;
}
export function resolveEquipped(items, equipped, maxSlots) {
  const slots = {},
    equippedByKey = {},
    unique = new Set(),
    stacks = {};
  const candidates = Object.entries(equipped ?? {})
    .map(([key, ref]) => ({ n: Number(key.match(/^slot_(\d+)$/)?.[1]), ref }))
    .filter((s) => s.n >= 1 && s.n <= maxSlots && s.ref)
    .sort((a, b) => a.n - b.n);
  for (const { n, ref } of candidates) {
    const d = parseRef(ref);
    if (!d) continue;
    const key = d.kind === "stack" ? d.stackKey : d.uid,
      rec = owns(items, key) ? items[key] : null;
    if (!rec) continue;
    if (d.kind === "special" && !isStackEntry(rec, key) && !unique.has(key)) {
      unique.add(key);
      slots[n] = {
        slot: n,
        kind: "special",
        uid: key,
        id: rec.id,
        variant: rec.variant,
      };
      equippedByKey["uid:" + key] = (equippedByKey["uid:" + key] ?? 0) + 1;
    } else if (
      d.kind === "stack" &&
      isStackEntry(rec, key) &&
      (stacks[key] ?? 0) < Math.max(0, Math.floor(Number(rec.quantity) || 0))
    ) {
      stacks[key] = (stacks[key] ?? 0) + 1;
      slots[n] = {
        slot: n,
        kind: "stack",
        stackKey: key,
        id: rec.id,
        variant: rec.variant ?? "basic",
      };
      equippedByKey[key] = (equippedByKey[key] ?? 0) + 1;
    }
  }
  return { slots, equippedByKey };
}
const slotKey = (n) => "slot_" + n;
const locked = (locks, n) =>
  locks?.[n] === true || locks?.[slotKey(n)] === true;
const match = (a, b) => {
  const x = parseRef(a),
    y = parseRef(b);
  return (
    x &&
    y &&
    x.kind === y.kind &&
    (x.kind === "stack" ? x.stackKey === y.stackKey : x.uid === y.uid)
  );
};
export function buildEquipped(items, refs, maxSlots, options = {}) {
  refs = Array.isArray(refs) ? refs : [];
  maxSlots = Math.max(0, Math.floor(Number(maxSlots) || 0));
  const equipped = {},
    usedUnique = new Set(),
    usedStacks = {},
    consumed = new Set();
  let accepted = 0,
    rejected = 0;
  function take(ref) {
    const d = parseRef(ref);
    if (!d) return null;
    const key = d.kind === "stack" ? d.stackKey : d.uid,
      rec = owns(items, key) ? items[key] : null;
    if (!rec) return null;
    if (
      d.kind === "special" &&
      !isStackEntry(rec, key) &&
      !usedUnique.has(key)
    ) {
      usedUnique.add(key);
      return key;
    }
    if (
      d.kind === "stack" &&
      isStackEntry(rec, key) &&
      (usedStacks[key] ?? 0) <
        Math.max(0, Math.floor(Number(rec.quantity) || 0))
    ) {
      usedStacks[key] = (usedStacks[key] ?? 0) + 1;
      return "stack|" + key;
    }
    return null;
  }
  for (let n = 1; n <= maxSlots; n++)
    if (locked(options.lockedSlots, n)) {
      const previous = options.previous?.[slotKey(n)];
      if (!previous) continue;
      for (let i = 0; i < refs.length; i++)
        if (!consumed.has(i) && match(refs[i], previous)) {
          const placed = take(refs[i]);
          if (placed) {
            equipped[slotKey(n)] = placed;
            consumed.add(i);
            accepted++;
          }
          break;
        }
    }
  let nextOpen = 1;
  for (let i = 0; i < refs.length; i++)
    if (!consumed.has(i)) {
      let n = nextOpen;
      while (
        n <= maxSlots &&
        (locked(options.lockedSlots, n) || equipped[slotKey(n)])
      )
        n++;
      if (n > maxSlots) {
        let reservedEmpty = false;
        for (let j = 1; j <= maxSlots; j++)
          if (locked(options.lockedSlots, j) && !equipped[slotKey(j)])
            reservedEmpty = true;
        if (reservedEmpty) break;
        rejected++;
      } else {
        const placed = take(refs[i]);
        if (placed) {
          equipped[slotKey(n)] = placed;
          nextOpen = n + 1;
          accepted++;
        } else rejected++;
      }
    }
  return {
    equipped,
    summary: { accepted, rejected, requested: refs.length, maxSlots },
  };
}
export function fillEmptySlots(items, equipped, refs, maxSlots, lockedSlots) {
  const resolved = resolveEquipped(items, equipped, maxSlots),
    result = {},
    counts = { ...resolved.equippedByKey };
  let occupied = 0,
    added = 0,
    rejected = 0;
  const addedRefs = [];
  for (const [n, d] of Object.entries(resolved.slots)) {
    result[slotKey(n)] = d.kind === "stack" ? "stack|" + d.stackKey : d.uid;
    occupied++;
  }
  for (const ref of refs ?? []) {
    let empty = null;
    for (let n = 1; n <= maxSlots; n++)
      if (!result[slotKey(n)] && !locked(lockedSlots, n)) {
        empty = n;
        break;
      }
    if (empty === null) break;
    let d = parseRef(ref);
    if (
      d?.kind === "special" &&
      owns(items, d.uid) &&
      isStackEntry(items[d.uid], d.uid)
    )
      d = { kind: "stack", stackKey: d.uid };
    let accepted = null,
      key;
    if (d?.kind === "special") {
      key = "uid:" + d.uid;
      const rec = owns(items, d.uid) ? items[d.uid] : null;
      if (rec && !isStackEntry(rec, d.uid) && !(counts[key] > 0))
        accepted = d.uid;
    } else if (d?.kind === "stack") {
      key = d.stackKey;
      const rec = owns(items, key) ? items[key] : null;
      if (
        rec &&
        isStackEntry(rec, key) &&
        (counts[key] ?? 0) < Math.max(0, Math.floor(Number(rec.quantity) || 0))
      )
        accepted = "stack|" + key;
    }
    if (accepted) {
      result[slotKey(empty)] = accepted;
      counts[key] = (counts[key] ?? 0) + 1;
      added++;
      addedRefs.push(ref);
    } else rejected++;
  }
  return {
    equipped: result,
    summary: {
      added,
      rejected,
      before: occupied,
      total: occupied + added,
      maxSlots,
      addedRefs,
    },
  };
}
// Higher-level commits reject the whole draft; ownership is never decremented on equip.
export function replaceEquipped(account, refs, maxSlots, options = {}) {
  if (!Array.isArray(refs))
    return { ok: false, reason: "invalid_refs", account };
  if (!account?.Inventory?.pets?.items || !account?.Equipped?.pets)
    return { ok: false, reason: "profile_unavailable", account };
  const result = buildEquipped(account.Inventory.pets.items, refs, maxSlots, {
    ...options,
    previous: account.Equipped.pets,
  });
  if (result.summary.rejected || result.summary.accepted !== refs.length)
    return {
      ok: false,
      reason: "The squad includes unavailable pets or locked slots",
      account,
    };
  const next = copy(account);
  next.Equipped.pets = result.equipped;
  return { ok: true, account: next };
}
