import DATA from "./lib/data/merge.yml";
import COMBAT from "./lib/data/combat.yml";
import { renderedPose } from "./lib/merge-choreography.js";

export const updateSchedule = { every: { seconds: COMBAT.poseStep } };
export function update(ctx) {
  const pose = ctx.self.state.pose;
  if (!pose) return;
  const rendered = renderedPose(pose, ctx.now() / 1000, DATA);
  ctx.self.feetPosition = rendered.feetPosition;
  ctx.self.rotation = rendered.rotation;
}
