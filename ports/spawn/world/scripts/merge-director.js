import DATA from "./lib/data/merge.yml";
import ASSETS from "./lib/data/assets.yml";
import COMBAT from "./lib/data/combat.yml";
import {
  combatHit,
  presentActor,
  faceTarget,
  effectProgram,
  publishPose,
} from "./lib/merge-presentation.js";
import { assignAttackSlots } from "./lib/merge-choreography.js";
import {
  freshProfile,
  command,
  earlyDifficulty,
  waveUnits,
  mitigate,
} from "./lib/merge-core.js";

export const updateSchedule = {
  every: { seconds: DATA.tuning.simulation.step },
};
function runtime(ctx) {
  return (ctx.self.session.mergeRuntime ??= {
    sceneVersion: DATA.tuning.scene.sceneVersion,
    owner: null,
    entities: [],
    enemies: [],
    pets: [],
    wave: 0,
    clock: 0,
    rate: {},
  });
}
function clear(ctx, run) {
  for (const id of run.entities) if (ctx.getObject(id)) ctx.destroy(id);
  run.entities = [];
  run.enemies = [];
  run.pets = [];
  run.boardRevision = undefined;
}
function profile(player) {
  return JSON.parse(JSON.stringify(player.state.merge));
}
function publish(ctx, run, owner) {
  const projection = {
    owner: run.owner,
    ownerName: owner?.displayName ?? "",
    wave: run.wave,
    enemies: run.enemies.filter((e) => e.hp > 0).length,
    remaining: run.enemies.length,
    director: ctx.self.simulatedBy,
    message: owner?.state.merge?.message ?? "Claim the bay to begin",
  };
  const stamp = JSON.stringify(projection);
  if (run.projection !== stamp) {
    run.projection = stamp;
    ctx.world.state.mergeBay = projection;
  }
}
function point(x, z, y = 0.1) {
  return { x, y, z };
}
function spawn(ctx, run, id, spec) {
  if (ctx.getObject(id)) ctx.destroy(id);
  ctx.spawn({ id, ...spec });
  if (!run.entities.includes(id)) run.entities.push(id);
  return id;
}
function redrawBoard(ctx, run, owner) {
  const scene = DATA.tuning.scene;
  for (let slot = 0; slot < DATA.tuning.boardSlots; slot++) {
    const id = `hh-board-egg-${slot}`,
      tier = owner.state.merge.board[slot];
    if (ctx.getObject(id)) ctx.destroy(id);
    if (tier)
      spawn(ctx, run, id, {
        feetPosition: scene.board[slot],
        model: ASSETS.eggs[DATA.tiers[tier - 1].eggId].url,
        tags: ["hh-board-egg"],
        state: { tier, slot },
      });
  }
  run.boardRevision = owner.state.merge.revision;
}
function redraw(ctx, run, owner) {
  clear(ctx, run);
  const s = owner.state.merge,
    scene = DATA.tuning.scene;
  s.deployed.forEach((tier, slot) => {
    if (!tier) return;
    const x = scene.hatcherX[slot];
    spawn(ctx, run, `hh-egg-${slot}`, {
      feetPosition: point(x, scene.hatcherZ, scene.eggStandHeight),
      model: ASSETS.eggs[DATA.tiers[tier - 1].eggId].url,
      tags: ["hh-egg"],
      state: { tier, slot },
    });
    const count =
      DATA.petsPerHatcher[Math.min(tier, DATA.petsPerHatcher.length) - 1];
    const formation = DATA.presentation.formation,
      scale = scene.sourceTransform.metersPerStud;
    const columns = formation.per_row;
    for (let i = 0; i < count; i++) {
      const id = `hh-pet-${slot}-${i}`,
        home = point(
          x +
            ((i % columns) - (Math.min(count, columns) - 1) / 2) *
              formation.col_spacing *
              scale,
          scene.hatcherZ +
            scene.petHomeOffset -
            Math.floor(i / columns) * formation.row_spacing * scale,
        );
      spawn(ctx, run, id, {
        feetPosition: home,
        behavior: ["scripts/merge-actor.js"],
        simulatedBy: "platform",
        model: ASSETS.doggy.url,
        tags: ["hh-pet"],
        rotation: { yaw: 0 },
        mixer: {
          locomotion: { clip: ASSETS.doggy.clips.walk, loop: "loop", speed: 0 },
        },
        state: {
          slot,
          tier,
          hp: DATA.tuning.simulation.petHealth * tier,
          maxHp: DATA.tuning.simulation.petHealth * tier,
        },
      });
      run.pets.push({
        id,
        slot,
        tier,
        equipSlot: slot * DATA.petsPerHatcher.at(-1) + i + 1,
        ...COMBAT.actors.pet,
        element: DATA.tiers[tier - 1].element,
        cadence: DATA.tuning.simulation.petCadence,
        x: home.x,
        z: home.z,
        home,
        hp: DATA.tuning.simulation.petHealth * tier,
        attackAt: 0,
        recoverAt: 0,
      });
    }
  });
  for (const actor of run.pets) publishPose(ctx, actor);
  redrawBoard(ctx, run, owner);
}
function beginWave(ctx, run, owner) {
  redraw(ctx, run, owner);
  run.wave = owner.state.merge.clearedWave + 1;
  const units = waveUnits(DATA, run.wave),
    [hpFactor, damageFactor] = earlyDifficulty(DATA, run.wave);
  const groups = DATA.waves[run.wave - 1].groups.length,
    scene = DATA.tuning.scene;
  units.forEach((unit, index) => {
    const spec = DATA.archetypes[unit.archetype];
    const x =
      groups === 1
        ? (index - (units.length - 1) / 2) * 1.8
        : (unit.group - (groups - 1) / 2) * 6 + ((index % 3) - 1) * 1.2;
    const z = scene.gateZ - Math.floor(index / groups) * 1.5;
    const id = `hh-enemy-${run.wave}-${index}`;
    spawn(ctx, run, id, {
      feetPosition: point(x, z),
      behavior: ["scripts/merge-actor.js"],
      simulatedBy: "platform",
      model: ASSETS.bear.url,
      scale: spec.rank === "boss" ? 1.8 : spec.rank === "tank" ? 1.2 : 0.85,
      rotation: { yaw: 180 },
      tags: ["hh-enemy"],
      material: { color: scene.colors.hell },
      state: {
        hp: spec.hp * hpFactor,
        maxHp: spec.hp * hpFactor,
        archetype: unit.archetype,
      },
    });
    run.enemies.push({
      id,
      x,
      z,
      ...COMBAT.actors.enemy,
      yaw: 180,
      hp: spec.hp * hpFactor,
      armor: spec.armor,
      damage: spec.damage * damageFactor,
      cadence: spec.cadence,
      element: "lava",
      reward: DATA.rewards[`${spec.reward_kind}_amount`],
      attackAt: 0,
      escaped: false,
    });
  });
  for (const actor of run.enemies) publishPose(ctx, actor);
  ctx.log("hh.wave.started", run.wave, units.length);
}
function stepToward(actor, target, distance) {
  const dx = target.x - actor.x,
    dz = target.z - actor.z,
    gap = Math.hypot(dx, dz);
  if (gap > distance) {
    actor.x += (dx / gap) * distance;
    actor.z += (dz / gap) * distance;
  } else {
    actor.x = target.x;
    actor.z = target.z;
  }
  return gap;
}
export function onSpawn(ctx) {
  runtime(ctx);
  ctx.log("hh.director.ready", ctx.self.simulatedBy);
}
function receive(ctx, request, meta) {
  const run = runtime(ctx),
    actor = ctx.getObject(meta.sourceId);
  if (!actor || !actor.tags.includes("player") || !actor.userId) return;
  if (!actor.state.merge?.version) actor.state.merge = freshProfile(DATA);
  if (request?.kind === "claim") {
    if (run.owner && run.owner !== actor.userId) {
      actor.state.mergeNotice = "This bay is occupied. You can watch this run.";
      return;
    }
    if (run.owner === actor.userId) return;
    run.owner = actor.userId;
    actor.state.merge.status =
      actor.state.merge.clearedWave >= DATA.waves.length ? "complete" : "ready";
    redraw(ctx, run, actor);
    publish(ctx, run, actor);
    return;
  }
  if (run.owner !== actor.userId) {
    actor.state.mergeNotice = "Claim the bay before playing";
    return;
  }
  const window = Math.floor(ctx.now() / 1000),
    previous = run.rate[actor.userId];
  const rate = previous?.window === window ? previous : { window, count: 0 };
  run.rate[actor.userId] = rate;
  if (++rate.count > DATA.tuning.commandsPerSecond) return;
  const result = command(DATA, profile(actor), request);
  actor.state.mergeNotice = result.ok ? "" : result.reason;
  if (!result.ok || result.duplicate) return;
  actor.state.merge = result.profile;
  if (request.kind === "drop")
    actor.state.mergeSelected =
      request.targetKind === "board" ? request.targetSlot : -1;
  if (request.kind === "start") beginWave(ctx, run, actor);
  else if (
    (["deploy", "recall", "upgrade", "restart"].includes(request.kind) ||
      (request.kind === "drop" && request.targetKind === "hatcher")) &&
    result.profile.status !== "fighting"
  )
    redraw(ctx, run, actor);
  if (request.kind === "merge" || request.kind === "drop") {
    const tier =
      request.kind === "merge"
        ? actor.state.merge.board[request.to ?? actor.state.mergeSelected]
        : request.targetKind === "board"
          ? actor.state.merge.board[request.targetSlot]
          : actor.state.merge.deployed[request.targetSlot];
    const info = DATA.tiers[Math.max(0, (tier ?? 1) - 1)];
    const p =
      request.targetKind === "hatcher"
        ? point(
            DATA.tuning.scene.hatcherX[request.targetSlot],
            DATA.tuning.scene.hatcherZ,
            1,
          )
        : (DATA.tuning.scene.board[
            request.targetSlot ?? request.to ?? actor.state.mergeSelected
          ] ?? DATA.tuning.scene.board[0]);
    ctx.emit(
      "fx",
      {
        position: p,
        script: effectProgram(DATA, COMBAT, info.element, "merge"),
      },
      { audience: { kind: "all" } },
    );
  }
  publish(ctx, run, actor);
}
export const ears = { "hh:command": receive };

export function update(ctx, dt) {
  const run = runtime(ctx);
  run.clock++;
  const players = ctx.world.players;
  for (const player of players)
    if (!player.state.merge?.version) player.state.merge = freshProfile(DATA);
  const owner = players.find((p) => p.userId === run.owner);
  if (run.owner && !owner) {
    clear(ctx, run);
    run.owner = null;
    publish(ctx, run, null);
    return;
  }
  if (!owner) {
    publish(ctx, run, null);
    return;
  }
  if (run.sceneVersion !== DATA.tuning.scene.sceneVersion) {
    run.sceneVersion = DATA.tuning.scene.sceneVersion;
    owner.state.merge.status = "ready";
    redraw(ctx, run, owner);
  }
  if (
    run.presentationVersion !== COMBAT.version &&
    owner.state.merge.status !== "fighting"
  ) {
    run.presentationVersion = COMBAT.version;
    redraw(ctx, run, owner);
  }
  if (run.boardRevision !== owner.state.merge.revision)
    redrawBoard(ctx, run, owner);
  if (owner.state.merge.status !== "fighting") {
    publish(ctx, run, owner);
    return;
  }
  const cfg = DATA.tuning.simulation,
    scene = DATA.tuning.scene,
    now = ctx.now() / 1000;
  // Existing open fights can hot-load this presentation without resetting their wave or wallet.
  for (const [kind, actors] of [
    ["pet", run.pets],
    ["enemy", run.enemies],
  ])
    for (const [index, actor] of actors.entries()) {
      actor.role ??= COMBAT.actors[kind].role;
      actor.petType ??= COMBAT.actors[kind].petType;
      actor.equipSlot ??= index + 1;
      const object = ctx.getObject(actor.id);
      if (object && object.state.presentationVersion !== COMBAT.version) {
        object.behavior = ["scripts/merge-actor.js"];
        object.simulatedBy = "platform";
        object.state.presentationVersion = COMBAT.version;
      }
    }
  const live = run.enemies.filter((enemy) => enemy.hp > 0);
  for (const pet of run.pets) {
    if (pet.hp <= 0 && now >= pet.recoverAt) {
      pet.hp = cfg.petHealth * pet.tier;
      pet.x = pet.home.x;
      pet.z = pet.home.z;
      pet.strikeAt = null;
      pet.reactAt = null;
      pet.targetId = null;
      const object = ctx.getObject(pet.id);
      if (object) {
        object.visible = true;
        object.state.hp = pet.hp;
      }
    }
  }
  assignAttackSlots(run.pets, live, now, DATA, COMBAT);
  for (const pet of run.pets) {
    if (pet.hp <= 0) continue;
    const target = live.find((e) => e.id === pet.targetId && e.hp > 0),
      before = { x: pet.x, z: pet.z };
    const goal = target ? pet.goal : pet.home;
    stepToward(pet, goal, cfg.petSpeed * dt);
    if (target) {
      faceTarget(ctx, pet, target);
      const distance = Math.hypot(target.x - pet.x, target.z - pet.z),
        toSlot = Math.hypot(goal.x - pet.x, goal.z - pet.z);
      if (
        distance <= pet.reach &&
        toSlot <= COMBAT.slotArrivalTolerance &&
        now >= pet.attackAt
      ) {
        const result = combatHit(
          ctx,
          run,
          pet,
          target,
          mitigate(cfg.petDamage * 2 ** (pet.tier - 1), target.armor),
          DATA,
          COMBAT,
        );
        pet.attackAt = now + cfg.petCadence;
        if (result.killed) {
          ctx.destroy(target.id);
          owner.state.merge.uncollected += target.reward;
          owner.state.merge.kills++;
        }
      }
    } else if (
      Math.hypot(pet.x - before.x, pet.z - before.z) >
      COMBAT.animation.motionEpsilon
    )
      faceTarget(ctx, pet, goal);
    publishPose(ctx, pet);
    presentActor(
      ctx,
      pet,
      now,
      Math.hypot(pet.x - before.x, pet.z - before.z),
      ASSETS.doggy,
      DATA,
      COMBAT,
    );
  }
  for (const enemy of live) {
    if (enemy.hp <= 0) continue;
    let target = null,
      nearest =
        DATA.presentation.roles.roles.tank.attack_range *
        scene.sourceTransform.metersPerStud;
    for (const pet of run.pets) {
      const distance = Math.hypot(enemy.x - pet.x, enemy.z - pet.z);
      if (pet.hp > 0 && distance < nearest) {
        nearest = distance;
        target = pet;
      }
    }
    const before = { x: enemy.x, z: enemy.z };
    if (target) faceTarget(ctx, enemy, target);
    if (target && now >= enemy.attackAt) {
      combatHit(ctx, run, enemy, target, enemy.damage, DATA, COMBAT);
      enemy.attackAt = now + enemy.cadence;
      if (target.hp <= 0) {
        target.recoverAt = now + cfg.petRecovery;
        const o = ctx.getObject(target.id);
        if (o) o.visible = false;
      }
    } else if (!target) enemy.z += cfg.enemySpeed * dt;
    if (!target) enemy.yaw = 180;
    publishPose(ctx, enemy);
    presentActor(
      ctx,
      enemy,
      now,
      Math.hypot(enemy.x - before.x, enemy.z - before.z),
      ASSETS.bear,
      DATA,
      COMBAT,
    );
    if (enemy.z >= scene.breachZ) {
      enemy.hp = 0;
      enemy.escaped = true;
      ctx.destroy(enemy.id);
      owner.state.merge.reserve = Math.max(
        0,
        owner.state.merge.reserve - DATA.objective.damage_per_escape,
      );
    }
  }
  if (owner.state.merge.reserve <= 0) {
    owner.state.merge.status = "lost";
    owner.state.merge.message =
      "The reserve is empty. Restart from your checkpoint.";
    clear(ctx, run);
  } else if (run.enemies.every((e) => e.hp <= 0)) {
    const s = profile(owner);
    s.clearedWave = run.wave;
    if (run.wave % DATA.checkpoints.interval === 0) s.checkpoint = run.wave;
    s.status = run.wave >= DATA.waves.length ? "complete" : "ready";
    s.message =
      s.status === "complete"
        ? "Wave 10 clear — checkpoint saved. Your bay is ready for the next porting stage."
        : `Wave ${run.wave} clear. Collect your Waycoins and improve the line.`;
    s.revision++;
    owner.state.merge = s;
    redraw(ctx, run, owner);
    ctx.log("hh.wave.cleared", run.wave, s.checkpoint);
  }
  publish(ctx, run, owner);
}
