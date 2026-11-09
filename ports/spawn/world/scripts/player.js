// The player's own movement: WASD relative to the camera's aim, jump, gravity: on the
// character controller. A body is three writes: feetPosition puts it there, velocity asks the
// controller to take it there (held until the next write: it slides, steps and grounds), forces
// push until null. Numbers live in lib/data/player.yml; gravity is the PLACE's
// (places/<p>/config.yaml gravity:), so a district that declares its own pulls on you the
// moment you step in. The body arrives dressed by the join: the template's model, else the card's
// avatar, and its own file carries Idle, Walk, Run, Sprint, Jump; any other clip is an address on a
// mixer channel (anim.sit = "cdn/clip-sit-loop.glb": →animations).
import PLAYER from './lib/data/player.yml'

// The keys' intent is this machine's alone: onInput writes it, update() reads it, nobody else does:
// and a value written to state rides the wire and the save on every tick it changes (the intent turns
// with the camera, so a running player would send a row a tick). ctx.self.session is this body's own
// scratch on this machine, never on the wire, gone with the body. Every script the body wears shares
// that one object, so this script keeps its intent under its own file name, where no other script's
// key lands.
function walkOf(ctx) {
  return (ctx.self.session['player.js'] ??= {})
}

export function onInput(ctx, input) {
  const facingSin = input.axes.aimYawSin ?? 0
  const facingCos = input.axes.aimYawCos ?? 1

  const moveX = input.axes.moveX ?? 0
  const moveZ = input.axes.moveZ ?? 0
  const mag = Math.hypot(moveX, moveZ)
  const nx = mag > 1 ? moveX / mag : moveX
  const nz = mag > 1 ? moveZ / mag : moveZ

  // Where the keys point, at walking speed: the INTENT update() eases the body toward every tick.
  // Written as intent, never straight into velocity: a key is a level (full or nothing) and a body
  // that jumps to 6 m/s the tick a key lands overshoots every tap; the ease makes a tap a nudge.
  walkOf(ctx).moveIntent = {
    x: (facingCos * nx - facingSin * nz) * PLAYER.walkSpeed,
    z: -(facingSin * nx + facingCos * nz) * PLAYER.walkSpeed,
  }

  // The jump is your y; x and z stay what the body did last tick (y reads 0 on the ground).
  // A seated body does not jump: the seat carries it, and a held y would lift it off the seat.
  if (input.pressed.jump && ctx.self.grounded && !ctx.self.parent) {
    const v = ctx.self.velocity
    ctx.self.velocity = { x: v.x, y: PLAYER.jumpSpeed, z: v.z }
  }
}

export function update(ctx, dt) {
  // Seated (attached to a hull, a mount): the seat carries the body: the legs rest.
  if (ctx.self.parent) return
  // What the body did last tick; y reads 0 on the ground.
  const v = ctx.self.velocity
  // The stride: ease the ground velocity toward the keys' intent: acceleration while the keys point
  // the way the body already moves, deceleration back to rest when none is down or the keys reverse
  // (both m/s², lib/data/player.yml). One capped step per tick, so a held key reaches walkSpeed in
  // walkSpeed / acceleration seconds and a release stops in walkSpeed / deceleration; a body stopped
  // by a wall reads 0 and pushes again from there.
  const intent = walkOf(ctx).moveIntent ?? { x: 0, z: 0 }
  const along = intent.x * v.x + intent.z * v.z > 0 || (v.x === 0 && v.z === 0 && (intent.x !== 0 || intent.z !== 0))
  const step = (along ? PLAYER.acceleration : PLAYER.deceleration) * dt
  const dx = intent.x - v.x
  const dz = intent.z - v.z
  const gap = Math.hypot(dx, dz)
  const k = gap > step ? step / gap : 1
  const vx = v.x + dx * k
  const vz = v.z + dz * k
  // Gravity is yours: the held velocity walks the body; bend its y every tick.
  ctx.self.velocity = { x: vx, y: v.y + ctx.place.gravity.y * dt, z: vz }
  // Standing on the ground with no word to walk: nothing changes until something moves the body or a key
  // is pressed: both wake this update (a row of the body written, or onInput running).
  if (ctx.self.grounded && vx === 0 && vz === 0 && intent.x === 0 && intent.z === 0) ctx.sleep()
}
