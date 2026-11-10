import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import {
  combatHit,
  presentActor,
  effectProgram,
} from "../world/scripts/lib/merge-presentation.js";
const read = (name) =>
  JSON.parse(
    fs.readFileSync(
      new URL("../world/scripts/lib/data/" + name + ".yml", import.meta.url),
    ),
  );
const data = read("merge"),
  config = read("combat"),
  assets = read("assets");
test("damage streamers report only applied damage, including lethal hits, with no duplicate kill", () => {
  const emitted = [],
    spawned = [],
    object = { state: {}, anim: {} };
  const ctx = {
    getObject: () => object,
    now: () => 1000,
    spawn: (spec) => spawned.push(spec),
    emit: (name, payload) => emitted.push({ name, payload }),
  };
  const run = {},
    source = { id: "pet", element: "grass", cadence: 1 },
    target = { id: "enemy", hp: 20, x: 0, z: 0 };
  assert.deepEqual(combatHit(ctx, run, source, target, 7.5, data, config), {
    amount: 7.5,
    killed: false,
  });
  assert.equal(spawned[0].state.amount, 7.5);
  assert.equal(target.hp, 12.5);
  assert.equal(source.attackSeq, 1);
  assert.deepEqual(combatHit(ctx, run, source, target, 50, data, config), {
    amount: 12.5,
    killed: true,
  });
  assert.equal(spawned[1].state.amount, 12.5);
  assert.equal(source.attackSeq, 2);
  assert.equal(object.state.hp, 0);
  assert.deepEqual(combatHit(ctx, run, source, target, 50, data, config), {
    amount: 0,
    killed: false,
  });
  assert.equal(spawned.length, 2);
  assert.equal(emitted.filter((e) => e.name === "fx").length, 3);
  for (const marker of spawned)
    assert.equal(
      marker.lifetime,
      data.presentation.combatText.duration + config.text.retentionPadding,
    );
});
test("walk and attack are separate; swings are once per real hit and restart on a distinct channel", () => {
  const object = { state: {}, anim: {} },
    ctx = { getObject: () => object };
  const actor = { id: "pet", cadence: 1, attackSeq: 1, attackVisualUntil: 2 };
  presentActor(ctx, actor, 1, 0, assets.doggy, data, config);
  assert.equal(object.anim.swing1.clip, "Attack");
  assert.equal(object.anim.swing1.loop, "once");
  assert.equal(object.anim.locomotion.weight, 0);
  actor.attackSeq = 2;
  actor.attackVisualUntil = 3;
  presentActor(ctx, actor, 2, 0, assets.doggy, data, config);
  assert.equal(object.anim.swing1, undefined);
  assert.equal(object.anim.swing0.clip, "Attack");
  presentActor(ctx, actor, 4, 1, assets.doggy, data, config);
  assert.equal(object.anim.swing0, undefined);
  assert.equal(object.anim.locomotion.clip, "Walk");
  assert.ok(object.anim.locomotion.speed > 0);
  presentActor(ctx, actor, 5, 0, assets.doggy, data, config);
  assert.equal(object.anim.locomotion.speed, 0);
  for (const element of ["grass", "ice", "lava", "desert"])
    assert.equal(effectProgram(data, config, element).includes("{"), false);
});
