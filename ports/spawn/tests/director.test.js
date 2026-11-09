import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import * as core from '../world/scripts/lib/merge-core.js';
const DATA = JSON.parse(fs.readFileSync(new URL('../world/scripts/lib/data/merge.yml', import.meta.url)));
const ASSETS = JSON.parse(fs.readFileSync(new URL('../world/scripts/lib/data/assets.yml', import.meta.url)));
// Run the actual behavior behind a minimal in-memory adapter. Engine transport/save guarantees
// are tested in the live room; this exercises its combat, command gate and checkpoint logic.
const source = fs.readFileSync(new URL('../world/scripts/merge-director.js', import.meta.url), 'utf8').replace(/^import .*;\n/gm, '').replace(/export /g, '');
const load = new Function('DATA','ASSETS','freshProfile','command','earlyDifficulty','waveUnits','mitigate',source+'\nreturn {onSpawn, update, ears};');
function harness() {
  const code=load(DATA,ASSETS,core.freshProfile,core.command,core.earlyDifficulty,core.waveUnits,core.mitigate);
  let now=0;const objects=new Map();
  const owner={id:'owner',userId:'owner-user',displayName:'Owner',tags:['player'],state:{merge:core.freshProfile(DATA)}};
  const visitor={id:'visitor',userId:'visitor-user',displayName:'Visitor',tags:['player'],state:{merge:core.freshProfile(DATA)}};
  objects.set(owner.id,owner);objects.set(visitor.id,visitor);
  const ctx={self:{session:{},simulatedBy:'platform'},world:{players:[owner,visitor],state:{}},now:()=>now,log:()=>{},getObject:id=>objects.get(id),destroy:id=>objects.delete(id),spawn:spec=>objects.set(spec.id,{tags:[],state:{},...spec})};
  code.onSpawn(ctx);
  const send=(who,kind,payload={})=>code.ears['hh:command'](ctx,{kind,nonce:`${who.id}-${kind}-${now}`, ...payload},{sourceId:who.id});
  const step=()=>{now+=DATA.tuning.simulation.step*1000;code.update(ctx,DATA.tuning.simulation.step);};
  return {code,ctx,owner,visitor,send,step,objects};
}
test('director authenticates the event source, ignores claimed actor IDs, and deduplicates purchases',()=>{
  const h=harness();h.send(h.owner,'claim');h.send(h.owner,'collect');
  const before=structuredClone(h.owner.state.merge);
  h.send(h.visitor,'buy',{userId:h.owner.userId,actor:h.owner.id});
  assert.deepEqual(h.owner.state.merge,before);assert.equal(h.visitor.state.merge.coins,0);
  h.send(h.owner,'buy',{nonce:'once'});h.send(h.owner,'buy',{nonce:'once'});
  assert.equal(h.owner.state.merge.coins,500);assert.equal(h.owner.state.merge.board.filter(Boolean).length,1);
});
test('actual director clears all ten source waves and stamps checkpoint 10',()=>{
  const h=harness();h.send(h.owner,'claim');h.owner.state.merge.deployed=Array(DATA.tuning.hatcherCount).fill(4);
  let ticks=0;
  for(let wave=1;wave<=10;wave++) {
    h.send(h.owner,'start');assert.equal(h.owner.state.merge.status,'fighting');
    for(let n=0;n<6000 && h.owner.state.merge.status==='fighting';n++){h.step();ticks++;}
    assert.equal(h.owner.state.merge.clearedWave,wave,`wave ${wave}, status ${h.owner.state.merge.status}`);
    assert.ok(h.owner.state.merge.reserve>0);assert.ok(core.invariant(DATA,h.owner.state.merge));
  }
  assert.equal(h.owner.state.merge.status,'complete');assert.equal(h.owner.state.merge.checkpoint,10);assert.ok(h.owner.state.merge.uncollected>DATA.economy.openingCoins);
});
test('owner departure frees the shared bay without deleting saved economy or eggs',()=>{
  const h=harness();h.send(h.owner,'claim');h.send(h.owner,'collect');const saved=structuredClone(h.owner.state.merge);
  h.ctx.world.players=[h.visitor];h.step();assert.equal(h.ctx.world.state.mergeBay.owner,null);assert.deepEqual(h.owner.state.merge,saved);
  h.send(h.visitor,'claim');assert.equal(h.ctx.world.state.mergeBay.owner,h.visitor.userId);
});
