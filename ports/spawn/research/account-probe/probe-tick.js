// Isolated assessment fixture: artificial account and reward, never production gameplay.
export const updateSchedule = { every: { seconds: 0.1 } };
export function update(ctx) {
  ctx.self.state.ticks = (ctx.self.state.ticks ?? 0) + 1;
  for (const p of ctx.place.players)
    if (!p.state.hhAccountProbe)
      p.state.hhAccountProbe = {
        schemaVersion: 1,
        Inventory: {
          pets: {
            items: {
              "bear:basic:": { id: "bear", variant: "basic", quantity: 3 },
              "probe-unique": {
                uid: "probe-unique",
                id: "doggy",
                variant: "rainbow",
                unique: true,
                level: 7,
                exp: 23,
              },
            },
          },
        },
        Equipped: {
          pets: { slot_1: "stack|bear:basic:", slot_2: "probe-unique" },
        },
        Stats: { Experience: 731 },
        Receipts: {},
      };
}
