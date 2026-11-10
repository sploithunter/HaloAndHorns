import { MeshStandardNodeMaterial } from 'builtin/three';
import { positionWorld, mx_noise_vec3, mx_worley_noise_float, mix, color, smoothstep } from 'builtin/tsl';
export function material(ctx) {
  const p = positionWorld.mul(ctx.param('scale', 1));
  const warped = p.add(mx_noise_vec3(p.mul(ctx.param('warpScale', 1))).mul(ctx.param('warp', 1)));
  const vein = smoothstep(ctx.param('veinStart', 0.6), ctx.param('veinEnd', 0.8), mx_worley_noise_float(warped));
  const m = new MeshStandardNodeMaterial();
  m.colorNode = mix(color(ctx.params.base), color(ctx.params.vein), vein);
  m.roughness = ctx.params.roughness;
  return m;
}
