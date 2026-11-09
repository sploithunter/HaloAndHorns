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
test('drag drops move board eggs, merge exact targets and upgrade an occupied stand atomically', () => {
  let state=freshProfile(data);state.board[0]=1;state.board[1]=1;state.board[2]=2;
  const drop=(from,targetKind,targetSlot,nonce)=>{
    const target=targetKind==='board' ? state.board : state.deployed;
    const request={kind:'drop',from,targetKind,targetSlot,expectedTier:state.board[from],expectedTargetTier:target[targetSlot],nonce};
    const result=command(data,state,request);assert.equal(result.ok,true,result.reason);state=result.profile;
    assert.ok(invariant(data,state));return request;
  };
  drop(0,'board',3,'move');assert.equal(state.board[0],0);assert.equal(state.board[3],1);
  drop(1,'board',3,'board-stack');assert.equal(state.board[3],2);assert.equal(state.board[1],0);
  drop(3,'hatcher',0,'install');assert.equal(state.deployed[0],2);assert.equal(state.board[3],0);
  const request=drop(2,'hatcher',0,'stand-stack');assert.equal(state.deployed[0],3);assert.equal(state.board[2],0);
  assert.equal(command(data,state,request).duplicate,true);assert.equal(state.coins,0);
});
test('invalid and stale drag drops preserve both eggs and reject stand changes during combat',()=>{
  const state=freshProfile(data);state.board[0]=2;state.board[1]=1;state.deployed[0]=2;
  const base={kind:'drop',from:0,expectedTier:2,targetKind:'board',targetSlot:1,expectedTargetTier:1,nonce:'reject-drop'};
  for(const change of [{},{from:999},{from:-1},{targetSlot:99},{targetSlot:0,expectedTargetTier:2},{expectedTier:1},{targetKind:'bad'},{targetKind:'hatcher',targetSlot:0,expectedTargetTier:1}]) {
    const before=JSON.stringify(state),result=command(data,state,{...base,...change});
    assert.equal(result.ok,false);assert.equal(JSON.stringify(state),before);assert.strictEqual(result.profile,state);
  }
  const fighting={...state,status:'fighting'};
  assert.equal(command(data,fighting,{...base,targetKind:'hatcher',targetSlot:0,expectedTargetTier:2}).ok,false);
  const maximum={...state,board:[4,4,...state.board.slice(2)]};
  assert.equal(command(data,maximum,{...base,expectedTier:4,expectedTargetTier:4}).ok,false);
});
