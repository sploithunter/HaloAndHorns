// Turns the humanoid avatar, plays its 3D GLB clips (Idle/Walk/Run/Sprint) by movement speed: the body's own
// paces pick the clip, and its rate comes from the body's speed and its pace on this body (paceRate below), and sits it
// when it is seated. turnTo picks the heading: the body's own state.turnTo when a script
// wrote one (a world whose places differ writes it as the body changes place), else the world's
// default in lib/data/player.yml. 'movement' (the fresh world's value: the standard third person):
// keys down, the body turns toward where the keys point; keys up, it HOLDS its heading while the
// look swings (the camera orbits a still body) until the look is more than turnInPlace degrees off
// the body, then it turns in place to where the look is: whole, feet with hips, ONE turn to one heading,
// a look still moving is never chased, and holds again.
// Every turn is ONE eased, rate-capped step per tick (turnSmoothing / turnSpeed, shortest arc);
// for a body the keys steer, never the velocity, which dies the moment you stop. 'walk': the same turn toward the keys, and a
// standing body keeps its heading whatever the look does: no turn in place. 'camera' (an aim game:
// the body IS the head): it snaps to the view on every input, walking too; a smoothed head reads as
// input lag. The heading comes from the raw move axes rotated into the camera basis (the same
// rotation player.js gives velocity), so physics can never bend it; the smoothed yaw lives in this
// script's own entry of the body's scratch (gaitOf below). A body no keys steer (an NPC that another
// script moves: not a player's own body, and no player drives it; steeredBody below) turns toward where
// it moves while its legs step, under every turnTo but 'none', and holds its heading when it stands. When
// another script turns that body while it walks, the yaw is that script's while it keeps turning it, and the
// walk takes the body back once it stops (npcHeading below). When something else turned the body (a door whose exit faces
// another way does), the script takes the body's own yaw and turns its held target by the same angle
// (bodyYawOf below). It only animates a 3D model: on a sprite-wearing player it does nothing. The turn
// is stepAngle from builtin/math; this file is its worked example.
// The clips follow what the body DID, never what it was asked to do: this script stands BEFORE
// player.js in the body's behavior list (templates/player.js), so the velocity it reads is what the
// body moved last tick: a body pressed into a wall reads 0 and stands, whatever the keys and the
// camera do. Read after the walker's write, the same dot answers the walker's ask, and a blocked body
// would walk in place for every other player.
import PLAYER from './lib/data/player.yml'
import { stepAngle } from 'builtin/math'

// The body's own word, else the world's default.
function turnTo(ctx) {
  return ctx.self.state.turnTo ?? PLAYER.turnTo
}

// The turn's working numbers: the smoothed yaw, its target, the turn-in-place flag, the speed the
// clips were last set to: are this machine's alone: nobody else reads them, and a value written to
// state rides the wire and the save on every tick it changes (a turning body would send a row a
// tick). ctx.self.session is this body's own scratch on this machine, never on the wire, gone with
// the body, so an NPC wearing this script has its own. Every script the body wears shares that one
// object, so this script keeps its numbers under its own file name, where no other script's key
// lands. state keeps what others must see (turnTo, the seat flags below).
function gaitOf(ctx) {
  return (ctx.self.session['humanoid-locomotion.js'] ??= {})
}

// An angle in degrees into (-180, 180].
function wrapDeg(deg) {
  let a = deg % 360
  if (a > 180) a -= 360
  else if (a <= -180) a += 360
  return a
}

// The heading to step from: the scratch's, or the body's own when someone else turned it.
function bodyYawOf(ctx, gait) {
  const own = ctx.self.yaw
  if (typeof own === 'number' && typeof gait.wroteYaw === 'number') {
    const turned = wrapDeg(own - gait.wroteYaw)
    if (Math.abs(turned) > 0.05) {
      gait.bodyYaw = own - (PLAYER.modelYaw || 0)
      gait.wroteYaw = own
      if (typeof gait.targetYaw === 'number') gait.targetYaw += turned
    }
  }
  return gait.bodyYaw ?? own
}

// Every humanoid, the player's own body included, reads its own measured paces. The Walk plays at its speed over the
// Walk's pace, and a Run or a Sprint at or under its pace plays the same way, so the feet cover the ground the body
// covers: a Run under its pace slows. Past its pace, a Run or a Sprint takes the speed the way a person running faster
// does, the stride and the cadence each a share: it plays at the square root of the speed over its pace (paceRate below),
// so the legs never cycle at a frantic rate. The grey body's Sprint (pace 3.462) at 6.5 m/s plays at 1.37× and at
// 8.5 m/s at 1.57×, where speed over pace would be 1.88× and 2.46×. Its feet then cover the geometric mean of the pace
// and the speed, 4.74 of 6.5 and 5.42 of 8.5 m/s. Under the Walk's floor, 1/PACE_BAND of its pace
// (0.8×), the Walk keeps the floor's tempo and SHORTENS ITS STRIDE instead: it shares the body with the Idle, its share
// the speed over the floor's pace (the idle→walk blend space every engine walks), from the first step the body moves. So
// a grandmother at 0.85 m/s on a Walk that paces 1.3 takes short steps at 0.8×, and a body that creeps at 0.3 m/s takes
// shorter ones: it never stands while it moves.
const PACE_BAND = 1.25
// The idle ends and the Walk begins at this share of the body's own Walk pace: 0.63 m/s on a man whose Walk paces 1.4,
// 0.35 on a child whose Walk paces 0.77. An NPC creeping under it takes a Walk share (below): only a still one stands.
const WALK_FROM = 0.45
// A gait rung is held down to this share of its threshold, for at most this long, before the body drops to the rung below.
const HOLD = 0.85
const HOLD_SECONDS = 0.35

// Each stepping clip's pace on THIS body, in metres a second, keyed by clip name or library address:
// the engine's measure in ctx.world.assets[<model>].gait, times the body's scale; none until measured.
function pacesOf(ctx) {
  const model = ctx.self.model
  const ref = typeof model === 'string' ? model : model?.id
  const measured = (ref && ctx.world?.assets?.[ref]?.gait) || {}
  const scale = ctx.self.effectiveScale?.y ?? 1
  const paces = {}
  for (const name in measured) paces[name] = measured[name] * scale
  return paces
}

// A gait clip's rate: the body's speed over the clip's pace, so the feet cover what the body covers. A running clip
// (`running`: the Run and the Sprint) past its pace plays at the square root of that ratio. Standing (or with no pace to
// read) the clip plays as authored. This `speed` is the rate the engine plays: nothing overrules it.
function paceRate(speed, pace, running) {
  if (!(speed > 0.1) || !(pace > 0)) return 1
  const ratio = speed / pace
  return running && ratio > 1 ? Math.sqrt(ratio) : ratio
}

// The seat's held pose. A body attached to something (a hull's seat, a mount, a chair) is seated,
// and this script (the body's one channel writer) holds this pose instead of the gait. A constant
// function of time: the mixer bakes it once, no per-frame code. Values are offsets from the
// T-pose bind. Rotations are degrees in each bone's own frame, the same on every humanoid rig; the
// hip drop is a FRACTION of the rig's hips rest height (sit.units), the same on every avatar,
// whatever its rig units. A seat's attach point is the floor straight under the seated hips, never
// the seat's top: the hips sit a chair's height above it and the soles land on that floor about 0.4 m
// ahead, so a bench's attach point stands under the middle of its slats, never at their front edge or
// where the feet go.
export function sit() {
  return {
    Hips: { position: [0, -0.5, 0] },
    Spine02: { rotation: [-8, 0, 0] },
    LeftUpLeg: { rotation: [-95, 0, 0] },
    RightUpLeg: { rotation: [-95, 0, 0] },
    LeftLeg: { rotation: [85, 0, 0] },
    RightLeg: { rotation: [85, 0, 0] },
    LeftArm: { rotation: [65, 0, 15] },
    RightArm: { rotation: [65, 0, -15] },
    LeftForeArm: { rotation: [60, 0, 30] },
    RightForeArm: { rotation: [60, 0, -30] },
  }
}
sit.units = 'hips'
sit.duration = 0.1

// A player's own body: its id is player/<session>. What a player carries (player/<session>/<name>) is a thing.
function playerBody(id) {
  return typeof id === 'string' && id.startsWith('player/') && id.indexOf('/', 7) < 0
}

// A body the keys steer: a player's own, or one a player drives (its controller names that player; a thing that drives a
// body sends it no keys). Any other body hears input only once, the frame the engine hands it when it is born, whose look
// is this machine's camera: that frame turns nothing.
function steeredBody(ctx) {
  return playerBody(ctx.self.id) || playerBody(ctx.self.controller)
}

// The heading of a body that no keys steer: where it moved, while its legs step. `walking` is the gait's own word (a rung
// above the idle at a speed the body moved, or a creep its legs step, below), so only a still body keeps its heading and
// a direction is read only from a velocity the body moved at. A yaw that changed since this script wrote it was written by another script:
// that tick is that script's, and its heading stands. A walking body faces its walk again once that script has left its
// heading unturned for `yieldTicks` ticks, at first none, so a body turned once (shoved, or glancing at a player) walks on
// facing its walk and never backwards. A script that puts its heading straight back over the walk's turn is holding the
// body: each time it does, the wait doubles, so a held heading shows the walk's step on ever fewer ticks. A standing body
// keeps its heading and forgets the wait. A script that owns a walking body's heading for good writes state.turnTo 'none'.
function npcHeading(ctx, gait, vel, walking) {
  const yaw = ctx.self.yaw
  if (typeof yaw === 'number' && typeof gait.wroteYaw === 'number' && Math.abs(wrapDeg(yaw - gait.wroteYaw)) > 0.05) {
    gait.bodyYaw = yaw - (PLAYER.modelYaw || 0)
    gait.wroteYaw = yaw
    gait.targetYaw = null
    gait.yieldTicks = gait.tookBack ? Math.max(1, 2 * (gait.yieldTicks || 0)) : gait.yieldTicks || 0
    gait.tookBack = false
    gait.yielding = true
    gait.unturned = 0
    return
  }
  if (!walking) {
    gait.yielding = false
    gait.tookBack = false
    gait.yieldTicks = 0
    return
  }
  if (gait.yielding) {
    gait.unturned += 1
    if (gait.unturned <= gait.yieldTicks) return
    gait.yielding = false
    gait.tookBack = true
  } else if (gait.tookBack) {
    gait.tookBack = false
    gait.yieldTicks = 0
  }
  // wrapDeg: a walk along +z reads atan2's -180, and the turn step lands on +180, the same heading a standing body compares to sleep.
  gait.targetYaw = wrapDeg((Math.atan2(-(vel.x || 0), -(vel.z || 0)) * 180) / Math.PI)
}

export function onInput(ctx, input) {
  if (ctx.self.sprite || !steeredBody(ctx)) return
  const sin = input.axes.aimYawSin
  const cos = input.axes.aimYawCos
  if (typeof sin !== 'number' || typeof cos !== 'number') return
  const moveX = input.axes.moveX ?? 0
  const moveZ = input.axes.moveZ ?? 0
  const mode = turnTo(ctx)
  const gait = gaitOf(ctx)
  const walking = moveX || moveZ
  const viewYaw = (Math.atan2(sin, cos) * 180) / Math.PI
  const bodyYaw = bodyYawOf(ctx, gait) ?? viewYaw
  if ((mode === 'movement' || mode === 'walk') && walking) {
    // The move axes in the camera basis: the body faces where it walks.
    gait.targetYaw = (Math.atan2(-(cos * moveX - sin * moveZ), sin * moveX + cos * moveZ) * 180) / Math.PI
    gait.turningInPlace = false
  } else if (mode === 'movement') {
    // Standing: hold while the look is within turnInPlace of the body. Past it, ONE turn to where the look is now: the
    // target stays put while the body turns, so a look still moving is never chased, then hold again.
    if (!gait.turningInPlace) {
      if (Math.abs(wrapDeg(viewYaw - bodyYaw)) > (PLAYER.turnInPlace ?? 90)) {
        gait.targetYaw = viewYaw
        gait.turningInPlace = true
      } else {
        gait.targetYaw = null
      }
    }
  } else {
    // 'walk' and 'none': a standing body holds, and keeps no target or turn that a later mode would finish. 'camera': the view heading.
    gait.targetYaw = mode === 'camera' ? viewYaw : null
    gait.turningInPlace = false
  }
}

export function update(ctx, dt) {
  if (ctx.self.sprite) return // sprites animate via the 2D mixer, never these GLB clips

  const clips = PLAYER.clips || {}
  // Seated: attached to a hull, a mount, a chair, or a sit someone else wrote on the sit channel
  // (mixer and anim read one table, so the script remembers whether the sit is its own). The seat
  // carries the body; this script holds the sit and sleeps until a row of this body lands from outside it
  // (the sit cleared, a velocity written, the parent changed: any of them wakes it). A sit on ANY OTHER
  // channel plays over the walk and the body slides seated: use `sit`, or parent the body to the seat.
  // A sit that is not its own is theirs: never written, never cleared.
  const theirSit = ctx.self.mixer?.sit && ctx.self.state.gaitSit !== 'own'
  if (ctx.self.parent || theirSit) {
    if (!ctx.self.state.gaitSeated) {
      ctx.self.state.gaitSeated = true
      ctx.self.anim.idle = null
      ctx.self.anim.walk = null
      ctx.self.anim.run = null
      if (ctx.self.anim.sprint) ctx.self.anim.sprint = null
      if (!theirSit) {
        ctx.self.anim.sit = { clip: clips.sit || sit, loop: 'loop', weight: 1, blendIn: 0.15 }
        ctx.self.state.gaitSit = 'own'
      }
      // grounding would sink the seated hips
      ctx.self.bones.LeftFoot.ground = 0
      ctx.self.bones.RightFoot.ground = 0
    }
    ctx.sleep()
    return
  }
  const gait = gaitOf(ctx)
  if (ctx.self.state.gaitSeated) {
    ctx.self.state.gaitSeated = false
    if (ctx.self.state.gaitSit === 'own') ctx.self.anim.sit = null
    ctx.self.state.gaitSit = null
    ctx.self.bones.LeftFoot.ground = null
    ctx.self.bones.RightFoot.ground = null
    gait.clipSpeed = undefined // the channels were cleared for the seat: the next tick writes them whatever the speed
  }

  const mode = turnTo(ctx)
  const vel = ctx.self.velocity // what the body did last tick: player.js has not written this tick's ask yet (the order above)
  const asked = Math.hypot(vel.x || 0, vel.z || 0)
  // The speed the gait wears is the speed the body MOVED, never more than the word it read: the feet's ground distance since the
  // last tick over dt. The order above answers the player's own walker; a resident whose script runs after this one and keeps
  // writing velocity into a doorway another body fills, or a body pushed while asking for nothing, stands instead of walking in
  // place all the same. The first tick after a spawn or a teleport has no honest distance and wears the word it was given.
  const feet = ctx.self.feetPosition
  const moved =
    feet && gait.lastFeet && dt > 0 ? Math.hypot((feet.x || 0) - gait.lastFeet.x, (feet.z || 0) - gait.lastFeet.z) / dt : null
  if (feet) gait.lastFeet = { x: feet.x || 0, z: feet.z || 0 }
  const movedSpeed = moved === null || moved > asked * 1.5 + 0.5 ? asked : Math.min(asked, moved)
  const speed = typeof PLAYER.speedOverride === 'number' ? PLAYER.speedOverride : movedSpeed
  // The speed the clips blend and play at: the body's, held still through float noise. A steady run under a
  // turning camera reads a speed that differs by one bit a tick (the hypot of a rotated vector), and a channel
  // written with a new number is a new row on the wire; a step under a millionth of a metre a second is no
  // change in the gait, so the memo stands until the speed really moves. A real change lands whole.
  if (gait.clipSpeed === undefined || Math.abs(speed - gait.clipSpeed) > 1e-6) gait.clipSpeed = speed
  const clipSpeed = gait.clipSpeed
  // Every switch is THIS body's own, read off its measured paces: the Walk begins at WALK_FROM of its Walk pace, the Run at
  // the geometric mean of its Walk and Run paces (where a stretched Walk and a slowed Run strain alike), the Sprint at the
  // mean of its Run and Sprint, so a child at 3.3 m/s sprints on her own legs while a man at 3.3 runs, and no body wears a
  // clip its speed has left behind. lib/data/player.yml's walkThreshold / runThreshold / sprintThreshold win when a world
  // names them (a world upgraded from 5.x carries its old character's there). Before the measure lands ({} paces) the switches sit at 0.8 and 3 m/s with no Sprint. ONE gait clip at a time: the speed picks the rung and the mixer crossfades
  // the switch in time (blendIn), so no steady speed ever wears two gaits: two clips with two periods drift against each
  // other and the legs fight. A speed on a threshold switches once: a rung is held down to HOLD of its threshold for
  // HOLD_SECONDS, so a wandering speed never flickers and a speed that settles in the hold band (Shift let go) hands over.
  const walkClip = clips.walk || 'Walk'
  const runClip = clips.run || 'Run'
  const sprintClip = clips.sprint || 'Sprint'
  const paces = pacesOf(ctx)
  const walkPace = paces[walkClip]
  const runPace = paces[runClip]
  const sprintPace = sprintClip === runClip ? 0 : paces[sprintClip]
  // The player's own body reads its paces like every other humanoid: the world's walkSpeed and runSpeed are how fast the body
  // moves, never how fast its legs cycle. A body that moves faster than its Run's pace wears the Sprint, and each clip plays
  // at the rate paceRate reads off the speed and its pace: the feet cover the ground the body covers up to the clip's pace,
  // and past it the cadence eases by the square root.
  const walkAt = typeof PLAYER.walkThreshold === 'number' ? PLAYER.walkThreshold : walkPace > 0 ? WALK_FROM * walkPace : 0.8
  const runAt = Math.max(walkAt, typeof PLAYER.runThreshold === 'number' ? PLAYER.runThreshold : walkPace > 0 && runPace > 0 ? Math.sqrt(walkPace * runPace) : 3)
  const sprintAt = Math.max(runAt, typeof PLAYER.sprintThreshold === 'number' ? PLAYER.sprintThreshold : runPace > 0 && sprintPace > 0 ? Math.sqrt(runPace * sprintPace) : Infinity)
  const hasSprint = sprintAt < Infinity
  const runRate = paceRate(clipSpeed, runPace, true)
  const rungs = ['idle', 'walk', 'run', 'sprint']
  const steps = [walkAt, runAt, sprintAt]
  let rung = gait.rung ?? 'idle'
  const worn = Math.max(0, rungs.indexOf(rung))
  // The hold band: the highest threshold at or under the worn rung's that the speed sits just below.
  let band = null
  for (let j = worn - 1; j >= 0 && band === null; j--) if (clipSpeed >= steps[j] * HOLD && clipSpeed < steps[j]) band = rungs[j + 1]
  gait.heldFor = band && band === gait.heldBand ? gait.heldFor + dt : 0
  gait.heldBand = band
  let next = 0
  while (next < 3 && clipSpeed >= steps[next]) next++
  rung = rungs[next]
  if (band && gait.heldFor < HOLD_SECONDS) rung = band
  gait.rung = rung
  // A creeping body moves under the Walk's switch and steps on the Walk's share (below). The Walk's rate floor is its pace
  // over PACE_BAND.
  const walkFloor = walkPace / PACE_BAND
  const creeping = rung === 'idle' && walkFloor > 0 && clipSpeed > 0.1 && clipSpeed < walkFloor
  // A body no keys steer faces its walk under every turnTo but 'none', which leaves it no target to finish.
  const steered = steeredBody(ctx)
  if (!steered && mode === 'none') gait.targetYaw = null
  else if (!steered) npcHeading(ctx, gait, vel, (rung !== 'idle' && movedSpeed >= walkAt * HOLD) || creeping)
  // turnTo 'none': this script turns nothing: another script (or nobody) owns the yaw.
  if (typeof gait.targetYaw === 'number' && mode !== 'none') {
    const from = bodyYawOf(ctx, gait) ?? gait.targetYaw
    const target = gait.targetYaw
    // 'camera' snaps a body the keys steer to the view. Every other turn is the eased step.
    gait.bodyYaw =
      mode === 'movement' || mode === 'walk' || !steered
        ? stepAngle(from, target, dt, { smoothing: PLAYER.turnSmoothing, maxDegPerSec: PLAYER.turnSpeed })
        : target
    gait.wroteYaw = gait.bodyYaw + (PLAYER.modelYaw || 0) // modelYaw: degrees a model's forward is off its rig's
    ctx.self.yaw = gait.wroteYaw
    // A turn in place ends when the body has come round to the look: it holds again until the next threshold.
    if (gait.turningInPlace && Math.abs(wrapDeg(target - gait.bodyYaw)) < 0.5) {
      gait.turningInPlace = false
      gait.targetYaw = null
    }
  }
  const targetYaw = gait.targetYaw
  // Anim channels are addresses: assign a channel object and the mixer follows (an equal write is a compare, never a row).
  // Each rung's clip plays at the rate paceRate reads off the body's speed and that clip's own pace. `clips: { run: Sprint }` in player.yml puts
  // another clip under the key; a sprint channel stands only on a body whose file carries a Sprint the measure has paced.
  // The Walk's share of the body: whole from its rate floor up; under the floor, the speed over the floor's pace (the feet
  // then cover the body's speed: share × pace/PACE_BAND), the Idle taking the rest. On the idle rung a body that still
  // moves (creeping, under the Walk's switch) wears the same share, so its feet step what it moves. A body with no
  // measured paces walks whole.
  const walkShare = creeping ? clipSpeed / walkFloor : rung !== 'walk' ? 0.001 : walkFloor > 0 && clipSpeed < walkFloor ? Math.max(0.001, clipSpeed / walkFloor) : 1
  const idleWeight = rung === 'walk' || creeping ? Math.max(0.001, 1 - walkShare) : rung === 'idle' ? 1 : 0.001
  const walkRate = Math.max(1 / PACE_BAND, paceRate(clipSpeed, walkPace))
  const sprintRate = paceRate(clipSpeed, sprintPace, true)
  ctx.self.anim.idle = { clip: clips.idle || 'Idle', loop: 'loop', weight: idleWeight, blendIn: 0.15 }
  ctx.self.anim.walk = { clip: walkClip, loop: 'loop', weight: walkShare, speed: walkRate, blendIn: 0.15 }
  ctx.self.anim.run = { clip: runClip, loop: 'loop', weight: rung === 'run' ? 1 : 0.001, speed: runRate, blendIn: 0.15 }
  if (hasSprint) ctx.self.anim.sprint = { clip: sprintClip, loop: 'loop', weight: rung === 'sprint' ? 1 : 0.001, speed: sprintRate, blendIn: 0.15 }
  else if (ctx.self.anim.sprint) ctx.self.anim.sprint = null
  // Standing, facing where it was told to: the clips hold their weights until the body moves or onInput
  // writes a new heading, either wakes this update.
  if (speed === 0 && (typeof targetYaw !== 'number' || gait.bodyYaw === targetYaw)) ctx.sleep()
}
