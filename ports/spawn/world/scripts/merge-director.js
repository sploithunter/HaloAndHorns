import DATA from './lib/data/merge.yml';
import ASSETS from './lib/data/assets.yml';
import { freshProfile, command, earlyDifficulty, waveUnits, mitigate } from './lib/merge-core.js';

export const updateSchedule = { every: { seconds: DATA.tuning.simulation.step } };
function runtime(ctx) {
  return (ctx.self.session.mergeRuntime ??= { sceneVersion: DATA.tuning.scene.sceneVersion, owner: null, entities: [], enemies: [], pets: [], wave: 0, clock: 0, rate: {} });
}
function clear(ctx, run) {
  for (const id of run.entities) if (ctx.getObject(id)) ctx.destroy(id);
  run.entities = []; run.enemies = []; run.pets = []; run.boardRevision = undefined;
}
function profile(player) { return JSON.parse(JSON.stringify(player.state.merge)); }
function publish(ctx, run, owner) {
  const projection = {
    owner: run.owner, ownerName: owner?.displayName ?? '', wave: run.wave,
    enemies: run.enemies.filter(e => e.hp > 0).length,
    remaining: run.enemies.length,
    director: ctx.self.simulatedBy, message: owner?.state.merge?.message ?? 'Claim the bay to begin',
  };
  const stamp = JSON.stringify(projection);
  if (run.projection !== stamp) { run.projection = stamp; ctx.world.state.mergeBay = projection; }
}
function point(x, z, y = 0.1) { return { x, y, z }; }
function spawn(ctx, run, id, spec) {
  if (ctx.getObject(id)) ctx.destroy(id);
  ctx.spawn({ id, ...spec }); run.entities.push(id); return id;
}
function redrawBoard(ctx, run, owner) {
  const scene = DATA.tuning.scene;
  for (let slot = 0; slot < DATA.tuning.boardSlots; slot++) {
    const id = `hh-board-egg-${slot}`, tier = owner.state.merge.board[slot];
    if (ctx.getObject(id)) ctx.destroy(id);
    if (tier) spawn(ctx, run, id, { feetPosition: scene.board[slot], primitive: { kind: 'sphere', radius: scene.eggRadius }, scale: { x: 0.8, y: 1.2, z: 0.8 }, material: { color: scene.colors.tier[tier - 1], roughness: 0.4 }, tags: ['hh-board-egg'], state: { tier, slot } });
  }
  run.boardRevision = owner.state.merge.revision;
}
function redraw(ctx, run, owner) {
  clear(ctx, run);
  const s = owner.state.merge, scene = DATA.tuning.scene;
  s.deployed.forEach((tier, slot) => {
    if (!tier) return;
    const x = scene.hatcherX[slot];
    spawn(ctx, run, `hh-egg-${slot}`, { feetPosition: point(x, scene.hatcherZ, scene.eggStandHeight), primitive: { kind: 'sphere', radius: scene.eggRadius }, scale: { x: 0.85, y: 1.15, z: 0.85 }, material: { color: scene.colors.tier[tier - 1], roughness: 0.35, metalness: 0.25 }, tags: ['hh-egg'], state: { tier, slot } });
    const count = DATA.petsPerHatcher[Math.min(tier, DATA.petsPerHatcher.length) - 1];
    for (let i = 0; i < count; i++) {
      const id = `hh-pet-${slot}-${i}`, home = point(x + (i - (count - 1) / 2) * scene.petSpacing, scene.hatcherZ + scene.petHomeOffset);
      spawn(ctx, run, id, { feetPosition: home, model: ASSETS.doggy.url, tags: ['hh-pet'], rotation: { yaw: 0 }, mixer: { action: { clip: ASSETS.doggy.clip, loop: 'loop', speed: 0.6 } }, state: { slot, tier } });
      run.pets.push({ id, slot, tier, x: home.x, z: home.z, home, hp: DATA.tuning.simulation.petHealth * tier, attackAt: 0, recoverAt: 0 });
    }
  });
  redrawBoard(ctx, run, owner);
}
function beginWave(ctx, run, owner) {
  redraw(ctx, run, owner);
  run.wave = owner.state.merge.clearedWave + 1;
  const units = waveUnits(DATA, run.wave), [hpFactor, damageFactor] = earlyDifficulty(DATA, run.wave);
  const groups = DATA.waves[run.wave - 1].groups.length, scene = DATA.tuning.scene;
  units.forEach((unit, index) => {
    const spec = DATA.archetypes[unit.archetype];
    const x = groups === 1 ? (index - (units.length - 1) / 2) * 1.8 : (unit.group - (groups - 1) / 2) * 6 + (index % 3 - 1) * 1.2;
    const z = scene.gateZ - Math.floor(index / groups) * 1.5;
    const id = `hh-enemy-${run.wave}-${index}`;
    spawn(ctx, run, id, { feetPosition: point(x, z), model: ASSETS.bear.url, scale: spec.rank === 'boss' ? 1.8 : spec.rank === 'tank' ? 1.2 : 0.85, rotation: { yaw: 180 }, tags: ['hh-enemy'], material: { color: scene.colors.hell }, state: { hp: spec.hp * hpFactor, maxHp: spec.hp * hpFactor, archetype: unit.archetype } });
    run.enemies.push({ id, x, z, hp: spec.hp * hpFactor, armor: spec.armor, damage: spec.damage * damageFactor, cadence: spec.cadence, reward: DATA.rewards[`${spec.reward_kind}_amount`], attackAt: 0, escaped: false });
  });
  ctx.log('hh.wave.started', run.wave, units.length);
}
function stepToward(actor, target, distance) {
  const dx = target.x - actor.x, dz = target.z - actor.z, gap = Math.hypot(dx, dz);
  if (gap > distance) { actor.x += dx / gap * distance; actor.z += dz / gap * distance; }
  else { actor.x = target.x; actor.z = target.z; }
  return gap;
}
function move(ctx, actor) {
  const object = ctx.getObject(actor.id);
  if (object) object.feetPosition = point(actor.x, actor.z);
}
export function onSpawn(ctx) {
  runtime(ctx);
  ctx.log('hh.director.ready', ctx.self.simulatedBy);
}
function receive(ctx, request, meta) {
  const run = runtime(ctx), actor = ctx.getObject(meta.sourceId);
  if (!actor || !actor.tags.includes('player') || !actor.userId) return;
  if (!actor.state.merge?.version) actor.state.merge = freshProfile(DATA);
  if (request?.kind === 'claim') {
    if (run.owner && run.owner !== actor.userId) { actor.state.mergeNotice = 'This bay is occupied. You can watch this run.'; return; }
    if (run.owner === actor.userId) return;
    run.owner = actor.userId;
    actor.state.merge.status = 'ready';
    redraw(ctx, run, actor); publish(ctx, run, actor); return;
  }
  if (run.owner !== actor.userId) { actor.state.mergeNotice = 'Claim the bay before playing'; return; }
  const window = Math.floor(ctx.now() / 1000), previous = run.rate[actor.userId];
  const rate = previous?.window === window ? previous : { window, count: 0 };
  run.rate[actor.userId] = rate;
  if (++rate.count > DATA.tuning.commandsPerSecond) return;
  const result = command(DATA, profile(actor), request);
  actor.state.mergeNotice = result.ok ? '' : result.reason;
  if (!result.ok || result.duplicate) return;
  actor.state.merge = result.profile;
  if (request.kind === 'drop') actor.state.mergeSelected = request.targetKind === 'board' ? request.targetSlot : -1;
  if (request.kind === 'start') beginWave(ctx, run, actor);
  else if ((['deploy', 'recall', 'upgrade', 'restart'].includes(request.kind) || (request.kind === 'drop' && request.targetKind === 'hatcher')) && result.profile.status !== 'fighting') redraw(ctx, run, actor);
  publish(ctx, run, actor);
}
export const ears = { 'hh:command': receive };

export function update(ctx, dt) {
  const run = runtime(ctx); run.clock++;
  const players = ctx.world.players;
  for (const player of players) if (!player.state.merge?.version) player.state.merge = freshProfile(DATA);
  const owner = players.find(p => p.userId === run.owner);
  if (run.owner && !owner) { clear(ctx, run); run.owner = null; publish(ctx, run, null); return; }
  if (!owner) { publish(ctx, run, null); return; }
  if (run.sceneVersion !== DATA.tuning.scene.sceneVersion) {
    run.sceneVersion = DATA.tuning.scene.sceneVersion; owner.state.merge.status = 'ready'; redraw(ctx, run, owner);
  }
  if (run.boardRevision !== owner.state.merge.revision) redrawBoard(ctx, run, owner);
  if (owner.state.merge.status !== 'fighting') { publish(ctx, run, owner); return; }
  const cfg = DATA.tuning.simulation, scene = DATA.tuning.scene, now = ctx.now() / 1000;
  const live = run.enemies.filter(enemy => enemy.hp > 0);
  for (const pet of run.pets) {
    if (pet.hp <= 0) {
      if (now < pet.recoverAt) continue;
      pet.hp = cfg.petHealth * pet.tier; pet.x = pet.home.x; pet.z = pet.home.z;
      const object = ctx.getObject(pet.id); if (object) object.visible = true;
    }
    let target = null, nearest = cfg.engageDistance;
    for (const enemy of live) {
      const distance = Math.hypot(enemy.x - pet.x, enemy.z - pet.z);
      if (enemy.hp > 0 && distance < nearest) { nearest = distance; target = enemy; }
    }
    if (target) {
      stepToward(pet, target, cfg.petSpeed * dt);
      if (nearest <= cfg.attackDistance && now >= pet.attackAt) {
        target.hp -= mitigate(cfg.petDamage * 2 ** (pet.tier - 1), target.armor);
        pet.attackAt = now + cfg.petCadence;
        const object = ctx.getObject(target.id); if (object) object.state.hp = Math.max(0, target.hp);
        if (target.hp <= 0) {
          if (object) ctx.destroy(target.id);
          owner.state.merge.uncollected += target.reward;
          owner.state.merge.kills++;
        }
      }
    } else stepToward(pet, pet.home, cfg.petSpeed * dt);
    move(ctx, pet);
  }
  for (const enemy of live) {
    if (enemy.hp <= 0) continue;
    let target = null, nearest = cfg.attackDistance;
    for (const pet of run.pets) {
      const distance = Math.hypot(enemy.x - pet.x, enemy.z - pet.z);
      if (pet.hp > 0 && distance < nearest) { nearest = distance; target = pet; }
    }
    if (target && now >= enemy.attackAt) {
      target.hp -= enemy.damage; enemy.attackAt = now + enemy.cadence;
      if (target.hp <= 0) { target.recoverAt = now + cfg.petRecovery; const o = ctx.getObject(target.id); if (o) o.visible = false; }
    } else if (!target) enemy.z += cfg.enemySpeed * dt;
    move(ctx, enemy);
    if (enemy.z >= scene.breachZ) {
      enemy.hp = 0; enemy.escaped = true; ctx.destroy(enemy.id);
      owner.state.merge.reserve = Math.max(0, owner.state.merge.reserve - DATA.objective.damage_per_escape);
    }
  }
  if (owner.state.merge.reserve <= 0) {
    owner.state.merge.status = 'lost'; owner.state.merge.message = 'The reserve is empty. Restart from your checkpoint.';
    clear(ctx, run);
  } else if (run.enemies.every(e => e.hp <= 0)) {
    const s = profile(owner); s.clearedWave = run.wave;
    if (run.wave % DATA.checkpoints.interval === 0) s.checkpoint = run.wave;
    s.status = run.wave >= DATA.waves.length ? 'complete' : 'ready';
    s.message = s.status === 'complete' ? 'Wave 10 clear — checkpoint saved. Your bay is ready for the next porting stage.' : `Wave ${run.wave} clear. Collect your Waycoins and improve the line.`;
    s.revision++; owner.state.merge = s;
    redraw(ctx, run, owner); ctx.log('hh.wave.cleared', run.wave, s.checkpoint);
  }
  publish(ctx, run, owner);
}
