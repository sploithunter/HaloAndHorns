import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import {
  attackOffset,
  strikeProfile,
  strikeSample,
  advanceSidestep,
  renderedPose,
  assignAttackSlots,
} from "../world/scripts/lib/merge-choreography.js";
const read = (name) =>
  JSON.parse(fs.readFileSync(new URL(name, import.meta.url)));
const data = read("../world/scripts/lib/data/merge.yml"),
  config = read("../world/scripts/lib/data/combat.yml"),
  fixtures = read("./fixtures.json");
function near(actual, expected, path = "") {
  if (typeof expected === "object")
    for (const key of Object.keys(expected))
      near(actual[key], expected[key], path + "." + key);
  else
    assert.ok(
      Math.abs(actual - expected) < 1e-9,
      `${path}: ${actual} != ${expected}`,
    );
}
test("all seven formations match the actual Roblox PetFormation module (273 fixtures)", () => {
  for (const f of fixtures.formations)
    near(
      attackOffset(f.index, f.count, f.phase, {
        ...data.presentation.attack,
        style: f.style,
        angle_offset: f.angle,
      }),
      f.result,
      f.style,
    );
});
test("all five role strikes, starter overrides and alternating sidesteps match Roblox", () => {
  for (const f of fixtures.strikes) {
    const profile = strikeProfile(data, f.role, f.petType);
    near(strikeSample(profile, f.elapsed), f.result, f.role);
    near(advanceSidestep(0.2, profile, 1), f.sidestepOdd);
    near(advanceSidestep(0.2, profile, 2), f.sidestepEven);
  }
});
test("contact/recovery and received flinch leave the authoritative formation pose clean", () => {
  const pose = {
      x: 3,
      z: 5,
      yaw: 0,
      role: "melee",
      petType: "doggy",
      strikeAt: 10,
      reactAt: 10,
      reactDx: 1,
      reactDz: 0,
      reactYaw: 1,
    },
    before = structuredClone(pose);
  const contact = renderedPose(pose, 10, data),
    settled = renderedPose(pose, 11, data),
    scale = data.tuning.scene.sourceTransform.metersPerStud;
  near(contact.feetPosition.z, pose.z - 3.15 * scale);
  near(contact.feetPosition.x, pose.x + 1.1 * scale);
  near(settled.feetPosition, { x: 3, y: data.tuning.scene.groundY, z: 5 });
  near(settled.rotation, { yaw: 0, pitch: 0, roll: 0 });
  assert.deepEqual(pose, before);
});
test("pets retain live targets, occupy distinct slots, sidestep once, and reset on retarget", () => {
  const pets = Array.from({ length: 9 }, (_, i) => ({
    id: "p" + i,
    equipSlot: i + 1,
    role: "melee",
    petType: "doggy",
    hp: 100,
    x: 0,
    z: 4,
    home: { x: 0, z: 8 },
  }));
  const enemies = [
    { id: "e1", x: 0, z: 0, hp: 100 },
    { id: "e2", x: 2, z: 0, hp: 100 },
  ];
  assignAttackSlots(pets, enemies, 0, data, config);
  assert.equal(new Set(pets.map((p) => JSON.stringify(p.goal))).size, 9);
  for (let i = 0; i < 9; i++)
    for (let j = i + 1; j < 9; j++)
      assert.ok(
        Math.hypot(
          pets[i].goal.x - pets[j].goal.x,
          pets[i].goal.z - pets[j].goal.z,
        ) >=
          data.presentation.formation.size.default_footprint *
            data.tuning.scene.sourceTransform.metersPerStud -
            1e-9,
      );
  enemies[1].x = 0;
  enemies[1].z = 3.9;
  assignAttackSlots(pets, enemies, 0.1, data, config);
  assert.ok(
    pets.every((p) => p.targetId === "e1"),
    "a newly closer foe does not reshuffle engaged pets",
  );
  pets[0].strikeAt = 0;
  pets[0].strikeTarget = "e1";
  pets[0].sidestepDone = false;
  assignAttackSlots(pets, enemies, 1, data, config);
  const angle = pets[0].strikeAngle;
  assert.ok(angle > 0);
  assignAttackSlots(pets, enemies, 2, data, config);
  assert.equal(pets[0].strikeAngle, angle);
  enemies[0].hp = 0;
  assignAttackSlots(pets, enemies, 3, data, config);
  assert.ok(pets.every((p) => p.targetId === "e2" && p.strikeAngle === 0));
});
