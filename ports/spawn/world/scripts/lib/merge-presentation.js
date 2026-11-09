// One authoritative resolved hit drives strike, flinch, damage stream and elemental impact.
export const rgbHex = (values) =>
  "#" +
  values
    .map((v) =>
      Math.max(0, Math.min(255, Math.round(v)))
        .toString(16)
        .padStart(2, "0"),
    )
    .join("");
export function effectProgram(data, config, element, kind = "impact") {
  const colors =
    data.presentation.melee[element]?.colors ??
    data.presentation.melee.grass.colors;
  const sink = config.elementSinks[element] ?? config.elementSinks.grass;
  const values = {
    r: colors[0][0] / 255,
    g: colors[0][1] / 255,
    b: colors[0][2] / 255,
    ...sink,
  };
  return config[kind + "Template"].replace(/\{(\w+)\}/g, (_, key) =>
    String(values[key]),
  );
}
export function combatHit(ctx, run, source, target, rawDamage, data, config) {
  if (!(target.hp > 0)) return { amount: 0, killed: false };
  const amount = Math.min(target.hp, Math.max(0, rawDamage));
  if (!(amount > 0)) return { amount: 0, killed: false };
  target.hp = Math.max(0, target.hp - amount);
  const now = ctx.now() / 1000;
  source.attackSeq = (source.attackSeq ?? 0) + 1;
  source.strikeAt = now;
  source.strikeTarget = target.id;
  source.sidestepDone = false;
  const dx = target.x - source.x,
    dz = target.z - source.z,
    gap = Math.hypot(dx, dz);
  target.reactAt = now;
  target.reactDx = gap > 0 ? dx / gap : 0;
  target.reactDz = gap > 0 ? dz / gap : 0;
  target.reactYaw = source.attackSeq % 2 ? 1 : -1;
  source.attackVisualUntil =
    ctx.now() / 1000 + source.cadence * config.animation.attackCadenceShare;
  const targetObject = ctx.getObject(target.id);
  if (targetObject) targetObject.state.hp = target.hp;
  publishPose(ctx, source);
  publishPose(ctx, target);
  const element = source.element ?? "lava",
    position = { x: target.x, y: config.text.height, z: target.z };
  const text = data.presentation.combatText;
  const serial = (run.hitSerial = (run.hitSerial ?? 0) + 1);
  if (text.enabled)
    ctx.spawn({
      id: `hh-hit-${Math.floor(ctx.now())}-${serial}`,
      feetPosition: {
        ...position,
        x: position.x + (((serial % 5) - 2) * config.text.spread) / 2,
      },
      render: false,
      lifetime: text.duration + config.text.retentionPadding,
      tags: [config.text.tag],
      state: {
        amount,
        duration: text.duration,
        rise: text.rise * data.tuning.scene.sourceTransform.metersPerStud,
        color: rgbHex(text.colors.normal),
        size: text.size,
        source: source.id,
        target: target.id,
      },
    });
  ctx.emit(
    "fx",
    {
      position,
      script: effectProgram(data, config, element),
      tags: ["hh-hit-fx"],
    },
    { audience: { kind: "all" } },
  );
  if (target.hp > 0)
    ctx.emit(
      "flash",
      {
        target: target.id,
        color: rgbHex(
          data.presentation.melee[element]?.colors[0] ??
            data.presentation.melee.lava.colors[0],
        ),
        ...config.flash,
      },
      { audience: { kind: "all" } },
    );
  else
    ctx.emit(
      "fx",
      {
        position,
        script: effectProgram(data, config, element, "death"),
        tags: ["hh-hit-fx"],
      },
      { audience: { kind: "all" } },
    );
  return { amount, killed: target.hp === 0 };
}
export function presentActor(ctx, actor, now, moved, asset, data, config) {
  const object = ctx.getObject(actor.id);
  if (!object) return;
  if (actor.assetUrl !== asset.url) {
    object.model = asset.url;
    actor.assetUrl = asset.url;
    actor.visualMode = null;
  }
  const mode =
    now < (actor.attackVisualUntil ?? 0)
      ? "attack"
      : moved > config.animation.motionEpsilon
        ? "walk"
        : "idle";
  if (mode === "attack") {
    if (actor.visualSeq !== actor.attackSeq) {
      const channel = "swing" + (actor.attackSeq % 2),
        previous = "swing" + (1 - (actor.attackSeq % 2));
      delete object.anim[previous];
      object.anim.locomotion = {
        clip: asset.clips.walk,
        loop: "loop",
        speed: 0,
        weight: 0,
      };
      object.anim[channel] = {
        clip: asset.clips.attack,
        loop: "once",
        speed:
          asset.attackSeconds /
          (actor.cadence * config.animation.attackCadenceShare),
        weight: 1,
        blendIn: data.presentation.animation.fade,
        blendOut: data.presentation.animation.fade,
      };
      object.state.attackSeq = actor.attackSeq;
      actor.visualSeq = actor.attackSeq;
    }
  } else if (actor.visualMode !== mode) {
    delete object.anim.swing0;
    delete object.anim.swing1;
    object.anim.locomotion = {
      clip: asset.clips.walk,
      loop: "loop",
      speed: mode === "walk" ? config.animation.walkSpeed : 0,
      weight: 1,
      blendIn: data.presentation.animation.fade,
    };
  }
  actor.visualMode = mode;
}
export function faceTarget(ctx, actor, target) {
  const dx = target.x - actor.x,
    dz = target.z - actor.z;
  if (Math.hypot(dx, dz) > 0.001)
    actor.yaw = (Math.atan2(-dx, -dz) * 180) / Math.PI;
}

export function publishPose(ctx, actor) {
  const object = ctx.getObject(actor.id);
  if (!object) return;
  const pose = {
    x: actor.x,
    z: actor.z,
    yaw: actor.yaw ?? 0,
    role: actor.role,
    petType: actor.petType,
    strikeAt: actor.strikeAt ?? null,
    reactAt: actor.reactAt ?? null,
    reactDx: actor.reactDx ?? 0,
    reactDz: actor.reactDz ?? 0,
    reactYaw: actor.reactYaw ?? 0,
  };
  const stamp = JSON.stringify(pose);
  if (actor.poseStamp !== stamp) {
    object.state.pose = pose;
    actor.poseStamp = stamp;
  }
}
