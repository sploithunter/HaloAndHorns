// Numeric ports of PetFormation.attackOffset, PetAttackMotion and HitReact.
// Distances stay in source studs here; convert only when composing the rendered pose.
const PI = Math.PI,
  TAU = 2 * PI;
export function attackOffset(index, count, phase, a) {
  const n = Math.max(count, 1),
    i = index - 1,
    R = a.ring_radius,
    height = a.ring_height;
  if (a.style === "spiral") {
    const t = n > 1 ? i / (n - 1) : 0,
      spin =
        a.spiral_inner_speed +
        (a.spiral_outer_speed - a.spiral_inner_speed) * t;
    const angle = t * a.spiral_turns * TAU + phase * spin,
      r = R * (0.35 + 0.65 * t);
    return {
      x: r * Math.cos(angle),
      y: height + a.spiral_rise * t,
      z: r * Math.sin(angle),
    };
  }
  if (a.style === "pincer") {
    const half = Math.ceil(n / 2),
      first = i < half,
      k = first ? i : i - half,
      cnt = first ? half : n - half;
    const spread = cnt > 1 ? k / (cnt - 1) - 0.5 : 0,
      angle = (first ? 0 : PI) + (spread * a.pincer_arc * PI) / 180;
    const r =
      R - a.pincer_squeeze * (0.5 + 0.5 * Math.sin(phase * a.pincer_speed));
    return { x: r * Math.cos(angle), y: height, z: r * Math.sin(angle) };
  }
  if (a.style === "firing_line")
    return {
      x: (i - (n - 1) / 2) * a.line_spacing,
      y: height,
      z:
        -R +
        a.line_recoil * Math.max(0, Math.sin(phase * a.line_speed - i * 0.5)),
    };
  if (a.style === "swarm") {
    const rad = R * a.swarm_radius_frac;
    return {
      x:
        (Math.sin((i + 1) * 12.9898) * 0.6 +
          Math.sin(phase * a.swarm_speed + i * 2.1) * 0.4) *
        rad,
      y: height + Math.sin(phase * 4 + i) * a.swarm_bob,
      z:
        (Math.sin((i + 1) * 78.233) * 0.6 +
          Math.cos(phase * a.swarm_speed + i * 1.7) * 0.4) *
        rad,
    };
  }
  const angle =
    (i / n) * TAU +
    (a.angle_offset ?? 0) +
    (a.style === "orbit" ? phase * a.orbit_speed : 0);
  const r =
    R -
    (a.style === "lunge"
      ? a.lunge_distance * (0.5 + 0.5 * Math.sin(phase * a.lunge_speed + i))
      : 0);
  return { x: r * Math.cos(angle), y: height, z: r * Math.sin(angle) };
}
export function strikeProfile(data, role, petType) {
  const cfg = data.presentation.attack.strike_motion;
  return {
    ...data.presentation.strikeDefaults,
    ...cfg.default,
    ...cfg.roles[role],
    ...cfg.by_type[petType],
    enabled: cfg.enabled !== false,
  };
}
export function strikeSample(p, elapsed) {
  const zero = { forward: 0, height: 0, pitch: 0, yaw: 0, roll: 0 };
  if (
    !p?.enabled ||
    p.style === "none" ||
    elapsed >= p.duration ||
    p.duration <= 0
  )
    return zero;
  const t = Math.max(0, elapsed) / p.duration,
    decay = (1 - t) ** 2,
    rebound = Math.sin(PI * t) * (1 - t),
    wave = Math.sin(TAU * t) * (1 - t);
  if (p.style === "lunge")
    return {
      forward: p.depth * decay - p.recoil * rebound,
      height: p.height * Math.sin(PI * t),
      pitch: p.pitch * decay,
      yaw: p.yaw * wave,
      roll: p.roll * wave,
    };
  if (p.style === "slam")
    return {
      forward: p.depth * decay - p.recoil * rebound,
      height: -p.drop * decay + p.height * rebound,
      pitch: p.pitch * decay,
      yaw: p.yaw * rebound,
      roll: p.roll * wave,
    };
  if (p.style === "recoil")
    return {
      forward: -p.recoil * decay,
      height: p.height * rebound,
      pitch: -p.pitch * decay,
      yaw: p.yaw * wave,
      roll: p.roll * wave,
    };
  if (p.style === "cast")
    return {
      forward: p.depth * rebound,
      height: p.height * Math.sin(PI * t),
      pitch: p.pitch * rebound,
      yaw: p.yaw * wave,
      roll: p.roll * wave,
    };
  return zero;
}
export function advanceSidestep(angle, p, equipSlot) {
  const step =
    ((Math.max(-45, Math.min(45, p.sidestep_degrees)) * PI) / 180) *
    (equipSlot % 2 === 1 ? 1 : -1);
  return (((angle + step) % TAU) + TAU) % TAU;
}
export function renderedPose(pose, now, data) {
  const scale = data.tuning.scene.sourceTransform.metersPerStud;
  const strike = strikeSample(
    strikeProfile(data, pose.role, pose.petType),
    pose.strikeAt == null ? Infinity : now - pose.strikeAt,
  );
  const reaction = data.presentation.hitReact,
    k =
      pose.reactAt == null
        ? 0
        : Math.max(0, 1 - (now - pose.reactAt) / reaction.duration);
  const yaw = ((pose.yaw ?? 0) * PI) / 180;
  return {
    feetPosition: {
      x:
        pose.x -
        Math.sin(yaw) * strike.forward * scale +
        (pose.reactDx ?? 0) * reaction.recoil * k * scale,
      y: data.tuning.scene.groundY + strike.height * scale,
      z:
        pose.z -
        Math.cos(yaw) * strike.forward * scale +
        (pose.reactDz ?? 0) * reaction.recoil * k * scale,
    },
    rotation: {
      yaw:
        (pose.yaw ?? 0) +
        ((strike.yaw + (pose.reactYaw ?? 0) * reaction.yaw * k) * 180) / PI,
      pitch: (strike.pitch * 180) / PI,
      roll: (strike.roll * 180) / PI,
    },
  };
}
// Stable target groups: no frame-by-frame nearest-target swaps or cosmetic offsets in combat math.
export function assignAttackSlots(pets, enemies, now, data, config) {
  const live = enemies.filter((e) => e.hp > 0),
    groups = new Map(),
    scale = data.tuning.scene.sourceTransform.metersPerStud;
  for (const pet of pets) {
    if (pet.hp <= 0) continue;
    let target = live.find((e) => e.id === pet.targetId);
    if (
      target &&
      Math.hypot(target.x - pet.x, target.z - pet.z) >
        data.tuning.simulation.engageDistance
    )
      target = null;
    if (!target) {
      let nearest = data.tuning.simulation.engageDistance;
      for (const enemy of live) {
        const d = Math.hypot(enemy.x - pet.x, enemy.z - pet.z);
        if (d < nearest) {
          target = enemy;
          nearest = d;
        }
      }
    }
    if (pet.targetId !== target?.id) {
      pet.targetId = target?.id ?? null;
      pet.strikeAngle = 0;
      pet.strikeTarget = null;
    }
    const profile = strikeProfile(data, pet.role, pet.petType);
    if (
      pet.strikeAt != null &&
      !pet.sidestepDone &&
      now - pet.strikeAt >= profile.duration
    ) {
      if (pet.strikeTarget === pet.targetId)
        pet.strikeAngle = advanceSidestep(
          pet.strikeAngle ?? 0,
          profile,
          pet.equipSlot,
        );
      pet.sidestepDone = true;
    }
    if (target) {
      const group = groups.get(target.id) ?? { target, pets: [] };
      group.pets.push(pet);
      groups.set(target.id, group);
    } else pet.goal = pet.home;
  }
  const attack = data.presentation.attack;
  for (const { target, pets: group } of groups.values()) {
    group.sort(
      (a, b) =>
        config.rolePriority[a.role] - config.rolePriority[b.role] ||
        a.equipSlot - b.equipSlot,
    );
    // Keep imported bodies apart when several hatchers focus one target. The source radius is
    // the minimum; the chord length uses the source formation footprint, rather than mesh overlap.
    const radius = Math.max(
      attack.ring_radius,
      group.length > 1
        ? data.presentation.formation.size.default_footprint /
            (2 * Math.sin(PI / group.length))
        : 0,
    );
    const anchor = {
      x: group.reduce((s, p) => s + p.home.x, 0) / group.length,
      z: group.reduce((s, p) => s + p.home.z, 0) / group.length,
    };
    const pole =
        Math.atan2(anchor.z - target.z, anchor.x - target.x) +
        (attack.combat_ring_zero === "away_from_player" ? PI : 0),
      ca = Math.cos(pole),
      sa = Math.sin(pole);
    group.forEach((pet, index) => {
      const role = data.presentation.roles.roles[pet.role],
        style =
          attack.mode.combat === "individual"
            ? (attack.role_styles[pet.role] ?? attack.style)
            : attack.style;
      const off = attackOffset(index + 1, group.length, now, {
        ...attack,
        style,
        ring_radius: radius,
        angle_offset: pet.strikeAngle ?? 0,
      });
      const gap = Math.hypot(off.x, off.z),
        push = gap > 0 ? (gap + role.standoff) / gap : 1;
      pet.goal = {
        x: target.x + (off.x * ca - off.z * sa) * scale * push,
        z: target.z + (off.x * sa + off.z * ca) * scale * push,
      };
      pet.reach = Math.max(
        role.attack_range * scale,
        radius * scale + config.slotArrivalTolerance,
      );
    });
  }
}
