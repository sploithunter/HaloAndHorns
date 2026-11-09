import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { eggPrice, mitigate, earlyDifficulty, waveUnits, freshProfile, command, invariant } from '../world/scripts/lib/merge-core.js';
const data = JSON.parse(fs.readFileSync(new URL('../world/scripts/lib/data/merge.yml', import.meta.url)));
const fixtures = JSON.parse(fs.readFileSync(new URL('./fixtures.json', import.meta.url)));
test('JavaScript agrees with source Luau prices, armor, early relief and all ten wave counts', () => {
  for (const row of fixtures.prices) assert.equal(eggPrice(data, row.tier), row.amount);
  for (const row of fixtures.mitigation) assert.ok(Math.abs(mitigate(row.damage, row.armor, row.k) - row.result) < 1e-9);
  for (const row of fixtures.difficulty) {
    const [hp, damage] = earlyDifficulty(data, row.wave);
    assert.ok(Math.abs(hp - row.hp) < 1e-9); assert.ok(Math.abs(damage - row.damage) < 1e-9);
  }
  for (const row of fixtures.waveCounts) assert.equal(waveUnits(data, row.wave).length, row.count);
});
test('collect, buy, merge, deploy and recall conserve egg value and currency', () => {
  let state = freshProfile(data), sequence = 0;
  const act = (kind, payload = {}) => {
    const result = command(data, state, { kind, nonce: String(++sequence), ...payload });
    assert.equal(result.ok, true, result.reason); state = result.profile;
    assert.equal(invariant(data, state), true);
  };
  act('collect'); assert.equal(state.coins, 600);
  act('buy'); act('buy'); assert.equal(state.coins, 400);
  act('merge', { from: 0, to: 1 }); assert.equal(state.board[1], 2);
  act('deploy', { from: 1, slot: 0 }); assert.equal(state.deployed[0], 2);
  act('recall', { slot: 0 }); assert.equal(state.board[0], 2);
  assert.equal(state.board.filter(Boolean).length, 1);
});
test('replayed purchases are idempotent and rejected input cannot mutate a profile', () => {
  const state = freshProfile(data); state.coins = 500;
  const request = { kind: 'buy', nonce: 'same-request' };
  const first = command(data, state, request);
  const replay = command(data, first.profile, request);
  assert.equal(replay.duplicate, true); assert.deepEqual(replay.profile, first.profile);
  const before = JSON.stringify(first.profile);
  for (const request of [
    { kind: 'deploy', from: -1, slot: 0 }, { kind: 'deploy', from: 0, slot: 999 },
    { kind: 'merge', from: 0, to: 0 }, { kind: 'merge', from: NaN, to: 1 },
    { kind: 'credit', amount: 100000000 }, { kind: 'buy', nonce: '' },
  ]) {
    const result = command(data, first.profile, { nonce: 'rejected', ...request });
    assert.equal(result.ok, false); assert.equal(JSON.stringify(first.profile), before);
  }
});
test('full boards, insufficient funds, active recalls and repeated starts reject safely', () => {
  const initial = freshProfile(data);
  assert.equal(command(data, initial, { kind: 'buy', nonce: 'poor' }).ok, false);
  const full = { ...initial, coins: 1000, board: Array(data.tuning.boardSlots).fill(1) };
  assert.equal(command(data, full, { kind: 'buy', nonce: 'full' }).ok, false);
  const deployed = { ...initial, deployed: [1, 0, 0, 0] };
  const started = command(data, deployed, { kind: 'start', nonce: 'start' }).profile;
  assert.equal(command(data, started, { kind: 'start', nonce: 'again' }).ok, false);
  assert.equal(command(data, started, { kind: 'recall', nonce: 'recall', slot: 0 }).ok, false);
});
test('generator upgrades use the canonical capacity-dependent quote and preserve installed eggs', () => {
  const state = freshProfile(data); state.coins = 2000; state.deployed[0] = 1;
  const result = command(data, state, { kind: 'upgrade', nonce: 'upgrade' });
  assert.equal(result.ok, true); assert.equal(result.profile.coins, 0);
  assert.equal(result.profile.generator, 2); assert.deepEqual(result.profile.deployed, [2, 0, 0, 0]);
});
