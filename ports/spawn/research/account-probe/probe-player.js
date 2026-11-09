// Isolated assessment fixture: artificial account and reward, never production gameplay.
export function onInput(ctx, input) {
  if (input.pressed.probeReward)
    ctx.emit("ui:probe-reward", { by: ctx.self.id }, { to: "probe-reward" });
  if (input.pressed.probeFarm) ctx.cross(ctx.self, "+farm_probe");
  if (input.pressed.probeMain) ctx.cross(ctx.self, "+main");
  if (input.pressed.probeEphemeral)
    ctx.cross(ctx.self, "+farm_ephemeral_probe");
}
