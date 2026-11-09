// Every lit surface in this world is shaded by this one function. The engine hands it the surface
// and the lights that reach it — the sun with its shadow, every placed light with its falloff and
// shadow, the sky's ambient — and takes back a color. This file is the standard model (Cook-Torrance
// GGX + Lambert, the math a PBR engine runs). Edit a line and every surface follows; delete one and
// see what it did. Toon, flat, hatching: the "looks" skill shows each as a few edits of this file.
import { dot, max, mix, normalize, pow, clamp, float, vec3, oneMinus, PI } from "builtin/tsl";

export function lighting(surface, lights) {
  const { albedo, normal: N, view: V, roughness, metalness } = surface;
  // f0: how much a surface reflects head-on — 4% for anything that is not metal, its own color for metal.
  const f0 = mix(vec3(0.04), albedo, metalness);

  // One call per light that reaches this point. light.direction points at the light; light.radiance is
  // its color × intensity after falloff and shadow (light.color and light.shadow are the two halves);
  // light.specular is the share of it the highlight takes (1 unless the light sets less).
  const direct = lights.each((light) => {
    const L = light.direction;
    const NdotL = max(dot(N, L), 0);
    const H = normalize(V.add(L));
    const NdotV = max(dot(N, V), 1e-4);
    const NdotH = max(dot(N, H), 0);
    // D — how tight the highlight is (GGX).
    const a = roughness.mul(roughness);
    const a2 = a.mul(a);
    const d = NdotH.mul(NdotH).mul(a2.sub(1)).add(1);
    const D = a2.div(max(PI.mul(d).mul(d), 1e-6));
    // G — the microfacets shadowing each other (Smith).
    const r = roughness.add(1);
    const k = r.mul(r).div(8);
    const G = NdotV.div(NdotV.mul(oneMinus(k)).add(k)).mul(NdotL.div(NdotL.mul(oneMinus(k)).add(k)));
    // F — more reflection at grazing angles (Schlick).
    const F = f0.add(oneMinus(f0).mul(pow(clamp(oneMinus(max(dot(H, V), 0)), 0, 1), 5)));
    const specular = D.mul(G).mul(F).div(max(float(4).mul(NdotV).mul(NdotL), 1e-4));
    // What fresnel did not reflect scatters as diffuse; metal has no diffuse.
    const diffuse = oneMinus(F).mul(oneMinus(metalness)).mul(albedo).div(PI);
    return diffuse.add(specular.mul(light.specular)).mul(light.radiance).mul(NdotL);
  });

  // The sky and the ambient, on the diffuse and on f0; the environment reflection the engine folded for this surface.
  const ambient = albedo.mul(oneMinus(metalness)).add(f0).mul(lights.ambient).mul(1 / Math.PI);
  return direct.add(ambient.add(lights.environment).mul(surface.occlusion));
}
