// The world's doorway (world.config.yaml engine.behaviors): onArrive fires when a player enters
// this world (first join, rejoin, a link in from another world: player.arrival.kind says which),
// and onLeave when they leave it. A move between this world's places (ctx.cross) fires neither:
// sim.js and the place's policy hear that move.
// Where a player stands is the engine's to keep: a body is one durable row in the
// room: a refresh reconnects the same body, a return an hour later lands where you stood, facing
// the way you faced, so nothing here saves or restores a spot. A world where every visit
// starts fresh (an arena, a race) moves the player here: ctx.cross(player, 'main').
export function onArrive(ctx, player) {}

export function onLeave(ctx, player) {}
