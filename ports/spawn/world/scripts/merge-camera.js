import DATA from './lib/data/merge.yml';
export function onInput(ctx, input) {
  const cfg = DATA.tuning.scene.camera, s = ctx.self.state;
  s.yaw = (s.yaw ?? cfg.yaw) - (input.axes.lookX ?? 0) * cfg.sensitivity;
  s.pitch = Math.max(-1.1, Math.min(0.6, (s.pitch ?? cfg.pitch) - (input.axes.lookY ?? 0) * cfg.sensitivity));
  s.distance = Math.max(cfg.minDistance, Math.min(cfg.maxDistance, (s.distance ?? cfg.distance) - (input.axes.zoomIn ?? 0) * cfg.zoomSensitivity));
}
export function update(ctx) {
  const target = ctx.self.target; if (!target) return;
  const cfg = DATA.tuning.scene.camera, s = ctx.self.state, f = target.feetPosition;
  const yaw = s.yaw ?? cfg.yaw, pitch = s.pitch ?? cfg.pitch, distance = s.distance ?? cfg.distance;
  ctx.self.feetPosition = { x: f.x + Math.sin(yaw) * Math.cos(pitch) * distance, y: f.y + cfg.height - Math.sin(pitch) * distance, z: f.z + Math.cos(yaw) * Math.cos(pitch) * distance };
  ctx.self.rotation = { lookAt: { x: f.x, y: f.y + cfg.aimHeight, z: f.z }, include: ['yaw', 'pitch'] };
  ctx.self.hideLocalPlayer = false;
}
