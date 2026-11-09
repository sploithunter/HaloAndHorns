// The world's program: the referee. Behaviors write their own rows (ctx.self.state.*); this reads what
// changed and writes the rows everyone reads: ctx.world.state.* (shared by every place, survives a restart)
// and ctx.place.state.*. A round, a wave, a score, a winner is a data row written here from one hand, never
// a second script. It runs on one machine per room, on the world's clock (ctx.now()), at this cadence.
//   for (const c of ctx.changed("place.players.*.state.score")) { … } // every row that moved since the last tick
//   export const scopes = { "world.state.hits.*": { merge: "counter" } }; // a row many hands += n at once: no race
export const cadence = "1s";
export function tick(ctx) {}
