// Engine-independent HH slice. Runtime adapters supply validated actor identity and a config.
export function eggPrice(data, tier) {
  const t = Math.max(1, Math.floor(tier));
  return t === 1 ? data.economy.basePrice : Math.floor(data.economy.firstUpgradedPrice * Math.max(2, data.economy.growth) ** (t - 2) + 0.5);
}
export function mitigate(damage, armor, k = 100) {
  return Math.max(0, damage * (1 - Math.max(0, armor) / (Math.max(0, armor) + k)));
}
export function earlyDifficulty(data, wave) {
  const points = data.earlyDifficulty.checkpoints;
  if (!data.earlyDifficulty.enabled) return [1, 1];
  let previous = points[0];
  for (const point of points) {
    if (wave <= point.wave) {
      const alpha = point.wave > previous.wave ? Math.max(0, Math.min(1, (wave - previous.wave) / (point.wave - previous.wave))) : 0;
      return [previous.hp_multiplier + (point.hp_multiplier - previous.hp_multiplier) * alpha, previous.damage_multiplier + (point.damage_multiplier - previous.damage_multiplier) * alpha];
    }
    previous = point;
  }
  return [previous.hp_multiplier, previous.damage_multiplier];
}
export function waveUnits(data, wave) {
  const plan = data.waves[wave - 1];
  if (!plan) return [];
  const out = [];
  for (let group = 0; group < plan.groups.length; group++) {
    for (const unit of plan.groups[group].units) {
      for (let n = 0; n < unit.count; n++) out.push({ archetype: unit.archetype, group });
    }
  }
  return out;
}
export function freshProfile(data) {
  return { version: 1, coins: 0, uncollected: data.economy.openingCoins, board: Array(data.tuning.boardSlots).fill(0), deployed: Array(data.tuning.hatcherCount).fill(0), generator: 1, clearedWave: 0, checkpoint: 0, reserve: data.objective.starting_eggs, kills: 0, status: 'ready', revision: 0, seen: [], message: 'Collect the opening Waycoins, buy two eggs, merge, then deploy.' };
}
const copy = (value) => JSON.parse(JSON.stringify(value));
function validIndex(index, length) { return Number.isInteger(index) && index >= 0 && index < length; }
export function command(data, profile, request) {
  if (!request || typeof request.nonce !== 'string' || request.nonce.length < 1 || request.nonce.length > 80) return { ok: false, reason: 'Invalid request ID', profile };
  if (profile.seen.includes(request.nonce)) return { ok: true, duplicate: true, profile };
  const next = copy(profile), board = next.board, deployed = next.deployed;
  const reject = (reason) => ({ ok: false, reason, profile });
  const empty = () => board.findIndex(tier => tier === 0);
  const selected = () => validIndex(request.from, board.length) && board[request.from] > 0;
  let message;
  switch (request.kind) {
    case 'collect': {
      if (!next.uncollected) return reject('No Waycoins to collect yet');
      const amount = next.uncollected;
      next.coins += amount; next.uncollected = 0;
      message = `Collected ${amount} Waycoins`;
      break;
    }
    case 'buy': {
      const slot = empty(), price = eggPrice(data, next.generator);
      if (slot < 0) return reject('The egg board is full');
      if (next.coins < price) return reject(`Need ${price} Waycoins`);
      next.coins -= price; board[slot] = next.generator;
      message = `Bought a Tier ${next.generator} egg`;
      break;
    }
    case 'drop': {
      if (!selected()) return reject('That egg is no longer on the board');
      const tier = board[request.from];
      if (request.expectedTier !== tier) return reject('The dragged egg changed; try again');
      const target = request.targetSlot;
      let destination;
      if (request.targetKind === 'board') {
        if (!validIndex(target, board.length)) return reject('Unknown board slot');
        if (target === request.from) return reject('Drop onto another slot');
        destination = board;
      } else if (request.targetKind === 'hatcher') {
        if (next.status === 'fighting') return reject('Change installed eggs after the wave');
        if (!validIndex(target, deployed.length)) return reject('Unknown hatcher');
        destination = deployed;
      } else return reject('Unknown drop target');
      if (request.expectedTargetTier !== destination[target]) return reject('The destination changed; try again');
      if (destination[target]) {
        if (destination[target] !== tier) return reject('Stack two eggs of the same tier');
        if (tier >= data.tuning.tiers.length) return reject('Maximum prototype tier');
        destination[target] = tier + 1;
        message = `Merged a Tier ${tier + 1} egg`;
      } else {
        destination[target] = tier;
        message = request.targetKind === 'hatcher' ? `Deployed hatcher ${target + 1}` : 'Egg moved';
      }
      board[request.from] = 0;
      break;
    }
    case 'merge': {
      if (!selected()) return reject('Select an egg on the board');
      const tier = board[request.from];
      if (tier >= data.tuning.tiers.length) return reject('Maximum prototype tier');
      const target = request.to ?? board.findIndex((value, index) => index !== request.from && value === tier);
      if (!validIndex(target, board.length) || target === request.from || board[target] !== tier) return reject('Two equal-tier eggs are required');
      board[request.from] = 0; board[target] = tier + 1;
      message = `Merged a Tier ${tier + 1} egg`;
      break;
    }
    case 'deploy': {
      if (next.status === 'fighting') return reject('Deploy after the wave');
      if (!selected()) return reject('Select an egg on the board');
      if (!validIndex(request.slot, deployed.length)) return reject('Unknown hatcher');
      if (deployed[request.slot]) return reject('Recall the installed egg first');
      deployed[request.slot] = board[request.from]; board[request.from] = 0;
      message = `Deployed hatcher ${request.slot + 1}`;
      break;
    }
    case 'recall': {
      if (next.status === 'fighting') return reject('Recall after the wave');
      if (!validIndex(request.slot, deployed.length) || !deployed[request.slot]) return reject('That hatcher is empty');
      const slot = empty(); if (slot < 0) return reject('The egg board is full');
      board[slot] = deployed[request.slot]; deployed[request.slot] = 0;
      message = 'Egg returned to the board';
      break;
    }
    case 'upgrade': {
      if (next.status === 'fighting') return reject('Upgrade after the wave');
      if (next.generator >= data.tuning.tiers.length) return reject('Maximum prototype generator');
      const price = eggPrice(data, next.generator + 1) * deployed.length * data.economy.upgradeMultiplier;
      if (next.coins < price) return reject(`Need ${price} Waycoins`);
      next.coins -= price; next.generator++;
      next.deployed = deployed.map(tier => tier ? Math.max(tier, next.generator) : 0);
      message = `Generator upgraded to Tier ${next.generator}`;
      break;
    }
    case 'start': {
      if (next.status === 'fighting') return reject('A wave is already running');
      if (!deployed.some(Boolean)) return reject('Deploy an egg first');
      if (next.clearedWave >= data.waves.length) return reject('The ten-wave capability run is complete');
      if (next.reserve <= 0) return reject('Restart the run to restore reserve eggs');
      next.status = 'fighting'; message = `Wave ${next.clearedWave + 1}`;
      break;
    }
    case 'restart': {
      if (next.status === 'fighting') return reject('Finish the current wave first');
      next.clearedWave = next.checkpoint;
      next.reserve = data.objective.starting_eggs;
      next.status = 'ready'; message = 'Run resumed from the checkpoint';
      break;
    }
    default: return reject('Unknown command');
  }
  next.revision++;
  next.seen = [...next.seen, request.nonce].slice(-data.tuning.commandHistory);
  next.message = message;
  return { ok: true, profile: next };
}
export function invariant(data, profile) {
  return Number.isSafeInteger(profile.coins) && profile.coins >= 0 && Number.isSafeInteger(profile.uncollected) && profile.uncollected >= 0 && profile.board.length === data.tuning.boardSlots && profile.deployed.length === data.tuning.hatcherCount && [...profile.board, ...profile.deployed].every(t => Number.isInteger(t) && t >= 0 && t <= data.tuning.tiers.length);
}
